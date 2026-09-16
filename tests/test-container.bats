#!/usr/bin/env bats
#
# test-container.bats — tests for scripts/.container.utils.sh + bin/container.sh.
#
# Hermetic: stub podman/docker binaries on a prepended PATH, real subid
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
    cat >"$STUBBIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >>"${STUB_CALLS}"
case "${1:-}" in
    info) exit "${DOCKER_STUB_INFO_RC:-0}" ;;
    --version) printf 'Docker version %s, build stub\n' "${DOCKER_STUB_VERSION:-29.7.2}"; exit 0 ;;
    *) exit 0 ;;
esac
EOF
    cat >"$STUBBIN/docker-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo "docker-script invoked" >>"${STUB_CALLS}"
exit "${DOCKER_SCRIPT_RC:-0}"
EOF
    chmod +x "$STUBBIN/podman" "$STUBBIN/docker" "$STUBBIN/docker-stub.sh"

    FIXUID="$(id -un)"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subuid"
    printf '%s:100000:65536\n' "$FIXUID" >"$BATS_TEST_TMPDIR/subgid"

    export STUB_CALLS="$CALLS"
    export _DOT_NO_PACKAGES=1
    export PODMAN_STUB_INFO_RC=0 PODMAN_STUB_VERSION=5.4.2
    export DOCKER_STUB_INFO_RC=0 DOCKER_STUB_VERSION=29.7.2
    export _DOT_CONTAINER_SUBUID_FILE="$BATS_TEST_TMPDIR/subuid"
    export _DOT_CONTAINER_SUBGID_FILE="$BATS_TEST_TMPDIR/subgid"
    unset _DOT_CONTAINER_RUNTIME
    export PATH="$STUBBIN:$PATH"

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.container.utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../bin/container.sh"
    # Sourced files enable strict mode; relax it — BATS manages errexit
    # itself and assertions (not aborts) report failures.
    set +e +u

    # Privilege safety: record-only, never executes.
    _priv() {
        printf 'PRIV:%s\n' "$*" >>"$CALLS"
        return "${PRIV_STUB_RC:-0}"
    }
    _container_docker_script() {
        printf '%s' "$STUBBIN/docker-stub.sh"
    }
}

@test "configured values normalize, default and reject" {
    assert_eq 'default configured podman' 'podman' "$(_ctr_configured)"
    export _DOT_CONTAINER_RUNTIME=docker
    assert_eq 'explicit docker' 'docker' "$(_ctr_configured)"
    export _DOT_CONTAINER_RUNTIME=Docker
    assert_eq 'case-insensitive' 'docker' "$(_ctr_configured)"
    export _DOT_CONTAINER_RUNTIME=auto
    assert_eq 'auto passthrough' 'auto' "$(_ctr_configured)"
    export _DOT_CONTAINER_RUNTIME=bogus
    run _ctr_configured
    assert_eq 'invalid rc 1' '1' "$status"
    assert_eq 'invalid empty out' '' "$output"
}

@test "installed, version and usability probes" {
    assert_eq 'podman installed' '0' "$(_ctr_installed podman; echo $?)"
    assert_eq 'podman version' '5.4.2' "$(_ctr_version podman)"
    assert_eq 'docker version' '29.7.2' "$(_ctr_version docker)"
    _ctr_usable_podman
    assert_eq 'podman usable rc' '0' "$?"
    _ctr_usable_docker
    assert_eq 'docker usable rc' '0' "$?"
    export PODMAN_STUB_INFO_RC=1
    run _ctr_usable_podman
    assert_eq 'unusable podman fails' '1' "$status"
}

@test "selection display is cheap and never probes" {
    export _DOT_CONTAINER_RUNTIME=auto
    : >"$CALLS"
    assert_eq 'auto displays podman default' 'podman' "$(_ctr_selected)"
    assert_eq 'no probe for display' '0' "$(grep -c 'info' "$CALLS" || true)"
}

