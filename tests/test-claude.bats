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
    unset CLAUDE_PROFILE CLAUDE_DEFAULT_PROFILE CLAUDE_NO_PICKER CLAUDE_CONFIG_DIR
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

@test "claude-profile rename moves the overlay and rewrites the marker" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude/projects"
    # Build a real overlay via add, then rename it.
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile add temp >/dev/null
        claude-profile rename temp temp2
        claude-profile ls
    " 2>/dev/null
    assert_eq 'rename rc 0' '0' "$status"
    assert_contains 'confirm rename' 'claude profile renamed: temp -> temp2' "$output"
    assert_contains 'new name listed' 'temp2' "$output"
    assert_eq 'marker rewritten' 'temp2' "$(cat "$FAKE_HOME/.claude-temp2/.dottod-profile")"
    [ ! -e "$FAKE_HOME/.claude-temp" ] || {
        printf 'FAIL: old dir still present\n' >&2
        return 1
    }
    [ -L "$FAKE_HOME/.claude-temp2/projects" ] || {
        printf 'FAIL: shared symlink lost after rename\n' >&2
        return 1
    }
}

@test "claude-profile rename refuses an existing target" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-a" "$FAKE_HOME/.claude-b"
    printf 'a\n' >"$FAKE_HOME/.claude-a/.dottod-profile"
    printf 'b\n' >"$FAKE_HOME/.claude-b/.dottod-profile"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile rename a b
    " 2>&1
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero renaming onto existing profile\n' >&2
        return 1
    fi
    assert_contains 'already exists' 'already exists' "$output"
    assert_eq 'source untouched' 'a' "$(cat "$FAKE_HOME/.claude-a/.dottod-profile")"
}

@test "claude-profile rename refuses a non-profile and a bad name" {
    mkdir -p "$FAKE_HOME/.claude-bak"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile rename bak foo
    " 2>&1
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero for non-profile source\n' >&2
        return 1
    fi
    assert_contains 'not a profile' 'not a profile' "$output"
    mkdir -p "$FAKE_HOME/.claude-a"
    printf 'a\n' >"$FAKE_HOME/.claude-a/.dottod-profile"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        claude-profile rename a '../evil'
    " 2>&1
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero for bad target name\n' >&2
        return 1
    fi
    assert_contains 'bad name' 'bad profile name' "$output"
}

@test "live profile detection finds a matching process" {
    local d="$BATS_TEST_TMPDIR/.claude-work"
    mkdir -p "$d"
    CLAUDE_CONFIG_DIR="$d" sleep 60 &
    local pid=$!
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_live_pid '$d'"
    kill "$pid" 2>/dev/null || true
    assert_eq 'rc 0' '0' "$status"
    assert_eq 'found the pid' "$pid" "$output"
}

@test "live profile detection is empty when nothing matches" {
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_live_pid '$BATS_TEST_TMPDIR/.claude-nope'"
    assert_eq 'rc 0' '0' "$status"
    assert_eq 'no match' '' "$output"
}

@test "live scan skips unreadable entries silently" {
    # Reproduces other-user processes (EACCES on environ): an unreadable
    # entry must be skipped with no "Permission denied" noise, while a
    # readable match is still found.
    local fake="$BATS_TEST_TMPDIR/fakeproc" d="$BATS_TEST_TMPDIR/.claude-x"
    mkdir -p "$fake/111" "$fake/222"
    printf 'PATH=/x\x00HOME=/y' >"$fake/111/environ"
    chmod 000 "$fake/111/environ"
    printf 'CLAUDE_CONFIG_DIR=%s\x00HOME=/y' "$d" >"$fake/222/environ"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_live_pid '$d' '$fake'" 2>&1
    assert_eq 'rc 0' '0' "$status"
    assert_eq 'found the readable match' '222' "$output"
    if printf '%s' "$output" | grep -qi 'denied'; then
        printf 'FAIL: permission noise leaked\n%s\n' "$output" >&2
        return 1
    fi
}

