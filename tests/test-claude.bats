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
    unset CLAUDE_PROFILE CLAUDE_DEFAULT_PROFILE CLAUDE_NO_PICKER CLAUDE_CONFIG_DIR CLAUDE_USAGE_TTL
    # Usage refreshes start in the background when the picker opens; the
    # tests that want them turn this back on.
    export CLAUDE_USAGE_REFRESH=0
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN"
    export PATH="$STUBBIN:$PATH"
    # Stub claude: records CLAUDE_CONFIG_DIR + args; `-p /usage` also
    # records its cwd and writes fresh usage numbers into the profile, as
    # Claude Code does (USAGE_STUB_FAIL=1: exits 1 without writing).
    cat >"$STUBBIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
printf 'DIR=%s ARGS=%s\n' "${CLAUDE_CONFIG_DIR:-}" "$*" >>"${CALLS_LOG:?}"
if [[ "$*" == '-p /usage --no-session-persistence' ]]; then
    printf 'USAGE_CWD=%s\n' "$PWD" >>"${CALLS_LOG:?}"
    [[ -z "${USAGE_STUB_FAIL:-}" ]] || exit 1
    printf '{"cachedUsageUtilization":{"utilization":{"five_hour":{"utilization":42,"resets_at":"2030-01-04T23:00:00+00:00"},"seven_day":{"utilization":7,"resets_at":"2030-01-16T01:00:00+00:00"}},"fetchedAtMs":%s000}}\n' "$(date +%s)" >"${CLAUDE_CONFIG_DIR}/.claude.json"
fi
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
    local plain
    plain="$(sed $'s/\033\\[[0-9;]*m//g' <<<"$output")"
    assert_contains 'prefs as indented JSON' '    "model": "sonnet"' "$plain"
    assert_eq 'prefs come last' '  }' "$(tail -n1 <<<"$plain")"
}

@test "profile prefs mask env values and secret-looking keys" {
    local d="$FAKE_HOME/.claude-work"
    mkdir -p "$d"
    printf '%s\n' '{"model":"opus","env":{"ANTHROPIC_AUTH_TOKEN":"sk-live-1","DEBUG":"1"},"mcp":{"githubToken":"ghp_2","url":"https://x"}}' >"$d/settings.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_profile_info '$d'"
    local plain
    plain="$(sed $'s/\033\\[[0-9;]*m//g' <<<"$output")"
    assert_contains 'env masked' '"ANTHROPIC_AUTH_TOKEN": "•••"' "$plain"
    assert_contains 'nested token masked' '"githubToken": "•••"' "$plain"
    assert_contains 'plain values kept' '"url": "https://x"' "$plain"
    if [[ "$plain" == *sk-live-1* || "$plain" == *ghp_2* ]]; then
        printf 'FAIL: a secret value reached the panel\n' >&2
        return 1
    fi
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
    assert_contains 'reset glyph' $'69%  \uf1da ' "$output"
    # Both stamps are years away: full dates.
    assert_match '7d reset far away: the date' $'7d .*\uf1da [A-Z][a-z]{2} [0-9]{2} [A-Z][a-z]{2} [0-9]{2}:[0-9]{2}$' "$(grep '7d' <<<"$output")"
    if [[ "$output" == *resets* ]]; then
        printf 'FAIL: the resets label is gone, the glyph replaces it\n' >&2
        return 1
    fi
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

@test "picker preview and ctrl-r run in a child shell with every helper" {
    # A stub fzf runs the picker's real --preview and ctrl-r commands the
    # way fzf does (a child bash, {} replaced by the quoted name), so a
    # helper left unexported shows up as "command not found".
    local d="$FAKE_HOME/.claude-work"
    mkdir -p "$d"
    printf 'work\n' >"$d/.dottod-profile"
    printf 'tok' >"$d/.credentials.json"
    cat >"$STUBBIN/fzf" <<'STUBEOF'
#!/usr/bin/env bash
name="$(head -n1)"
for a in "$@"; do
    case "$a" in
        --preview=*) cmd="${a#--preview=}"; bash -c "${cmd//\{\}/\'$name\'}" >>"$PREVIEW_LOG" 2>&1 ;;
        --bind=ctrl-r:execute-silent\(*) cmd="${a#--bind=ctrl-r:execute-silent(}"; cmd="${cmd%)+refresh-preview}"
            bash -c "${cmd//\{\}/\'$name\'}" >>"$PREVIEW_LOG" 2>&1 ;;
    esac
done
for a in "$@"; do
    case "$a" in --preview=*) cmd="${a#--preview=}"; bash -c "${cmd//\{\}/\'$name\'}" >>"$PREVIEW_LOG" 2>&1 ;; esac
