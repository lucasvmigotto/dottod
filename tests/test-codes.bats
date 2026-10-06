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
    unset CODES_SUBMODULES CODES_GROUP
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
    assert_contains 'submodule nested' 'super/sub' "$output"
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
