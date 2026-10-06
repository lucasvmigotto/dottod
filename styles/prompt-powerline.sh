#!/usr/bin/env bash
#
# prompt-powerline.sh — segmented powerline prompt (Nerd Font).
#   user ▸ project/sub ▸ branch ▸ lang      3s ✓ ‹ 09:35 ‹ 27G
# Left blocks carry user, directory, git state and project language; the
# right cluster shows command duration, exit status, time and free disk.
# Needs a Nerd Font; DOT_PROMPT_GLYPHS=ascii degrades to plain text.
# Disk readout off with DOT_PROMPT_RESOURCES=0.

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/promptlib.sh"

__DOTTD_PW_PREV_SECONDS=0

# __dottod_pw_text <bg> <fg> <text>: one block's content (no separator yet).
__dottod_pw_text() {
    printf '\[\\e[48;5;%sm\\e[38;5;%sm\] %s ' "${1}" "${2}" "${3}"
}

# __dottod_pw_sep <bg> <next>: block separator, colored bg-on-next.
__dottod_pw_sep() {
    printf '\[\\e[48;5;%sm\\e[38;5;%sm\]%s' "${2}" "${1}" "$(__dottod_glyph sep_left)"
}

# __dottod_pw_end <bg>: closing separator on the default background.
__dottod_pw_end() {
    printf '\[\\e[38;5;%sm\]%s\[\\e[0m\]' "${1}" "$(__dottod_glyph sep_left)"
}

# __dottod_visible_len <ps1>: printable width (strips \[ \] and ANSI).
__dottod_visible_len() {
    local clean
    clean="$(printf '%s' "${1}" | sed -e 's/\\\[[^]]*\]//g' -e 's/\\e\[[0-9;]*m//g')"
    printf '%s' "${#clean}"
}

__dottod_prompt_powerline() {
    local last_status=$? # must be first line to capture $?
    local now dur
    now="${SECONDS}"
    dur=$((now - __DOTTD_PW_PREV_SECONDS))
    __DOTTD_PW_PREV_SECONDS="${now}"

    local user dir lname lglyph lang
    user="${USER:-$(id -un 2>/dev/null || printf 'user')}"
    dir="$(__dottod_project_dir)"
    if lname="$(__dottod_lang 2>/dev/null)"; then
        lglyph="$(__dottod_glyph "lang_${lname}")"
        if [[ -n "${lglyph}" ]]; then
            lang="${lglyph} ${lname}"
        else
            lang="${lname}"
        fi
    else
        lang=""
    fi

    # Left blocks as bg<US>fg<US>text (US = unit separator, cannot appear
    # in git refs); joined so each separator bridges into the next block.
    local US=$'\x1f'
    local -a segs=()
    segs+=("196${US}15${US}$(__dottod_glyph user) ${user}")
    segs+=("27${US}15${US}$(__dottod_glyph folder) ${dir}")

    local gitfields head ahead behind staged unstaged untracked stash _up
    local gittext gitbg
    gitbg="30"
    if gitfields="$(__dottod_git_segments 2>/dev/null)"; then
        IFS='|' read -r head ahead behind staged unstaged untracked stash _up <<<"${gitfields}"
        gittext="$(__dottod_glyph branch) ${head}"
        ((ahead > 0)) && gittext+=" ⇡${ahead}"
        ((behind > 0)) && gittext+=" ⇣${behind}"
        ((stash > 0)) && gittext+=" *${stash}"
        if ((staged + unstaged + untracked > 0)); then
            gittext+=" ✗"
            gitbg="172"
        fi
        segs+=("${gitbg}${US}15${US}${gittext}")
    fi
    [[ -n "${lang}" ]] && segs+=("129${US}15${US}${lang}")

    local left i bg fg text nbg
    left=""
    for ((i = 0; i < ${#segs[@]}; i++)); do
        IFS="${US}" read -r bg fg text <<<"${segs[i]}"
        left+="$(__dottod_pw_text "${bg}" "${fg}" "${text}")"
        if ((i + 1 < ${#segs[@]})); then
            nbg="${segs[i + 1]%%"${US}"*}"
            left+="$(__dottod_pw_sep "${bg}" "${nbg}")"
        else
            left+="$(__dottod_pw_end "${bg}")"
        fi
    done
    # Host stays out of the blocks (shown on demand via \h elsewhere).

    # Right cluster: duration, status, time, free disk.
    local right status_glyph time disk avail
    if ((last_status == 0)); then
        status_glyph='\[\e[1;32m\]✓'
    else
        status_glyph='\[\e[1;31m\]✗'
    fi
    time="$(date +%H:%M 2>/dev/null)"
    right="\[\e[38;5;14m\]$(__dottod_duration "${dur}") ${status_glyph}"
    right+=" \[\e[38;5;244m\]$(__dottod_glyph sep_right_thin) \[\e[38;5;15m\]${time} $(__dottod_glyph clock)"
    if [[ "${DOT_PROMPT_RESOURCES:-1}" == "1" ]] && avail="$(__dottod_disk_avail 2>/dev/null)"; then
        disk=" \[\e[38;5;244m\]$(__dottod_glyph sep_right_thin) \[\e[38;5;214m\]${avail} $(__dottod_glyph disk)"
        right+="${disk}"
    fi

    local cols pad gap
    cols="${COLUMNS:-80}"
    pad=$(($(__dottod_visible_len "${left}") + $(__dottod_visible_len "${right}")))
    gap=$((cols - pad - 1)) # -1 for the trailing space in PS1
    if ((gap >= 1)); then
        gap="$(printf '%*s' "${gap}" '')"
        PS1="${left}${gap}${right} "
    else
        PS1="${left}\n${right} "
    fi
    return $last_status
}

# Prepend to PROMPT_COMMAND without clobbering existing entries
case ";${PROMPT_COMMAND};" in
    *";__dottod_prompt_powerline;"*) ;;
    *) PROMPT_COMMAND="__dottod_prompt_powerline${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
