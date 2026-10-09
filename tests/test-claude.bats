#!/usr/bin/env bats
#
# test-claude.bats — hermetic tests for scripts/.claude.sh (named profiles
# over a shared store). The `claude` binary is stubbed; HOME is fake; no
# network, no real credentials.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME/.claude"
    unset CLAUDE_PROFILE CLAUDE_DEFAULT_PROFILE CLAUDE_NO_PICKER
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

@test "CLAUDE_PROFILE launches the overlay sharing the store" {
    seed_store
    printf 'token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=work claude --version" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
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
    assert_eq 'overlay stamped with marker' 'work' "$(cat "$FAKE_HOME/.claude-work/.dottod-profile")"
}

@test "personal overlay adopts the shared token once" {
    seed_store
    printf 'token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=personal claude --version" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
    assert_contains 'config dir is the personal overlay' "DIR=$FAKE_HOME/.claude-personal" "$(cat "$CALLS_LOG")"
    assert_eq 'token moved out of the store' '' "$(cat "$FAKE_HOME/.claude/.credentials.json" 2>/dev/null || true)"
    assert_eq 'token present in overlay' 'token' "$(cat "$FAKE_HOME/.claude-personal/.credentials.json")"
}

@test "-P selects a profile and strips the flag" {
    seed_store
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; claude -P work --version" 2>/dev/null
    assert_eq 'flag rc 0' '0' "$status"
    assert_contains 'work overlay used' "DIR=$FAKE_HOME/.claude-work" "$(cat "$CALLS_LOG")"
    assert_contains 'flag stripped' 'ARGS=--version' "$(cat "$CALLS_LOG")"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; claude --profile=work --version" 2>/dev/null
    assert_eq 'long flag rc 0' '0' "$status"
    assert_contains 'work overlay used' "DIR=$FAKE_HOME/.claude-work" "$(cat "$CALLS_LOG")"
}

@test "unknown CLAUDE_PROFILE fails with a hint" {
    seed_store
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE='../evil' claude --version" 2>&1
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero for bad profile name\n' >&2
        return 1
    fi
    assert_contains 'bad name message' 'bad profile name' "$output"
    assert_eq 'nothing launched' '' "$(cat "$CALLS_LOG")"
}

@test "explicit profile is created on first use" {
    seed_store
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=brandnew claude --version" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
    assert_contains 'new overlay used' "DIR=$FAKE_HOME/.claude-brandnew" "$(cat "$CALLS_LOG")"
    assert_eq 'marker stamped' 'brandnew' "$(cat "$FAKE_HOME/.claude-brandnew/.dottod-profile")"
}

@test "discovery ignores dirs without the marker" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-bak" "$FAKE_HOME/.claude-work"
    printf 'work\n' >"$FAKE_HOME/.claude-work/.dottod-profile"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        __dottod_claude_profiles
    " 2>/dev/null
    assert_eq 'discovery rc 0' '0' "$status"
    assert_eq 'only marked dirs listed' 'work' "$output"
}

@test "claude-profile add creates an isolated overlay" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude/backups"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile add extra
        claude-profile ls
    " 2>/dev/null
    assert_eq 'add rc 0' '0' "$status"
    assert_contains 'overlay ready' 'claude profile ready: extra' "$output"
    assert_contains 'listed unauthenticated' 'extra (needs /login)' "$output"
    [ -L "$FAKE_HOME/.claude-extra/projects" ] || {
        printf 'FAIL: projects not symlinked\n' >&2
        return 1
    }
    if [[ -L "$FAKE_HOME/.claude-extra/backups" ]]; then
        printf 'FAIL: identity dir linked\n' >&2
        return 1
    fi
}

@test "claude-profile rejects bad names" {
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile add '../evil'
    " 2>/dev/null
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero for bad name\n' >&2
        return 1
    fi
    assert_contains 'bad name message' 'bad profile name' "$output"
}

