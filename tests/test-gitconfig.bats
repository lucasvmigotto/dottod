#!/usr/bin/env bats
#
# test-gitconfig.bats — hermetic tests for bin/gitconfig.sh.
#
# Covers: env-driven writes, idempotent skip when the identity already
# matches (no backup, no rewrite), backup + rewrite on change, and loud
# failure without values. HOME is redirected to a temp dir so the real
# ~/.gitconfig is never touched (`git config --global` follows HOME).

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    unset GIT_NAME GIT_EMAIL
    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/gitconfig.sh"
    set +u
}

@test "gitconfig writes identity from env when none exists" {
    export GIT_NAME="Test User" GIT_EMAIL="test@example.com"
    run _main
    assert_eq 'write rc 0' '0' "$status"
    assert_eq 'name written' 'Test User' "$(git config --global user.name)"
    assert_eq 'email written' 'test@example.com' "$(git config --global user.email)"
    assert_eq 'no backup on fresh install' '0' "$([[ -e "$FAKE_HOME/.gitconfig.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "gitconfig skips without backup when identity matches" {
    export GIT_NAME="Test User" GIT_EMAIL="test@example.com"
    _main >/dev/null
    : >"$BATS_TEST_TMPDIR/marker"
    run _main
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message' 'already set' "$output"
    assert_eq 'no backup on skip' '0' "$([[ -e "$FAKE_HOME/.gitconfig.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "gitconfig backs up and rewrites on changed values" {
    export GIT_NAME="Old Name" GIT_EMAIL="old@example.com"
    _main >/dev/null
    export GIT_NAME="New Name" GIT_EMAIL="new@example.com"
    run _main
    assert_eq 'rewrite rc 0' '0' "$status"
    assert_contains 'backup warning' 'Backing up' "$output"
    assert_eq 'backup holds old name' 'Old Name' "$(git config --file "$FAKE_HOME/.gitconfig.dottod.bak" user.name)"
    assert_eq 'new name live' 'New Name' "$(git config --global user.name)"
    assert_eq 'new email live' 'new@example.com' "$(git config --global user.email)"
}

@test "gitconfig fails loudly without values or TTY" {
    run _main
    assert_eq 'missing values rc 1' '1' "$status"
    assert_contains 'names the requirement' 'GIT_NAME/GIT_EMAIL' "$output"
}

@test "gitconfig reads existing global identity without env" {
    git config --global user.name "Existing User"
    git config --global user.email "existing@example.com"
    run _main
    assert_eq 'reuse rc 0' '0' "$status"
    assert_contains 'skip message' 'already set' "$output"
}
