#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_DOCKER_GPG_URL_DEFAULT='https://download.docker.com/linux/debian/gpg'
_DOT_DOCKER_REPO_URL_DEFAULT='https://download.docker.com/linux/debian'

function _docker_repo_configured() {
    local keyring=${1:?'Keyring must be informed'}
    local source_file=${2:?'Source file must be informed'}
    local repo_url=${3:?'Repo URL must be informed'}
    local codename=${4:?'Codename must be informed'}

    local arch want
    arch="$(dpkg --print-architecture)"
    want="deb [arch=${arch} signed-by=${keyring}] ${repo_url} ${codename} stable"

    [[ -f "${keyring}" ]] || return 1
    [[ -f "${source_file}" ]] || return 1
    grep -qxF "${want}" "${source_file}" 2>/dev/null
}

function _docker_install() {
    if _is_installed docker; then
        log_info 'docker already installed, skipping...'
        return 0
    fi

    local current_user codename arch keyrings_dir gpg_url repo_url source_file
    current_user="$(id -un)"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")"
    arch="$(dpkg --print-architecture)"
    keyrings_dir='/etc/apt/keyrings'
    gpg_url=${_DOT_DOCKER_GPG_URL:-"${_DOT_DOCKER_GPG_URL_DEFAULT}"}
    repo_url=${_DOT_DOCKER_REPO_URL:-"${_DOT_DOCKER_REPO_URL_DEFAULT}"}
    source_file='/etc/apt/sources.list.d/docker.list'

    _install_packages 'ca-certificates curl gnupg'

    if _docker_repo_configured "${keyrings_dir}/docker.gpg" "${source_file}" "${repo_url}" "${codename}"; then
        log_info 'Docker apt repository already configured, skipping...'
    else
        # Download-then-install (never pipe a remote key straight into a
        # privileged command): a failed download must not produce a keyring.
        local tmp_key
        tmp_key="$(mktemp)"
        log_step 'Adding Docker apt repository'
        _download "${gpg_url}" "${tmp_key}"
        _priv install -m 0755 -d "${keyrings_dir}"
        <"${tmp_key}" _priv gpg --dearmor --yes -o "${keyrings_dir}/docker.gpg"
        _priv chmod a+r "${keyrings_dir}/docker.gpg"
        rm -f "${tmp_key}"

        echo "deb [arch=${arch} signed-by=${keyrings_dir}/docker.gpg] ${repo_url} ${codename} stable" |
            _priv tee "${source_file}" >/dev/null

        _priv apt-get update -qq --yes >/dev/null 2>&1
    fi

    log_step 'Installing Docker'
    _priv apt-get install -qq --yes --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

    if ! groups "${current_user}" | grep -qw docker; then
        _priv usermod -aG docker "${current_user}"
        log_warn 'Added current user to the docker group. Log out and back in for it to take effect.'
    fi

    if ! _is_installed docker; then
        log_error 'Docker install did not yield a docker binary on PATH.'
        return 1
    fi

    log_ok 'docker installed'
    return 0
}

function _main() {
    log_step 'Installing Docker'
    _docker_install
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
