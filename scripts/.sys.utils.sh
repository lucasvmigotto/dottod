#!/usr/bin/env bash

function mkcd() {

    mkdir -p "$1" \
        && cd "$1" || return 1

    return 0

}

function rulisten() {

    lsof -i :"$1"

    return 0

}

function fps() {
    ps aux \
        | grep -i "$1" \
        | grep -v grep
}

function fd() {

    find . -type d -iname "*$1*"

    return 0

}

function ff() {

    find . -type f -iname "*$1*"

    return 0

}

function topcmd() {

    local top_n=${1:-10}

    history \
        | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' \
        | grep -v "./" \
        | column -c3 -s " " -t \
        | sort -nr \
        | nl \
        | head -n "${top_n}"

    return 0

}
