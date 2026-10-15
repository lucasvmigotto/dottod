#!/usr/bin/env bash
#
# bun.sh — dottod Bun task (first-class JS runtime).
#
# Installs Bun from its official release zips using download-then-verify
# (never bun's pipe-to-shell installer, which would append exports to
# `~/.bashrc` — the repo symlink — behind our back). The single `bun`
# binary lands in `~/.local/bin`, already on PATH via
# `config/.custom.bashrc`; no shell-rc file is ever modified.
#
# Env overrides:
#   _DOT_BUN_VERSION       bun tag (default latest; e.g. bun-v1.2.0)
#   _DOT_BUN_GITHUB        GitHub base for mirror override (default https://github.com)
#   _DOT_TARGET_USER       target user (default id -un)
#   _DOT_NO_PACKAGES       1 skips package installs (tests)
#
# Usage: bun.sh [""] | status | --help|-h
#   ("")     ensure bun (idempotent skip when bun exists)
#   status   print bun report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_BUN_VERSION_DEFAULT='latest'
_DOT_BUN_GITHUB_DEFAULT='https://github.com'

# Release target: linux-<arch>, plus -musl on musl systems (Alpine), where
# the glibc build cannot run. An unknown libc gets the glibc build; the
# runnable check after install refuses it if that guess was wrong.
function _bun_arch() {
    local arch
    case "$(uname -m)" in
        x86_64 | amd64) arch='linux-x64' ;;
        arm64 | aarch64) arch='linux-aarch64' ;;
        *) return 1 ;;
    esac
    [[ "$(_os_libc)" == musl ]] && arch+='-musl'
    printf '%s' "${arch}"
}

# sha256 for a release asset from the release's own SHASUMS256.txt
# (published next to every Bun asset). Needs only curl: no JSON parser,
# so minimal systems without python3 still verify, and mirrors that copy
# the file verify too. Prints the hex digest, or nothing when the file or
# the entry is missing (caller warns and proceeds).
function _bun_shasum() {
    local sums_url=${1:?'SHASUMS URL must be informed'}
    local asset_name=${2:?'Asset name must be informed'}
    local sums hash name
    sums="$(curl -fsSL "${sums_url}" 2>/dev/null)" || return 0
    while read -r hash name; do
        if [[ "${name#\*}" == "${asset_name}" && "${hash}" =~ ^[0-9a-f]{64}$ ]]; then
            printf '%s' "${hash}"
            return 0
        fi
    done <<<"${sums}"
    return 0
}

# Resolve the zip download URL and its sha256 digest for a version.
# Prints "<url> <sha256hex>" (digest may be empty); fails only when the
# asset itself cannot be found. Accepts `latest` or a `bun-vX.Y.Z` tag.
function _bun_zip_asset() {
    local version=${1:?'Version must be informed'}
    local target=${2:?'Target must be informed'}
    local github=${_DOT_BUN_GITHUB:-"${_DOT_BUN_GITHUB_DEFAULT}"}
    local asset_name="bun-${target}.zip"
    local url digest=""

    local base
    if [[ "${version}" == 'latest' ]]; then
        base="${github}/oven-sh/bun/releases/latest/download"
    else
        local tag="${version}"
        [[ "${tag}" == bun-v* ]] || tag="bun-v${version#v}"
        base="${github}/oven-sh/bun/releases/download/${tag}"
    fi
    url="${base}/${asset_name}"
    digest="$(_bun_shasum "${base}/SHASUMS256.txt" "${asset_name}")"

    if [[ -z "${url}" ]]; then
        log_error "No asset '${asset_name}' for Bun ${version}"
        return 1
    fi
    printf '%s %s\n' "${url}" "${digest}"
}

function _bun_ensure() {
    if _is_runnable bun; then
        log_info "bun $(bun --version 2>/dev/null) already installed, skipping..."
    else
        _bun_install_runtime || return 1
    fi

    _bun_devcontainer
    return 0
}

