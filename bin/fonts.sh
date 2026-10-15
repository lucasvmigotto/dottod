#!/usr/bin/env bash
#
# fonts.sh — dottod Nerd Fonts task.
#
# Usage: fonts.sh [FONT...] | status [FONT...] | --help|-h
#   (FONT...)  install the fonts (default: the dottod set)
#   status     print which fonts are installed, without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# _font_family <zip name>: the family name the font registers with
# fontconfig (the Nerd Fonts zip names match it, except the symbols set).
function _font_family() {
    case "${1}" in
        NerdFontsSymbolsOnly) printf 'Symbols Nerd Font' ;;
        *) printf '%s' "${1}" ;;
    esac
}

# Read the whole family list before matching: piping fc-list into
# `grep -q` under pipefail fails whenever grep exits early (fc-list dies
# of SIGPIPE), so installed fonts looked missing and re-downloaded.
function _font_installed() {
    local font=${1:?'Font must be informed'}
    local families
    families="$(fc-list --format='%{family}\n' 2>/dev/null)" || return 1
    grep -qiF -- "$(_font_family "${font}")" <<<"${families}"
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

readonly DOT_FONTS_DEFAULT=(FiraCode FiraMono RobotoMono NerdFontsSymbolsOnly ZedMono)

function _fonts_status() {
    local -a fonts=("$@")
    [[ ${#fonts[@]} -gt 0 ]] || fonts=("${DOT_FONTS_DEFAULT[@]}")
    local folder="${HOME}/.local/share/fonts"
    [[ "${_DOT_NERDFONT_GLOBAL_INSTALL:-0}" == 1 ]] && folder='/usr/local/share/fonts'
    local font state lines=''
    for font in "${fonts[@]}"; do
        if ! command -v fc-list >/dev/null 2>&1; then
            state='unknown (no fc-list)'
        elif _font_installed "${font}"; then
            state='installed'
        else
            state='missing'
        fi
        lines+="$(printf '  %-22s %s' "${font}" "${state}")"$'\n'
    done
    cat <<EOF
Fonts
-----
Folder:    ${folder} ($([[ -d "${folder}" ]] && echo present || echo missing))
fc-list:   $(_dot_have fc-list)
${lines%$'\n'}
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: fonts.sh [FONT...] | status [FONT...]

  (FONT...)  install the Nerd Fonts (default: the dottod set)
  status     print which fonts are installed, without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        status)
            shift
            _fonts_status "$@"
            return 0
            ;;
        --help | -h)
            _usage
            return 0
            ;;
    esac

    local nerdfont_version=${_DOT_NERDFONT_VERSION:-"v3.4.0"}
    local nerdfont_base=${_DOT_NERDFONT_BASE:-"https://github.com/ryanoasis/nerd-fonts/releases/download"}
    local nerdfont_temp_destination=${_DOT_NERDFONT_TEMP_DESTINATION:-"/tmp/fonts"}
    local nerdfont_global_install=${_DOT_NERDFONT_GLOBAL_INSTALL:-0}
    local nerdfont_die_if_fail_once=${_DOT_NERDFONT_DIE_IF_FAIL_ONCE:-0}

    local -a fonts=("$@")
    if [[ ${#fonts[@]} -lt 1 ]]; then
        fonts=("${DOT_FONTS_DEFAULT[@]}")
    fi

    local fonts_final_folder
    if [[ "${nerdfont_global_install}" == 1 ]]; then
        fonts_final_folder="/usr/local/share/fonts"
    else
        fonts_final_folder="${HOME}/.local/share/fonts"
    fi
    mkdir -p "${fonts_final_folder}"

    # User-level installs must not require privilege: only escalate for
    # prerequisites that are actually missing (probed, not assumed).
    local -a need=()
    command -v curl >/dev/null 2>&1 || need+=('curl' 'ca_certificates')
    command -v fc-list >/dev/null 2>&1 || need+=('fontconfig')
    command -v unzip >/dev/null 2>&1 || need+=('unzip')
    if [[ ${#need[@]} -gt 0 ]]; then
        _install_packages "${need[@]}"
    else
        log_info 'Font prerequisites already present, skipping package install...'
    fi

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

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
