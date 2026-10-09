#!/usr/bin/env bash
#
# .xclip.utils.sh — clipboard helpers (X11 `xclip`).
#   clip   copy stdin → clipboard          (`xclip -sel clipboard`)
#   pclip  paste clipboard → stdout        (`xclip -sel clipboard -o`)
#   cclip  clear the clipboard
#   eclip  copy arguments as one line      (`eclip hello world`)
#   fclip  copy a file's contents

alias clip='xclip -sel clipboard'
alias pclip='xclip -sel clipboard -o'
alias cclip='xclip -sel clipboard < /dev/null'

eclip() {
    printf '%s\n' "$*" | xclip -sel clipboard
}

fclip() {
    local filename=${1:?'File name must be informed'}

    if [[ ! -f "${filename}" ]]; then
        echo "File '${filename}' does not exist" >&2
        return 1
    fi

    xclip -sel clipboard <"${filename}"
    return 0
}
