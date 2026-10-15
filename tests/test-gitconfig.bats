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
    # utils.sh replaces bats' EXIT trap; re-arm it so a failing test is
    # reported by name instead of dropping out of the run.
    local _bats_exit_trap
    _bats_exit_trap="$(trap -p EXIT)"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/gitconfig.sh"
    eval "${_bats_exit_trap}"
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

@test "gitconfig writes work identity and includeIf from env" {
    export GIT_NAME="Personal User" GIT_EMAIL="personal@example.com"
    export GIT_WORK_NAME="Work User" GIT_WORK_EMAIL="work@example.com"
    run _main
    assert_eq 'write rc 0' '0' "$status"
    assert_eq 'personal name' 'Personal User' "$(git config --global user.name)"
    assert_eq 'work name in file' 'Work User' "$(git config --file "$FAKE_HOME/.gitconfig-work" user.name)"
    assert_eq 'work email in file' 'work@example.com' "$(git config --file "$FAKE_HOME/.gitconfig-work" user.email)"
    assert_contains 'includeIf present' 'includeIf "gitdir:~/codes/**"' "$(cat "$FAKE_HOME/.gitconfig")"
}

@test "gitconfig resolves work identity inside ~/codes and personal outside" {
    export GIT_NAME="Personal User" GIT_EMAIL="personal@example.com"
    export GIT_WORK_NAME="Work User" GIT_WORK_EMAIL="work@example.com"
    _main >/dev/null
    mkdir -p "$FAKE_HOME/codes/workproj" "$FAKE_HOME/other"
    git -C "$FAKE_HOME/codes/workproj" init -q
    git -C "$FAKE_HOME/other" init -q
    assert_eq 'work email in codes repo' 'work@example.com' "$(git -C "$FAKE_HOME/codes/workproj" config user.email)"
    assert_eq 'personal email outside codes' 'personal@example.com' "$(git -C "$FAKE_HOME/other" config user.email)"
}

@test "gitconfig without work env writes no work file and no includeIf" {
    export GIT_NAME="Test User" GIT_EMAIL="test@example.com"
    run _main
    assert_eq 'write rc 0' '0' "$status"
    assert_eq 'no work file' '0' "$([[ -e "$FAKE_HOME/.gitconfig-work" ]] && echo 1 || echo 0)"
    if grep -q 'includeIf' "$FAKE_HOME/.gitconfig"; then
        printf 'FAIL: includeIf present without work identity\n' >&2
        return 1
    fi
}