function _bun_install_runtime() {
    local version=${_DOT_BUN_VERSION:-"${_DOT_BUN_VERSION_DEFAULT}"}
    local target url digest tmpdir dest
    target="$(_bun_arch)" || {
        log_error "Unsupported architecture '$(uname -m)' for Bun."
        return 1
    }
    dest="$(_ensure_local_bin)/bun"

    # Prerequisites first: the checksum lookup below needs curl, and on a
    # fresh system it would otherwise come back empty (installing unverified).
    log_step 'Installing Bun prerequisites'
    _install_packages curl ca_certificates unzip
    # The musl build links the C++ runtime, absent from a base Alpine.
    if [[ "$(_os_libc)" == musl ]]; then
        _install_packages cxx_runtime
    fi
    read -r url digest <<<"$(_bun_zip_asset "${version}" "${target}")"

    tmpdir="$(mktemp -d)"
    log_step "Installing Bun ${version} (${target}) with sha256 verification"
    _download "${url}" "${tmpdir}/bun.zip"
    if [[ -n "${digest}" ]]; then
        local actual
        actual="$(sha256sum "${tmpdir}/bun.zip" | cut -d' ' -f1)"
        if [[ "${actual}" != "${digest}" ]]; then
            log_error "Bun zip checksum mismatch (want ${digest}, got ${actual})."
            rm -rf "${tmpdir}"
            return 1
        fi
    else
        log_warn "No checksum published for bun ${version}; installing unverified."
    fi
    unzip -oqq "${tmpdir}/bun.zip" "bun-${target}/bun" -d "${tmpdir}"
    install -m 0755 "${tmpdir}/bun-${target}/bun" "${dest}"
    rm -rf "${tmpdir}"

    # Check the artifact path directly (not ambient PATH: a bare
    # `bun.sh` run may not have sourced the repo bashrc that adds
    # ~/.local/bin yet).
    if [[ ! -x "${dest}" ]]; then
        log_error 'Bun install did not yield a bun binary on PATH.'
        return 1
    fi
    if ! "${dest}" --version >/dev/null 2>&1; then
        log_error "Installed ${dest} does not run on this system (libc: $(_os_libc)); removing it."
        rm -f "${dest}"
        return 1
    fi
    log_ok "bun installed ($("${dest}" --version 2>/dev/null))"
    return 0
}

# Marker on the line after the shebang of the wrapper dottod writes; a
# devcontainer file without it is the user's and is never overwritten.
_DOT_DEVCONTAINER_MARKER='# dottod: devcontainer CLI on Bun (no Node.js)'

# devcontainer CLI, installed and run by Bun: `bun install --global`, then
# a ~/.local/bin/devcontainer wrapper that runs the CLI with `bun --bun`.
# The package's own launcher starts with `#!/usr/bin/env node`; the
# wrapper (first on PATH) makes Node.js unnecessary, so no distro ever
# installs or compiles it for this. Pinned package unless overridden.
function _bun_devcontainer() {
    local package=${_DOT_DEVCONTAINER_PACKAGE:-'@devcontainers/cli@latest'}

    if _is_runnable devcontainer; then
        log_info "devcontainer $(devcontainer --version 2>/dev/null) already installed, skipping..."
        return 0
    fi

    local bun_bin wrapper cli
    bun_bin="$(_ensure_local_bin)/bun"
    wrapper="$(_ensure_local_bin)/devcontainer"
    if [[ ! -x "${bun_bin}" ]]; then
        log_warn 'bun binary missing; skipping devcontainer CLI install.'
        return 0
    fi
    if [[ -e "${wrapper}" ]] && ! grep -qxF "${_DOT_DEVCONTAINER_MARKER}" "${wrapper}" 2>/dev/null; then
        log_warn "${wrapper} exists and is not dottod's; leaving it alone."
        return 0
    fi

    log_step "Installing devcontainer CLI (${package}) with Bun"
    if ! "${bun_bin}" install --global "${package}" >/dev/null 2>&1; then
        log_error 'devcontainer CLI install failed.'
        return 1
    fi

    cli="${BUN_INSTALL:-"${HOME}/.bun"}/install/global/node_modules/@devcontainers/cli/devcontainer.js"
    if [[ ! -f "${cli}" ]]; then
        log_error "devcontainer CLI install did not yield ${cli}."
        return 1
    fi

    {
        printf '#!/bin/sh\n'
        printf '%s\n' "${_DOT_DEVCONTAINER_MARKER}"
        printf 'exec "%s" --bun "%s" "$@"\n' "${bun_bin}" "${cli}"
    } >"${wrapper}"
    chmod 0755 "${wrapper}"

    if ! "${wrapper}" --version >/dev/null 2>&1; then
        log_error "${wrapper} does not run the devcontainer CLI under Bun."
        return 1
    fi
    log_ok "devcontainer CLI $("${wrapper}" --version 2>/dev/null) installed (runs on Bun)"
    return 0
}

function _bun_status() {
    cat <<EOF
Bun
---
Installed: $(command -v bun >/dev/null 2>&1 && bun --version 2>/dev/null || echo missing)
Pinned:    ${_DOT_BUN_VERSION:-"${_DOT_BUN_VERSION_DEFAULT}"} (default for fresh installs)
Home:      $(command -v bun >/dev/null 2>&1 && dirname "$(command -v bun)" || echo -)
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: bun.sh [status]

Bun JS runtime (direct-zip install, idempotent).

  (no args)  install bun unless present
  status     print bun report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '')
            _bun_ensure
            return 0
            ;;
        status)
            _bun_status
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
