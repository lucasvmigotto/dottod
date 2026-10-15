#!/usr/bin/env bats
#
# test-packages.bats — hermetic tests for lib/package.sh behind
# _install_packages (bin/utils.sh), plus the runnable-binary probe.
#
# Every package manager and query tool is a stub on a sealed PATH; the
# distro comes from an os-release fixture (_DOT_OS_RELEASE_FILE). _priv
# records argv and never executes, except in the lock test, which runs
# the stubbed manager to observe interleaving. Packages listed in
# $MISSING report as not installed in every backend's query stub.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    FIX="${BATS_TEST_DIRNAME}/fixtures/os-release"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"
    unset _DOT_NO_PACKAGES MISSING DOT_RUN_ID _DOT_PKG_READY
    export PATH="$STUBBIN:/usr/bin:/bin"

    # Query stubs: the queried package is the last argument.
    local q
    for q in dpkg-query portageq rpm; do
        cat >"$STUBBIN/$q" <<'EOF'
#!/usr/bin/env bash
name="${@: -1}"
for bad in ${MISSING:-}; do [[ "$name" == "$bad" ]] && exit 1; done
[[ "$(basename "$0")" == dpkg-query ]] && printf 'install ok installed\n'
exit 0
EOF
    done
    # pacman/apk/apt-cache/dnf answer queries and record everything else.
    cat >"$STUBBIN/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -Q) for bad in ${MISSING:-}; do [[ "$2" == "$bad" ]] && exit 1; done; exit 0 ;;
    -Si) printf 'Repository      : extra\nName            : %s\nVersion         : 0.11.4-1\n' "$2"; exit 0 ;;
esac
echo "pacman $*" >>"$CALLS"
EOF
    cat >"$STUBBIN/apk" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    info) for bad in ${MISSING:-}; do [[ "$3" == "$bad" ]] && exit 1; done; exit 0 ;;
    policy) printf '%s policy:\n  0.11.1-r0:\n    https://dl-cdn.alpinelinux.org/alpine/v3.22/community\n' "$2"; exit 0 ;;
esac
echo "apk $*" >>"$CALLS"
EOF
    cat >"$STUBBIN/apt-cache" <<'EOF'
#!/usr/bin/env bash
printf '%s:\n  Installed: (none)\n  Candidate: %s\n' "$2" "${APT_CANDIDATE:-1:0.10.4-3}"
EOF
    cat >"$STUBBIN/dnf" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == repoquery ]] && { printf '0.11.3\n'; exit 0; }
