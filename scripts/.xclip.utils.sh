#!/usr/bin/env bash

alias clip='xclip -sel clipboard'

function eclip() {

    echo "$@" | clip

}

function fclip() {

    local filename
    filename=${1:?'File name must be informed'}

    if [[ ! -f "${filename}" ]]; then
        echo "File '${filename}' does not exists" >&2
        return 1
    fi

    cat "${filename}" | clip

    return 0

}