done
printf '%s\n' "$name"
STUBEOF
    chmod +x "$STUBBIN/fzf"
    export PREVIEW_LOG="$BATS_TEST_TMPDIR/preview.log"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_fzf"
    assert_eq 'picked' 'work' "$output"
    local log
    log="$(cat "$PREVIEW_LOG")"
    if [[ "$log" == *'command not found'* ]]; then
        printf 'FAIL: a helper is missing in the child shell\n%s\n' "$log" >&2
        return 1
    fi
    assert_contains 'ctrl-r refreshed the profile' "DIR=$d ARGS=-p /usage --no-session-persistence" "$(cat "$CALLS_LOG")"
    assert_contains 'preview redrawn with the new numbers' '42%' "$log"
    assert_contains 'fresh' 'updated just now' "$log"
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
        export -f __dottod_claude_profile_info __dottod_claude_bar __dottod_claude_epoch __dottod_claude_until __dottod_claude_ago __dottod_claude_usage_lines
        bash -c \"__dottod_claude_profile_info '$d'\"
    "
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'bar rendered' '69%' "$output"
    assert_contains 'reset shown' $'\uf1da' "$output"
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

@test "init repairs split profiles, links them and seeds the memory once" {
    local h="$FAKE_HOME" mem
    mkdir -p "$h/.claude/projects/p" "$h/.claude-a/projects/p" "$h/.claude-b"
    printf 'a\n' >"$h/.claude-a/.dottod-profile"
    printf 'b\n' >"$h/.claude-b/.dottod-profile"
    printf 'one' >"$h/.claude-a/projects/p/s1.jsonl"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile init; claude-profile init"
    assert_eq 'init rc 0' '0' "$status"
    assert_eq 'a merged' 'one' "$(cat "$h/.claude/projects/p/s1.jsonl")"
    assert_eq 'a linked' "$h/.claude/projects" "$(readlink "$h/.claude-a/projects")"
    assert_eq 'b linked' "$h/.claude/projects" "$(readlink "$h/.claude-b/projects")"
    mem="$h/.claude/projects/${h//[^A-Za-z0-9]/-}/memory"
    assert_contains 'note written' 'claude-profile init' "$(cat "$mem/claude-profiles.md")"
    assert_eq 'indexed once' '1' "$(grep -c 'claude-profiles.md' "$mem/MEMORY.md")"
}

@test "init keeps an edited memory note" {
    local mem="$FAKE_HOME/.claude/projects/${FAKE_HOME//[^A-Za-z0-9]/-}/memory"
    mkdir -p "$mem"
    printf 'mine' >"$mem/claude-profiles.md"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile init"
    assert_eq 'init rc 0' '0' "$status"
    assert_eq 'note untouched' 'mine' "$(cat "$mem/claude-profiles.md")"
}

@test "init refuses a split profile in use and leaves it alone" {
    mkdir -p "$FAKE_HOME/.claude-a/projects"
    printf 'a\n' >"$FAKE_HOME/.claude-a/.dottod-profile"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_live_pid() { printf 42; }; claude-profile init"
    assert_eq 'refused' '1' "$status"
    assert_contains 'says why' 'split but in use by claude (pid 42)' "$output"
    [[ -d "$FAKE_HOME/.claude-a/projects" && ! -L "$FAKE_HOME/.claude-a/projects" ]]
}

