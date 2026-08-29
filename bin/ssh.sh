#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _ssh_dir() {
    local current_user=${1:?'User must be informed'}

    local ssh_dir="/home/${current_user}/.ssh"
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    echo "${ssh_dir}"
}

function _main() {
    local current_user ssh_dir
    current_user="$(id -un)"
    ssh_dir="$(_ssh_dir "${current_user}")"

    _link_file "${DOT_CONFIG_DIR}/.ssh.config" "${ssh_dir}/config"

    log_ok 'ssh config installed'
    return 0
}

_main "$@"
