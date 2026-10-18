#!/usr/bin/env bash
#
# promptlib.sh — shared prompt collectors for the styles/* variants.
#
# Pure function definitions, silent on source, safe in non-interactive
# shells (no PROMPT_COMMAND registration here — each styles/prompt-*.sh
# variant registers its own). Plain bash only: no arrays of doom, no
# associative arrays (macOS ships bash 3.2), no external deps beyond git.

# __dottod_glyph <name>: prints the Nerd Font glyph for <name>, or an ASCII
# fallback when DOT_PROMPT_GLYPHS=ascii — or on bash before 4.2, whose
# printf has no \u escapes (the literal \u… would reach PS1, where \u is
# the user name). Keeps variant files readable.
# The hot path (every prompt) avoids `$(...)`: each helper has an `_r`
# form that leaves its result in REPLY, and a printing form that wraps it.
__dottod_glyph_r() {
    local name="${1:?glyph name required}"
    if [[ "${DOT_PROMPT_GLYPHS:-nerd}" == "ascii" ]] ||
        ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2))); then
        case "${name}" in
            sep_left) printf -v REPLY '>' ;;
            sep_right | sep_left_thin | sep_right_thin) printf -v REPLY '<' ;;
            branch) printf -v REPLY '' ;;
            folder) printf -v REPLY '' ;;
            user) printf -v REPLY '' ;;
            clock) printf -v REPLY '' ;;
            disk) printf -v REPLY '' ;;
            lang_*) printf -v REPLY '%s' "${name#lang_}" ;;
            os_*) printf -v REPLY '%s' "${name#os_}" ;;
            container) printf -v REPLY 'ctr' ;;
            prompt_char) printf -v REPLY '>' ;;
            *) printf -v REPLY '' ;;
        esac
        return 0
    fi
    case "${name}" in
        sep_left) printf -v REPLY '\ue0b0' ;;
        sep_right) printf -v REPLY '\ue0b2' ;;
        sep_left_thin) printf -v REPLY '\ue0b1' ;;
        sep_right_thin) printf -v REPLY '\ue0b3' ;;
        branch) printf -v REPLY '\ue0a0' ;;
        folder) printf -v REPLY '\uf07b' ;;
        user) printf -v REPLY '\uf007' ;;
        clock) printf -v REPLY '\uf017' ;;
        disk) printf -v REPLY '\uf0a0' ;;
        lang_node) printf -v REPLY '\ue718' ;;
        lang_rust) printf -v REPLY '\ue7a8' ;;
        lang_go) printf -v REPLY '\ue627' ;;
        lang_python) printf -v REPLY '\ue606' ;;
        lang_ruby) printf -v REPLY '\ue791' ;;
        lang_php) printf -v REPLY '\ue73d' ;;
        lang_java) printf -v REPLY '\ue738' ;;
        lang_bun) printf -v REPLY '\ue76f' ;;
        lang_deno) printf -v REPLY '\ue7c0' ;;
        lang_dotnet) printf -v REPLY '\ue77f' ;;
        cap_left) printf -v REPLY '\ue0b6' ;;
        cap_right) printf -v REPLY '\ue0b4' ;;
        fade) printf -v REPLY '░▒▓' ;;
        container) printf -v REPLY '\uf4b7' ;;
        prompt_char) printf -v REPLY '❯' ;;
        os_debian) printf -v REPLY '\uf306' ;;
        os_ubuntu) printf -v REPLY '\uf31b' ;;
        os_gentoo) printf -v REPLY '\uf30d' ;;
        os_arch) printf -v REPLY '\uf303' ;;
        os_fedora) printf -v REPLY '\uf30a' ;;
        os_alpine) printf -v REPLY '\uf300' ;;
        os_*) printf -v REPLY '\uf31a' ;;
        *) printf -v REPLY '' ;;
    esac
}

# __dottod_glyph <name>: prints it (for callers that can afford a subshell).
__dottod_glyph() {
    __dottod_glyph_r "$@"
    printf '%s' "${REPLY}"
}

