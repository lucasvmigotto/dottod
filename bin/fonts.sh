#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _font_installed() {
    local font=${1:?'Font must be informed'}
    fc-list --format='%{family}\n' | grep -qi "${font}"
}

function _install_nerdfont() {
    local font=${1:?'Font must be informed'}
    local font_url_base=${2:?'Font URL base must be informed'}
    local font_final_folder=${3:?'Font folder must be informed'}
    local font_global_install=${4:-0}
    local font_die_if_fail=${5:-0}
    local font_tmp_folder=${6:-'/tmp/fonts'}

    if _font_installed "${font}"; then
        log_info "${font} already installed, skipping..."
        return 0
    fi

    local font_url="${font_url_base}/${font}.zip"
    if ! curl -fsSLI "${font_url}" >/dev/null 2>&1; then
        log_warn "URL ${font_url} is not available"
        return 1
    fi

    local font_name font_path
    font_name="$(basename "${font_url}" | tr '[:upper:]' '[:lower:]')"
    font_path="${font_tmp_folder}/${font_name}"

    log_step "Downloading ${font}"
    _download "${font_url}" "${font_path}"

    if [[ ! -f "${font_path}" ]]; then
        log_warn "Download failed for ${font_name}"
        if [[ "${font_die_if_fail}" == 1 ]]; then
            return 1
        fi
        return 0
    fi

    if [[ "${font_global_install}" == 1 ]]; then
        _priv unzip -oqq "${font_path}" '*.[ot]tf' -d "${font_final_folder}" >/dev/null
    else
        unzip -oqq "${font_path}" '*.[ot]tf' -d "${font_final_folder}" >/dev/null
    fi

    fc-cache -f
    rm -rf "${font_path}"

    log_ok "Installed ${font}"
    return 0
}

function _main() {
    local nerdfont_version=${_DOT_NERDFONT_VERSION:-"v3.4.0"}
    local nerdfont_base=${_DOT_NERDFONT_BASE:-"https://github.com/ryanoasis/nerd-fonts/releases/download"}
    local nerdfont_temp_destination=${_DOT_NERDFONT_TEMP_DESTINATION:-"/tmp/fonts"}
    local nerdfont_global_install=${_DOT_NERDFONT_GLOBAL_INSTALL:-0}
    local nerdfont_die_if_fail_once=${_DOT_NERDFONT_DIE_IF_FAIL_ONCE:-0}

    local -a fonts=("$@")
    if [[ ${#fonts[@]} -lt 1 ]]; then
        fonts=(FiraCode FiraMono RobotoMono NerdFontsSymbolsOnly ZedMono)
    fi

    local fonts_final_folder
    if [[ "${nerdfont_global_install}" == 1 ]]; then
        fonts_final_folder="/usr/local/share/fonts"
    else
        fonts_final_folder="${HOME}/.local/share/fonts"
    fi
    mkdir -p "${fonts_final_folder}"

    _install_packages 'git fontconfig unzip curl ca-certificates'

    mkdir -p "${nerdfont_temp_destination}"

    for font in "${fonts[@]}"; do
        _install_nerdfont \
            "${font}" \
            "${nerdfont_base}/${nerdfont_version}" \
            "${fonts_final_folder}" \
            "${nerdfont_global_install}" \
            "${nerdfont_die_if_fail_once}" \
            "${nerdfont_temp_destination}"
    done

    rm -rf "${nerdfont_temp_destination}"

    log_ok 'Fonts installed'
    return 0
}

_main "$@"
