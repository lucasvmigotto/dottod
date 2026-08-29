#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _main() {
    if _is_installed code; then
        log_info 'VSCode already installed, skipping...'
        return 0
    fi

    local arch keyrings_dir gpg_url
    arch="$(dpkg --print-architecture)"
    keyrings_dir='/etc/apt/keyrings'
    gpg_url='https://packages.microsoft.com/keys/microsoft.asc'

    _install_packages 'curl ca-certificates gnupg'

    _priv install -m 0755 -d "${keyrings_dir}"
    curl -fsSL "${gpg_url}" | _priv gpg --dearmor --yes -o "${keyrings_dir}/microsoft.gpg"
    _priv chmod a+r "${keyrings_dir}/microsoft.gpg"

    echo "deb [arch=${arch} signed-by=${keyrings_dir}/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | _priv tee /etc/apt/sources.list.d/vscode.list >/dev/null

    _priv apt-get update -qq --yes >/dev/null 2>&1
    _priv apt-get install -qq --yes code >/dev/null 2>&1

    log_ok 'VSCode installed'
    return 0
}

_main "$@"
