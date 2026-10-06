#!/usr/bin/env bash
#
# prompt-kali.sh — kali terminal style prompt (two lines).
#   ┌──(user㉿host)-[project/sub/path] git:(branch)
#   └─$
# Blue frame, green user (red for root), `#` mark for root, `$` otherwise
# (red when the last command failed). Git fragment is the shared one.

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/promptlib.sh"

__dottod_prompt_kali() {
    local last_status=$? # must be first line to capture $?
    local user host dir git
    user="${USER:-$(id -un 2>/dev/null || printf 'user')}"
    host="${HOSTNAME:-$(hostname -s 2>/dev/null || printf 'host')}"
    dir="$(__dottod_project_dir)"
    git="$(__dottod_git_info)"

    local blue='\[\e[1;34m\]'
    local ucolor='\[\e[1;32m\]'
    local mark='$'
    local mcolor="${blue}"
    if ((EUID == 0)); then
        ucolor='\[\e[1;31m\]'
        mark='#'
    fi
    if ((last_status != 0)); then
        mcolor='\[\e[1;31m\]'
    fi

    PS1="${blue}┌──(${ucolor}${user}${blue}㉿${blue}${host}${blue})-[${blue}${dir}${blue}]${git}\n${blue}└─${mcolor}${mark}\[\e[0m\] "
    return $last_status
}

# Prepend to PROMPT_COMMAND without clobbering existing entries
case ";${PROMPT_COMMAND};" in
    *";__dottod_prompt_kali;"*) ;;
    *) PROMPT_COMMAND="__dottod_prompt_kali${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
