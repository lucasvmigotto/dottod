#!/usr/bin/env bats
#
# test-prompt.bats — hermetic tests for styles/promptlib.sh and the
# styles/prompt-*.sh variants (sourced by config/.custom.bashrc).

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
}

@test "promptlib collectors work in a fixture repo" {
    local repo="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@t
    git -C "$repo" config user.name t
    git -C "$repo" commit -q --allow-empty -m init
    touch "$repo/package.json"
    run bash -c "
        source '$REPO_ROOT/styles/promptlib.sh'
        cd '$repo' || exit 1
        printf 'git=%s\n' \"\$(__dottod_git_info)\"
        printf 'dir=%s\n' \"\$(__dottod_project_dir)\"
        printf 'lang=%s\n' \"\$(__dottod_lang)\"
        printf 'segs=%s\n' \"\$(__dottod_git_segments)\"
    "
    assert_eq 'collectors rc 0' '0' "$status"
    assert_contains 'git fragment names the branch' 'git:(' "$output"
    assert_contains 'project dir is the repo name' 'dir=proj' "$output"
    assert_contains 'language detected from marker' 'lang=node' "$output"
    assert_match 'segments carry branch, counts and local upstream' 'segs=(master|main)\|0\|0\|0\|0\|1\|' "$output"
}

@test "promptlib collectors stay silent outside a repo" {
    local plain="$BATS_TEST_TMPDIR/plain"
    mkdir -p "$plain"
    run bash -c "
        source '$REPO_ROOT/styles/promptlib.sh'
        cd '$plain' || exit 1
        __dottod_git_info >/dev/null 2>&1; printf 'git_rc=%s\n' \"\$?\"
        __dottod_lang >/dev/null 2>&1; printf 'lang_rc=%s\n' \"\$?\"
        printf 'dir=%s\n' \"\$(__dottod_project_dir)\"
    "
    assert_eq 'collectors rc 0' '0' "$status"
    assert_contains 'git fragment false outside repo' 'git_rc=1' "$output"
    assert_contains 'lang false without markers' 'lang_rc=1' "$output"
    assert_contains 'dir falls back to basename' 'dir=plain' "$output"
}

@test "robbyrussell variant keeps the default prompt" {
    local ihome="$BATS_TEST_TMPDIR/ihome-ruby"
    mkdir -p "$ihome"
    run env HOME="$ihome" bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; __dottod_prompt; printf '%s' \"\$PS1\"" 2>/dev/null
    assert_eq 'interactive source rc 0' '0' "$status"
    assert_contains 'PS1 has the arrow prompt' '➜' "$output"
}

@test "kali variant renders the two-line frame" {
    local ihome="$BATS_TEST_TMPDIR/ihome-kali"
    mkdir -p "$ihome"
    run env HOME="$ihome" DOT_PROMPT_STYLE=kali bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; __dottod_prompt_kali; printf '%s' \"\$PS1\"" 2>/dev/null
    assert_eq 'kali source rc 0' '0' "$status"
    assert_contains 'kali top frame' '┌──(' "$output"
    assert_contains 'kali bottom frame' '└─' "$output"
    assert_contains 'kali user mark' '$' "$output"
}

@test "powerline variant renders blocks and the status cluster" {
    local ihome="$BATS_TEST_TMPDIR/ihome-power"
    mkdir -p "$ihome"
    local repo="$BATS_TEST_TMPDIR/pwproj"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@t
    git -C "$repo" config user.name t
    git -C "$repo" commit -q --allow-empty -m init
    touch "$repo/package.json"
    run env HOME="$ihome" DOT_PROMPT_STYLE=powerline DOT_PROMPT_GLYPHS=ascii COLUMNS=200 bash -i -c "cd '$repo' && source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; sleep 2; __DOTTD_PW_PREV_SECONDS=\$SECONDS; __dottod_prompt_powerline; printf '%s' \"\$PS1\"" 2>/dev/null
    assert_eq 'powerline source rc 0' '0' "$status"
    assert_contains 'powerline project block' 'pwproj' "$output"
    assert_contains 'powerline language block' 'node' "$output"
    # Duration is wall-clock (SECONDS delta): pin the timer so the worker
    # speed never decides between 0s and 1s. The sleep above proves it.
    assert_contains 'powerline status cluster' '0s' "$output"
    assert_contains 'powerline ok status' '✓' "$output"
}

@test "powerline arrows are visible: filled on the right, closing one on the default background" {
    local ihome="$BATS_TEST_TMPDIR/ihome-pwright"
    mkdir -p "$ihome"
    run env HOME="$ihome" DOT_PROMPT_STYLE=powerline COLUMNS=200 bash -i -c "cd '$ihome' && source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; __dottod_prompt_powerline; printf '%s' \"\$PS1\"" 2>/dev/null
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'filled left-pointing arrow' $'\ue0b2' "$output"
    # The left side's closing arrow sits on the default background.
    assert_contains 'closing arrow after a reset' '\e[0m\e[38;5;27m\]'$'\ue0b0' "$output"
    if [[ "$output" == *$'\ue0b3'* ]]; then
        printf 'FAIL: thin separator on the right side\n' >&2
        return 1
    fi
}

@test "unknown style falls back to robbyrussell with a warning" {
    local ihome="$BATS_TEST_TMPDIR/ihome-fallback"
    mkdir -p "$ihome"
    run env HOME="$ihome" DOT_PROMPT_STYLE=nope bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null; __dottod_prompt; printf '%s' \"\$PS1\"" 2>&1
    assert_eq 'fallback source rc 0' '0' "$status"
    assert_contains 'fallback warns' 'unknown DOT_PROMPT_STYLE' "$output"
    assert_contains 'fallback renders default' '➜' "$output"
}

@test "reloading with another DOT_PROMPT_STYLE switches styles, never stacks them" {
    # Regression: each style prepended its hook and nothing removed the old
    # one, so `reload` after changing the style kept the previous prompt.
    local ihome="$BATS_TEST_TMPDIR/ihome-switch"
    mkdir -p "$ihome"
    run env HOME="$ihome" DOT_NO_UPDATE_CHECK=1 bash -i -c "
        PROMPT_COMMAND='history -a'
        for s in powerline kali robbyrussell; do
            DOT_PROMPT_STYLE=\$s; source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1
        done
        printf '%s' \"\$PROMPT_COMMAND\"" 2>/dev/null
    assert_eq 'only the last style, user entry kept' '__dottod_prompt;history -a' "${output##*$'\n'}"
}
