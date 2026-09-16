#!/usr/bin/env bash

function loadenv() {

    local env_file=${1:-'.env'}

    set -a
    eval "$(cat "${env_file}")"
    set +a

}
