#!/usr/bin/env bash
#
# vim.sh — dottod Vim task: vim-plug, the dottod vimrc and its plugins.
#
# Usage: vim.sh [""] | status | --help|-h
#   ("")     install vim-plug, link ~/.vimrc, install the declared plugins
#   status   print the Vim report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# Home directory for a task user (see _dot_user_home in bin/utils.sh).
function _vim_home() {
    _dot_user_home "${1:?'User must be informed'}"
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

function _vim_status() {
    local current_user home vimrc
    current_user="$(id -un)"
    home="$(_vim_home "${current_user}")"
    vimrc="${home}/.vimrc"

    local wanted=0 present=0 plug
    while IFS= read -r plug; do
        [[ -n "${plug}" ]] || continue
        wanted=$((wanted + 1))
        [[ -d "${home}/.vim/plugged/${plug}" ]] && present=$((present + 1))
    done < <(_vim_wanted_plugins "${vimrc}")

    cat <<EOF
Vim
---
Installed: $(command -v vim >/dev/null 2>&1 && _dot_first_line vim --version || echo missing)
Vimrc:     ${vimrc} ($(_dot_path_state "${vimrc}" "${DOT_CONFIG_DIR}/.custom.vimrc"))
vim-plug:  $([[ -f "${home}/.vim/autoload/plug.vim" ]] && echo present || echo missing)
Plugins:   ${present}/${wanted} installed
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: vim.sh [status]

  (no args)  install vim-plug, link ~/.vimrc and install its plugins
  status     print the Vim report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '') ;;
        status)
            _vim_status
            return 0
            ;;
        --help | -h)
            _usage
            return 0
            ;;
        *)
            log_error "Unknown action: ${1} (want empty or 'status')"
            _usage
            return 1
            ;;
    esac

    local vim_plug_script=${_DOT_VIM_SCRIPT_URL:-"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"}

    local current_user
    current_user="$(id -un)"

    _install_packages git vim curl

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
