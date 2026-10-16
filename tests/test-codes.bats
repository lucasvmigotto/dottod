#!/usr/bin/env bats
#
# test-codes.bats — hermetic tests for scripts/.codes.sh discovery,
# qualified matching and grouped display.
#
# Fixture tree (under $BATS_TEST_TMPDIR/roots):
#   solo/                 independent repo
#   family/a, family/b    sibling repos (non-repo parent -> parent/name)
#   super/                superproject repo
#   super/sub             submodule-style checkout (.git file -> modules)
#   super/vendor/nested   vendored clone (nested .git dir -> dropped)

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export ROOTS="$BATS_TEST_TMPDIR/roots"
    export CODES_ROOTS="$ROOTS"
    unset CODES_SUBMODULES CODES_GROUP CODES_CLAUDE CODES_CLAUDE_GLYPH CLAUDE_CONFIG_DIR
    mkdir -p "$ROOTS/solo" "$ROOTS/family/a" "$ROOTS/family/b"
    mkdir -p "$ROOTS/super/sub" "$ROOTS/super/vendor/nested"
    local r
    for r in solo family/a family/b super super/vendor/nested super/sub; do
        git -C "$ROOTS/$r" init -q
        git -C "$ROOTS/$r" config user.email t@t
        git -C "$ROOTS/$r" config user.name t
        git -C "$ROOTS/$r" commit -q --allow-empty -m init
    done
    # submodule layout: real repo, .git relocated under modules/, linked
    # back with a gitfile (no network, works on any git version)
    mkdir -p "$ROOTS/super/.git/modules"
    mv "$ROOTS/super/sub/.git" "$ROOTS/super/.git/modules/sub"
    printf 'gitdir: ../.git/modules/sub' >"$ROOTS/super/sub/.git"
}

codes_find() {
    bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; __codes_find" 2>/dev/null
}

@test "find keeps linked nested checkouts and drops vendored clones" {
    run codes_find
    assert_eq 'find rc 0' '0' "$status"
    assert_contains 'top repo listed' "$ROOTS/solo" "$output"
    assert_contains 'siblings listed' "$ROOTS/family/a" "$output"
    assert_contains 'superproject listed' "$ROOTS/super" "$output"
    assert_contains 'submodule-style checkout kept' "$ROOTS/super/sub" "$output"
    if printf '%s' "$output" | grep -q "$ROOTS/super/vendor/nested"; then
        printf 'FAIL: vendored clone listed\n%s\n' "$output" >&2
        return 1
    fi
}

@test "find with CODES_SUBMODULES=0 drops every nested checkout" {
    export CODES_SUBMODULES=0
    run codes_find
    assert_eq 'find rc 0' '0' "$status"
    assert_contains 'superproject listed' "$ROOTS/super" "$output"
    if printf '%s' "$output" | grep -q "$ROOTS/super/sub"; then
        printf 'FAIL: nested checkout listed with CODES_SUBMODULES=0\n%s\n' "$output" >&2
        return 1
    fi
}

@test "list qualifies siblings and nests submodule checkouts" {
    run env CODES_ROOTS="$ROOTS" bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; codes -l" 2>/dev/null
    assert_eq 'list rc 0' '0' "$status"
    assert_contains 'sibling qualified' 'family/a' "$output"
    assert_contains 'sibling qualified' 'family/b' "$output"
    assert_contains 'top repo bare' 'solo' "$output"
    assert_contains 'submodule nested' '└─' "$output"
    if printf '%s' "$output" | grep -q 'super/sub'; then
        printf 'FAIL: nested child carries parent prefix\n%s\n' "$output" >&2
        return 1
    fi
}

@test "list with CODES_GROUP=0 stays flat" {
    export CODES_GROUP=0 CODES_SUBMODULES=0
    run env CODES_ROOTS="$ROOTS" bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; codes -l" 2>/dev/null
    assert_eq 'list rc 0' '0' "$status"
    if printf '%s' "$output" | grep -qE '├─|└─'; then
        printf 'FAIL: nested display with CODES_GROUP=0\n%s\n' "$output" >&2
        return 1
    fi
    if printf '%s' "$output" | grep -q 'family/a'; then
        printf 'FAIL: qualified names with CODES_GROUP=0\n%s\n' "$output" >&2
        return 1
    fi
}

@test "path prints the full path for a qualified query" {
    run env CODES_ROOTS="$ROOTS" bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; codes -p family/a" 2>/dev/null
    assert_eq 'path rc 0' '0' "$status"
    assert_contains 'full path printed' "$ROOTS/family/a" "$output"
}

@test "parent query restricts the table to its children" {
    run env CODES_ROOTS="$ROOTS" bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; codes -l family" 2>/dev/null
    assert_eq 'list rc 0' '0' "$status"
    assert_contains 'first child shown' 'family/a' "$output"
    assert_contains 'second child shown' 'family/b' "$output"
    if printf '%s' "$output" | grep -q 'solo'; then
        printf 'FAIL: unrelated project in restricted table\n%s\n' "$output" >&2
        return 1
    fi
}

# stderr only from codes itself (bash -i adds job-control noise).
codes_list() {
    env CODES_ROOTS="$ROOTS" bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; codes -l $* 2>&1" 2>/dev/null
}

