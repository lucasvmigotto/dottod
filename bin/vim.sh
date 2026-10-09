#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# Home directory for a task user: the real $HOME for ourselves (honors test
# redirection), /home/<user> otherwise. Mirrors bin/neovim.sh.
function _vim_home() {
    local user=${1:?'User must be informed'}
    if [[ "${user}" == "$(id -un)" ]]; then
        printf '%s' "${HOME}"
    else
        printf '/home/%s' "${user}"
    fi
}

function _vim_vimplug_install() {
    local current_user=${1:?'User must be informed'}
    local vim_plug_url=${2:?'vim-plug URL must be informed'}

    local vim_plug_file
    vim_plug_file="$(_vim_home "${current_user}")/.vim/autoload/plug.vim"

    if [[ -f "${vim_plug_file}" ]]; then
        log_info 'vim-plug already installed, skipping...'
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    log_step 'Installing vim-plug'
    _download "${vim_plug_url}" "${tmp}"
    mkdir -p "$(dirname "${vim_plug_file}")"
    install -m 0644 "${tmp}" "${vim_plug_file}"
    rm -f "${tmp}"
    log_ok 'vim-plug installed'

    return 0
}

# Plugin names declared in the vimrc (`Plug '<name>'` or `Plug '<org>/<name>'`).
function _vim_wanted_plugins() {
    local vimrc=${1:?'vimrc must be informed'}

    grep -oE "^[[:space:]]*Plug[[:space:]]+'[^']+'" "${vimrc}" 2>/dev/null |
        sed -E "s/.*'([^']+)'.*/\\1/; s#.*/##" || true
}

function _vim_plugins_installed() {
    local current_user=${1:?'User must be informed'}
    local vimrc=${2:?'vimrc must be informed'}

    local plug missing=0
    while IFS= read -r plug; do
        [[ -n "${plug}" ]] || continue
        if [[ ! -d "$(_vim_home "${current_user}")/.vim/plugged/${plug}" ]]; then
            missing=1
            break
        fi
    done < <(_vim_wanted_plugins "${vimrc}")
    return "${missing}"
}

function _main() {
    local vim_plug_script=${_DOT_VIM_SCRIPT_URL:-"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"}

    local current_user
    current_user="$(id -un)"

    _install_packages 'git vim curl'

    _vim_vimplug_install "${current_user}" "${vim_plug_script}"

    local vimrc
    vimrc="$(_vim_home "${current_user}")/.vimrc"
    _link_file "${DOT_CONFIG_DIR}/.custom.vimrc" "${vimrc}"

    if _vim_plugins_installed "${current_user}" "${vimrc}"; then
        log_info 'vim plugins already installed, skipping...'
    else
        log_step 'Installing vim plugins'
        if ! vim -es -u "${vimrc}" -i NONE -c 'PlugInstall' -c 'qa'; then
            log_warn 'vim PlugInstall reported errors (may be non-fatal)'
        fi
        log_ok 'vim plugins installed'
    fi

    if [[ ! -f "$(_vim_home "${current_user}")/.vim/autoload/plug.vim" ]]; then
        log_error 'vim-plug install did not yield autoload/plug.vim.'
        return 1
    fi

    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