@test "init leaves a healthy profile in use alone" {
    mkdir -p "$FAKE_HOME/.claude-a"
    printf 'a\n' >"$FAKE_HOME/.claude-a/.dottod-profile"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_live_pid() { printf 42; }; claude-profile init"
    assert_eq 'init rc 0' '0' "$status"
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

@test "reset stamps: time left up to a day, the date beyond" {
    source "$REPO_ROOT/scripts/.claude.sh" >/dev/null 2>&1
    local soon later far
    # Epoch arithmetic: BusyBox date has no relative "+35 minutes".
    soon="$(date -u -d "@$(($(date +%s) + 2120))" +%FT%TZ)"
    later="$(date -u -d "@$(($(date +%s) + 15150))" +%FT%TZ)"
    far="$(date -u -d "@$(($(date +%s) + 259200))" +%FT%TZ)"
    assert_eq 'minutes' 'in 35m' "$(__dottod_claude_until "$soon")"
    assert_eq 'hours and minutes' 'in 4h 12m' "$(__dottod_claude_until "$later")"
    assert_eq 'more than a day: the date' "$(date -d "@$(($(date +%s) + 259200))" +'%a %d %b %H:%M')" "$(__dottod_claude_until "$far")"
    assert_eq 'past' 'any moment' "$(__dottod_claude_until 2001-01-01T00:00:00Z)"
    assert_eq 'unparseable stays raw' 'soon-ish' "$(__dottod_claude_until soon-ish)"
}

@test "usage is stale when logged in and missing, old, or past CLAUDE_USAGE_TTL" {
    source "$REPO_ROOT/scripts/.claude.sh" >/dev/null 2>&1
    local d="$BATS_TEST_TMPDIR/p"
    mkdir -p "$d"
    run __dottod_claude_usage_stale "$d"
    assert_eq 'not logged in: never refreshed' '1' "$status"
    printf 'tok' >"$d/.credentials.json"
    run __dottod_claude_usage_stale "$d"
    assert_eq 'no numbers yet' '0' "$status"
    printf '{"cachedUsageUtilization":{"fetchedAtMs":%s000}}' "$(($(date +%s) - 60))" >"$d/.claude.json"
    run __dottod_claude_usage_stale "$d"
    assert_eq 'a minute old: fresh' '1' "$status"
    CLAUDE_USAGE_TTL=30 run __dottod_claude_usage_stale "$d"
    assert_eq 'past a shorter TTL' '0' "$status"
}

@test "usage refresh asks claude -p /usage from HOME, under a lock" {
    source "$REPO_ROOT/scripts/.claude.sh" >/dev/null 2>&1
    local d="$FAKE_HOME/.claude-work"
    mkdir -p "$d"
    run __dottod_claude_usage_refresh "$d"
    assert_eq 'rc' '0' "$status"
    assert_contains 'Claude Code itself, no session saved' "DIR=$d ARGS=-p /usage --no-session-persistence" "$(cat "$CALLS_LOG")"
    assert_contains 'from HOME' "USAGE_CWD=$FAKE_HOME" "$(cat "$CALLS_LOG")"
    assert_eq 'lock released' '0' "$([[ -e "$d/.dottod-usage.lock" ]] && echo 1 || echo 0)"

    : >"$CALLS_LOG"
    mkdir "$d/.dottod-usage.lock"
    run __dottod_claude_usage_refresh "$d"
    assert_eq 'busy: skipped' '1' "$status"
    assert_eq 'nothing ran' '' "$(cat "$CALLS_LOG")"
    touch -t "$(date -d "@$(($(date +%s) - 180))" +%Y%m%d%H%M.%S)" "$d/.dottod-usage.lock"
    run __dottod_claude_usage_refresh "$d"
    assert_eq 'stale lock taken over' '0' "$status"

    USAGE_STUB_FAIL=1 run __dottod_claude_usage_refresh "$d"
    assert_eq 'failure reported' '1' "$status"
    assert_eq 'lock released after a failure' '0' "$([[ -e "$d/.dottod-usage.lock" ]] && echo 1 || echo 0)"
}

@test "the picker refreshes only stale, logged-in profiles in the background" {
    local p
    for p in fresh stale nologin; do
        mkdir -p "$FAKE_HOME/.claude-$p"
        printf '%s\n' "$p" >"$FAKE_HOME/.claude-$p/.dottod-profile"
    done
    printf 'tok' >"$FAKE_HOME/.claude-fresh/.credentials.json"
    printf 'tok' >"$FAKE_HOME/.claude-stale/.credentials.json"
    printf '{"cachedUsageUtilization":{"fetchedAtMs":%s000}}' "$(date +%s)" >"$FAKE_HOME/.claude-fresh/.claude.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; CLAUDE_USAGE_REFRESH=1 __dottod_claude_usage_spawn"
    assert_eq 'returns at once' '0' "$status"
    local i
    for ((i = 0; i < 50; i++)); do
        grep -q 'USAGE_CWD' "$CALLS_LOG" && break
        sleep 0.1
    done
    sleep 0.3
    local calls
    calls="$(cat "$CALLS_LOG")"
    assert_contains 'stale refreshed' "DIR=$FAKE_HOME/.claude-stale ARGS=-p /usage" "$calls"
    assert_eq 'only that one' '1' "$(grep -c 'ARGS=-p /usage' <<<"$calls")"

    : >"$CALLS_LOG"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; CLAUDE_USAGE_REFRESH=0 __dottod_claude_usage_spawn"
    sleep 0.5
    assert_eq 'CLAUDE_USAGE_REFRESH=0: none' '' "$(cat "$CALLS_LOG")"
}

@test "claude-profile usage refreshes now and prints every profile's bars" {
    mkdir -p "$FAKE_HOME/.claude-work" "$FAKE_HOME/.claude-guest"
    printf 'work\n' >"$FAKE_HOME/.claude-work/.dottod-profile"
    printf 'guest\n' >"$FAKE_HOME/.claude-guest/.dottod-profile"
    printf 'tok' >"$FAKE_HOME/.claude-work/.credentials.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile usage"
    assert_eq 'rc' '0' "$status"
    assert_contains 'work refreshed' '42%' "$output"
    assert_contains 'fresh' 'updated just now' "$output"
    assert_contains 'guest has no login' $'guest\nnot authenticated' "$output"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; claude-profile usage nobody"
    assert_eq 'unknown rc' '1' "$status"
    assert_contains 'says so' 'not a profile: nobody' "$output"
}

@test "a usage window with nothing used yet shows 0% and no reset" {
    local d="$FAKE_HOME/.claude-idle"
    mkdir -p "$d"
    printf '%s\n' '{"cachedUsageUtilization":{"utilization":{"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":68,"resets_at":"2030-01-16T01:00:00+00:00"}},"fetchedAtMs":1893800000000}}' >"$d/.claude.json"
    run bash -c "source '$REPO_ROOT/scripts/.claude.sh'; __dottod_claude_usage_lines '$d'"
    assert_match '5h at 0%, no glyph' '^usage    5h .*   0%$' "$(grep '5h' <<<"$output")"
    assert_contains '7d keeps its reset' $'68%  \uf1da ' "$output"
}

@test "ISO stamps parse without GNU date (offsets, fractions, Z)" {
    source "$REPO_ROOT/scripts/.claude.sh" >/dev/null 2>&1
    assert_eq 'epoch start' '0' "$(__dottod_claude_epoch 1970-01-01T00:00:00Z)"
    assert_eq 'zero offset' '1893456000' "$(__dottod_claude_epoch 2030-01-01T00:00:00+00:00)"
    assert_eq 'positive offset' '1893456000' "$(__dottod_claude_epoch 2030-01-01T02:00:00+02:00)"
    assert_eq 'negative offset' '1893463200' "$(__dottod_claude_epoch 2029-12-31T20:30:00-05:30)"
    assert_eq 'fraction ignored' '1893456000' "$(__dottod_claude_epoch 2030-01-01T00:00:00.987654Z)"
    assert_eq 'leap day' '951868800' "$(__dottod_claude_epoch 2000-03-01T00:00:00Z)"
    run __dottod_claude_epoch 'not a date'
    assert_eq 'garbage fails' '1' "$status"
}
