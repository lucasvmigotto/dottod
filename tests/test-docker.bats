#!/usr/bin/env bats
#
# test-docker.bats — hermetic tests for bin/docker.sh helpers.
#
# Covers: repository-configured detection (exact line match, missing
# keyring/source, codename sensitivity) and the installed-docker skip.
# Privileged installation is never exercised here (see the container
# integration scripts for the real path).

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FIX="$BATS_TEST_TMPDIR/fix"
    mkdir -p "$FIX"
    export _DOT_NO_PACKAGES=1
    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/docker.sh"
    set +u
}

@test "repo check passes on an exact configured match" {
    local keyring="$FIX/docker.gpg" source="$FIX/docker.list" arch
    arch="$(dpkg --print-architecture)"
    printf 'key' >"$keyring"
    printf "deb [arch=${arch} signed-by=%s] https://download.docker.com/linux/debian trixie stable\n" "$keyring" >"$source"
    run _docker_repo_configured "$keyring" "$source" 'https://download.docker.com/linux/debian' 'trixie'
    assert_eq 'configured rc 0' '0' "$status"
}

@test "repo check fails when the keyring is missing" {
    local keyring="$FIX/docker.gpg" source="$FIX/docker.list"
    printf "deb [arch=${arch} signed-by=%s] https://download.docker.com/linux/debian trixie stable\n" "$keyring" >"$source"
    run _docker_repo_configured "$keyring" "$source" 'https://download.docker.com/linux/debian' 'trixie'
    assert_eq 'missing keyring rc 1' '1' "$status"
}

@test "repo check fails on codename drift" {
    local keyring="$FIX/docker.gpg" source="$FIX/docker.list" arch
    arch="$(dpkg --print-architecture)"
    printf 'key' >"$keyring"
    printf "deb [arch=${arch} signed-by=%s] https://download.docker.com/linux/debian bookworm stable\n" "$keyring" >"$source"
    run _docker_repo_configured "$keyring" "$source" 'https://download.docker.com/linux/debian' 'trixie'
    assert_eq 'drift rc 1' '1' "$status"
}

@test "docker install skips when already present" {
    mkdir -p "$BATS_TEST_TMPDIR/stubbin"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/stubbin/docker"
    chmod +x "$BATS_TEST_TMPDIR/stubbin/docker"
    export PATH="$BATS_TEST_TMPDIR/stubbin:$PATH"
    run _docker_install
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message' 'already installed' "$output"
}
