#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _zsh_use_as_shell() {
    local current_user=${1:?'User must be informed'}

    local zsh_bin current_shell
    zsh_bin="$(command -v zsh)"
    current_shell="$(getent passwd "${current_user}" | cut -d: -f7)"

    if [[ "${zsh_bin}" == "${current_shell}" ]]; then
        log_info 'zsh already installed and in use, skipping...'
        return 0
    fi

    log_step 'Setting zsh as the default shell'
    _priv chsh -s "${zsh_bin}" "${current_user}"
    log_ok 'zsh set as default shell'

    return 0
}

function _omz_install() {
    local current_user=${1:?'User must be informed'}
    local script_url=${2:?'Download script must be informed'}

    local omz_dir="/home/${current_user}/.oh-my-zsh"

    if [[ -d "${omz_dir}" ]]; then
        log_info 'oh-my-zsh already installed, skipping...'
        return 0
    fi

    log_step 'Installing oh-my-zsh'
    sh -c "$(curl -fsSL "${script_url}")" '' --unattended --keep-zshrc >/dev/null 2>&1

    if [[ ! -d "${omz_dir}" ]]; then
        log_error '.oh-my-zsh/ not found in home'
        return 1
    fi

    log_ok 'oh-my-zsh installed'
    return 0
}

function _omz_plugins() {
    local current_user=${1:?'User must be informed'}
    local zsh_custom=${2:?'oh-my-zsh customs dir must be informed'}
    shift 2
    local -a plugin_list=("$@")

    if [[ ${#plugin_list[@]} -lt 1 ]]; then
        log_info 'No oh-my-zsh plugins to install, skipping'
        return 0
    fi

    for plugin in "${plugin_list[@]}"; do
        if [[ -d "${zsh_custom}/plugins/${plugin}" ]]; then
            log_info "Plugin '${plugin}' already installed, skipping..."
            continue
        fi

        log_step "Installing plugin '${plugin}'"
        git clone --depth 1 --quiet \
            "https://github.com/zsh-users/${plugin}" \
            "${zsh_custom}/plugins/${plugin}"
        log_ok "Plugin '${plugin}' installed"
    done

    return 0
}

function _spaceship_install() {
    local zsh_custom=${1:?'oh-my-zsh customs dir must be informed'}
    local rep_url=${2:?'Repository URL must be informed'}

    local destination="${zsh_custom}/themes/spaceship-prompt"
    local symlink="${zsh_custom}/themes/spaceship.zsh-theme"

    if [[ -d "${destination}" && -L "${symlink}" ]]; then
        log_info 'Spaceship already installed, skipping...'
        return 0
    fi

    log_step 'Installing Spaceship prompt'
    git clone --depth 1 --quiet "${rep_url}" "${destination}"
    ln -s "${destination}/spaceship.zsh-theme" "${symlink}"
    log_ok 'Spaceship installed'

    return 0
}

function _custom_zshrc() {
    local current_user=${1:?'User must be informed'}

    _link_file "${DOT_CONFIG_DIR}/.custom.zshrc" "/home/${current_user}/.zshrc"
}

function _main() {
    local omz_script_url=${_DOT_OMZ_SCRIPT_URL:-"https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"}
    local omz_plugin_list=${_DOT_OMZ_PLUGIN_LIST:-"zsh-autosuggestions zsh-syntax-highlighting"}
    local spaceship_rep_url=${_DOT_SPACESHIP_URL:-"https://github.com/spaceship-prompt/spaceship-prompt.git"}

    local current_user
    current_user="${_DOT_TARGET_USER:-$(id -un)}"

    log_step 'Installing git and zsh'
    _install_packages 'git zsh curl ca-certificates'

    _zsh_use_as_shell "${current_user}"

    _omz_install "${current_user}" "${omz_script_url}"

    local zsh_custom=${ZSH_CUSTOM:-"/home/${current_user}/.oh-my-zsh/custom"}

    _omz_plugins "${current_user}" "${zsh_custom}" ${omz_plugin_list}

    _spaceship_install "${zsh_custom}" "${spaceship_rep_url}"

    _custom_zshrc "${current_user}"

    log_ok 'Shell bootstrap complete'
    return 0
}

_main "$@"
