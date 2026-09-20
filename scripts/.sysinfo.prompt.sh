#!/usr/bin/env zsh
# shellcheck disable=SC1071
#
# .sysinfo.prompt.sh — Spaceship `sysinfo` + `container` sections.
#
# `sysinfo`: system metrics display (see scripts/system-info.sh).
# `container`: selected container runtime token (see
#   scripts/.container.utils.sh). Both render via the Spaceship section API
#   and are strictly additive: no stock Spaceship section is touched.
#
# Auto-sourced by config/.custom.zshrc (scripts/*.sh glob) BEFORE oh-my-zsh
# loads, so this file must only define things — never call Spaceship APIs at
# source time. Registration happens post-omz via _dottod_*_register,
# which .custom.zshrc invokes explicitly.
#
# Display options (SPACESHIP_SYSINFO_* / SPACESHIP_CONTAINER_* convention):
#   SPACESHIP_SYSINFO_SHOW    false to hide the section (default: true)
#   SPACESHIP_SYSINFO_COLOR   section color (default: cyan)
#   SPACESHIP_SYSINFO_SYMBOL  symbol shown before content (default: empty;
#                             the collector output already carries glyphs)
#   SPACESHIP_SYSINFO_PREFIX / _SUFFIX fall back to the prompt defaults.
#   SPACESHIP_CONTAINER_SHOW  false to hide the runtime token (default: true)
#   SPACESHIP_CONTAINER_COLOR section color (default: cyan)
#   SPACESHIP_CONTAINER_PREFIX / _SUFFIX fall back to the prompt defaults.
#
# Collector behavior is tuned via _DOT_SYSTEM_INFO_* (see scripts/system-info.sh).
# _DOT_SYSTEM_INFO_ENABLED=false hides both sections.

: "${_DOT_SYSTEM_INFO_ENABLED:=true}"
: "${_DOT_SYSTEM_INFO_SHOW_MEM_PCT:=false}"
: "${_DOT_SYSTEM_INFO_SHOW_NET:=false}"

: "${SPACESHIP_SYSINFO_PREFIX:=[}"
: "${SPACESHIP_SYSINFO_SUFFIX:=]}"
: "${SPACESHIP_SYSINFO_SHOW:=true}"
: "${SPACESHIP_SYSINFO_COLOR:=cyan}"
: "${SPACESHIP_SYSINFO_SYMBOL:=}"
: "${SPACESHIP_CONTAINER_SHOW:=true}"
: "${SPACESHIP_CONTAINER_COLOR:=cyan}"
: "${SPACESHIP_CONTAINER_PREFIX:=[}"
: "${SPACESHIP_CONTAINER_SUFFIX:=]}"

: "${SPACESHIP_EXEC_TIME_SHOW:=true}"
: "${SPACESHIP_EXEC_TIME_THRESHOLD:=3}"
: "${SPACESHIP_EXEC_TIME_PREFIX:=[\U000F19A0 }"
: "${SPACESHIP_EXEC_TIME_SUFFIX:=]}"



# Nerd Font glyph (explicit code-point notation; Nerd Fonts 3.x MDI,
# verified against glyphnames.json): md-cube, runtime-agnostic on purpose
# (MDI ships a Docker whale but no Podman icon; the runtime name carries
# the meaning).
_DOT_CONTAINER_GLYPH=$'\U000F01A6 '

# Resolve the collector next to this file (<repo>/scripts/system-info.sh).
if [[ -z "${_DOT_SYSINFO_COLLECTOR:-}" ]]; then
    _DOT_SYSINFO_COLLECTOR="${${(%):-%N}:A:h}/system-info.sh"
fi

# Thin integration layer: Spaceship -> collector -> kernel interfaces.
# Best effort: any failure prints nothing and returns 0 (never break the prompt).
function spaceship_sysinfo() {
    [[ "${SPACESHIP_SYSINFO_SHOW-true}" == "false" ]] && return 0
    [[ "${_DOT_SYSTEM_INFO_ENABLED-true}" == "false" ]] && return 0

    local collector="${_DOT_SYSINFO_COLLECTOR:-}"
    [[ -n "${collector}" && -x "${collector}" ]] || return 0

    local info
    info="$("${collector}" 2>/dev/null)" || return 0
    [[ -n "${info}" ]] || return 0

    if (( $+functions[spaceship::section] )); then
        spaceship::section \
            --color "${SPACESHIP_SYSINFO_COLOR-cyan}" \
            --prefix "${SPACESHIP_SYSINFO_PREFIX-[}" \
            --suffix "${SPACESHIP_SYSINFO_SUFFIX-]}" \
            --symbol "${SPACESHIP_SYSINFO_SYMBOL-}" \
            "${info}"
    else
        print -r -- "[${info}]"
    fi

    return 0
}

