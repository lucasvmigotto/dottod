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
    _ctr_have_subids "$FIXUID"
    assert_eq 'subids present rc 0' '0' "$?"
    printf 'other:200000:65536\n' >"$BATS_TEST_TMPDIR/subuid"
    run _ctr_have_subids "$FIXUID"
    assert_eq 'user missing from subuid rc 1' '1' "$status"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subuid"
    rm -f "$BATS_TEST_TMPDIR/subgid"
    run _ctr_have_subids "$FIXUID"
    assert_eq 'subgid file absent rc 1' '1' "$status"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subgid"
    printf 'garbage-without-colon\n' >"$BATS_TEST_TMPDIR/subuid"
    run _ctr_have_subids "$FIXUID"
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
    assert_contains 'explains with host findings' 'not usable rootlessly' "$output"
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

# fake_host <userns> <cgroup v2: 1|0> <openrc: 1|0>: a fake /proc, /sys,
# /run under _DOT_CTR_ROOT for the rootless findings.
fake_host() {
    local root="$BATS_TEST_TMPDIR/host"
    rm -rf "$root"
    mkdir -p "$root/proc/sys/user" "$root/proc/sys/kernel" "$root/sys/fs/cgroup" "$root/run"
    printf '%s\n' "$1" >"$root/proc/sys/user/max_user_namespaces"
    [[ "$2" == 1 ]] && : >"$root/sys/fs/cgroup/cgroup.controllers"
    [[ "$3" == 1 ]] && mkdir -p "$root/run/openrc"
    export _DOT_CTR_ROOT="$root"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/newuidmap"
    chmod +x "$STUBBIN/newuidmap"
}

@test "findings: a ready host reports all ok" {
    fake_host 15000 1 0
    run _ctr_rootless_findings "$FIXUID"
    assert_eq 'rc' '0' "$status"
    assert_eq 'four checks, all ok' '4' "$(grep -c $'^ok\t' <<<"$output")"
}

@test "findings: disabled user namespaces warn, either knob" {
    fake_host 0 1 0
    run _ctr_rootless_findings "$FIXUID"
    assert_contains 'max_user_namespaces' 'user.max_user_namespaces=0' "$output"
    fake_host 15000 1 0
    printf '0\n' >"$_DOT_CTR_ROOT/proc/sys/kernel/unprivileged_userns_clone"
    run _ctr_rootless_findings "$FIXUID"
    assert_contains 'debian knob' 'kernel.unprivileged_userns_clone=0' "$output"
}

@test "findings: missing subids and newuidmap warn" {
    fake_host 15000 1 0
    printf 'other:100000:65536\n' >"$BATS_TEST_TMPDIR/subuid"
    run _ctr_rootless_findings "$FIXUID"
    assert_contains 'subids' "no subuid/subgid ranges for $FIXUID" "$output"
    local bare="$BATS_TEST_TMPDIR/bare"
    mkdir -p "$bare"
    ln -sf "$(command -v cat)" "$bare/cat"
    ln -sf "$(command -v grep)" "$bare/grep"
    ln -sf "$(command -v id)" "$bare/id"
    PATH="$bare" run _ctr_rootless_findings "$FIXUID"
    assert_contains 'newuidmap' 'newuidmap missing' "$output"
}

@test "findings: cgroup v1 hints per init system, never edits" {
    fake_host 15000 0 1
    run _ctr_rootless_findings "$FIXUID"
    assert_contains 'openrc hint' 'rc_cgroup_mode="unified" in /etc/rc.conf' "$output"
    assert_eq 'rc.conf untouched' '0' "$([[ -e "$_DOT_CTR_ROOT/etc/rc.conf" ]] && echo 1 || echo 0)"
    fake_host 15000 0 0
    run _ctr_rootless_findings "$FIXUID"
    assert_contains 'systemd hint' 'systemd.unified_cgroup_hierarchy=1' "$output"
}

@test "status lists the host findings" {
    fake_host 15000 1 1
    run _container_status
    assert_contains 'host header' 'Host:' "$output"
    assert_contains 'finding line' '[ok] cgroup v2' "$output"
}

@test "ensure installs the rootless helpers even when podman is present" {
    export PODMAN_STUB_INFO_RC=1
    _install_packages() { printf 'PKGS:%s\n' "$*" >>"$CALLS"; }
    run _podman_ensure
    assert_contains 'helpers requested' 'PKGS:podman podman_rootless' "$(cat "$CALLS")"
}