@test "rename refuses a live profile" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-a"
    printf 'a\n' >"$FAKE_HOME/.claude-a/.dottod-profile"
    CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude-a" sleep 60 &
    local pid=$!
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile rename a b" 2>&1
    kill "$pid" 2>/dev/null || true
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: rename should refuse a live profile\n' >&2
        return 1
    fi
    assert_contains 'in use' 'in use by claude' "$output"
    [ -d "$FAKE_HOME/.claude-a" ] || {
        printf 'FAIL: live profile was renamed anyway\n' >&2
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

@test "profile info shows usage bars with resets" {
    local d="$FAKE_HOME/.claude-metered"
    mkdir -p "$d"
    printf '%s\n' '{"cachedUsageUtilization":{"utilization":{"five_hour":{"utilization":69,"resets_at":"2030-01-04T23:00:00+00:00"},"seven_day":{"utilization":15,"resets_at":"2030-01-16T01:00:00+00:00"}},"fetchedAtMs":1893800000000}}' >"$d/.claude.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_profile_info '$d'"
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'five-hour percent' '69%' "$output"
    assert_contains 'seven-day percent' '15%' "$output"
    assert_contains 'five-hour row' 'usage    5h' "$output"
    assert_contains 'seven-day row' '7d' "$output"
    assert_contains 'reset labels' 'resets ' "$output"
    assert_contains 'staleness line' 'updated' "$output"
}

@test "profile info omits usage without cached data" {
    local d="$FAKE_HOME/.claude-fresh"
    mkdir -p "$d"
    printf '%s\n' '{"oauthAccount":{"emailAddress":"x@y.org"}}' >"$d/.claude.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_profile_info '$d'"
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'account still shown' 'x@y.org' "$output"
    if printf '%s' "$output" | grep -q 'usage'; then
        printf 'FAIL: usage section without cached data\n%s\n' "$output" >&2
        return 1
    fi
}

@test "bar colors follow consume level" {
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        __dottod_claude_bar 10 | od -An -c | head -n1
        __dottod_claude_bar 60 | od -An -c | head -n1
        __dottod_claude_bar 95 | od -An -c | head -n1
    "
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'green under 50' '3   2   m' "$output"
    assert_contains 'yellow under 80' '3   3   m' "$output"
    assert_contains 'red at/above 80' '3   1   m' "$output"
}

@test "picker exports every preview helper" {
    # fzf can't run hermetically, so assert the fix directly: the picker's
    # export must cover all callees of __dottod_claude_profile_info, or the
    # preview subshell logs "command not found" for bar/until/ago.
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        declare -f __dottod_claude_fzf
    "
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'exports profile info' 'export -f __dottod_claude_profile_info' "$output"
    assert_contains 'exports bar' '__dottod_claude_bar' "$output"
    assert_contains 'exports until' '__dottod_claude_until' "$output"
    assert_contains 'exports ago' '__dottod_claude_ago' "$output"
}

@test "fzf cancel aborts the launch" {
    # The exact user report: ESC/Ctrl+C in the picker (fzf rc 130) must
    # abort, never fall through to the default profile and launch.
    mkdir -p "$FAKE_HOME/.claude-work"
    printf 'work\n' >"$FAKE_HOME/.claude-work/.dottod-profile"
    cat >"$STUBBIN/fzf" <<'STUBEOF'
#!/usr/bin/env bash
exit 130
STUBEOF
    chmod +x "$STUBBIN/fzf"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        __dottod_claude_fzf
    "
    assert_eq 'helper propagates cancel' '130' "$status"
}

@test "aborted pick never launches the binary" {
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        __dottod_claude_pick_profile() { return 130; }
        claude --version
    "
    assert_eq 'launch aborted' '130' "$status"
    assert_eq 'nothing launched' '' "$(cat "$CALLS_LOG")"
}

@test "profile info resolves helpers in a child shell" {
    # Simulates the preview subshell: a fresh bash that inherits ONLY the
    # exported functions (as the picker does), not the sourced definitions.
    # Guards against any future callee left unexported.
    local d="$FAKE_HOME/.claude-metered"
    mkdir -p "$d"
    printf '%s\n' '{"cachedUsageUtilization":{"utilization":{"five_hour":{"utilization":69,"resets_at":"2030-01-04T23:00:00+00:00"},"seven_day":{"utilization":15,"resets_at":"2030-01-16T01:00:00+00:00"}},"fetchedAtMs":1893800000000}}' >"$d/.claude.json"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh'
        export -f __dottod_claude_profile_info __dottod_claude_bar __dottod_claude_until __dottod_claude_ago
        bash -c \"__dottod_claude_profile_info '$d'\"
    "
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'bar rendered' '69%' "$output"
    assert_contains 'reset shown' 'resets ' "$output"
    if printf '%s' "$output" | grep -q 'command not found'; then
        printf 'FAIL: helper command not found in preview subshell\n%s\n' "$output" >&2
        return 1
    fi
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

@test "empty store: first launch creates shared entries and links them" {
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=work claude true" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
    assert_eq 'projects linked' "$FAKE_HOME/.claude/projects" "$(readlink "$FAKE_HOME/.claude-work/projects")"
    assert_eq 'history linked' "$FAKE_HOME/.claude/history.jsonl" "$(readlink "$FAKE_HOME/.claude-work/history.jsonl")"
    [[ -d "$FAKE_HOME/.claude/projects" && -f "$FAKE_HOME/.claude/history.jsonl" ]]
}

@test "overlay copy is adopted when the store lacks the entry" {
    mkdir -p "$FAKE_HOME/.claude-work/projects/p"
    printf 'mine' >"$FAKE_HOME/.claude-work/projects/p/s.jsonl"
    run bash -i -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=work claude true" 2>/dev/null
    assert_eq 'launch rc 0' '0' "$status"
    assert_eq 'moved into the store' 'mine' "$(cat "$FAKE_HOME/.claude/projects/p/s.jsonl")"
    [[ -L "$FAKE_HOME/.claude-work/projects" ]]
}

@test "consolidate merges two split profiles into the store" {
    local h="$FAKE_HOME"
    mkdir -p "$h/.claude/projects/p" "$h/.claude-a/projects/p/memory" "$h/.claude-b/projects/q" "$h/.claude-a/plugins"
    printf 'a\n' >"$h/.claude-a/.dottod-profile"
    printf 'b\n' >"$h/.claude-b/.dottod-profile"
    printf 'old' >"$h/.claude/projects/p/s0.jsonl"
    printf 'one' >"$h/.claude-a/projects/p/s1.jsonl"
    printf 'A' >"$h/.claude-a/projects/p/memory/MEMORY.md"
    printf 'two' >"$h/.claude-b/projects/q/s2.jsonl"
    printf '{"display":"x","timestamp":2}\n' >"$h/.claude-a/history.jsonl"
    printf '{"display":"y","timestamp":1}\n' >"$h/.claude-b/history.jsonl"
    printf '{"p":"%s/.claude-a/plugins/m"}' "$h" >"$h/.claude-a/plugins/known_marketplaces.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile consolidate"
    assert_eq 'consolidate rc 0' '0' "$status"
    assert_eq 'store kept' 'old' "$(cat "$h/.claude/projects/p/s0.jsonl")"
    assert_eq 'a merged' 'one' "$(cat "$h/.claude/projects/p/s1.jsonl")"
    assert_eq 'memory merged' 'A' "$(cat "$h/.claude/projects/p/memory/MEMORY.md")"
    assert_eq 'b merged' 'two' "$(cat "$h/.claude/projects/q/s2.jsonl")"
    assert_eq 'a linked' "$h/.claude/projects" "$(readlink "$h/.claude-a/projects")"
    assert_eq 'b linked' "$h/.claude/projects" "$(readlink "$h/.claude-b/projects")"
    assert_eq 'history merged and ordered' 'yx' "$(jq -j '.display' "$h/.claude/history.jsonl")"
    assert_contains 'plugin paths rewritten' "$h/.claude/plugins/m" "$(cat "$h/.claude/plugins/known_marketplaces.json")"
}

@test "consolidate keeps differing files side by side" {
    local h="$FAKE_HOME"
    mkdir -p "$h/.claude/projects/p" "$h/.claude-a/projects/p"
    printf 'a\n' >"$h/.claude-a/.dottod-profile"
    printf 'store' >"$h/.claude/projects/p/MEMORY.md"
    printf 'mine' >"$h/.claude-a/projects/p/MEMORY.md"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile consolidate a 2>/dev/null"
    assert_eq 'consolidate rc 0' '0' "$status"
    assert_eq 'store wins' 'store' "$(cat "$h/.claude/projects/p/MEMORY.md")"
    assert_eq 'profile copy kept' 'mine' "$(cat "$h/.claude/projects/p/MEMORY.md.from-a")"
}

@test "consolidate refuses a live profile without --force" {
    mkdir -p "$FAKE_HOME/.claude-a/projects"
    printf 'a\n' >"$FAKE_HOME/.claude-a/.dottod-profile"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_live_pid() { printf 42; }; claude-profile consolidate a"
    assert_eq 'refused' '1' "$status"
    [[ -d "$FAKE_HOME/.claude-a/projects" && ! -L "$FAKE_HOME/.claude-a/projects" ]]
}

@test "consolidate appends a transcript resumed in both places" {
    local h="$FAKE_HOME"
    mkdir -p "$h/.claude/projects/p" "$h/.claude-a/projects/p"
    printf 'a\n' >"$h/.claude-a/.dottod-profile"
    printf '1\n2\n' >"$h/.claude/projects/p/s.jsonl"
    printf '2\n3\n4\n' >"$h/.claude-a/projects/p/s.jsonl"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile consolidate a"
    assert_eq 'consolidate rc 0' '0' "$status"
    assert_eq 'missing lines appended in order' '1234' "$(tr -d '\n' <"$h/.claude/projects/p/s.jsonl")"
    [[ ! -e "$h/.claude/projects/p/s.jsonl.from-a" ]]
}

@test "launch warns about a private copy even when quiet" {
    seed_store
    mkdir -p "$FAKE_HOME/.claude-work/projects"
    printf 'work\n' >"$FAKE_HOME/.claude-work/.dottod-profile"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1; CLAUDE_PROFILE=work claude -c 2>&1"
    assert_eq 'launch rc 0' '0' "$status"
    assert_contains 'split reported' 'private copy, not shared (run claude-profile init)' "$output"
}

# continue_probe <answer> <args...>: claude in a project dir, as if on a
# terminal (the can_ask seam), answering the y/N question with <answer>.
continue_probe() {
    local answer="$1"
    shift
    mkdir -p "$BATS_TEST_TMPDIR/proj.x"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1
        __dottod_claude_can_ask() { return 0; }
        cd '$BATS_TEST_TMPDIR/proj.x'
        CLAUDE_PROFILE=work claude $* <<<'$answer'
    "
}

conversation_key() {
    local p
    p="$(cd "$BATS_TEST_TMPDIR/proj.x" && pwd -P)"
    printf '%s' "${p//[^A-Za-z0-9]/-}"
}

@test "--continue with no conversation asks; y starts a new one" {
    continue_probe y --continue --model opus
    assert_eq 'rc' '0' "$status"
    assert_contains 'asks' 'no conversation to continue in' "$output"
    assert_contains 'y/N' 'Start a new one? [y/N]' "$output"
    assert_contains 'launched without --continue' 'ARGS=--model opus' "$(cat "$CALLS_LOG")"
}

@test "--continue with no conversation: N (or enter) launches nothing" {
    continue_probe '' -c
    assert_eq 'rc' '1' "$status"
    assert_eq 'never launched' '' "$(cat "$CALLS_LOG")"
    continue_probe n -c
    assert_eq 'n rc' '1' "$status"
    assert_eq 'still never launched' '' "$(cat "$CALLS_LOG")"
}

@test "--continue with a saved conversation goes straight through" {
    mkdir -p "$BATS_TEST_TMPDIR/proj.x"
    mkdir -p "$FAKE_HOME/.claude/projects/$(conversation_key)"
    : >"$FAKE_HOME/.claude/projects/$(conversation_key)/abc.jsonl"
    continue_probe n -c
    assert_eq 'rc' '0' "$status"
    assert_eq 'no question' '' "$output"
    assert_contains 'continue kept' 'ARGS=-c' "$(cat "$CALLS_LOG")"
}

@test "--continue without a terminal passes through untouched" {
    mkdir -p "$BATS_TEST_TMPDIR/proj.x"
    run bash -c "
        source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1
        cd '$BATS_TEST_TMPDIR/proj.x'
        CLAUDE_PROFILE=work claude --continue -p hi </dev/null
    "
    assert_eq 'rc' '0' "$status"
    assert_eq 'no question' '' "$output"
    assert_contains 'Claude Code decides' 'ARGS=--continue -p hi' "$(cat "$CALLS_LOG")"
}

@test "only options ask: -c after -- is an argument, and is kept" {
    continue_probe n -- -c
    assert_eq 'rc' '0' "$status"
    assert_eq 'no question' '' "$output"
    assert_contains 'forwarded' 'ARGS=-- -c' "$(cat "$CALLS_LOG")"
}

@test "conversation lookup keys the path like Claude Code" {
    source "$REPO_ROOT/scripts/.claude.sh" >/dev/null 2>&1
    local d="$BATS_TEST_TMPDIR/cfg"
    mkdir -p "$d/projects/-srv-my-app-v1-2"
    run __dottod_claude_has_conversation "$d" /srv/my_app/v1.2
    assert_eq 'empty dir: none' '1' "$status"
    : >"$d/projects/-srv-my-app-v1-2/s.jsonl"
    run __dottod_claude_has_conversation "$d" /srv/my_app/v1.2
    assert_eq 'found' '0' "$status"
    run __dottod_claude_has_conversation "$d" "/$(printf 'x%.0s' {1..210})"
    assert_eq 'long path: Claude Code decides' '0' "$status"
}

@test "a bare --resume with no conversation asks too; y starts a new one" {
    continue_probe y -r --model opus
    assert_eq 'rc' '0' "$status"
    assert_contains 'asks about resuming' 'no conversation to resume in' "$output"
    assert_contains 'launched without -r' 'ARGS=--model opus' "$(cat "$CALLS_LOG")"
    : >"$CALLS_LOG"
    continue_probe n --resume
    assert_eq 'n rc' '1' "$status"
    assert_eq 'never launched' '' "$(cat "$CALLS_LOG")"
}

@test "--resume with a session id or search term is Claude Code's to resolve" {
    continue_probe n --resume 3f2a-id
    assert_eq 'rc' '0' "$status"
    assert_eq 'no question' '' "$output"
    assert_contains 'id kept' 'ARGS=--resume 3f2a-id' "$(cat "$CALLS_LOG")"
}

@test "--resume with a saved conversation goes straight to the picker" {
    mkdir -p "$BATS_TEST_TMPDIR/proj.x"
    mkdir -p "$FAKE_HOME/.claude/projects/$(conversation_key)"
    : >"$FAKE_HOME/.claude/projects/$(conversation_key)/abc.jsonl"
    continue_probe n -r
    assert_eq 'rc' '0' "$status"
    assert_eq 'no question' '' "$output"
    assert_contains 'resume kept' 'ARGS=-r' "$(cat "$CALLS_LOG")"
}