@test "claude-profile rm refuses real files without --force" {
    seed_store
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile add temp >/dev/null
        printf 'x' >'$FAKE_HOME/.claude-temp/.credentials.json'
        claude-profile rm temp
        echo \"AFTER_REFUSAL=\$?\"
        test -d '$FAKE_HOME/.claude-temp'
        echo \"STILL_THERE=\$?\"
        claude-profile rm --force temp
        test ! -e '$FAKE_HOME/.claude-temp'
        echo \"GONE=\$?\"
    " 2>/dev/null
    assert_eq 'rm flow rc 0' '0' "$status"
    assert_contains 'refusal warns' 'holds real files' "$output"
    assert_contains 'refusal kept dir' 'STILL_THERE=0' "$output"
    assert_contains 'force removed dir' 'GONE=0' "$output"
}

@test "claude-profile rm refuses non-profiles" {
    mkdir -p "$FAKE_HOME/.claude-bak"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile rm bak
    " 2>/dev/null
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero for non-profile\n' >&2
        return 1
    fi
    assert_contains 'not a profile' 'not a profile' "$output"
    [ -d "$FAKE_HOME/.claude-bak" ] || {
        printf 'FAIL: non-profile dir was touched\n' >&2
        return 1
    }
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

@test "existing overlay files are never replaced by links" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-work/projects"
    printf 'mine' >"$FAKE_HOME/.claude-work/projects/keep.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=work claude true" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
    assert_eq 'real file kept' 'mine' "$(cat "$FAKE_HOME/.claude-work/projects/keep.json")"
    if [[ -L "$FAKE_HOME/.claude-work/projects" ]]; then
        printf 'FAIL: real dir replaced by a link\n' >&2
        return 1
    fi
}

@test "differing shared token: launch stays quiet and both logins survive" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-personal"
    printf 'overlay-token' >"$FAKE_HOME/.claude-personal/.credentials.json"
    printf 'shared-token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=personal claude --version" 2>&1
    assert_eq 'launch rc 0' '0' "$status"
    if printf '%s' "$output" | grep -q 'ignoring a login'; then
        printf 'FAIL: launch should be quiet\n%s\n' "$output" >&2
        return 1
    fi
    assert_eq 'overlay token kept' 'overlay-token' "$(cat "$FAKE_HOME/.claude-personal/.credentials.json")"
    assert_eq 'shared token kept' 'shared-token' "$(cat "$FAKE_HOME/.claude/.credentials.json")"
}

@test "differing shared token warns on explicit add" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-personal"
    printf 'overlay-token' >"$FAKE_HOME/.claude-personal/.credentials.json"
    printf 'shared-token' >"$FAKE_HOME/.claude/.credentials.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile add personal" 2>&1
    assert_eq 'add rc 0' '0' "$status"
    assert_contains 'stray login warning' 'ignoring a login in the shared store' "$output"
}

@test "profile info shows account, plan and prefs" {
    local d="$FAKE_HOME/.claude-work"
    mkdir -p "$d"
    printf '%s\n' '{"claudeAiOauth":{"subscriptionType":"team","rateLimitTier":"default_raven"}}' >"$d/.credentials.json"
    printf '%s\n' '{"oauthAccount":{"emailAddress":"x@y.org","displayName":"X Y","organizationName":"Acme"}}' >"$d/.claude.json"
    printf '%s\n' '{"model":"sonnet","theme":"dark"}' >"$d/settings.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_profile_info '$d'"
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'authenticated' 'authenticated' "$output"
    assert_contains 'email' 'x@y.org' "$output"
    assert_contains 'name' 'X Y' "$output"
    assert_contains 'plan' 'team' "$output"
    assert_contains 'prefs' 'model=sonnet' "$output"
}

@test "profile info degrades without login" {
    local d="$FAKE_HOME/.claude-brandnew"
    mkdir -p "$d"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_profile_info '$d'"
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'not authenticated' 'not authenticated' "$output"
}

@test "missing binary fails without launching" {
    seed_store
    mkdir -p "$BATS_TEST_TMPDIR/emptybin"
    run bash -i -c "
        source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1
        PATH='$BATS_TEST_TMPDIR/emptybin:/usr/bin:/bin'
        CLAUDE_PROFILE=work claude --version
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
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=work claude --version" 2>/dev/null
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero on mkdir failure\n%s\n' "$output" >&2
        return 1
    fi
    assert_eq 'nothing launched' '' "$(cat "$CALLS_LOG")"
}
