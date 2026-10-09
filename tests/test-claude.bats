#!/usr/bin/env bats
#
# test-claude.bats — hermetic tests for scripts/.claude.sh (work/personal
# profiles over a shared store). The `claude` binary is stubbed; HOME is
# fake; no network, no real credentials.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME/.claude"
    unset CLAUDE_PROFILE CLAUDE_WORK_DIR CLAUDE_PERSONAL_DIR CLAUDE_DEFAULT_PROFILE CLAUDE_NO_PICKER
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN"
    export PATH="$STUBBIN:$PATH"
    # Stub claude: records CLAUDE_CONFIG_DIR + args.
    cat >"$STUBBIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
printf 'DIR=%s ARGS=%s\n' "${CLAUDE_CONFIG_DIR:-}" "$*" >>"${CALLS_LOG:?}"
STUBEOF
    chmod +x "$STUBBIN/claude"
    export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALLS_LOG"
}

seed_store() {
    mkdir -p "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude/skills"
    printf 'memory' >"$FAKE_HOME/.claude/projects/sess.json"
    printf '{"model":"x"}' >"$FAKE_HOME/.claude/settings.json"
}

@test "claudew builds the work overlay sharing the store" {
    seed_store
    printf 'token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_NO_PICKER=1 claudew --version" 2>/dev/null
    assert_eq 'claudew rc 0' '0' "$status"
    assert_contains 'config dir is the work overlay' "DIR=$FAKE_HOME/.claude-work" "$(cat "$CALLS_LOG")"
    assert_contains 'args forwarded' 'ARGS=--version' "$(cat "$CALLS_LOG")"
    [ -L "$FAKE_HOME/.claude-work/projects" ] || {
        printf 'FAIL: projects not symlinked\n' >&2
        return 1
    }
    assert_eq 'link target is the store' "$FAKE_HOME/.claude/projects" "$(readlink "$FAKE_HOME/.claude-work/projects")"
    [ ! -e "$FAKE_HOME/.claude-work/.credentials.json" ] || {
        printf 'FAIL: work overlay must not adopt the token\n' >&2
        return 1
    }
}

@test "claudep adopts the shared token into the personal overlay" {
    seed_store
    printf 'token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_NO_PICKER=1 claudep --version" 2>/dev/null
    assert_eq 'claudep rc 0' '0' "$status"
    assert_contains 'config dir is the personal overlay' "DIR=$FAKE_HOME/.claude-personal" "$(cat "$CALLS_LOG")"
    assert_eq 'token moved out of the store' '' "$(cat "$FAKE_HOME/.claude/.credentials.json" 2>/dev/null || true)"
    assert_eq 'token present in overlay' 'token' "$(cat "$FAKE_HOME/.claude-personal/.credentials.json")"
}

@test "non-interactive launch defaults to personal" {
    seed_store
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude --help
    " 2>/dev/null
    assert_eq 'default rc 0' '0' "$status"
    assert_contains 'personal overlay used' "DIR=$FAKE_HOME/.claude-personal" "$(cat "$CALLS_LOG")"
}

@test "CLAUDE_PROFILE bypasses the picker" {
    seed_store
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        CLAUDE_PROFILE=work claude --help
    " 2>/dev/null
    assert_eq 'profile rc 0' '0' "$status"
    assert_contains 'work overlay used' "DIR=$FAKE_HOME/.claude-work" "$(cat "$CALLS_LOG")"
}

@test "existing overlay files are never replaced by links" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-work/projects"
    printf 'mine' >"$FAKE_HOME/.claude-work/projects/keep.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_NO_PICKER=1 claudew true" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
    assert_eq 'real file kept' 'mine' "$(cat "$FAKE_HOME/.claude-work/projects/keep.json")"
    if [[ -L "$FAKE_HOME/.claude-work/projects" ]]; then
        printf 'FAIL: real dir replaced by a link\n' >&2
        return 1
    fi
}

@test "differing shared token warns and both logins survive" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-personal"
    printf 'overlay-token' >"$FAKE_HOME/.claude-personal/.credentials.json"
    printf 'shared-token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_NO_PICKER=1 claudep --version" 2>&1
    assert_eq 'launch rc 0' '0' "$status"
    assert_contains 'stray login warning' 'ignoring a login in the shared store' "$output"
    assert_eq 'overlay token kept' 'overlay-token' "$(cat "$FAKE_HOME/.claude-personal/.credentials.json")"
    assert_eq 'shared token kept' 'shared-token' "$(cat "$FAKE_HOME/.claude/.credentials.json")"
}

@test "missing binary fails without launching" {
    seed_store
    mkdir -p "$BATS_TEST_TMPDIR/emptybin"
    run bash -i -c "
        source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1
        PATH='$BATS_TEST_TMPDIR/emptybin:/usr/bin:/bin'
        CLAUDE_NO_PICKER=1 claudew --version
    " 2>/dev/null
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero without a binary\n' >&2
        return 1
    fi
    assert_contains 'missing binary message' 'not found on PATH' "$output"
    assert_eq 'nothing launched' '' "$(cat "$CALLS_LOG")"
}

@test "mkdir failure aborts before launching" {
    seed_store
    touch "$FAKE_HOME/.claude-work"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_NO_PICKER=1 claudew --version" 2>/dev/null
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero on mkdir failure\n%s\n' "$output" >&2
        return 1
    fi
    assert_eq 'nothing launched' '' "$(cat "$CALLS_LOG")"
}
