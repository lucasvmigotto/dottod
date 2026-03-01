#!/usr/bin/env bash

source "$(pwd)/$(dirname $0)/_utils.sh"

function _zsh_use_as_shell() {

    local current_user=${1:?'User must be informed'}

    if [[ $(which zsh) == "$(cat /etc/passwd | grep "${current_user}" | cut -d ':' -f7)" ]]; then
        echo 'zsh already installed and in use, skipping...' >&2
        return 0
    fi

    "$(_power_giver panic)" chsh -s "$(which zsh)" "${current_user}"

    return 0

}

function _omz_install() {

    local current_user=${1:?'User must be informed'}

    if [[ ! -z $ZSH || -d "/home/${current_user}/.oh-my-zsh" ]]; then
        echo 'oh-my-zsh already installed, skipping...' >&2
        return 0
    fi

    local script_url=${2:-'Download script must be informed'}
    sh -c "$(curl -fsSL ${script_url}) '' --unattended > /dev/null" > /dev/null

    if [[ ! -d "/home/${current_user}/.oh-my-zsh" ]]; then
        echo ".oh-my-zsh/ not fount in home" >&2
        return 1
    fi

    return 0

}

function _omz_plugins() {

    local current_user=${1:?'User must be informed'}
    local zsh_custom=${2:-'oh-my-zsh customs dir must be informed'}
    local plugin_list=${@:3}

    if [[ ${#plugin_list[@]} < 1 ]]; then
        echo 'No oh-my-zsh plugin to install, skipping' >&2
        return 0
    fi

    local plugins_add=( )
    for plugin in ${plugin_list[@]}; do
        if [[ -d "${zsh_custom}/plugins/${plugin}" ]]; then
            echo "Plugin '${plugin}' already installed, skipping..." >&2
            continue
        fi

        git clone --quiet \
            "https://github.com/zsh-users/${plugin}" \
            "${zsh_custom}/plugins/${plugin}"

        plugins_add+=("${plugin}")
    done

    if [[ ${#plugins_add[@]} > 0 ]]; then
        local replace="s/^plugins=\((.*)\)/plugins=(\1 ${plugins_add[@]})/"
        sed -Ei "${replace}" "/home/${current_user}/.zshrc"
    fi

    return 0

}

function _spaceship_install() {

    local current_user=${1:?'User must be informed'}
    local zsh_custom=${2:-'oh-my-zsh customs dir must be informed'}
    local rep_url=${3:-'Download script must be informed'}

    local destination="${zsh_custom}/themes/spaceship-prompt"
    local spaceship_symlink="${zsh_custom}/themes/spaceship.zsh-theme"
    if [[ -d "${destination}" && -L "${spaceship_symlink}" ]]; then
        echo 'Spaceship already installed, skipping...' >&2
        return 0
    fi

    git clone \
        --depth 1 \
        --quiet \
        "${rep_url}" \
        "${destination}"

    ln -s \
        "${destination}/spaceship.zsh-theme" \
        "${spaceship_symlink}"

    local zsh_config="/home/${current_user}/.zshrc"
    if [[ $(grep '^ZSH_THEME=' "${zsh_config}") ]]; then
        sed -Ei "s/ZSH_THEME=.*/ZSH_THEME='spaceship'/" "${zsh_config}"
    else
        sed -i "1i ZSH_THEME='spaceship'" "${zsh_config}"
    fi

    return 0

}

function _starship_install() {

    local current_user=${1:?'User must be informed'}
    local script_url=${2:-'Download script must be informed'}
    local local_bin_in_path=${3:-}

    local local_bin="/home/${current_user}/.local/bin"

    if [[ ! -f "${local_bin}/starship" ]]; then
        [[ ! -d "${local_bin}" ]] \
            && mkdir -p "${local_bin}" \
            || echo "${local_bin} already exists"

        curl -fsSL "${script_url}" | sh -s -- \
            --bin-dir "${local_bin}" \
            --force > /dev/null
    fi

    if [[ $(grep 'starship init zsh)"$' "/home/${current_user}/.zshrc") ]]; then
        echo 'eval starship already in .zshrc' >&2
        return 0
    fi

    local starship_init=$(
        [[ -z "${local_bin_in_path}" ]] \
            && echo "${local_bin}/starship" \
            || echo 'starship'
    )
    echo "eval \"\$(${starship_init} init zsh)\"" \
        | tee -a "/home/${current_user}/.zshrc"

    return 0
}

function _main() {

    local omz_script_url=${_DOT_OMZ_SCRIPT_URL:-"https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"}
    local omz_skip_plugins=${_DOT_OMZ_SKIP_PLUGINS:-0}
    local omz_plugin_list=${_DOT_OMZ_PLUGIN_LIST:-"zsh-autosuggestions zsh-syntax-highlighting"}

    local use_spaceship=${_DOT_SPACESHIP_USE:-1}
    local spaceship_rep_url=${_DOT_SPACESHIP_URL:-"https://github.com/spaceship-prompt/spaceship-prompt.git"}

    local use_starship=${_DOT_STARSHIP_USE:-}
    local starship_rep_url=${_DOT_STARSHIP_URL:-"https://starship.rs/install.sh"}
    local starship_local_bin_path=${_DOT_STARSHIP_LOCAL_BIN_PATH:-}

    if [[ ! (-z "${use_spaceship}" || -z "${use_starship}") ]]; then
        echo "Choose one between 'use_spaceship' and 'use_starship'" >&2
        exit 1
    fi

    local current_user="$(whoami)"

    _install_packages 'git zsh'

    _zsh_use_as_shell "${current_user}"

    _omz_install "${current_user}" "${omz_script_url}"

    local zsh_custom=${ZSH_CUSTOM:-"/home/${current_user}/.oh-my-zsh/custom"}

    if [[ "${omz_skip_plugins}" == 0 || $# < 1 ]]; then
        _omz_plugins \
            "${current_user}" "${zsh_custom}" $@
    fi

    if [[ "${use_spaceship}" == 1 ]]; then
        _spaceship_install \
            "${current_user}" "${zsh_custom}" "${spaceship_rep_url}"
    fi

    if [[ "${use_starship}" == 1 ]]; then
        _starship_install \
            "${current_user}" "${starship_rep_url}" "${starship_local_bin_path}"
    fi

    return 0
}

set -e

_main $@ # zsh-autosuggestions zsh-syntax-highlighting