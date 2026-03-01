#!/usr/bin/env bash

function _power_giver() {

    if [[ $(which sudo) ]]; then
        echo "sudo"
    elif [[ $(which doas) ]]; then
        echo "doas"
    elif [[ "$1" == 'panic' ]]; then
        echo 'Neither `sudo` or `doas` installed. Install one of then and retry' >&2
        exit 1
    else
        echo '0'
    fi

}

function _install_packages() {

    local package_list=${1:?'Package list not provided'}

    if [[ -z $DEBIAN_FRONTEND ]]; then
        export DEBIAN_FRONTEND=noninteractive
    fi

    local my_power="$(_power_giver panic)"

    "${my_power}" apt-get update -qq --yes > /dev/null
    "${my_power}" apt-get install -qq --yes ${package_list// / } > /dev/null
    "${my_power}" rm -rf /var/lib/apt/lists/*

    return 0

}