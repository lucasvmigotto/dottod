#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

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

    local url tmp
    url="$(_github_asset_url "${repo}" "${pattern}")"
    tmp="$(mktemp)"

    log_step "Installing ${binary_name}"
    _download "${url}" "${tmp}"
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

    local url tmpdir extracted
    url="$(_github_asset_url "${repo}" "${pattern}")"
    tmpdir="$(mktemp -d)"

    log_step "Installing ${binary_name}"
    _download "${url}" "${tmpdir}/asset.tar.gz"
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

function _main() {
    local go_arch rust_arch
    go_arch="$(_go_arch)"
    rust_arch="$(_rust_arch)"

    log_step 'Installing CLI tools (apt)'
    _install_packages 'btop httpie chafa xclip bat jq curl tar ca-certificates'

    if ! _is_installed batcat && _is_installed bat; then
        ln -sf "$(command -v bat)" "$(_ensure_local_bin)/batcat"
        log_info 'Created batcat alias -> bat'
    fi

    _github_tarball_install 'jesseduffield/lazygit' 'lazygit' "Linux_${go_arch}.tar.gz"
    _github_tarball_install 'jesseduffield/lazydocker' 'lazydocker' "Linux_${go_arch}.tar.gz"
    _github_tarball_install 'derailed/k9s' 'k9s' "Linux_${rust_arch}.tar.gz"
    _github_binary_install 'unkn0wn-root/resterm' 'resterm' 'resterm_Linux_'

    log_ok 'Tools installed'
    return 0
}

_main "$@"
