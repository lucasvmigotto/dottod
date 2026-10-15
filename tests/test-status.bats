#!/usr/bin/env bats
#
# test-status.bats — the uniform `status` surface of the task scripts.
#
# Every task answers `<task>.sh status` with a read-only report: exit 0, a
# titled block, nothing written to HOME. Unknown actions fail (fonts takes
# font names instead), `--help` succeeds, and `bootstrap.sh --status`
# prints every selected report. Scripts run as subprocesses with HOME
# redirected, so the real home is never read or touched.

load helpers

# Tasks whose status must leave HOME byte-identical. neovim is left out:
# running `nvim --version` lets Neovim write its own ~/.local/state log.
STATUS_TASKS=(shell fonts vim zed gitconfig ssh tools cargo bun container)

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export _DOT_NO_PACKAGES=1
}

snapshot() {
    (cd "$HOME" && find . -printf '%p %s %l\n' | sort)
}

@test "every task's status exits 0, prints its report and writes nothing" {
    local task before
    before="$(snapshot)"
    for task in "${STATUS_TASKS[@]}"; do
        run "$REPO_ROOT/bin/${task}.sh" status
        assert_eq "${task} status rc" '0' "$status"
        assert_match "${task} report has a title and rule" $'^[A-Z][A-Za-z ]+\n-+' "$output"
    done
    assert_eq 'HOME untouched by status' "$before" "$(snapshot)"
}

@test "unknown actions fail and --help succeeds" {
    local task
    for task in shell vim zed gitconfig ssh tools; do
        run "$REPO_ROOT/bin/${task}.sh" bogus
        assert_eq "${task} bogus rc" '1' "$status"
        assert_contains "${task} names the action" 'Unknown action: bogus' "$output"
        run "$REPO_ROOT/bin/${task}.sh" --help
        assert_eq "${task} --help rc" '0' "$status"
        assert_contains "${task} help lists status" 'status' "$output"
    done
}

@test "shell status recognises the dottod bashrc link" {
    ln -s "$REPO_ROOT/config/.custom.bashrc" "$HOME/.bashrc"
    run "$REPO_ROOT/bin/shell.sh" status
    assert_contains 'dottod link' "(dottod)" "$output"
    rm "$HOME/.bashrc"
    echo '# mine' >"$HOME/.bashrc"
    run "$REPO_ROOT/bin/shell.sh" status
    assert_contains 'user file' 'file (user-managed)' "$output"
}

@test "gitconfig status reports both identities" {
    printf '[user]\n    name = Ada\n    email = ada@example.test\n' >"$HOME/.gitconfig"
    printf '[user]\n    name = Ada Work\n    email = ada@work.test\n' >"$HOME/.gitconfig-work"
    run "$REPO_ROOT/bin/gitconfig.sh" status
    assert_contains 'name' 'Name:      Ada' "$output"
    assert_contains 'email' 'Email:     ada@example.test' "$output"
    assert_contains 'work identity' 'Ada Work <ada@work.test>' "$output"
}

@test "ssh status finds the GitHub block and the key without creating ~/.ssh" {
    run "$REPO_ROOT/bin/ssh.sh" status
    assert_contains 'no config' 'no Host github.com block' "$output"
    [[ ! -e "$HOME/.ssh" ]] || {
        echo 'status created ~/.ssh' >&2
        return 1
    }
    mkdir -p "$HOME/.ssh"
    printf 'Host github.com\n    User git\n' >"$HOME/.ssh/config"
    touch "$HOME/.ssh/github" "$HOME/.ssh/github.pub"
    run "$REPO_ROOT/bin/ssh.sh" status
    assert_contains 'block found' 'Host github.com block present' "$output"
    assert_contains 'key found' 'present (+ .pub)' "$output"
}

@test "vim status counts the declared plugins that are installed" {
    printf "Plug 'tpope/vim-fugitive'\nPlug 'junegunn/fzf'\n" >"$HOME/.vimrc"
    mkdir -p "$HOME/.vim/plugged/vim-fugitive"
    run "$REPO_ROOT/bin/vim.sh" status
    assert_contains 'plugins counted' 'Plugins:   1/2 installed' "$output"
}

@test "fonts status reports the fonts it is given" {
    run "$REPO_ROOT/bin/fonts.sh" status FiraCode
    assert_eq 'fonts status rc' '0' "$status"
    assert_contains 'named font listed' 'FiraCode' "$output"
    assert_eq 'only the named font' '1' "$(grep -c 'Mono\|Code' <<<"$output")"
}

@test "tools status marks the extras DOT_TOOLS_EXTRA selects" {
    DOT_TOOLS_EXTRA=gh run "$REPO_ROOT/bin/tools.sh" status
    assert_eq 'tools status rc' '0' "$status"
    assert_contains 'gh selected' 'Selected:  gh (DOT_TOOLS_EXTRA)' "$output"
    assert_match 'extras counted' 'Extras: +[0-9]+/7 present' "$output"
    assert_match 'core counted' 'Core: +[0-9]+/12 present' "$output"
}

@test "bootstrap --status prints the selected reports and nothing else" {
    run "$REPO_ROOT/bin/bootstrap.sh" --status --only shell,gitconfig
    assert_eq 'bootstrap --status rc' '0' "$status"
    assert_contains 'shell report' 'Shell' "$output"
    assert_contains 'git report' 'Git' "$output"
    [[ "$output" != *'Bootstrap starting'* ]] || {
        echo 'bootstrap ran tasks instead of reporting' >&2
        return 1
    }
}