# Thin integration layer: Spaceship -> selected runtime name.
# Cost is one shell function + tr (no probing, no subprocess of note), so
# prompt latency is unaffected. Best effort: prints nothing, returns 0.
function spaceship_container() {
    [[ "${SPACESHIP_CONTAINER_SHOW-true}" == "false" ]] && return 0
    [[ "${_DOT_SYSTEM_INFO_ENABLED-true}" == "false" ]] && return 0
    (( $+functions[_ctr_selected] )) || return 0

    local rt
    rt="$(_ctr_selected 2>/dev/null)" || return 0
    [[ -n "${rt}" ]] || return 0

    if (( $+functions[spaceship::section] )); then
        spaceship::section \
            --color "${SPACESHIP_CONTAINER_COLOR-cyan}" \
            --prefix "${SPACESHIP_CONTAINER_PREFIX-[}" \
            --suffix "${SPACESHIP_CONTAINER_SUFFIX-]}" \
            --symbol "${_DOT_CONTAINER_GLYPH}" \
            "${rt}"
    else
        print -r -- "[${_DOT_CONTAINER_GLYPH} ${rt}]"
    fi

    return 0
}

# Insert `sysinfo` at the end of the prompt's first line (before `line_sep`
# when present), without touching any other section. Idempotent: repeated
# calls never duplicate the entry; a user-defined order is respected.
function _dottod_sysinfo_register() {
    (( ${+SPACESHIP_PROMPT_ORDER} )) || return 0
    (( ${SPACESHIP_PROMPT_ORDER[(I)sysinfo]} == 0 )) || return 0

    if (( ${SPACESHIP_PROMPT_ORDER[(I)line_sep]} )); then
        SPACESHIP_PROMPT_ORDER=(
            ${SPACESHIP_PROMPT_ORDER[1,${SPACESHIP_PROMPT_ORDER[(I)line_sep]}-1]}
            sysinfo
            ${SPACESHIP_PROMPT_ORDER[${SPACESHIP_PROMPT_ORDER[(I)line_sep]},-1]}
        )
    else
        SPACESHIP_PROMPT_ORDER+=(sysinfo)
    fi
    return 0
}

# Insert `container` directly after `sysinfo` (falling back to the same
# line_sep rule), so the runtime token reads as part of the system display.
# Idempotent; user-defined orders respected.
function _dottod_container_register() {
    (( ${+SPACESHIP_PROMPT_ORDER} )) || return 0
    (( ${SPACESHIP_PROMPT_ORDER[(I)container]} == 0 )) || return 0

    if (( ${SPACESHIP_PROMPT_ORDER[(I)sysinfo]} )); then
        local _idx=${SPACESHIP_PROMPT_ORDER[(I)sysinfo]}
        local -a _tail=()
        if (( _idx < ${#SPACESHIP_PROMPT_ORDER[@]} )); then
            _tail=(${SPACESHIP_PROMPT_ORDER[_idx+1,-1]})
        fi
        SPACESHIP_PROMPT_ORDER=(
            ${SPACESHIP_PROMPT_ORDER[1,_idx]}
            container
            ${_tail[@]}
        )
        unset _idx _tail
    elif (( ${SPACESHIP_PROMPT_ORDER[(I)line_sep]} )); then
        SPACESHIP_PROMPT_ORDER=(
            ${SPACESHIP_PROMPT_ORDER[1,${SPACESHIP_PROMPT_ORDER[(I)line_sep]}-1]}
            container
            ${SPACESHIP_PROMPT_ORDER[${SPACESHIP_PROMPT_ORDER[(I)line_sep]},-1]}
        )
    else
        SPACESHIP_PROMPT_ORDER+=(container)
    fi
    return 0
}

# Move exec_time to the very end of line 1 (after sysinfo/container).
# Removal-then-reinsert makes this idempotent regardless of call order elsewhere.
function _dottod_exec_time_register() {
    (( ${+SPACESHIP_PROMPT_ORDER} )) || return 0

    local et_idx=${SPACESHIP_PROMPT_ORDER[(I)exec_time]}
    (( et_idx )) || return 0

    SPACESHIP_PROMPT_ORDER[et_idx]=()   # pull it out

    local ls_idx=${SPACESHIP_PROMPT_ORDER[(I)line_sep]}
    if (( ls_idx )); then
        SPACESHIP_PROMPT_ORDER=(
            ${SPACESHIP_PROMPT_ORDER[1,ls_idx-1]}
            exec_time
            ${SPACESHIP_PROMPT_ORDER[ls_idx,-1]}
        )
    else
        SPACESHIP_PROMPT_ORDER+=(exec_time)
    fi
    return 0
}
