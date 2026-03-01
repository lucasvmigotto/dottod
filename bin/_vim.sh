#!/usr/bin/env bash

source "$(pwd)/$(dirname $0)/_utils.sh"

function _vim_vimplug_install() {

    local current_user=${1:?'User must be informed'}
    local vim_plug_url=${2:?'Custom config dir must be informed'}
    local vim_plug_file="/home/${current_user}/.vim/autoload/plug.vim"

    if [[ -f "${vim_plug_file}" ]]; then
        echo 'Vim plug already installed' >&2
        return 0
    fi

    curl --create-dirs \
        -fsSLo "${vim_plug_file}"  \
        "${vim_plug_url}"

    return 0


}

function _vim_profile() {

    local current_user=${1:?'User must be informed'}
    local custom_configs_dir=${2:?'Custom config dir must be informed'}
    local vim_config_file=${3:-".vimrc"}

    local vim_config_file_symlink="/home/${current_user}/${vim_config_file}"
    if [[ -L "${vim_config_file_symlink}" ]]; then
        echo "${vim_config_file_symlink} already exists" >&2
        return 0
    fi

    local vim_custom_config="${custom_configs_dir}/${vim_config_file}"
    ln -s "${vim_custom_config}" "${vim_config_file_symlink}"

    if [[ ! -L "${vim_config_file_symlink}" ]]; then
        echo "Sym links could not be created" >&2
        return 1
    fi

    return 0

}

function _vim_vimplug_plugins_install() {

    local current_user=${1:?'User must be informed'}
    local custom_configs_dir=${2:?'Custom config dir must be informed'}
    local vim_plugins_file=${3:-".plugins.vim"}

    local vim_plugins_file_symlink="/home/${current_user}/${vim_plugins_file}"
    if [[ -L "${vim_plugins_file_symlink}" ]]; then
        echo "${vim_plugins_file_symlink} already exists" >&2
        return 0
    fi

    local vim_plugins_config="${custom_configs_dir}/${vim_plugins_file}"
    ln -s "${vim_plugins_config}" "${vim_plugins_file_symlink}"

    if [[ ! -L "${vim_plugins_file_symlink}" ]]; then
        echo "Sym links could not be created" >&2
        return 1
    fi

    vim -es -u "/home/${current_user}/.vimrc" -i NONE -c "PlugInstall" -c "qa" > /dev/null

    return 0

}

function _main() {

    local plugin_list=${_DOT_VIM_PLUGIN_LIST:-""}
    local vim_plug_script=${_DOT_VIM_SCRIPT_URL:-"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"}

    local current_user="$(whoami)"

    _install_packages 'git vim' > /dev/null

    _vim_vimplug_install "${current_user}" "${vim_plug_script}"

    local custom_configs_dir="$(pwd)/$(dirname $0)/../.config"

    _vim_profile "${current_user}" "${custom_configs_dir}"

    _vim_vimplug_plugins_install "${current_user}" "${custom_configs_dir}"

    return 0
}

set -e

_main $@