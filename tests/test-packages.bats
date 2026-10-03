#!/usr/bin/env bats
#
# test-packages.bats — hermetic tests for the shared install primitives
# in bin/utils.sh: the apt fast path (skip when everything is installed)
# and the runnable-binary probe (broken shims count as missing).

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"
    unset _DOT_NO_PACKAGES
    export PATH="$STUBBIN:/usr/bin:/bin"

    # dpkg-query stub: packages in $DPKG_MISSING report as absent.
    cat >"$STUBBIN/dpkg-query" <<'EOF'
#!/usr/bin/env bash
name="${@: -1}"
for bad in ${DPKG_MISSING:-}; do
    if [[ "$name" == "$bad" ]]; then
        exit 1
    fi
done
printf 'install ok installed\n'
EOF
    chmod +x "$STUBBIN/dpkg-query"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/utils.sh"
    set +u
    _priv() { printf 'PRIV:%s\n' "$*" >>"$CALLS"; return 0; }
}

@test "packages: skips apt entirely when all are installed" {
    run _install_packages 'curl ca-certificates'
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message' 'already installed' "$output"
    assert_eq 'no privilege calls' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
}

@test "packages: proceeds when anything is missing" {
    export DPKG_MISSING="ca-certificates"
    run _install_packages 'curl ca-certificates'
    assert_eq 'install rc 0' '0' "$status"
    assert_contains 'apt update attempted' 'apt-get update' "$(cat "$CALLS")"
    unset DPKG_MISSING
}

@test "packages: no-packages flag short-circuits everything" {
    export _DOT_NO_PACKAGES=1 DPKG_MISSING="curl ca-certificates"
    run _install_packages 'curl ca-certificates'
    assert_eq 'flag rc 0' '0' "$status"
    assert_eq 'no privilege calls' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
    unset _DOT_NO_PACKAGES DPKG_MISSING
}

@test "runnable: true for a working binary" {
    cat >"$STUBBIN/good" <<'EOF'
#!/usr/bin/env bash
echo "good 1.0"
EOF
    chmod +x "$STUBBIN/good"
    run _is_runnable good
    assert_eq 'working rc 0' '0' "$status"
}

@test "runnable: false for a broken shim on PATH" {
    cat >"$STUBBIN/broken" <<'EOF'
#!/usr/bin/env bash
echo "broken shim" >&2
exit 1
EOF
    chmod +x "$STUBBIN/broken"
    run _is_runnable broken
    assert_eq 'broken rc 1' '1' "$status"
}

@test "runnable: false for a missing binary" {
    run _is_runnable 'definitely-not-a-real-binary'
    assert_eq 'missing rc 1' '1' "$status"
}
