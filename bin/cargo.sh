#!/usr/bin/env bash
#
# cargo.sh — dottod Rust toolchain task (rustup, first-class).
#
# Installs the Rust toolchain via rustup using download-then-run (never a
# pipe-to-shell): the init script is fetched with retries, executed from a
# file, then removed. `--no-modify-path` keeps installers away from
# `~/.bashrc` (the repo symlink); PATH comes from `config/.custom.bashrc`.
#
# Env overrides:
#   _DOT_RUSTUP_INIT_URL   rustup-init script URL (default https://sh.rustup.rs)
#   _DOT_RUSTUP_TOOLCHAIN  toolchain to install (default stable; versions OK)
#   _DOT_RUSTUP_PROFILE    rustup profile (default minimal)
#   _DOT_CARGO_HOME        cargo home (default ~/.cargo)
#   _DOT_TARGET_USER       target user (default id -un)
#   _DOT_NO_PACKAGES       1 skips apt (tests)
#
# Usage: cargo.sh [""] | status | --help|-h
#   ("")     ensure toolchain (idempotent skip when cargo exists)
#   status   print toolchain report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_RUSTUP_INIT_URL_DEFAULT='https://sh.rustup.rs'
_DOT_RUSTUP_TOOLCHAIN_DEFAULT='stable'
_DOT_RUSTUP_PROFILE_DEFAULT='minimal'

function _cargo_home() {
    printf '%s' "${_DOT_CARGO_HOME:-"${HOME}/.cargo"}"
}

function _cargo_ensure() {
    if _is_runnable cargo; then
        log_info "cargo $(cargo --version 2>/dev/null | cut -d' ' -f2) already installed, skipping..."
        return 0
    fi

    local init_url=${_DOT_RUSTUP_INIT_URL:-"${_DOT_RUSTUP_INIT_URL_DEFAULT}"}
    local toolchain=${_DOT_RUSTUP_TOOLCHAIN:-"${_DOT_RUSTUP_TOOLCHAIN_DEFAULT}"}
    local profile=${_DOT_RUSTUP_PROFILE:-"${_DOT_RUSTUP_PROFILE_DEFAULT}"}
    local cargo_home
    cargo_home="$(_cargo_home)"

    log_step 'Installing Rust toolchain prerequisites'
    _install_packages 'curl ca-certificates'

    local tmp
    tmp="$(mktemp)"
    log_step "Installing Rust toolchain (${toolchain}, profile ${profile})"
    if ! _download "${init_url}" "${tmp}"; then
        rm -f "${tmp}"
        log_error "rustup-init download failed: ${init_url}"
        return 1
    fi
    if ! sh "${tmp}" -y --no-modify-path --profile "${profile}" --default-toolchain "${toolchain}" >/dev/null 2>&1; then
        rm -f "${tmp}"
        log_error 'rustup-init failed.'
        return 1
    fi
    rm -f "${tmp}"

    if [[ ! -x "${cargo_home}/bin/cargo" ]]; then
        log_error "rustup finished but ${cargo_home}/bin/cargo is missing."
        return 1
    fi
    log_ok "cargo installed ($("${cargo_home}/bin/cargo" --version 2>/dev/null | cut -d' ' -f2))"
    return 0
}

function _cargo_status() {
    local cargo_home
    cargo_home="$(_cargo_home)"
    cat <<EOF
Rust toolchain
--------------
Cargo:    $(command -v cargo >/dev/null 2>&1 && cargo --version 2>/dev/null || echo missing)
Home:     ${cargo_home}
Profile:  ${_DOT_RUSTUP_PROFILE:-"${_DOT_RUSTUP_PROFILE_DEFAULT}"} (default for fresh installs)
Toolchain: ${_DOT_RUSTUP_TOOLCHAIN:-"${_DOT_RUSTUP_TOOLCHAIN_DEFAULT}"} (default for fresh installs)
Rustup:   $(command -v rustup >/dev/null 2>&1 && echo present || echo missing)
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: cargo.sh [status]

Rust toolchain via rustup (download-then-run, idempotent).

  (no args)  install toolchain unless cargo exists
  status     print toolchain report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '')
            _cargo_ensure
            return 0
            ;;
        status)
            _cargo_status
            return 0
            ;;
        --help|-h)
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
