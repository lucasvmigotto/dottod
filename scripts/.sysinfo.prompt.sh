#!/usr/bin/env zsh
#
# .sysinfo.prompt.sh — Spaceship `sysinfo` section (system metrics display).
#
# Auto-sourced by config/.custom.zshrc (scripts/*.sh glob) BEFORE oh-my-zsh
# loads, so this file must only define things — never call Spaceship APIs at
# source time. Registration happens post-omz via _dottod_sysinfo_register,
# which .custom.zshrc invokes explicitly.
#
# Display options (SPACESHIP_SYSINFO_* naming convention):
#   SPACESHIP_SYSINFO_SHOW    false to hide the section (default: true)
#   SPACESHIP_SYSINFO_COLOR   section color (default: cyan)
#   SPACESHIP_SYSINFO_SYMBOL  symbol shown before content (default: empty;
#                             the collector output already carries glyphs)
#   SPACESHIP_SYSINFO_PREFIX / _SUFFIX fall back to the prompt defaults.
#
# Collector behavior is tuned via _DOT_SYSTEM_INFO_* (see scripts/system-info.sh).

: "${_DOT_SYSTEM_INFO_ENABLED:=true}"
: "${SPACESHIP_SYSINFO_SHOW:=true}"
: "${SPACESHIP_SYSINFO_COLOR:=cyan}"
: "${SPACESHIP_SYSINFO_SYMBOL:=}"

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
        local -a section_args=(
            --color "${SPACESHIP_SYSINFO_COLOR-cyan}"
            --prefix "${SPACESHIP_SYSINFO_PREFIX-$SPACESHIP_PROMPT_DEFAULT_PREFIX}"
            --suffix "${SPACESHIP_SYSINFO_SUFFIX-$SPACESHIP_PROMPT_DEFAULT_SUFFIX}"
        )
        [[ -n "${SPACESHIP_SYSINFO_SYMBOL-}" ]] && section_args+=(--symbol "${SPACESHIP_SYSINFO_SYMBOL}")
        spaceship::section "${section_args[@]}" "${info}"
    else
        # Spaceship API unavailable (e.g. theme failed to load): plain output.
        print -r -- "${info} "
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
