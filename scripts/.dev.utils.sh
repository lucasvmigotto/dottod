#!/usr/bin/env bash

alias z='zed --existing .'

function loadenv() {

    local env_file=${1:-'.env'}

    if [[ ! -f "${env_file}" ]]; then
        echo "File ${env_file} not found" >&2
        return 1
    fi

    set -a
    eval "$(cat "${env_file}")"
    set +a

    return 0

}
