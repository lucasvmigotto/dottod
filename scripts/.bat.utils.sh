#!/usr/bin/env bash

alias _batcat_help='batcat --language help --style plain'

function bhelp() {

    "$@" --help 2>&1 | _batcat_help

    return 0

}
