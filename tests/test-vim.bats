#!/usr/bin/env bats
#
# test-vim.bats — hermetic tests for bin/vim.sh helpers.
#
# Covers: Plug-name parsing (org prefixes and trailing options stripped),
# the all-plugins-present probe (PlugInstall skip gate), and vim-plug
# download-vs-skip. HOME is redirected so the real ~/.vim is never
# touched (_vim_home honors $HOME for the current user).

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export _DOT_NO_PACKAGES=1
    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/vim.sh"
    set +u
}

@test "wanted plugins parses names without orgs or options" {
    local vimrc="$BATS_TEST_TMPDIR/vimrc"
    cat >"$vimrc" <<'EOF'
call plug#begin('~/.vim/plugged')
Plug 'tpope/vim-fugitive'
Plug 'preservim/NERDTree'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
" Plug 'commented/out'
call plug#end()
EOF
    run _vim_wanted_plugins "$vimrc"
    assert_eq 'parse rc 0' '0' "$status"
    assert_eq 'names parsed' "$(printf 'vim-fugitive\nNERDTree\nfzf')" "$output"
}

@test "plugins probe passes when every dir exists" {
    local user
    user="$(id -un)"
    for p in vim-fugitive NERDTree fzf; do
        mkdir -p "$FAKE_HOME/.vim/plugged/$p"
    done
    local vimrc="$BATS_TEST_TMPDIR/vimrc"
    printf "Plug 'tpope/vim-fugitive'\nPlug 'preservim/NERDTree'\nPlug 'junegunn/fzf'\n" >"$vimrc"
    run _vim_plugins_installed "$user" "$vimrc"
    assert_eq 'all present rc 0' '0' "$status"
}

@test "plugins probe fails when any dir is missing" {
    local user
    user="$(id -un)"
    mkdir -p "$FAKE_HOME/.vim/plugged/vim-fugitive"
    local vimrc="$BATS_TEST_TMPDIR/vimrc"
    printf "Plug 'tpope/vim-fugitive'\nPlug 'preservim/NERDTree'\n" >"$vimrc"
    run _vim_plugins_installed "$user" "$vimrc"
    assert_eq 'missing dir rc 1' '1' "$status"
}

@test "vimplug skips when already present" {
    local user
    user="$(id -un)"
    mkdir -p "$FAKE_HOME/.vim/autoload"
    printf 'stub' >"$FAKE_HOME/.vim/autoload/plug.vim"
    run _vim_vimplug_install "$user" 'file:///nonexistent-plug.vim'
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message' 'already installed' "$output"
    assert_eq 'stub untouched' 'stub' "$(cat "$FAKE_HOME/.vim/autoload/plug.vim")"
}

@test "vimplug downloads through the retry helper when absent" {
    local user
    user="$(id -un)"
    printf 'plug-body' >"$BATS_TEST_TMPDIR/plug.vim"
    run _vim_vimplug_install "$user" "file://$BATS_TEST_TMPDIR/plug.vim"
    assert_eq 'download rc 0' '0' "$status"
    assert_eq 'plug.vim planted' 'plug-body' "$(cat "$FAKE_HOME/.vim/autoload/plug.vim")"
}
