#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _set_gsetting() {
    local schema=${1} key=${2} value=${3}

    if command -v gsettings >/dev/null 2>&1 && gsettings get "${schema}" "${key}" >/dev/null 2>&1; then
        gsettings set "${schema}" "${key}" "${value}"
        log_ok "gsettings ${schema} ${key} = ${value}"
    else
        log_warn "skipping ${schema} ${key} (no gsettings or GNOME session)"
    fi
}

function _main() {
    local system_monitor=${_DOT_SYSTEM_MONITOR:-'gnome-system-monitor'}
    local ui_font=${_DOT_DESKTOP_FONT:-'FiraCode Nerd Font 11'}

    log_step 'Installing desktop utilities'
    _install_packages "${system_monitor}"

    log_step 'Applying GNOME dark theme and fonts'
    _set_gsetting org.gnome.desktop.interface color-scheme 'prefer-dark'
    _set_gsetting org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    _set_gsetting org.gnome.desktop.interface icon-theme 'Adwaita-dark'
    _set_gsetting org.gnome.desktop.interface font-name "${ui_font}"
    _set_gsetting org.gnome.desktop.interface document-font-name "${ui_font}"
    _set_gsetting org.gnome.desktop.interface monospace-font-name "${ui_font}"

    log_ok 'Desktop configured'
    return 0
}

_main "$@"
