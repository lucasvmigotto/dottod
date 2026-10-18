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
# <text> is escaped: it carries directory and branch names.
__dottod_pw_text() {
    __dottod_ps_esc_r "${3}"
    printf -v REPLY '\[\\e[48;5;%sm\\e[38;5;%sm\] %s ' "${1}" "${2}" "${REPLY}"
}

# __dottod_pw_sep <bg> <next>: block separator, colored bg-on-next.
__dottod_pw_sep() {
    __dottod_glyph_r sep_left
    printf -v REPLY '\[\\e[48;5;%sm\\e[38;5;%sm\]%s' "${2}" "${1}" "${REPLY}"
}

# __dottod_pw_rblock <prev bg|""> <bg> <fg> <text>: one right-side block,
# opened by a filled left-pointing arrow (bg-on-prev, or on the default
# background for the first block) — the mirror of the left side.
__dottod_pw_rblock() {
    local sep
    __dottod_glyph_r sep_right
    if [[ -n "${1}" ]]; then
        printf -v sep '\[\\e[48;5;%sm\\e[38;5;%sm\]%s' "${1}" "${2}" "${REPLY}"
    else
        printf -v sep '\[\\e[0m\\e[38;5;%sm\]%s' "${2}" "${REPLY}"
    fi
    printf -v REPLY '%s\[\\e[48;5;%sm\\e[38;5;%sm\] %s ' "${sep}" "${2}" "${3}" "${4}"
}

# __dottod_pw_end <bg>: closing separator on the default background (reset
# first: drawn on the block's own background, the arrow would vanish).
__dottod_pw_end() {
    __dottod_glyph_r sep_left
    printf -v REPLY '\[\\e[0m\\e[38;5;%sm\]%s\[\\e[0m\]' "${1}" "${REPLY}"
}

# __dottod_visible_len <ps1>: printable width (strips \[ \] and ANSI), in
# REPLY. Pure bash: the markers are cut out piece by piece.
__dottod_visible_len() {
    local rest="${1}" out="" pre
    while [[ "${rest}" == *'\['* ]]; do
        pre="${rest%%'\['*}"
        out+="${pre}"
        rest="${rest#*'\['}"
        rest="${rest#*'\]'}"
    done
    out+="${rest}"
    # \e[…m sequences outside the markers (status glyph colors).
    rest="${out}"
    out=""
    while [[ "${rest}" == *'\e['* ]]; do
        out+="${rest%%'\e['*}"
        rest="${rest#*'\e['}"
        rest="${rest#*m}"
    done
    out+="${rest}"
    REPLY="${#out}"
}

__dottod_prompt_powerline() {
    local last_status=$? # must be first line to capture $?
    local now dur
    now="${SECONDS}"
    dur=$((now - __DOTTD_PW_PREV_SECONDS))
    __DOTTD_PW_PREV_SECONDS="${now}"

    __dottod_find_git || :
    local user dir lname lglyph lang
    user="${USER:-$(id -un 2>/dev/null || printf 'user')}"
    __dottod_project_dir_r
    dir="${REPLY}"
    lang=""
    if __dottod_lang_r; then
        lname="${REPLY}"
        __dottod_glyph_r "lang_${lname}"
        lglyph="${REPLY}"
        if [[ -n "${lglyph}" ]]; then
            lang="${lglyph} ${lname}"
        else
            lang="${lname}"
        fi
    fi

    # Left blocks as bg<US>fg<US>text (US = unit separator, cannot appear
    # in git refs); joined so each separator bridges into the next block.
    local US=$'\x1f'
    local -a segs=()
    __dottod_glyph_r user
    segs+=("196${US}15${US}${REPLY} ${user}")
    __dottod_glyph_r folder
    segs+=("27${US}15${US}${REPLY} ${dir}")

    local gittext gitbg
    gitbg="30"
    if __dottod_git_state; then
        __dottod_glyph_r branch
        gittext="${REPLY} ${__DG_HEAD}"
        ((__DG_AHEAD > 0)) && gittext+=" ⇡${__DG_AHEAD}"
        ((__DG_BEHIND > 0)) && gittext+=" ⇣${__DG_BEHIND}"
        ((__DG_STASH > 0)) && gittext+=" *${__DG_STASH}"
        if ((__DG_STAGED + __DG_UNSTAGED + __DG_UNTRACKED > 0)); then
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
        __dottod_pw_text "${bg}" "${fg}" "${text}"
        left+="${REPLY}"
        if ((i + 1 < ${#segs[@]})); then
            nbg="${segs[i + 1]%%"${US}"*}"
            __dottod_pw_sep "${bg}" "${nbg}"
        else
            __dottod_pw_end "${bg}"
        fi
        left+="${REPLY}"
    done
    # Host stays out of the blocks (shown on demand via \h elsewhere).

    # Right cluster, filled blocks like the left: duration + status, time,
    # free disk.
    local right status_glyph time
    if ((last_status == 0)); then
        status_glyph='\[\e[1;32m\]✓\[\e[22m\]'
    else
        status_glyph='\[\e[1;31m\]✗\[\e[22m\]'
    fi
    if ! printf -v time '%(%H:%M)T' -1 2>/dev/null; then
        time="$(date +%H:%M 2>/dev/null)"
    fi
    __dottod_duration_r "${dur}"
    __dottod_pw_rblock '' 240 14 "${REPLY} ${status_glyph}"
    right="${REPLY}"
    __dottod_glyph_r clock
    __dottod_pw_rblock 240 31 15 "${time} ${REPLY}"
    right+="${REPLY}"
    if [[ "${DOT_PROMPT_RESOURCES:-1}" == "1" ]] && __dottod_disk_avail_r 2>/dev/null; then
        time="${REPLY}"
        __dottod_glyph_r disk
        __dottod_pw_rblock 31 214 0 "${time} ${REPLY}"
        right+="${REPLY}"
    fi
    right+='\[\e[0m\]'

    local cols pad gap
    cols="${COLUMNS:-80}"
    __dottod_visible_len "${left}"
    pad="${REPLY}"
    __dottod_visible_len "${right}"
    pad=$((pad + REPLY))
    gap=$((cols - pad - 1)) # -1 for the trailing space in PS1
    if ((gap >= 1)); then
        printf -v gap '%*s' "${gap}" ''
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
