#!/usr/bin/env bash
#
# shell.sh — dottod bash task.
#
# Ensures bash is installed and the login shell, then links the dottod
# interactive customization (config/.custom.bashrc) to ~/.bashrc.
# Plain bash only: no zsh, no oh-my-zsh, no prompt frameworks, no plugins.
# The prompt is a lightweight PROMPT_COMMAND in .custom.bashrc.
#
# Usage: shell.sh [""] | status | --help|-h
#   ("")     install bash, make it the login shell, link ~/.bashrc
#   status   print the shell report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# _bash_shells_path: the first executable bash listed in /etc/shells
# (_DOT_SHELLS_FILE overrides it for tests); chsh only accepts those.
function _bash_shells_path() {
    local line
    while IFS= read -r line; do
        if [[ "${line}" == /*/bash && -x "${line}" ]]; then
            printf '%s' "${line}"
            return 0
        fi
    done <"${_DOT_SHELLS_FILE:-/etc/shells}"
    return 1
}

function _bash_use_as_shell() {
    local current_user=${1:?'User must be informed'}

    local bash_path current_shell
    current_shell="$(_dot_passwd_entry "${current_user}" | cut -d: -f7)" || current_shell=''

    # Any executable bash counts, whatever its path spelling (/bin/bash vs
    # /usr/bin/bash on merged-/usr systems).
    if [[ "${current_shell##*/}" == bash && -x "${current_shell}" ]]; then
        log_info 'bash already installed and in use, skipping...'
        return 0
    fi

    if ! bash_path="$(_bash_shells_path 2>/dev/null)"; then
        log_warn "bash is not listed in /etc/shells, so the login shell stays ${current_shell:-unchanged}."
        log_warn "Add it, then switch: echo $(command -v bash) | sudo tee -a /etc/shells && chsh -s $(command -v bash)"
        return 0
    fi
    if ! command -v chsh >/dev/null 2>&1; then
        log_warn "chsh is not available, so the login shell stays ${current_shell:-unchanged}."
        log_warn "Switch it as root: usermod -s ${bash_path} ${current_user}"
        return 0
    fi

    log_step 'Setting bash as the default shell'
    _priv chsh -s "${bash_path}" "${current_user}"
    log_ok "bash (${bash_path}) set as default shell"

    return 0
}

function _custom_bashrc() {
    local current_user=${1:?'User must be informed'}

    local home
    home="$(_dot_user_home "${current_user}")" || return 1
    _link_file "${DOT_CONFIG_DIR}/.custom.bashrc" "${home}/.bashrc"
}

function _shell_status() {
    local current_user home login
    current_user="${_DOT_TARGET_USER:-$(id -un)}"
    home="$(_dot_user_home "${current_user}")" || home="${HOME}"
    login="$(_dot_passwd_entry "${current_user}" | cut -d: -f7)" || login=''
    local state='not bash'
    [[ "${login##*/}" == bash ]] && state='bash'
    cat <<EOF
Shell
-----
Bash:      $(command -v bash >/dev/null 2>&1 && _dot_first_line bash --version || echo missing)
Login:     ${login:-unknown} (${state})
Bashrc:    ${home}/.bashrc ($(_dot_path_state "${home}/.bashrc" "${DOT_CONFIG_DIR}/.custom.bashrc"))
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: shell.sh [status]

  (no args)  install bash, make it the login shell and link ~/.bashrc
  status     print the shell report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '') ;;
        status)
            _shell_status
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

    local current_user
    current_user="${_DOT_TARGET_USER:-$(id -un)}"

    log_step 'Installing git and bash'
    _install_packages git bash curl ca_certificates

    _bash_use_as_shell "${current_user}"

    _custom_bashrc "${current_user}"

    log_ok 'Shell bootstrap complete'
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
