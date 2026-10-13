#!/usr/bin/env bats
#
# test-containers.bats — tests for scripts/.containers.sh listing helpers.
#
# Hermetic: stub podman/docker binaries on a prepended PATH. Podman is
# usable by default (info rc 0); flip *_STUB_INFO_RC to simulate a down
# runtime. Follows tests/test-container.bats stub conventions.

load helpers

setup() {
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"

    cat >"$STUBBIN/podman" <<'EOF'
#!/usr/bin/env bash
echo "podman $*" >>"${STUB_CALLS}"
case "${1:-}" in
    info) exit "${PODMAN_STUB_INFO_RC:-0}" ;;
    *) exit 0 ;;
esac
EOF
    cat >"$STUBBIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >>"${STUB_CALLS}"
case "${1:-}" in
    info) exit "${DOCKER_STUB_INFO_RC:-0}" ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$STUBBIN/podman" "$STUBBIN/docker"

    export STUB_CALLS="$CALLS"
    export PODMAN_STUB_INFO_RC=0 DOCKER_STUB_INFO_RC=0
    unset _DOT_CONTAINER_RUNTIME
    export PATH="$STUBBIN:$PATH"

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.container.utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.containers.sh"
}

@test "cps lists containers with the resolved runtime" {
    run cps
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'podman used' 'podman container ls -a' "$(cat "$CALLS")"
}

@test "cps honors an explicit docker runtime" {
    export _DOT_CONTAINER_RUNTIME=docker
    run cps --format 'table {{.ID}}'
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'docker used' 'docker container ls -a' "$(cat "$CALLS")"
    assert_contains 'extra args forwarded' "{{.ID}}" "$(cat "$CALLS")"
}

@test "cimg lists images" {
    run cimg
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'images listed' 'podman image ls -a' "$(cat "$CALLS")"
}

@test "helpers fail loudly when the runtime is unusable" {
    podman() { return 127; }
    docker() { return 127; }
    export -f podman docker
    run cps
    unset -f podman docker
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero with no usable runtime\n' >&2
        return 1
    fi
    assert_contains 'loud error' 'containers:' "$output"
}

@test "helpers fail loudly when the binary is missing" {
    # Hermetic absence: a PATH with the tools the helpers need (tr) but
    # neither runtime binary, so resolution must fail loudly anywhere.
    mkdir -p "$BATS_TEST_TMPDIR/onlytr"
    ln -sf "$(command -v tr)" "$BATS_TEST_TMPDIR/onlytr/tr"
    PATH="$BATS_TEST_TMPDIR/onlytr" run cps
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero without binaries\n' >&2
        return 1
    fi
    assert_contains 'loud error' 'not found on PATH' "$output"
}

@test "cprune --yes prunes without prompting" {
    run cprune --yes
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'prune ran' 'podman system prune -af' "$(cat "$CALLS")"
}

@test "cprune asks and aborts on no" {
    set +e
    printf 'n\n' | cprune >"$BATS_TEST_TMPDIR/out.txt" 2>&1
    status=$?
    set -e
    output="$(cat "$BATS_TEST_TMPDIR/out.txt")"
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero on abort\n' >&2
        return 1
    fi
    assert_contains 'abort message' 'aborted' "$output"
    if grep -q 'prune' "$CALLS"; then
        printf 'FAIL: prune ran despite abort\n' >&2
        return 1
    fi
}

@test "cprune asks and prunes on yes" {
    printf 'y\n' | cprune >"$BATS_TEST_TMPDIR/out.txt" 2>&1
    status=$?
    output="$(cat "$BATS_TEST_TMPDIR/out.txt")"
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'prune ran' 'podman system prune -af' "$(cat "$CALLS")"
}

@test "csh runs a command in the container" {
    run csh webapp ls /srv
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'exec forwarded' 'podman exec -it webapp ls /srv' "$(cat "$CALLS")"
}

@test "clog follows logs" {
    run clog webapp
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'logs followed' 'podman logs -f webapp' "$(cat "$CALLS")"
}
