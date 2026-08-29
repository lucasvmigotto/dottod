#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _vim_vimplug_install() {
    local current_user=${1:?'User must be informed'}
    local vim_plug_url=${2:?'vim-plug URL must be informed'}

    local vim_plug_file="/home/${current_user}/.vim/autoload/plug.vim"

    if [[ -f "${vim_plug_file}" ]]; then
        log_info 'vim-plug already installed, skipping...'
        return 0
    fi

    log_step 'Installing vim-plug'
    curl --create-dirs -fsSLo "${vim_plug_file}" "${vim_plug_url}"
    log_ok 'vim-plug installed'

    return 0
}

function _main() {
    local vim_plug_script=${_DOT_VIM_SCRIPT_URL:-"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"}

    local current_user
    current_user="$(id -un)"

    _install_packages 'git vim curl'

    _vim_vimplug_install "${current_user}" "${vim_plug_script}"

    _link_file "${DOT_CONFIG_DIR}/.custom.vimrc" "/home/${current_user}/.vimrc"

    log_step 'Installing vim plugins'
    if ! vim -es -u "/home/${current_user}/.vimrc" -i NONE -c 'PlugInstall' -c 'qa'; then
        log_warn 'vim PlugInstall reported errors (may be non-fatal)'
    fi
    log_ok 'vim plugins installed'

    return 0
}

_main "$@"
