#!/usr/bin/env bash
#
# shell.sh — dottod bash task.
#
# Ensures bash is installed and the login shell, then links the dottod
# interactive customization (config/.custom.bashrc) to ~/.bashrc.
# Plain bash only: no zsh, no oh-my-zsh, no prompt frameworks, no plugins.
# The prompt is a lightweight PROMPT_COMMAND in .custom.bashrc.

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _bash_use_as_shell() {
    local current_user=${1:?'User must be informed'}

    local bash_bin current_shell
    bash_bin="$(command -v bash)"
    current_shell="$(getent passwd "${current_user}" | cut -d: -f7)"

    if [[ "${bash_bin}" == "${current_shell}" ]]; then
        log_info 'bash already installed and in use, skipping...'
        return 0
    fi

    log_step 'Setting bash as the default shell'
    _priv chsh -s "${bash_bin}" "${current_user}"
    log_ok 'bash set as default shell'

    return 0
}

function _custom_bashrc() {
    local current_user=${1:?'User must be informed'}

    _link_file "${DOT_CONFIG_DIR}/.custom.bashrc" "/home/${current_user}/.bashrc"
}

function _main() {
    local current_user
    current_user="${_DOT_TARGET_USER:-$(id -un)}"

    log_step 'Installing git and bash'
    _install_packages 'git bash curl ca-certificates'

    _bash_use_as_shell "${current_user}"

    _custom_bashrc "${current_user}"

    log_ok 'Shell bootstrap complete'
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
