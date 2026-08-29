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

    if _is_installed ghostty; then
        log_info 'ghostty already installed, skipping...'
        _ghostty_set_default_terminal
        return 0
    fi

    _install_packages 'curl ca-certificates'

    log_step 'Installing Ghostty'
    curl -fsSL "${installer_url}" | _priv bash

    _ghostty_set_default_terminal

    log_ok 'Ghostty installed'
    return 0
}

_main "$@"