@test "without a work identity there is no context column and filters refuse" {
    run codes_list
    if printf '%s' "$output" | grep -qw 'personal'; then
        printf 'FAIL: context column without a work identity\n%s\n' "$output" >&2
        return 1
    fi
    run codes_list --work
    assert_eq 'filter rc 1' '1' "$status"
    assert_contains 'explains' 'no work identity' "$output"
}

@test "context follows the email git resolves; --work and --personal filter" {
    printf '[user]\n    email = w@w\n' >"$HOME/.gitconfig-work"
    git -C "$ROOTS/solo" config user.email W@w
    run codes_list
    assert_eq 'solo is work' '1' "$(printf '%s\n' "$output" | grep -c '^solo  *work ')"
    assert_contains 'others personal' 'personal' "$output"
    run codes_list --work
    assert_eq 'work rc 0' '0' "$status"
    assert_eq 'only solo' '1' "$(printf '%s\n' "$output" | grep -c .)"
    assert_contains 'solo listed' 'solo' "$output"
    run codes_list --personal
    if printf '%s' "$output" | grep -qw 'solo'; then
        printf 'FAIL: work repo in --personal\n%s\n' "$output" >&2
        return 1
    fi
    assert_contains 'personal listed' 'family/a' "$output"
}

@test "GIT_WORK_EMAIL overrides ~/.gitconfig-work for the context" {
    git -C "$ROOTS/family/b" config user.email env@w
    run env GIT_WORK_EMAIL=env@w bash -c "$(declare -f codes_list); ROOTS='$ROOTS' REPO_ROOT='$REPO_ROOT' codes_list --work"
    assert_contains 'family/b is work' "$ROOTS/family" "$output"
    assert_eq 'as work' '1' "$(printf '%s\n' "$output" | grep -c '^b  *work ')"
    assert_eq 'only it' '1' "$(printf '%s\n' "$output" | grep -c .)"
}

@test "--by-context lists work repos before personal ones" {
    printf '[user]\n    email = w@w\n' >"$HOME/.gitconfig-work"
    git -C "$ROOTS/family/b" config user.email w@w
    # Make a personal repo the most recent: it would come first otherwise.
    git -C "$ROOTS/solo" commit -q --allow-empty -m newer
    run codes_list --by-context
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'first row is work' 'work' "$(printf '%s\n' "$output" | sed -n 1p)"
    assert_eq 'one work row' '1' "$(printf '%s\n' "$output" | grep -cw 'work')"
}

# claude_key <path>: Claude Code's projects/ folder name for a path.
claude_key() {
    printf '%s' "${1//[^A-Za-z0-9]/-}"
}

@test "repos with a saved Claude conversation carry the mark" {
    mkdir -p "$FAKE_HOME/.claude/projects/$(claude_key "$ROOTS/solo")"
    : >"$FAKE_HOME/.claude/projects/$(claude_key "$ROOTS/solo")/s.jsonl"
    # A folder without a session file is not a conversation.
    mkdir -p "$FAKE_HOME/.claude/projects/$(claude_key "$ROOTS/family/a")"
    run codes_list
    assert_eq 'rc' '0' "$status"
    assert_match 'solo marked' $'solo .*\xee\xb0\x90' "$(grep 'solo' <<<"$output")"
    assert_eq 'family/a unmarked' '0' "$(grep 'family/a' <<<"$output" | grep -c $'\xee\xb0\x90' || true)"
}

@test "CODES_CLAUDE=0 hides the mark; CODES_CLAUDE_GLYPH replaces it" {
    mkdir -p "$FAKE_HOME/.claude/projects/$(claude_key "$ROOTS/solo")"
    : >"$FAKE_HOME/.claude/projects/$(claude_key "$ROOTS/solo")/s.jsonl"
    CODES_CLAUDE=0 run codes_list
    assert_eq 'hidden' '0' "$(grep -c $'\xee\xb0\x90' <<<"$output" || true)"
    CODES_CLAUDE_GLYPH='C*' run codes_list
    assert_match 'custom glyph' 'solo .*C\*' "$(grep 'solo' <<<"$output")"
}

@test "CLAUDE_CONFIG_DIR points the lookup at another store" {
    local store="$BATS_TEST_TMPDIR/other-store"
    mkdir -p "$store/projects/$(claude_key "$ROOTS/solo")"
    : >"$store/projects/$(claude_key "$ROOTS/solo")/s.jsonl"
    CLAUDE_CONFIG_DIR="$store" run codes_list
    assert_match 'solo marked' $'solo .*\xee\xb0\x90' "$(grep 'solo' <<<"$output")"
}

@test "codes -c jumps, then continues the Claude conversation there" {
    run env CODES_ROOTS="$ROOTS" bash -i -c "
        source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1
        claude() { printf 'claude %s in %s\n' \"\$*\" \"\$PWD\"; }
        codes -c solo
    " 2>/dev/null
    assert_eq 'rc' '0' "$status"
    assert_contains 'continued in the project' "claude -c in $ROOTS/solo" "$output"
    run env CODES_ROOTS="$ROOTS" bash -i -c "source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1; codes -c -l" 2>&1
    assert_eq 'with -l rc' '2' "$status"
    assert_contains 'refused' 'not with -l or -p' "$output"
}
