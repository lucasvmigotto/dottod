#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _ghostty_set_default_terminal() {
    if command -v gsettings >/dev/null 2>&1 \
        && gsettings get org.gnome.desktop.default-applications.terminal >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
        gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
        log_ok 'Ghostty set as default GNOME terminal'
    fi

    if command -v update-alternatives >/dev/null 2>&1 && _is_installed ghostty; then
        _priv update-alternatives --set x-terminal-emulator "$(command -v ghostty)"
        log_ok 'Ghostty set as x-terminal-emulator'
    fi
}

function _main() {
    local installer_url=${_DOT_GHOSTTY_INSTALLER_URL:-'https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh'}

    if _is_runnable ghostty; then
        log_info 'ghostty already installed, skipping...'
        _ghostty_set_default_terminal
        return 0
    fi

    _install_packages 'curl ca-certificates'

    log_step 'Installing Ghostty'
    # Download-then-run (never pipe a remote script into a privileged
    # shell): a failed/truncated download must not execute as root. The
    # URL stays overridable. Failures return loudly, as the original
    # pipefail pipeline did — only with clearer messages.
    local installer_tmp
    installer_tmp="$(mktemp)"
    if ! _download "${installer_url}" "${installer_tmp}"; then
        rm -f "${installer_tmp}"
        log_error "Ghostty installer download failed: ${installer_url}"
        return 1
    fi
    if ! _priv bash "${installer_tmp}"; then
        rm -f "${installer_tmp}"
        log_error 'Ghostty installer failed.'
        return 1
    fi
    rm -f "${installer_tmp}"

    _ghostty_set_default_terminal

    log_ok 'Ghostty installed'
    return 0
}

_main "$@"
