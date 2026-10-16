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
    assert_contains 'fallback warns' 'unknown prompt style' "$output"
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

# Renders a style's prompt in <dir> and expands it the way bash does at the
# prompt (${PS1@P}), printing the result.
render_prompt() {
    local style="$1" dir="$2" script="$BATS_TEST_TMPDIR/render.sh"
    cat >"$script" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
${PROMPT_COMMAND%%;*}
printf '%s' "${PS1@P}"
SH
    (cd "$dir" && DOT_PROMPT_STYLE="$style" COLUMNS=200 bash -i "$script" 2>/dev/null)
}

@test "branch and directory names never run as commands in any style" {
    local repo="$BATS_TEST_TMPDIR/evil" style name out
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email t@t
    git -C "$repo" config user.name t
    git -C "$repo" commit -q --allow-empty -m init
    # A directory inside the repo with the same payloads, plus a backslash
    # (git refuses those in branch names; powerline and kali show the path
    # below the repo root).
    local sub="$repo/"'d$(touch${IFS}PWNED)`touch${IFS}PWNED`\$(touch${IFS}PWNED)'
    mkdir -p "$sub"
    for name in 'x$(touch${IFS}PWNED)' 'y`touch${IFS}PWNED`' 'w${HOME}'; do
        git -C "$repo" checkout -q -b "$name"
        for style in robbyrussell kali powerline; do
            out="$(render_prompt "$style" "$sub")"
            if [[ -e "$repo/PWNED" || -e "$sub/PWNED" ]]; then
                printf 'FAIL: %s ran a command from branch %s\n' "$style" "$name" >&2
                return 1
            fi
            assert_contains "$style shows branch $name literally" "$name" "$out"
        done
    done
    for style in kali powerline; do
        assert_contains "$style shows the directory literally" \
            'd$(touch${IFS}PWNED)`touch${IFS}PWNED`\$(touch${IFS}PWNED)' "$(render_prompt "$style" "$sub")"
    done
}

@test "prompt-style saves the style for new shells; --dry-run changes this shell only" {
    local script="$BATS_TEST_TMPDIR/pstyle.sh" newshell="$BATS_TEST_TMPDIR/newshell.sh"
    cat >"$script" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
prompt-style
echo "--"
prompt-style catppuccin && echo "hook=${PROMPT_COMMAND%%;*} env=${DOT_PROMPT_STYLE:-none}"
prompt-style | grep '^\*'
prompt-style --dry-run kali && echo "hook=${PROMPT_COMMAND%%;*} env=${DOT_PROMPT_STYLE:-none}"
prompt-style | grep '^\*'
echo "file=$(cat "$HOME/.prompt-style")"
prompt-style nope; echo "rc=$? file=$(cat "$HOME/.prompt-style")"
COMP_WORDS=(prompt-style --d); COMP_CWORD=1; _prompt_style; echo "complete=${COMPREPLY[*]}"
SH
    cat >"$newshell" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
echo "new shell hook=${PROMPT_COMMAND%%;*}"
SH
    run bash -c "cd '$BATS_TEST_TMPDIR' && bash -i '$script' 2>&1"
    assert_contains 'default marked' '* robbyrussell  (default)' "$output"
    assert_contains 'themes listed' '  catppuccin' "$output"
    assert_contains 'saved' 'prompt-style: catppuccin, saved in ~/.prompt-style' "$output"
    assert_contains 'applied here, no override' 'hook=__dottod_prompt_segments env=none' "$output"
    assert_contains 'saved style marked' '* catppuccin  (~/.prompt-style)' "$output"
    assert_contains 'dry run' 'prompt-style: kali in this shell only' "$output"
    assert_contains 'dry run applied' 'hook=__dottod_prompt_kali env=kali' "$output"
    assert_contains 'dry run marked' '* kali  (DOT_PROMPT_STYLE, this shell)' "$output"
    assert_contains 'file untouched by dry run' 'file=catppuccin' "$output"
    assert_contains 'unknown refused' 'prompt-style: unknown style nope' "$output"
    assert_contains 'unknown leaves the file' 'rc=1 file=catppuccin' "$output"
    assert_contains 'completion' 'complete=--dry-run' "$output"
    run bash -c "cd '$BATS_TEST_TMPDIR' && bash -i '$newshell' 2>/dev/null"
    assert_contains 'a new shell uses the saved style' 'new shell hook=__dottod_prompt_segments' "$output"
}

@test "a saved style that isn't a style name is never sourced" {
    mkdir -p "$BATS_TEST_TMPDIR/x"
    printf 'touch "%s/SOURCED"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/x/evil.sh"
    printf '../../../../../../..%s/x/evil\n' "$BATS_TEST_TMPDIR" >"$HOME/.prompt-style"
    run bash -c "cd '$BATS_TEST_TMPDIR' && bash -i -c \"source '$REPO_ROOT/config/.custom.bashrc'; echo hook=\\\${PROMPT_COMMAND%%;*}\" 2>&1"
    assert_eq 'not sourced' '0' "$([[ -e "$BATS_TEST_TMPDIR/SOURCED" ]] && echo 1 || echo 0)"
    assert_contains 'warns' 'unknown prompt style' "$output"
    assert_contains 'falls back' 'hook=__dottod_prompt' "$output"
}
