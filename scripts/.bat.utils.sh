#!/usr/bin/env bash

# bat is batcat on Debian; use whichever name this system has.
function _batcat_help() {
    local bat
    bat="$(command -v bat || command -v batcat)" || {
        cat
        return 0
    }
    "${bat}" --language help --style plain
}

function bhelp() {

    "$@" --help 2>&1 | _batcat_help

    return 0

}
