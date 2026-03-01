#!/usr/bin/env bash

source "$(pwd)/$(dirname $0)/_utils.sh"

function _install_nerdfont() {

    local font=${1:?"Font must be informed"}
    if [[ $(fc-list | grep -i "${font}") ]]; then
        echo "${font} already installed, skipping..."
        return 0
    else
        echo "Installing ${font}"
    fi

    local font_url_base=${2:?"Font URL must be informed"}
    local font_final_folder=${3:?"Font folder must be informed"}
    local font_global_install=${4:-0}
    local font_die_if_fail=${5:-0}
    local font_tmp_folder=${6:-"/tmp/fonts"}

    local font_url="${font_url_base}/${font}.zip"
    if ! curl -fsSLI "${font_url}" > /dev/null; then
        echo "URL ${font_url} is not available" >&2
        return 1
    fi

    local font_name=$(
        basename "${font_url}" | tr '[:upper:]' '[:lower:]'
    )
    local font_path="${font_tmp_folder}/${font_name}"

    curl -fsSLo "${font_path}" "${font_url}"

    if [[ ! -f "${font_path}" ]]; then
        echo "Download failed for ${font_name}"
        if [[ "${font_die_if_fail}" == 1 ]]; then
            return 1
        else
            return 0
        fi
    fi

    $([[ "${font_global_install}" == 1 ]] && _power_giver panic) unzip \
        -oqq "${font_path}" "*.[ot]tf" \
        -d "${font_final_folder}" > /dev/null

    fc-cache -f

    rm -rf "${font_path}"

    return 0

}

function _main() {

    local nerdfont_version=${_DOT_NERDFONT_VERSION:-"v3.4.0"}
    local nerdfont_base=${_DOT_NERDFONT_BASE:-"https://github.com/ryanoasis/nerd-fonts/releases/download"}
    local nerdfont_temp_destination=${_DOT_NERDFONT_TEMP_DESTINATION:-"/tmp/fonts"}
    local nerdfont_global_install=${_DOT_NERDFONT_GLOBAL_INSTALL:-}
    local nerdfont_die_if_fail_once=${_DOT_NERDFONT_DIE_IF_FAIL_ONCE:-}

    if [[ $# -lt 1 ]]; then
        echo 'No fonts provided'
        return 0
    fi

    local fonts_final_folder
    if [[ -z "${nerdfont_global_install}" ]]; then
        fonts_final_folder="/home/$(whoami)/.local/share/fonts"
        mkdir -p "${fonts_final_folder}"
    else
        fonts_final_folder="/usr/local/share/fonts"
    fi

    _install_packages 'git fontconfig unzip'

    mkdir -p "${nerdfont_temp_destination}"

    for font in $@; do
        _install_nerdfont \
            "${font}" \
            "${nerdfont_base}/${nerdfont_version}" \
            "${fonts_final_folder}" \
            "${nerdfont_global_install}" \
            "${nerdfont_die_if_fail_once}" \
            "${nerdfont_temp_destination}"
    done

    rm -rf "${nerdfont_temp_destination}"

    return 0

}

set -e

_main $@ # FiraCode FiraMono RobotoMono NerdFontsSymbolsOnly ZedMono