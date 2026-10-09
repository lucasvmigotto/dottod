#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# Checksum for a release asset, mirroring bin/neovim.sh: the GitHub API
# exposes a `digest` per asset; print the sha256 hex or nothing when the
# API gives no usable digest (caller warns and proceeds as before).
function _github_asset_digest() {
    local repo=${1:?'GitHub repo (owner/name) must be informed'}
    local pattern=${2:?'Asset name pattern must be informed'}

    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | python3 -c '
import json, re, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
pat = re.compile(sys.argv[1])
for a in data.get("assets", []):
    if pat.search(a.get("name", "")):
        print((a.get("digest") or "").removeprefix("sha256:"))
        break
' "${pattern}" || true
}

# Verify a download when a digest exists; warn-and-proceed otherwise so a
# missing digest never breaks an install that worked before.
function _verify_download() {
    local file=${1:?'File must be informed'}
    local digest=${2:-}
    local label=${3:-'download'}

    if [[ -z "${digest}" ]]; then
        log_warn "No checksum published for ${label}; installing unverified."
        return 0
    fi

    local actual
    actual="$(sha256sum "${file}" | cut -d' ' -f1)"
    if [[ "${actual}" != "${digest}" ]]; then
        log_error "Checksum mismatch for ${label} (want ${digest}, got ${actual})."
        return 1
    fi
    return 0
}

function _github_binary_install() {
    local repo=${1:?'GitHub repo (owner/name) must be informed'}
    local binary_name=${2:?'Binary name must be informed'}
    local pattern=${3:?'Asset name pattern must be informed'}

    local local_bin dest
    local_bin="$(_ensure_local_bin)"
    dest="${local_bin}/${binary_name}"

    if _is_installed "${binary_name}" || [[ -x "${dest}" ]]; then
        log_info "${binary_name} already installed, skipping..."
        return 0
    fi

    local url tmp digest
    url="$(_github_asset_url "${repo}" "${pattern}")"
    digest="$(_github_asset_digest "${repo}" "${pattern}" || true)"
    tmp="$(mktemp)"

    log_step "Installing ${binary_name}"
    _download "${url}" "${tmp}"
    if ! _verify_download "${tmp}" "${digest}" "${binary_name}"; then
        rm -f "${tmp}"
        return 1
    fi
    install -m 0755 "${tmp}" "${dest}"
    rm -f "${tmp}"
    log_ok "${binary_name} installed"

    return 0
}

function _github_tarball_install() {
    local repo=${1:?'GitHub repo (owner/name) must be informed'}
    local binary_name=${2:?'Binary name must be informed'}
    local pattern=${3:?'Asset name pattern must be informed'}

    local local_bin dest
    local_bin="$(_ensure_local_bin)"
    dest="${local_bin}/${binary_name}"

    if _is_installed "${binary_name}" || [[ -x "${dest}" ]]; then
        log_info "${binary_name} already installed, skipping..."
        return 0
    fi

    local url tmpdir digest extracted
    url="$(_github_asset_url "${repo}" "${pattern}")"
    digest="$(_github_asset_digest "${repo}" "${pattern}" || true)"
    tmpdir="$(mktemp -d)"

    log_step "Installing ${binary_name}"
    _download "${url}" "${tmpdir}/asset.tar.gz"
    if ! _verify_download "${tmpdir}/asset.tar.gz" "${digest}" "${binary_name}"; then
        rm -rf "${tmpdir}"
        return 1
    fi
    tar -xzf "${tmpdir}/asset.tar.gz" -C "${tmpdir}"

    extracted="$(find "${tmpdir}" -type f -name "${binary_name}" | head -n1)"
    if [[ -z "${extracted}" ]]; then
        log_error "${binary_name} not found in downloaded archive"
        rm -rf "${tmpdir}"
        return 1
    fi

    install -m 0755 "${extracted}" "${dest}"
    rm -rf "${tmpdir}"
    log_ok "${binary_name} installed"

    return 0
}

function _github_cli_install() {
    # GitHub CLI from its official apt repository
    # (https://cli.github.com/manual/installation-linux).
    if _is_installed gh; then
        log_info 'gh already installed, skipping...'
        return 0
    fi

    local arch keyring tmp_key
    arch="$(dpkg --print-architecture)"
    keyring='/usr/share/keyrings/githubcli-archive-keyring.gpg'

    log_step 'Installing GitHub CLI prerequisites'
    _install_packages 'curl ca-certificates gnupg'

    # Download-then-install (never pipe a remote key straight into a
    # privileged command): a failed download must not produce a keyring.
    tmp_key="$(mktemp)"
    log_step 'Adding GitHub CLI apt repository'
    _download 'https://cli.github.com/packages/githubcli-archive-keyring.gpg' "${tmp_key}"
    _priv install -m 0644 "${tmp_key}" "${keyring}"
    rm -f "${tmp_key}"

    echo "deb [arch=${arch} signed-by=${keyring}] https://cli.github.com/packages stable main" |
        _priv tee /etc/apt/sources.list.d/github-cli.list >/dev/null

    log_step 'Installing GitHub CLI (gh)'
    _install_packages 'gh'

    if ! _is_installed gh; then
        log_error 'GitHub CLI install did not yield a gh binary on PATH.'
        return 1
    fi
    log_ok 'GitHub CLI installed'
    return 0
}

function _main() {
    local go_arch rust_arch
    go_arch="$(_go_arch)"
    rust_arch="$(_rust_arch)"

    log_step 'Installing CLI tools (apt)'
    _install_packages 'btop httpie chafa xclip bat jq curl tar ca-certificates lsof fzf'

    _github_cli_install

    if ! _is_installed batcat && _is_installed bat; then
        ln -sf "$(command -v bat)" "$(_ensure_local_bin)/batcat"
        log_info 'Created batcat alias -> bat'
    fi

    # NOTE: lazygit upstream names Linux assets lowercase (`linux_`);
    # lazydocker still uses `Linux_`. Patterns are per-repo on purpose.
    _github_tarball_install 'jesseduffield/lazygit' 'lazygit' "linux_${go_arch}.tar.gz"
    _github_tarball_install 'jesseduffield/lazydocker' 'lazydocker' "Linux_${go_arch}.tar.gz"
    _github_tarball_install 'derailed/k9s' 'k9s' "Linux_${rust_arch}.tar.gz"
    _github_binary_install 'unkn0wn-root/resterm' 'resterm' 'resterm_Linux_'

    log_ok 'Tools installed'
    return 0
}

_main "$@"
