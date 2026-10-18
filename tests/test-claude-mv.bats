#!/usr/bin/env bats
#
# test-claude-mv.bats — hermetic tests for scripts/.claude-mv.sh (spec 021):
# moving a directory brings its Claude Code sessions along. A fake HOME
# holds the shared store (~/.claude), two profiles linking projects/ and
# history.jsonl to it, each with its own .claude.json, and ~/.claude.json.
#
#   $W/proj            the directory moved (sessions in it and in docs/)
#   $W/proj-x          a lookalike: its key starts with proj's — untouched

load helpers

key() { printf '%s' "${1//[^A-Za-z0-9]/-}"; }

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    unset CLAUDE_CONFIG_DIR XDG_STATE_HOME
    W="$BATS_TEST_TMPDIR/w"
    mkdir -p "$W/proj/docs" "$W/proj-x" "$W/dest"
    W="$(cd "$W" && pwd -P)"
    P="$W/proj" X="$W/proj-x" N="$W/dest/renamed"
    printf 'code\n' >"$P/main.sh"
    S="$HOME/.claude"
    mkdir -p "$S/projects/$(key "$P")/memory" "$S/projects/$(key "$P")/abc/subagents" \
        "$S/projects/$(key "$P/docs")" "$S/projects/$(key "$X")"
    # The session started in proj, wandered into docs; its text mentions proj.
    {
        printf '{"cwd":"%s","sessionId":"abc","type":"user","message":"look at %s/main.sh"}\n' "$P" "$P"
        printf '{"cwd":"%s/docs","sessionId":"abc","type":"user"}\n' "$P"
        printf '{"type":"summary","sessionId":"abc"}\n'
    } >"$S/projects/$(key "$P")/abc.jsonl"
    printf '{"cwd":"%s","sessionId":"abc","isSidechain":true}\n' "$P" >"$S/projects/$(key "$P")/abc/subagents/a1.jsonl"
    printf 'remember this\n' >"$S/projects/$(key "$P")/memory/MEMORY.md"
    printf '{"cwd":"%s/docs","sessionId":"def"}\n' "$P" >"$S/projects/$(key "$P/docs")/def.jsonl"
    printf '{"cwd":"%s","sessionId":"ghi"}\n' "$X" >"$S/projects/$(key "$X")/ghi.jsonl"
    {
        printf '{"display":"a","project":"%s","sessionId":"abc"}\n' "$P"
        printf '{"display":"b","project":"%s/docs","sessionId":"def"}\n' "$P"
        printf '{"display":"c","project":"%s","sessionId":"ghi"}\n' "$X"
    } >"$S/history.jsonl"
    local prof
    for prof in work personal; do
        mkdir -p "$HOME/.claude-$prof"
        printf '%s\n' "$prof" >"$HOME/.claude-$prof/.dottod-profile"
        ln -s "$S/projects" "$HOME/.claude-$prof/projects"
        ln -s "$S/history.jsonl" "$HOME/.claude-$prof/history.jsonl"
        printf '{"projects":{"%s":{"hasTrustDialogAccepted":true,"who":"%s"},"%s/docs":{"x":1},"%s":{"y":2}},"githubRepoPaths":{"o/r":["%s"]}}\n' \
            "$P" "$prof" "$P" "$X" "$P" >"$HOME/.claude-$prof/.claude.json"
    done
    printf '{"projects":{"%s":{"z":3}}}\n' "$P" >"$HOME/.claude.json"
    mkdir -p "$HOME/.local/state/codes"
    printf '100\t%s\n200\t%s/docs\n300\t%s\n' "$P" "$P" "$X" >"$HOME/.local/state/codes/visits"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.claude.sh" >/dev/null 2>&1
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.claude-mv.sh"
    # No real process ever counts as live here.
    __dottod_mv_live() { :; }
}

snapshot() {
    find "$HOME" "$W" -type f -exec md5sum {} + | sort
}