# __dottod_ps_esc <text>: <text> made inert inside PS1. Bash decodes PS1's
# backslash escapes, then expands the result like a double-quoted string,
# so a `$`, backtick or backslash in untrusted text — a branch name chosen
# by whoever controls a remote, a directory inside a cloned repo — would
# run commands at every prompt. Each gets a backslash that survives the
# decoding. A character loop: ${t//…/…} replacements quote differently
# across bash 3.2 to 5.2 (patsub_replacement).
__dottod_ps_esc_r() {
    local t="${1}" out="" c i
    for ((i = 0; i < ${#t}; i++)); do
        c="${t:i:1}"
        case "${c}" in
            '\') out+='\\\\' ;;
            '$' | '`') out+="\\\\${c}" ;;
            *) out+="${c}" ;;
        esac
    done
    REPLY="${out}"
}

__dottod_ps_esc() {
    __dottod_ps_esc_r "$@"
    printf '%s' "${REPLY}"
}

# __dottod_find_git: the repo around $PWD without running git — walks up
# looking for `.git` (a directory, or a file for worktrees and submodules).
# Sets __DG_TOP and __DG_GD; fails outside a repo.
__dottod_find_git() {
    local d="${PWD}" l
    __DG_TOP=""
    __DG_GD=""
    while true; do
        if [[ -d "${d}/.git" ]]; then
            __DG_TOP="${d}"
            __DG_GD="${d}/.git"
            return 0
        elif [[ -f "${d}/.git" ]]; then
            IFS= read -r l <"${d}/.git" || true
            l="${l#gitdir: }"
            [[ "${l}" == /* ]] || l="${d}/${l}"
            __DG_TOP="${d}"
            __DG_GD="${l}"
            return 0
        fi
        [[ "${d}" == / || -z "${d}" ]] && return 1
        d="${d%/*}"
        [[ -z "${d}" ]] && d=/
    done
}

# __dottod_git_hidden: true when the repo's own config says
# `dottod.hide-dirty = 1` (read from the file: no git process).
__dottod_git_hidden() {
    local f="${__DG_GD}/config" line sect=""
    [[ -n "${__DG_GD}" ]] || return 1
    if [[ -r "${__DG_GD}/commondir" ]]; then
        IFS= read -r line <"${__DG_GD}/commondir" || true
        [[ "${line}" == /* ]] || line="${__DG_GD}/${line}"
        f="${line}/config"
    fi
    [[ -r "${f}" ]] || return 1
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        case "${line}" in
            '['*) sect="${line}" ;;
            hide-dirty*)
                [[ "${sect}" == '[dottod]' ]] || continue
                line="${line#hide-dirty}"
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line#=}"
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line%"${line##*[![:space:]]}"}"
                [[ "${line}" == 1 ]] && return 0
                ;;
        esac
    done <"${f}"
    return 1
}

# __dottod_git_state [nostatus]: the one git call of a prompt. Fills
# __DG_HEAD __DG_AHEAD __DG_BEHIND __DG_STAGED __DG_UNSTAGED __DG_UNTRACKED
# __DG_STASH __DG_UP from `git status --porcelain=v2 --branch` (no index
# locks); fails outside a repo or when git does. With `nostatus` the branch
# is read from HEAD and the counts stay 0 — no git process at all.
__dottod_git_state() {
    local line oid="" out ref
    __DG_HEAD=""
    __DG_UP=""
    __DG_AHEAD=0
    __DG_BEHIND=0
    __DG_STAGED=0
    __DG_UNSTAGED=0
    __DG_UNTRACKED=0
    __DG_STASH=0
    [[ -n "${__DG_GD}" ]] || return 1

    if [[ "${1:-}" == nostatus ]]; then
        IFS= read -r line <"${__DG_GD}/HEAD" || return 1
        case "${line}" in
            'ref: refs/heads/'*) __DG_HEAD="${line#'ref: refs/heads/'}" ;;
            *) return 1 ;;
        esac
        return 0
    fi

    out="$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --branch --untracked-files=normal --ignore-submodules=dirty 2>/dev/null)" || return 1
    while IFS= read -r line; do
        case "${line}" in
            '# branch.head '*) __DG_HEAD="${line#'# branch.head '}" ;;
            '# branch.oid '*) oid="${line#'# branch.oid '}" ;;
            '# branch.upstream '*) __DG_UP="${line#'# branch.upstream '}" ;;
            '# branch.ab +'*)
                line="${line#'# branch.ab +'}"
                __DG_AHEAD="${line%% *}"
                __DG_BEHIND="${line##* -}"
                ;;
            [12]' '*)
                line="${line:2:2}"
                [[ "${line:0:1}" != "." ]] && __DG_STAGED=$((__DG_STAGED + 1))
                [[ "${line:1:1}" != "." ]] && __DG_UNSTAGED=$((__DG_UNSTAGED + 1))
                ;;
            'u '*) __DG_STAGED=$((__DG_STAGED + 1)) ;;
            '? '*) __DG_UNTRACKED=$((__DG_UNTRACKED + 1)) ;;
        esac
    done <<<"${out}"

    if [[ "${__DG_HEAD}" == "(detached)" ]]; then
        __DG_HEAD="@${oid:0:7}"
    elif [[ -z "${__DG_HEAD}" ]]; then
        return 1
    fi
    # A branch with no upstream shows no .ab line: surface that as `local`.
    [[ -n "${__DG_UP}" ]] || __DG_UP="local"

    if [[ -s "${__DG_GD}/logs/refs/stash" ]]; then
        ref="$(wc -l <"${__DG_GD}/logs/refs/stash")"
        __DG_STASH="${ref//[[:space:]]/}"
    fi
    return 0
}

# __dottod_git_segments: the state as `branch|ahead|behind|staged|unstaged|
# untracked|stash|upstream` (empty and false outside a repo). Printing form
# of __dottod_git_state, kept for callers that can afford a subshell.
__dottod_git_segments() {
    __dottod_find_git || return 1
    __dottod_git_state || return 1
    printf '%s|%s|%s|%s|%s|%s|%s|%s' "${__DG_HEAD}" "${__DG_AHEAD}" "${__DG_BEHIND}" "${__DG_STAGED}" "${__DG_UNSTAGED}" "${__DG_UNTRACKED}" "${__DG_STASH}" "${__DG_UP}"
}

# __dottod_git_info_r: short git fragment for inline prompts, in REPLY.
# ` git:(branch) ✗` — empty outside a repo. Byte-identical to the original
# .custom.bashrc rendering for the default style. One git call (none when
# the repo hides its dirty mark); a detached HEAD asks git for a tag name.
__dottod_git_info_r() {
    local ref dirty="" mode=""
    REPLY=""
    __dottod_find_git || return 1
    __dottod_git_hidden && mode=nostatus
    if ! __dottod_git_state "${mode}"; then
        # Detached (or unreadable): the slow path names a tag or short hash.
        ref="$(git describe --tags --exact-match HEAD 2>/dev/null)" ||
            ref="$(git rev-parse --short HEAD 2>/dev/null)" ||
            return 1
        __DG_HEAD="${ref}"
    elif [[ "${__DG_HEAD}" == @* ]]; then
        ref="$(git describe --tags --exact-match HEAD 2>/dev/null)" && __DG_HEAD="${ref}" || __DG_HEAD="${__DG_HEAD#@}"
    fi
    if [[ -z "${mode}" ]] && ((__DG_STAGED + __DG_UNSTAGED + __DG_UNTRACKED > 0)); then
        dirty=' \[\e[33m\]✗'
    fi
    __dottod_ps_esc_r "${__DG_HEAD}"
    REPLY=' \[\e[1;34m\]git:(\[\e[0;31m\]'"${REPLY}"'\[\e[34m\])'"${dirty}"'\[\e[0m\]'
}

__dottod_git_info() {
    __dottod_git_info_r || return 1
    printf '%s' "${REPLY}"
}

# __dottod_project_dir_r: `project[/sub/path]` inside a repo, `~`/basename
# out, in REPLY. Call __dottod_find_git first (the prompt does, once).
__dottod_project_dir_r() {
    local dir="${PWD}" name sub
    if [[ -n "${__DG_TOP}" ]]; then
        name="${__DG_TOP##*/}"
        if [[ "${dir}" == "${__DG_TOP}" ]]; then
            REPLY="${name}"
        else
            sub="${dir#"${__DG_TOP}/"}"
            REPLY="${name}/${sub}"
        fi
    elif [[ "${dir}" == "${HOME:-/nonexistent}" ]]; then
        REPLY='~'
    else
        REPLY="${dir##*/}"
    fi
}

__dottod_project_dir() {
    __dottod_find_git || :
    __dottod_project_dir_r
    printf '%s' "${REPLY}"
}

# __dottod_lang_r: language key of the current project (`node`, `rust`, …)
# in REPLY, nearest marker file from $PWD up to the repo root; fails outside
# projects. Marker walk only — never invokes toolchains (prompt stays fast).
__dottod_lang_r() {
    local dir="${PWD}" top="${__DG_TOP:-${PWD}}" marker
    REPLY=""
    while true; do
        for marker in package.json Cargo.toml go.mod pyproject.toml setup.py requirements.txt Gemfile composer.json pom.xml; do
            if [[ -f "${dir}/${marker}" ]]; then
                case "${marker}" in
                    package.json) REPLY='node' ;;
                    Cargo.toml) REPLY='rust' ;;
                    go.mod) REPLY='go' ;;
                    pyproject.toml | setup.py | requirements.txt) REPLY='python' ;;
                    Gemfile) REPLY='ruby' ;;
                    composer.json) REPLY='php' ;;
                    pom.xml) REPLY='java' ;;
                esac
                return 0
            fi
        done
        [[ "${dir}" == "${top}" || "${dir}" == "/" || -z "${dir}" ]] && break
        dir="${dir%/*}"
        [[ -z "${dir}" ]] && dir=/
    done
    return 1
}