echo "dnf $*" >>"$CALLS"
EOF
    for q in apt-get emerge; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"$CALLS"\n' "$q" >"$STUBBIN/$q"
    done
    printf '#!/usr/bin/env bash\nexec "$@"\n' >"$STUBBIN/env"
    chmod +x "$STUBBIN"/*
    ln -s /usr/bin/flock "$STUBBIN/flock" 2>/dev/null || true

    use_os debian

    # utils.sh replaces bats' EXIT trap (_sudo_cleanup); re-arm it so a
    # failed assertion is reported instead of vanishing.
    local _bats_exit_trap
    _bats_exit_trap="$(trap -p EXIT)"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/utils.sh"
    eval "${_bats_exit_trap}"
    set +u
    _priv() { printf 'PRIV:%s\n' "$*" >>"$CALLS"; return "${PRIV_RC:-0}"; }
}

use_os() {
    export _DOT_OS_RELEASE_FILE="${FIX}/${1}"
    unset _DOT_PKG_READY
}

# install_as <family>: install curl+jq with jq missing; prints the PRIV lines.
install_as() {
    use_os "$1"
    : >"$CALLS"
    MISSING=jq run _install_packages curl jq
    grep '^PRIV:' "$CALLS" || true
}

@test "each backend installs only what is missing, with exact argv" {
    assert_eq 'debian' $'PRIV:env DEBIAN_FRONTEND=noninteractive apt-get update -qq\nPRIV:env DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes jq' "$(install_as debian)"
    assert_eq 'gentoo' 'PRIV:emerge --noreplace --ask=n --autounmask=n jq' "$(install_as gentoo)"
    assert_eq 'arch' 'PRIV:pacman -S --needed --noconfirm jq' "$(install_as arch)"
    assert_eq 'fedora' 'PRIV:dnf install -y jq' "$(install_as fedora)"
    assert_eq 'alpine' $'PRIV:apk update -q\nPRIV:apk add -q jq' "$(install_as alpine)"
}

@test "all installed: no privilege, no refresh, no lock" {
    local os
    for os in debian gentoo arch fedora alpine; do
        use_os "$os"
        : >"$CALLS"
        run _install_packages curl jq
        assert_eq "$os rc" '0' "$status"
        assert_contains "$os skip message" 'already installed' "$output"
        assert_eq "$os no calls" '' "$(cat "$CALLS")"
    done
}

@test "the original single-string form still works" {
    : >"$CALLS"
    MISSING='jq bat' run _install_packages 'curl jq bat'
    assert_contains 'both missing installed' 'apt-get install -qq --yes jq bat' "$(cat "$CALLS")"
}

@test "unknown or inconsistent distro fails before any package command" {
    use_os unknown
    run _install_packages curl
    assert_eq 'unknown rc' '1' "$status"
    assert_contains 'says unsupported' 'unsupported distribution' "$output"
    assert_eq 'unknown: no calls' '' "$(cat "$CALLS")"

    use_os fedora
    rm "$STUBBIN/dnf"
    run _install_packages curl
    assert_eq 'no dnf rc' '1' "$status"
    assert_contains 'names the manager' "'dnf' is not on PATH" "$output"
    assert_eq 'no apt fallback' '0' "$(grep -c 'apt-get' "$CALLS" || true)"
}

@test "a failed transaction fails the call and explains" {
    export PRIV_RC=1 MISSING=jq
    run _install_packages curl jq
    assert_eq 'debian failure rc' '1' "$status"
    assert_contains 'debian error' 'apt-get failed to install: jq' "$output"
    use_os arch
    run _install_packages curl jq
    assert_eq 'arch failure rc' '1' "$status"
    assert_contains 'arch remedy' 'pacman -Syu' "$output"
    use_os gentoo
    run _install_packages jq
    assert_contains 'gentoo remedy' 'never edits it' "$output"
    unset PRIV_RC MISSING
}

@test "index refresh happens once per run, shared through DOT_RUN_ID" {
    export MISSING='jq bat' DOT_RUN_ID="test-$$-$RANDOM"
    _install_packages jq >/dev/null
    _install_packages bat >/dev/null
    bash -c "source '$REPO_ROOT/bin/utils.sh'; _priv() { printf 'PRIV:%s\n' \"\$*\" >>'$CALLS'; }; _install_packages jq" >/dev/null 2>&1
    assert_eq 'one update across calls and processes' '1' "$(grep -c 'apt-get update' "$CALLS")"
    assert_eq 'three installs' '3' "$(grep -c 'apt-get install' "$CALLS")"
    rm -f "/tmp/dottod/pkg-refresh.debian.${DOT_RUN_ID}"
    unset MISSING DOT_RUN_ID
}

@test "a task run directly refreshes once per process" {
    local -a before=(/tmp/dottod/pkg-refresh.*) after=()
    export MISSING='jq bat'
    _install_packages jq >/dev/null
    _install_packages bat >/dev/null
    after=(/tmp/dottod/pkg-refresh.*)
    assert_eq 'one update in this process' '1' "$(grep -c 'apt-get update' "$CALLS")"
    assert_eq 'no stamp file without a run id' "${before[*]}" "${after[*]}"
    unset MISSING
}

@test "concurrent transactions never interleave" {
    printf '#!/usr/bin/env bash\necho "start $*" >>"$CALLS"; sleep 0.3; echo "end $*" >>"$CALLS"\n' >"$STUBBIN/pacman-run"
    chmod +x "$STUBBIN/pacman-run"
    use_os arch
    _priv() { "$@"; }
    _pkg_arch_install() { _priv pacman-run "$@"; }
    export MISSING='jq bat'
    _install_packages jq >/dev/null 2>&1 &
    _install_packages bat >/dev/null 2>&1 &
    wait
    local order
    order="$(cut -d' ' -f1 "$CALLS" | tr '\n' ' ')"
    assert_eq 'strictly paired' 'start end start end ' "$order"
    unset MISSING
}

@test "symlinked lock file is refused" {
    local lock=/tmp/dottod/pkg.lock saved=''
    [[ -e "$lock" && ! -L "$lock" ]] && saved="$BATS_TEST_TMPDIR/lock.bak" && mv "$lock" "$saved"
    ln -s "$BATS_TEST_TMPDIR/elsewhere" "$lock"
    MISSING=jq run _install_packages jq
    rm -f "$lock"
    [[ -n "$saved" ]] && mv "$saved" "$lock"
    assert_eq 'refused rc' '1' "$status"
    assert_contains 'says why' 'Refusing symlinked lock file' "$output"
}

@test "no-packages flag short-circuits everything, even detection" {
    use_os unknown
    export _DOT_NO_PACKAGES=1
    run _install_packages curl jq
    assert_eq 'flag rc 0' '0' "$status"
    assert_eq 'no calls' '' "$(cat "$CALLS")"
    unset _DOT_NO_PACKAGES
}

@test "candidate versions per backend, normalized" {
    use_os debian
    assert_eq 'debian epoch+revision stripped' '0.10.4' "$(_pkg_candidate_version neovim)"
    APT_CANDIDATE='(none)' run _pkg_candidate_version neovim
    assert_eq 'debian none rc 1' '1' "$status"
    use_os arch
    assert_eq 'arch' '0.11.4' "$(_pkg_candidate_version neovim)"
    use_os fedora
    assert_eq 'fedora' '0.11.3' "$(_pkg_candidate_version neovim)"
    use_os alpine
    assert_eq 'alpine' '0.11.1' "$(_pkg_candidate_version neovim)"
    use_os gentoo
    printf '#!/usr/bin/env bash\n[[ "$1" == best_visible ]] && printf "app-editors/neovim-0.11.4-r1\\n"\n' >"$STUBBIN/portageq"
    assert_eq 'gentoo atom stripped' '0.11.4' "$(_pkg_candidate_version app-editors/neovim)"
    use_os unknown
    run _pkg_candidate_version neovim
    assert_eq 'unknown rc 2' '2' "$status"
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
