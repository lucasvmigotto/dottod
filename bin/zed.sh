#!/usr/bin/env bash
#
# zed.sh — dottod Zed task (first-class GUI editor).
#
# Installs Zed from its official installer using download-then-run (never a
# pipe-to-shell): the installer is fetched with retries, executed from a
# file, then removed. The installer is user-level (binary lands in
# ~/.local/bin, already on PATH); no privilege escalation is used for the
# install itself.
#
# Env overrides:
#   _DOT_ZED_INSTALLER_URL   installer URL (default https://zed.dev/install.sh)
#   _DOT_ZED_CHANNEL         release channel (default stable)
#   _DOT_ZED_VERSION         version pin (default latest)
#   _DOT_NO_PACKAGES         1 skips apt (tests)

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_ZED_INSTALLER_URL_DEFAULT='https://zed.dev/install.sh'

function _zed_ensure() {
    if _is_installed zed; then
        log_info 'zed already installed, skipping...'
        return 0
    fi

    local installer_url=${_DOT_ZED_INSTALLER_URL:-"${_DOT_ZED_INSTALLER_URL_DEFAULT}"}

    log_step 'Installing Zed prerequisites'
    _install_packages 'curl ca-certificates tar'

    # Download-then-run (never pipe a remote script straight into a
    # shell): a failed/truncated download must not execute. The URL stays
    # overridable. Channel/version pass through as the installer expects.
    local installer_tmp
    installer_tmp="$(mktemp)"
    log_step 'Installing Zed'
    if ! _download "${installer_url}" "${installer_tmp}"; then
        rm -f "${installer_tmp}"
        log_error "Zed installer download failed: ${installer_url}"
        return 1
    fi
    if ! ZED_CHANNEL="${_DOT_ZED_CHANNEL:-stable}" \
        ZED_VERSION="${_DOT_ZED_VERSION:-latest}" \
        sh "${installer_tmp}"; then
        rm -f "${installer_tmp}"
        log_error 'Zed installer failed.'
        return 1
    fi
    rm -f "${installer_tmp}"

    # Check the artifact path directly (a bare `zed.sh` run may not have
    # ~/.local/bin on its ambient PATH yet).
    if [[ ! -x "${HOME}/.local/bin/zed" ]] && ! _is_installed zed; then
        log_error 'Zed install did not yield a zed binary on PATH.'
        return 1
    fi
    log_ok 'Zed installed'
    return 0
}

function _main() {
    _zed_ensure
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