@test "--dry-run shows the plan and changes nothing" {
    local before
    before="$(snapshot)"
    run claude-mv --dry-run "$P" "$N"
    assert_eq 'rc' '0' "$status"
    assert_contains 'says so' 'dry run — nothing changes' "$output"
    assert_contains 'directory' "directory: $P -> $N" "$output"
    assert_contains 'top folder' "sessions:  $(key "$P") -> $(key "$N")" "$output"
    assert_contains 'subdirectory folder' "sessions:  $(key "$P/docs") -> $(key "$N/docs")" "$output"
    assert_contains 'history' 'history:   2 line(s)' "$output"
    assert_contains 'a profile config' 'config:    3 entries in ~/.claude-work/.claude.json' "$output"
    assert_contains 'default config' 'config:    1 entry in ~/.claude.json' "$output"
    assert_contains 'codes visits' 'codes:     2 visit(s)' "$output"
    if [[ "$output" == *"$(key "$X")"* ]]; then
        printf 'FAIL: the lookalike folder was planned\n' >&2
        return 1
    fi
    assert_eq 'nothing changed' "$before" "$(snapshot)"
}

@test "moves the directory and every record of its sessions" {
    run claude-mv "$P" "$N"
    assert_eq 'rc' '0' "$status"
    assert_eq 'directory moved' 'code' "$(cat "$N/main.sh")"
    assert_eq 'old path gone' '0' "$([[ -e "$P" ]] && echo 1 || echo 0)"

    local nf
    nf="$S/projects/$(key "$N")"
    assert_eq 'folder renamed' '1' "$([[ -f "$nf/abc.jsonl" && ! -e "$S/projects/$(key "$P")" ]] && echo 1 || echo 0)"
    assert_contains 'cwd repointed' "\"cwd\":\"$N\"" "$(cat "$nf/abc.jsonl")"
    assert_contains 'subdirectory cwd repointed' "\"cwd\":\"$N/docs\"" "$(cat "$nf/abc.jsonl")"
    assert_contains 'conversation text kept' "look at $P/main.sh" "$(cat "$nf/abc.jsonl")"
    assert_contains 'subagent transcript repointed' "\"cwd\":\"$N\"" "$(cat "$nf/abc/subagents/a1.jsonl")"
    assert_eq 'memory moved' 'remember this' "$(cat "$nf/memory/MEMORY.md")"
    assert_contains 'session started in docs moved' "\"cwd\":\"$N/docs\"" "$(cat "$S/projects/$(key "$N/docs")/def.jsonl")"

    assert_contains 'lookalike untouched' "\"cwd\":\"$X\"" "$(cat "$S/projects/$(key "$X")/ghi.jsonl")"
    local hist
    hist="$(cat "$S/history.jsonl")"
    assert_contains 'history repointed' "\"project\":\"$N\"" "$hist"
    assert_contains 'history subdirectory' "\"project\":\"$N/docs\"" "$hist"
    assert_contains 'history lookalike kept' "\"project\":\"$X\"" "$hist"

    local prof
    for prof in work personal; do
        run jq -r --arg n "$N" --arg x "$X" '[.projects[$n].who, (.projects[$n + "/docs"].x), .projects[$x].y, .githubRepoPaths["o/r"][0]] | join(",")' "$HOME/.claude-$prof/.claude.json"
        assert_eq "$prof config" "$prof,1,2,$N" "$output"
    done
    assert_eq 'default config' '3' "$(jq -r --arg n "$N" '.projects[$n].z' "$HOME/.claude.json")"
    assert_eq 'codes visits' "100	$N
200	$N/docs
300	$X" "$(cat "$HOME/.local/state/codes/visits")"
    assert_eq 'profile links intact' "$S/projects" "$(readlink "$HOME/.claude-work/projects")"
}

@test "backs up every file and folder it rewrites first" {
    run claude-mv "$P" "$N"
    assert_eq 'rc' '0' "$status"
    local b
    b="$(find "$HOME/.local/state/dottod/claude-mv" -mindepth 1 -maxdepth 1 -type d)"
    assert_eq 'one backup' '1' "$(grep -c . <<<"$b")"
    assert_eq 'private' '700' "$(stat -c %a "$b")"
    assert_contains 'original transcript' "\"cwd\":\"$P\"" "$(cat "$b/$(key "$P")/abc.jsonl")"
    assert_contains 'original history' "\"project\":\"$P\"" "$(cat "$b/$(key "$S/history.jsonl")")"
    assert_contains 'original config' "$P" "$(cat "$b/$(key "$HOME/.claude-work/.claude.json")")"
    assert_contains 'reported' 'backup in ~/.local/state/dottod/claude-mv/' "$output"
}

