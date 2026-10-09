#!/usr/bin/env bats
#
# test-doctor.bats — hermetic tests for scripts/.doctor.sh. Fixtures for
# the repo, codes roots, update state and Claude overlays; no network.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    mkdir -p "$XDG_STATE_HOME"
    unset DOT_NO_UPDATE_CHECK DOT_UPDATE_DAYS DOT_UPDATE_REPO DOT_UPDATE_ROOT
    unset DOT_PROMPT_STYLE DOT_DOCTOR_TOOLS CLAUDE_PROFILE CLAUDE_NO_PICKER
    unset CODES_ROOTS CODES_GROUP CODES_SUBMODULES
    export FIXREPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FIXREPO"
    git -C "$FIXREPO" init -q
    git -C "$FIXREPO" config user.email t@t
    git -C "$FIXREPO" config user.name t
    git -C "$FIXREPO" commit -q --allow-empty -m init
    git -C "$FIXREPO" tag 1.2.0
}

doctor_run() {
    bash -i -c "
        source '$REPO_ROOT/scripts/.doctor.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.update.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1
        PROMPT_COMMAND='__dottod_prompt'
        dottod-doctor
    " 2>/dev/null
}

seed_profiles() {
    mkdir -p "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude-work" "$FAKE_HOME/.claude-personal"
    printf 'x' >"$FAKE_HOME/.claude-work/.credentials.json"
    printf 'x' >"$FAKE_HOME/.claude-personal/.credentials.json"
    ln -s "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude-work/projects"
    ln -s "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude-personal/projects"
}

seed_update_state() {
    local tag=${1}
    mkdir -p "$XDG_STATE_HOME/dottod"
    printf '%s %s\n' "$(date +%s)" "$tag" >"$XDG_STATE_HOME/dottod/update-check"
}

@test "healthy tree reports ok and exits zero" {
    export CODES_ROOTS="$FIXREPO" DOT_UPDATE_ROOT="$FIXREPO"
    mkdir -p "$FIXREPO/proj"
    git -C "$FIXREPO/proj" init -q
    seed_profiles
    seed_update_state 1.2.0
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'bash ok' '[ok] bash' "$output"
    assert_contains 'prompt ok' 'prompt robbyrussell installed' "$output"
    assert_contains 'projects counted' 'projects found' "$output"
    assert_contains 'claude work ok' 'claude work logged in' "$output"
    assert_contains 'summary line' 'doctor:' "$output"
}

@test "tool override surfaces a missing tool as a warning" {
    export DOT_DOCTOR_TOOLS="git definitely-not-a-tool-xyz"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'git ok' '[ok] git on PATH' "$output"
    assert_contains 'missing tool warns' 'definitely-not-a-tool-xyz missing' "$output"
}

@test "broken overlay link warns" {
    seed_profiles
    ln -s "$FAKE_HOME/.claude/nope" "$FAKE_HOME/.claude-work/skills"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'broken link warns' 'has broken links' "$output"
}

@test "unknown prompt style warns" {
    export DOT_PROMPT_STYLE="bogus"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'style warns' 'unknown DOT_PROMPT_STYLE=bogus' "$output"
}

@test "pending update warns with both versions" {
    export DOT_UPDATE_ROOT="$FIXREPO"
    seed_update_state 1.3.0
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'pending update warns' '1.2.0 → 1.3.0' "$output"
}
