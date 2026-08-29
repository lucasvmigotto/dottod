#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _docker_install() {
    if _is_installed docker; then
        log_info 'docker already installed, skipping...'
        return 0
    fi

    local current_user codename arch keyrings_dir gpg_url
    current_user="$(id -un)"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")"
    arch="$(dpkg --print-architecture)"
    keyrings_dir='/etc/apt/keyrings'
    gpg_url='https://download.docker.com/linux/debian/gpg'

    _install_packages 'ca-certificates curl gnupg'

    _priv install -m 0755 -d "${keyrings_dir}"
    curl -fsSL "${gpg_url}" | _priv gpg --dearmor --yes -o "${keyrings_dir}/docker.gpg"
    _priv chmod a+r "${keyrings_dir}/docker.gpg"

    echo "deb [arch=${arch} signed-by=${keyrings_dir}/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" \
        | _priv tee /etc/apt/sources.list.d/docker.list >/dev/null

    _priv apt-get update -qq --yes >/dev/null 2>&1
    _priv apt-get install -qq --yes --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

    if ! groups "${current_user}" | grep -qw docker; then
        _priv usermod -aG docker "${current_user}"
        log_warn 'Added current user to the docker group. Log out and back in for it to take effect.'
    fi

    log_ok 'docker installed'
    return 0
}

function _main() {
    log_step 'Installing Docker'
    _docker_install
    return 0
}

_main "$@"
