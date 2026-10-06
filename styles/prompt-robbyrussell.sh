#!/usr/bin/env bash
#
# prompt-robbyrussell.sh — dottod default prompt (previous .custom.bashrc).
#   ➜  dirname git:(branch) ✗
#   - arrow is bold green if last command succeeded, bold red otherwise
#   - dir is cyan (basename only, like zsh %c)
#   - git:( bold blue, branch red, ) blue, ✗ yellow when dirty
#   - disable dirty check per repo: git config --local dottod.hide-dirty 1

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/promptlib.sh"

__dottod_prompt() {
    local last_status=$? # must be first line to capture $?
    local arrow

    if ((last_status == 0)); then
        arrow='\[\e[1;32m\]➜\[\e[0m\]'
    else
        arrow='\[\e[1;31m\]➜\[\e[0m\]'
    fi

    PS1="${arrow}  \[\e[36m\]\W\[\e[0m\]$(__dottod_git_info) "
    return $last_status
}

# Prepend to PROMPT_COMMAND without clobbering existing entries
case ";${PROMPT_COMMAND};" in
    *";__dottod_prompt;"*) ;;
    *) PROMPT_COMMAND="__dottod_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