@test "--fixup repoints a directory already moved by hand" {
    mv "$P" "$N"
    run claude-mv "$P" "$N"
    assert_eq 'without --fixup: refused' '1' "$status"
    assert_contains 'hints' 'already moved? use --fixup' "$output"
    run claude-mv --fixup "$P" "$N"
    assert_eq 'rc' '0' "$status"
    assert_contains 'says so' "directory: already at $N" "$output"
    assert_contains 'repointed' "\"cwd\":\"$N\"" "$(cat "$S/projects/$(key "$N")/abc.jsonl")"
    run claude-mv --fixup "$W/dest" "$W/other"
    assert_eq 'fixup with OLD still there: refused' '1' "$status"
}

@test "merges into a destination that already has sessions" {
    mkdir -p "$S/projects/$(key "$N")"
    printf '{"cwd":"%s","sessionId":"new"}\n' "$N" >"$S/projects/$(key "$N")/new.jsonl"
    run claude-mv "$P" "$N"
    assert_eq 'rc' '0' "$status"
    assert_contains 'plan says merged' '(merged)' "$output"
    assert_eq 'both sessions there' '2' "$(find "$S/projects/$(key "$N")" -maxdepth 1 -name '*.jsonl' | wc -l)"
    assert_eq 'old folder gone' '0' "$([[ -e "$S/projects/$(key "$P")" ]] && echo 1 || echo 0)"
}

@test "refuses: an existing NEW, NEW inside OLD, a missing parent, odd paths" {
    mkdir -p "$W/taken"
    run claude-mv "$P" "$W/taken"
    assert_contains 'existing' 'already exists' "$output"
    run claude-mv "$P" "$P/docs/inner"
    assert_contains 'inside' 'or inside it' "$output"
    run claude-mv "$P" "$W/nowhere/x"
    assert_contains 'parent' "$W/nowhere does not exist" "$output"
    run claude-mv "$P" "$W/a\"b"
    assert_eq 'quote rc' '2' "$status"
    run claude-mv "$P"
    assert_eq 'usage rc' '2' "$status"
    assert_eq 'nothing moved' 'code' "$(cat "$P/main.sh")"
}

@test "refuses while Claude Code works inside the directory" {
    __dottod_mv_live() { [[ "$1" == "$P" ]] && echo 4242; }
    run claude-mv "$P" "$N"
    assert_eq 'rc' '1' "$status"
    assert_contains 'names the process' "running inside $P (pid 4242)" "$output"
    assert_eq 'nothing moved' 'code' "$(cat "$P/main.sh")"
}

@test "live detection: claude binaries working inside the directory only" {
    unset -f __dottod_mv_live
    source "${BATS_TEST_DIRNAME}/../scripts/.claude-mv.sh"
    local proc="$BATS_TEST_TMPDIR/proc"
    mkdir -p "$proc/11" "$proc/12" "$proc/13" "$proc/14"
    ln -s /home/u/.local/share/claude/versions/2.1.302 "$proc/11/exe"
    ln -s "$P/docs" "$proc/11/cwd"
    ln -s /usr/bin/bash "$proc/12/exe"
    ln -s "$P" "$proc/12/cwd"
    ln -s /home/u/.local/bin/claude "$proc/13/exe"
    ln -s "$X" "$proc/13/cwd"
    ln -s /home/u/.local/bin/claude "$proc/14/exe"
    ln -s "$P" "$proc/14/cwd"
    run __dottod_mv_live "$P" "$proc"
    assert_eq 'claude inside (any depth); not bash, not the lookalike' $'11\n14' "$output"
}

@test "a project folder with only memory moves on its exact key" {
    rm -f "$S/projects/$(key "$P")"/*.jsonl
    rm -rf "$S/projects/$(key "$P")/abc" "$S/projects/$(key "$P/docs")"
    run claude-mv "$P" "$N"
    assert_eq 'rc' '0' "$status"
    assert_eq 'memory moved' 'remember this' "$(cat "$S/projects/$(key "$N")/memory/MEMORY.md")"
}