@test "resolution matrix honors explicit choice and auto policy" {
    assert_eq 'unset resolves podman' 'podman' "$(_ctr_resolve)"
    export _DOT_CONTAINER_RUNTIME=docker
    export DOCKER_STUB_INFO_RC=1
    assert_eq 'explicit docker never switches' 'docker' "$(_ctr_resolve)"
    export _DOT_CONTAINER_RUNTIME=podman
    export PODMAN_STUB_INFO_RC=1
    assert_eq 'explicit podman never switches' 'podman' "$(_ctr_resolve)"
    export _DOT_CONTAINER_RUNTIME=auto
    export PODMAN_STUB_INFO_RC=0
    assert_eq 'auto prefers podman' 'podman' "$(_ctr_resolve)"
    export PODMAN_STUB_INFO_RC=1
    export DOCKER_STUB_INFO_RC=0
    assert_eq 'auto falls to docker' 'docker' "$(_ctr_resolve)"
    export DOCKER_STUB_INFO_RC=1
    assert_eq 'auto with neither targets podman' 'podman' "$(_ctr_resolve)"
}

@test "ctr dispatcher follows resolution" {
    run ctr ps -a
    assert_contains 'ctr dispatches to podman' 'podman ps -a' "$(cat "$CALLS")"
    export _DOT_CONTAINER_RUNTIME=docker
    run ctr images
    assert_contains 'ctr dispatches to docker' 'docker images' "$(cat "$CALLS")"
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
    _container_ensure >/dev/null
    assert_eq 'ready rc 0' '0' "$?"
    assert_eq 'ready makes no priv calls' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
}

@test "ensure fails loudly when podman is missing" {
    mv "$STUBBIN/podman" "$STUBBIN/podman.hidden"
    run _container_ensure
    assert_eq 'missing podman rc 1' '1' "$status"
    assert_eq 'no priv calls on missing' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
    mv "$STUBBIN/podman.hidden" "$STUBBIN/podman"
}

@test "ensure attempts usermod exactly once when subids are missing" {
    printf '' >"$BATS_TEST_TMPDIR/subuid"
    export PODMAN_STUB_INFO_RC=1
    run _container_ensure
    assert_eq 'subid path rc 1 (still unusable)' '1' "$status"
    assert_eq 'usermod attempted once' '1' "$(grep -c '^PRIV:.*usermod' "$CALLS" || true)"
}

@test "ensure on docker delegates without touching the podman path" {
    export _DOT_CONTAINER_RUNTIME=docker
    export DOCKER_STUB_INFO_RC=1
    _container_ensure >/dev/null 2>&1
    assert_eq 'docker delegates rc 0' '0' "$?"
    assert_contains 'docker script ran' 'docker-script invoked' "$(cat "$CALLS")"
    assert_eq 'no usermod on docker path' '0' "$(grep -c 'usermod' "$CALLS" || true)"
}

@test "status reports fields and rejects invalid config" {
    out="$(_container_status)"
    assert_contains 'status configured' 'Configured:' "$out"
    assert_contains 'status selected podman' 'Selected:   podman' "$out"
    assert_contains 'status podman ver' 'Podman:     installed 5.4.2' "$out"
    assert_contains 'status docker ver' 'Docker:     installed 29.7.2' "$out"
    assert_contains 'status rootless' 'Rootless:   yes' "$out"
    assert_contains 'status usable' 'Usable:     yes' "$out"
    export _DOT_CONTAINER_RUNTIME=bogus
    run _container_status
    assert_eq 'status invalid rc 1' '1' "$status"
}

@test "repeated ensure makes no privileged calls" {
    : >"$CALLS"
    _container_ensure >/dev/null
    _container_ensure >/dev/null
    assert_eq 'double ensure makes no priv calls' '0' "$(grep -c '^PRIV:' "$CALLS" || true)"
}