__dottod_lang() {
    __dottod_find_git || :
    __dottod_lang_r || return 1
    printf '%s' "${REPLY}"
}

# __dottod_disk_avail: free space on / in df -h form (`27G`); empty on error.
# Remembered for 30 s of shell time: it costs three processes.
__dottod_disk_avail_r() {
    local avail
    if [[ -n "${__DG_DISK:-}" ]] && ((SECONDS - __DG_DISK_AT < 30)); then
        REPLY="${__DG_DISK}"
        return 0
    fi
    avail="$(df -h / --output=avail 2>/dev/null | tail -n 1 | tr -d '[:space:]')" || return 1
    [[ -n "${avail}" && "${avail}" != "Avail" ]] || return 1
    __DG_DISK="${avail}"
    __DG_DISK_AT="${SECONDS}"
    REPLY="${avail}"
}

__dottod_disk_avail() {
    __dottod_disk_avail_r || return 1
    printf '%s' "${REPLY}"
}

# __dottod_duration <seconds>: `3s`, `2m 05s`, `1h 02m`.
__dottod_duration_r() {
    local total="${1:-0}" h m s
    h=$((total / 3600))
    m=$(((total % 3600) / 60))
    s=$((total % 60))
    if ((h > 0)); then
        printf -v REPLY '%dh %02dm' "${h}" "${m}"
    elif ((m > 0)); then
        printf -v REPLY '%dm %02ds' "${m}" "${s}"
    else
        printf -v REPLY '%ds' "${s}"
    fi
}

__dottod_duration() {
    __dottod_duration_r "$@"
    printf '%s' "${REPLY}"
}
