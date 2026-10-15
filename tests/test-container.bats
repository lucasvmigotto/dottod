#!/usr/bin/env bats
#
# test-container.bats — tests for scripts/.container.utils.sh + bin/container.sh.
#
# Hermetic: stub podman binary on a prepended PATH, real subid
# fixture files via overrides, _DOT_NO_PACKAGES=1 so no apt call is
# possible. Privilege safety: _priv is redefined to record-only (it never
# executes anything), so usermod paths are asserted without touching
# the system. There is deliberately NO getent stub (see subid tests).

load helpers

setup() {
    STUBBIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"

    cat >"$STUBBIN/podman" <<'EOF'
#!/usr/bin/env bash
echo "podman $*" >>"${STUB_CALLS}"
case "${1:-}" in
    info) exit "${PODMAN_STUB_INFO_RC:-0}" ;;
    --version) printf 'podman version %s\n' "${PODMAN_STUB_VERSION:-5.4.2}"; exit 0 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$STUBBIN/podman"

    FIXUID="$(id -un)"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subuid"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subgid"

    export STUB_CALLS="$CALLS"
    export _DOT_NO_PACKAGES=1
    export PODMAN_STUB_INFO_RC=0 PODMAN_STUB_VERSION=5.4.2
    export _DOT_CONTAINER_SUBUID_FILE="$BATS_TEST_TMPDIR/subuid"
    export _DOT_CONTAINER_SUBGID_FILE="$BATS_TEST_TMPDIR/subgid"
    export PATH="$STUBBIN:$PATH"

    # container.sh brings utils.sh, whose EXIT trap replaces bats' own:
    # save and re-arm it. Errexit stays on so a failing assertion aborts
    # and is reported (with `set +e`, every assertion but the last could
    # fail silently); only nounset is relaxed for bats internals.
    local _bats_exit_trap
    _bats_exit_trap="$(trap -p EXIT)"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.container.utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../bin/container.sh"
    eval "${_bats_exit_trap}"
    set +u

    # Privilege safety: record-only, never executes.
    _priv() {
        printf 'PRIV:%s\n' "$*" >>"$CALLS"
        return "${PRIV_STUB_RC:-0}"
    }
}

@test "installed, version and usability probes" {
    _ctr_installed
    assert_eq 'podman installed rc' '0' "$?"
    assert_eq 'podman version' '5.4.2' "$(_ctr_version)"
    _ctr_usable
    assert_eq 'podman usable rc' '0' "$?"
    export PODMAN_STUB_INFO_RC=1
    run _ctr_usable
    assert_eq 'unusable podman fails' '1' "$status"
}

@test "ctr dispatches to podman" {
    run ctr ps -a
    assert_contains 'ctr dispatches to podman' 'podman ps -a' "$(cat "$CALLS")"
}

@test "subid lookup reads real files without stubs" {
    _podman_have_subids "$FIXUID"
    assert_eq 'subids present rc 0' '0' "$?"
    printf 'other:200000:65536\n' >"$BATS_TEST_TMPDIR/subuid"
    run _podman_have_subids "$FIXUID"
    assert_eq 'user missing from subuid rc 1' '1' "$status"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subuid"
    rm -f "$BATS_TEST_TMPDIR/subgid"
    run _podman_have_subids "$FIXUID"
    assert_eq 'subgid file absent rc 1' '1' "$status"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subgid"
    printf 'garbage-without-colon\n' >"$BATS_TEST_TMPDIR/subuid"
    run _podman_have_subids "$FIXUID"
    assert_eq 'malformed subuid rc 1' '1' "$status"
}

@test "ensure is a no-op when podman is usable" {
    : >"$CALLS"
    _podman_ensure >/dev/null
    assert_eq 'ready rc 0' '0' "$?"
    assert_eq 'ready makes no priv calls' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
}

@test "ensure fails loudly when podman is missing" {
    # Absence through the probes, not PATH: hiding the stub let a host
    # /usr/bin/podman answer instead (this test passed for the wrong
    # reason while the suite ran with errexit off).
    _ctr_installed() { return 1; }
    _ctr_usable() { return 1; }
    run _podman_ensure
    assert_eq 'missing podman rc 1' '1' "$status"
    assert_eq 'no priv calls on missing' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
}

@test "ensure attempts usermod exactly once when subids are missing" {
    printf '' >"$BATS_TEST_TMPDIR/subuid"
    export PODMAN_STUB_INFO_RC=1
    run _podman_ensure
    assert_eq 'subid path rc 1 (still unusable)' '1' "$status"
    assert_eq 'usermod attempted once' '1' "$(grep -c '^PRIV:.*usermod' "$CALLS" || true)"
}

@test "status reports podman fields" {
    out="$(_container_status)"
    assert_contains 'status podman ver' 'Podman:     installed 5.4.2' "$out"
    assert_contains 'status rootless' 'Rootless:   yes' "$out"
    export PODMAN_STUB_INFO_RC=1
    out="$(_container_status)"
    assert_contains 'status not rootless' 'Rootless:   no' "$out"
}

@test "repeated ensure makes no privileged calls" {
    : >"$CALLS"
    _podman_ensure >/dev/null
    _podman_ensure >/dev/null
    assert_eq 'double ensure makes no priv calls' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
}
