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
#   _DOT_NO_PACKAGES       1 skips apt (tests)
#
# Usage: bun.sh [""] | status | --help|-h
#   ("")     ensure bun (idempotent skip when bun exists)
#   status   print bun report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_BUN_VERSION_DEFAULT='latest'
_DOT_BUN_GITHUB_DEFAULT='https://github.com'

function _bun_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf 'linux-x64' ;;
        arm64|aarch64) printf 'linux-aarch64' ;;
        *) return 1 ;;
    esac
}

# Digest for a release asset from the public GitHub API. Prints the sha256
# hex or nothing (mirror overrides have no API; caller warns and proceeds).
function _bun_api_digest() {
    local api_url=${1:?'API URL must be informed'}
    local asset_name=${2:?'Asset name must be informed'}

    curl -fsSL "${api_url}" 2>/dev/null | python3 -c '
import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for a in data.get("assets", []):
    if a.get("name") == sys.argv[1]:
        print((a.get("digest") or "").removeprefix("sha256:"))
        break
' "${asset_name}" 2>/dev/null || true
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

    if [[ "${version}" == 'latest' ]]; then
        url="${github}/oven-sh/bun/releases/latest/download/${asset_name}"
        if [[ "${github}" == "${_DOT_BUN_GITHUB_DEFAULT}" ]]; then
            digest="$(_bun_api_digest 'https://api.github.com/repos/oven-sh/bun/releases/latest' "${asset_name}")"
        fi
    else
        local tag="${version}"
        [[ "${tag}" == bun-v* ]] || tag="bun-v${version#v}"
        url="${github}/oven-sh/bun/releases/download/${tag}/${asset_name}"
        if [[ "${github}" == "${_DOT_BUN_GITHUB_DEFAULT}" ]]; then
            digest="$(_bun_api_digest "https://api.github.com/repos/oven-sh/bun/releases/tags/${tag}" "${asset_name}")"
        fi
    fi

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
    read -r url digest <<<"$(_bun_zip_asset "${version}" "${target}")"
    dest="$(_ensure_local_bin)/bun"

    log_step 'Installing Bun prerequisites'
    _install_packages 'curl ca-certificates unzip'

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
    log_ok "bun installed ($("${dest}" --version 2>/dev/null))"
    return 0
}

# devcontainer CLI via a bun global install (the user asked for bun as the
# installer, not npm): idempotent presence probe, pinned package unless
# overridden. Runs with the fresh binary directly — ambient PATH may not
# have ~/.local/bin yet in this same run.
function _bun_devcontainer() {
    local package=${_DOT_DEVCONTAINER_PACKAGE:-'@devcontainers/cli@latest'}

    if _is_runnable devcontainer; then
        log_info "devcontainer $(devcontainer --version 2>/dev/null) already installed, skipping..."
        return 0
    fi

    local bun_bin
    bun_bin="$(_ensure_local_bin)/bun"
    if [[ ! -x "${bun_bin}" ]]; then
        log_warn 'bun binary missing; skipping devcontainer CLI install.'
        return 0
    fi

    # The devcontainer CLI is a Node script (#!/usr/bin/env node): ensure a
    # runtime exists, escalating only when it is actually missing.
    if ! command -v node >/dev/null 2>&1; then
        log_step 'Installing Node.js runtime (for the devcontainer CLI)'
        _install_packages 'nodejs'
    fi

    log_step "Installing devcontainer CLI (${package})"
    if ! "${bun_bin}" install --global "${package}" >/dev/null 2>&1; then
        log_error 'devcontainer CLI install failed.'
        return 1
    fi

    # `bun install --global` links binaries into the bun home's bin dir
    # (~/.bun/bin by default), which config/.custom.bashrc already puts on
    # PATH — accept that location as well as ~/.local/bin.
    local bun_home_bin="${BUN_INSTALL:-"${HOME}/.bun"}/bin/devcontainer"
    if [[ ! -x "$(_ensure_local_bin)/devcontainer" ]] \
        && [[ ! -x "${bun_home_bin}" ]] \
        && ! _is_installed devcontainer; then
        log_error 'devcontainer CLI install did not yield a devcontainer binary on PATH.'
        return 1
    fi
    log_ok 'devcontainer CLI installed'
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
