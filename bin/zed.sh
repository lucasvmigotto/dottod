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
#   _DOT_NO_PACKAGES         1 skips package installs (tests)
#
# Usage: zed.sh [""] | status | --help|-h
#   ("")     install Zed (skipped when it already runs)
#   status   print the Zed report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_ZED_INSTALLER_URL_DEFAULT='https://zed.dev/install.sh'

function _zed_ensure() {
    if _is_runnable zed; then
        log_info 'zed already installed, skipping...'
        return 0
    fi

    # Zed ships glibc builds only: on musl (Alpine) it cannot run, so the
    # optional GUI task skips with the reason instead of failing.
    if [[ "$(_os_libc)" == musl ]]; then
        log_warn 'Zed provides glibc builds only; skipping it on this musl system.'
        return 0
    fi

    local installer_url=${_DOT_ZED_INSTALLER_URL:-"${_DOT_ZED_INSTALLER_URL_DEFAULT}"}

    log_step 'Installing Zed prerequisites'
    _install_packages curl ca_certificates tar

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
    local bin="${HOME}/.local/bin/zed"
    [[ -x "${bin}" ]] || bin="$(command -v zed 2>/dev/null)" || bin=''
    if [[ -z "${bin}" ]]; then
        log_error 'Zed install did not yield a zed binary on PATH.'
        return 1
    fi
    # The installer exiting 0 is not proof: the binary must run here.
    if ! "${bin}" --version >/dev/null 2>&1; then
        log_error "Installed ${bin} does not run on this system."
        return 1
    fi
    log_ok "Zed installed ($(_dot_first_line "${bin}" --version))"
    return 0
}

function _zed_status() {
    local bin=''
    if command -v zed >/dev/null 2>&1; then
        bin="$(command -v zed)"
    elif [[ -x "${HOME}/.local/bin/zed" ]]; then
        bin="${HOME}/.local/bin/zed"
    fi
    cat <<EOF
Zed
---
Installed: $([[ -n "${bin}" ]] && _dot_first_line "${bin}" --version || echo missing)
Binary:    ${bin:-missing}
Channel:   ${_DOT_ZED_CHANNEL:-stable} (for fresh installs)
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: zed.sh [status]

  (no args)  install Zed with its official installer (download, then run)
  status     print the Zed report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '')
            _zed_ensure
            return 0
            ;;
        status)
            _zed_status
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
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
