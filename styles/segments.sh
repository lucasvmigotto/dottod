#!/usr/bin/env bash
#
# segments.sh — the renderer behind the segmented themes (spec 018).
#
# A theme file (styles/prompt-<theme>.sh) only declares data, then calls
# __dottod_seg_register:
#   __DOTTOD_THEME_SEGS  "segment:bg:fg ..." in order (256-color codes);
#                        segments: os, user, osuser, dir, git, stack,
#                        containers, time
#   __DOTTOD_THEME_HEAD  none | cap (rounded) | fade (░▒▓)
#   __DOTTOD_THEME_SEP   arrow | round
#   __DOTTOD_THEME_TAIL  arrow | round
#
# A segment with nothing to say (no repo, no stack, no containers) folds:
# its text goes, its color stays as one separator.
#
# Slow facts never block the prompt: toolchain versions
# (DOT_PROMPT_VERSIONS=1) and this project's running containers
# (DOT_PROMPT_CONTAINERS=0 turns them off) come from a cache under
# ${XDG_CACHE_HOME:-~/.cache}/dottod/prompt, refreshed by a detached
# background job when stale.
#
# Plain bash, 3.2-compatible like promptlib.sh (no associative arrays).

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/promptlib.sh"

# ── time and cache ───────────────────────────────────────────────

__dottod_seg_now() {
    if [[ -n "${EPOCHSECONDS:-}" ]]; then
        printf '%s' "${EPOCHSECONDS}"
    elif printf '%(%s)T' -1 >/dev/null 2>&1; then
        printf '%(%s)T' -1
    else
        date +%s
    fi
}

# The cache dir in REPLY, created once per shell; fails when unusable.
__dottod_seg_cache_r() {
    local d="${XDG_CACHE_HOME:-${HOME}/.cache}/dottod/prompt"
    if [[ "${__DOTTOD_SEG_CACHE_OK:-}" != "${d}" ]]; then
        mkdir -p "${d}" 2>/dev/null && [[ -w "${d}" ]] || return 1
        __DOTTOD_SEG_CACHE_OK="${d}"
    fi
    REPLY="${d}"
}

__dottod_seg_cache() {
    __dottod_seg_cache_r || return 1
    printf '%s' "${REPLY}"
}

# djb2 of a string, for cache file names (no external process).
__dottod_seg_hash() {
    local s="${1}" h=5381 i c
    for ((i = 0; i < ${#s}; i++)); do
        printf -v c '%d' "'${s:i:1}"
        h=$(((h * 33 + c) & 2147483647))
    done
    printf '%s' "${h}"
}

# __dottod_seg_spawn <lock> <function> [args...]: run the function as a
# detached job (no job-control noise) unless another refresh holds <lock>.
# A lock older than a minute is from a job that died: taken over.
__dottod_seg_spawn() {
    local lock="${1}" now held
    shift
    now="${EPOCHSECONDS:-$(__dottod_seg_now)}"
    if ! (set -C && printf '%s' "${now}" >"${lock}") 2>/dev/null; then
        held="$(cat "${lock}" 2>/dev/null)"
        [[ "${held}" =~ ^[0-9]+$ ]] && ((now - held < 60)) && return 0
        printf '%s' "${now}" >"${lock}" 2>/dev/null || return 0
    fi
    ( (
        "$@"
        rm -f "${lock}"
    ) </dev/null >/dev/null 2>&1 &)
}

# __dottod_seg_cached_r <file> <ttl> <lock> <function> [args...]: the
# cached value, in REPLY (everything after the first line, which holds its epoch)
# and refreshes it in the background when missing or older than <ttl>.
__dottod_seg_cached_r() {
    local file="${1}" ttl="${2}" lock="${3}" stamp="" body="" nl="" line now
    shift 3
    if [[ -r "${file}" ]]; then
        {
            IFS= read -r stamp
            # The last line may lack a newline: keep it too.
            while IFS= read -r line || [[ -n "${line}" ]]; do
                body+="${nl}${line}"
                nl=$'\n'
            done
        } <"${file}"
    fi
    now="${EPOCHSECONDS:-$(__dottod_seg_now)}"
    if ! [[ "${stamp}" =~ ^[0-9]+$ ]] || ((now - stamp > ttl)); then
        __dottod_seg_spawn "${lock}" "$@"
    fi
    REPLY="${body}"
}

__dottod_seg_cached() {
    __dottod_seg_cached_r "$@"
    printf '%s' "${REPLY}"
}

# __dottod_seg_store <file> <command...>: run the command, store its output
# under a fresh epoch line (atomically).
__dottod_seg_store() {
    local file="${1}" tmp
    shift
    tmp="${file}.$$"
    {
        __dottod_seg_now
        printf '\n'
        "$@"
    } >"${tmp}" 2>/dev/null && mv -f "${tmp}" "${file}"
    rm -f "${tmp}"
}

# ── facts ────────────────────────────────────────────────────────

# Distribution id from os-release (read once per shell, never sourced), in
# REPLY.
__dottod_seg_os_id_r() {
    if [[ -z "${__DOTTOD_SEG_OS:-}" ]]; then
        local f="${_DOT_OS_RELEASE_FILE:-/etc/os-release}" k v id='linux'
        [[ -r "${f}" ]] || f='/usr/lib/os-release'
        if [[ -r "${f}" ]]; then
            while IFS='=' read -r k v; do
                [[ "${k}" == ID ]] || continue
                v="${v#[\"\']}"
                id="${v%[\"\']}"
            done <"${f}"
        fi
        __DOTTOD_SEG_OS="${id}"
    fi
    REPLY="${__DOTTOD_SEG_OS}"
}

__dottod_seg_os_id() {
    __dottod_seg_os_id_r
    printf '%s' "${REPLY}"
}

# Stacks at the nearest directory (from $PWD up to <top>) holding a marker,
# space-separated in REPLY: `node`, `bun python`, …
__dottod_seg_stacks_r() {
    local top="${1}" dir="${PWD}" found g
    REPLY=""
    while true; do
        found=''
        if [[ -f "${dir}/package.json" ]]; then
            if [[ -f "${dir}/bun.lock" || -f "${dir}/bun.lockb" ]]; then
                found+=' bun'
            else
                found+=' node'
            fi
        fi
        [[ -f "${dir}/deno.json" || -f "${dir}/deno.jsonc" ]] && found+=' deno'
        [[ -f "${dir}/Cargo.toml" ]] && found+=' rust'
        [[ -f "${dir}/go.mod" ]] && found+=' go'
        [[ -f "${dir}/pyproject.toml" || -f "${dir}/setup.py" || -f "${dir}/requirements.txt" ]] && found+=' python'
        [[ -f "${dir}/Gemfile" ]] && found+=' ruby'
        [[ -f "${dir}/composer.json" ]] && found+=' php'
        [[ -f "${dir}/pom.xml" || -f "${dir}/build.gradle" || -f "${dir}/build.gradle.kts" ]] && found+=' java'
        for g in "${dir}"/*.csproj "${dir}"/*.fsproj "${dir}"/*.sln "${dir}/global.json"; do
            if [[ -e "${g}" ]]; then
                found+=' dotnet'
                break
            fi
        done
        if [[ -n "${found}" ]]; then
            REPLY="${found# }"
            return 0
        fi
        [[ "${dir}" == "${top}" || "${dir}" == / || -z "${dir}" ]] && return 1
        dir="${dir%/*}"
        [[ -z "${dir}" ]] && dir=/
    done
}

__dottod_seg_stacks() {
    __dottod_seg_stacks_r "$@" || return 1
    printf '%s' "${REPLY}"
}

# A toolchain's version, probed in <root> (version managers read it).
__dottod_seg_version_probe() {
    local stack="${1}" root="${2}" out a b c tm=''
    command -v timeout >/dev/null 2>&1 && tm='timeout 5'
    cd "${root}" 2>/dev/null || return 0
    case "${stack}" in
        node) out="$(${tm} node --version)" ;;
        bun) out="$(${tm} bun --version)" ;;
        deno) out="$(${tm} deno --version)" ;;
        rust) out="$(${tm} rustc --version)" ;;
        go) out="$(${tm} go version)" ;;
        python) out="$(${tm} python3 --version 2>&1)" ;;
        ruby) out="$(${tm} ruby --version)" ;;
        php) out="$(${tm} php --version)" ;;
        java) out="$(${tm} java -version 2>&1)" ;;
        dotnet) out="$(${tm} dotnet --version)" ;;
        *) return 0 ;;
    esac || return 0
    out="${out%%$'\n'*}"
    read -r a b c _ <<<"${out}"
    case "${stack}" in
        node | bun | dotnet) out="${a}" ;;
        deno | rust | python | ruby | php) out="${b}" ;;
        go) out="${c#go}" ;;
        java)
            out="${out#*\"}"
            out="${out%%\"*}"
            ;;
    esac
    out="${out#v}"
    [[ "${out}" =~ ^[0-9][0-9A-Za-z.+_-]*$ ]] && printf '%s' "${out}"
}

# Cached version of <stack> for <root>, or nothing yet.
__dottod_seg_version() {
    local stack="${1}" root="${2}" cache key
    __dottod_seg_cache_r || return 0
    cache="${REPLY}"
    key="${stack}|${root}|${PATH}"
    if [[ "${__DOTTOD_SEG_VKEY:-}" != "${key}" ]]; then
        __DOTTOD_SEG_VKEY="${key}"
        __DOTTOD_SEG_VHASH="$(__dottod_seg_hash "${key}")"
    fi
    local file="${cache}/version-${stack}-${__DOTTOD_SEG_VHASH}"
    __dottod_seg_cached "${file}" 600 "${file}.lock" \
        __dottod_seg_store "${file}" __dottod_seg_version_probe "${stack}" "${root}"
}

# One line per running container: its compose working dir or devcontainer
# folder label (empty when it has neither).
__dottod_seg_containers_probe() {
    local tm=''
    command -v timeout >/dev/null 2>&1 && tm='timeout 5'
    ${tm} podman ps --format '{{index .Labels "com.docker.compose.project.working_dir"}}|{{index .Labels "devcontainer.local_folder"}}'
}

# How many running containers belong here: their compose or devcontainer
# folder is $PWD or one of its parents (the project you are in), never a
# directory below (/tmp is not every project under it).
__dottod_seg_containers_r() {
    local cache file list line a b n=0
    REPLY=""
    [[ "${DOT_PROMPT_CONTAINERS:-1}" == 1 ]] || return 0
    command -v podman >/dev/null 2>&1 || return 0
    __dottod_seg_cache_r || return 0
    cache="${REPLY}"
    file="${cache}/containers"
    __dottod_seg_cached_r "${file}" 10 "${file}.lock" \
        __dottod_seg_store "${file}" __dottod_seg_containers_probe
    list="${REPLY}"
    REPLY=""
    while IFS='|' read -r a b; do
        for line in "${a}" "${b}"; do
            if [[ -n "${line}" && ("${PWD}" == "${line}" || "${PWD}" == "${line%/}/"*) ]]; then
                n=$((n + 1))
                break
            fi
        done
    done <<<"${list}"
    ((n > 0)) && REPLY="${n}"
    return 0
}

__dottod_seg_containers() {
    __dottod_seg_containers_r
    printf '%s' "${REPLY}"
}

# ── render ───────────────────────────────────────────────────────

# __dottod_seg_text_r <segment> <top>: the segment's text (escaped for PS1)
# in REPLY, empty when it folds.
__dottod_seg_text_r() {
    local seg="${1}" top="${2}" t='' s v
    case "${seg}" in
        os)
            __dottod_seg_os_id_r
            __dottod_glyph_r "os_${REPLY}"
            t="${REPLY}"
            ;;
        user | osuser)
            if [[ -n "${USER:-}" ]]; then
                __dottod_ps_esc_r "${USER}"
            else
                __dottod_ps_esc_r "$(id -un 2>/dev/null)"
            fi
            t="${REPLY}"
            if [[ "${seg}" == osuser ]]; then
                __dottod_seg_os_id_r
                __dottod_glyph_r "os_${REPLY}"
            else
                __dottod_glyph_r user
            fi
            t="${REPLY} ${t}"
            ;;
        dir)
            __dottod_project_dir_r
            __dottod_ps_esc_r "${REPLY}"
            t="${REPLY}"
            ;;
        git)
            if ! __dottod_git_state; then
                REPLY=""
                return 0
            fi
            __dottod_glyph_r branch
            t="${REPLY}"
            __dottod_ps_esc_r "${__DG_HEAD}"
            t+=" ${REPLY}"
            ((__DG_AHEAD > 0)) && t+=" ⇡${__DG_AHEAD}"
            ((__DG_BEHIND > 0)) && t+=" ⇣${__DG_BEHIND}"
            ((__DG_STASH > 0)) && t+=" *${__DG_STASH}"
            ((__DG_STAGED + __DG_UNSTAGED + __DG_UNTRACKED > 0)) && t+=' ✗'
            ;;
        stack)
            if __dottod_seg_stacks_r "${top}"; then
                for s in ${REPLY}; do
                    [[ -n "${t}" ]] && t+=' '
                    __dottod_glyph_r "lang_${s}"
                    t+="${REPLY}"
                    if [[ "${DOT_PROMPT_VERSIONS:-0}" == 1 ]]; then
                        v="$(__dottod_seg_version "${s}" "${top}")"
                        if [[ -n "${v}" ]]; then
                            __dottod_ps_esc_r "${v}"
                            t+=" v${REPLY}"
                        fi
                    fi
                done
            fi
            ;;
        containers)
            __dottod_seg_containers_r
            if [[ -n "${REPLY}" ]]; then
                v="${REPLY}"
                __dottod_glyph_r container
                t="${REPLY} ${v}"
            fi
            ;;
        time)
            __dottod_glyph_r clock
            t="${REPLY} \\A"
            ;;
    esac
    REPLY="${t}"
}

__dottod_seg_text() {
    __dottod_find_git || :
    __dottod_seg_text_r "$@"
    printf '%s' "${REPLY}"
}

__dottod_seg_sep_r() {
    if [[ "${1}" == round ]]; then
        __dottod_glyph_r cap_right
    else
        __dottod_glyph_r sep_left
    fi
}

__dottod_prompt_segments() {
    local last_status=$? # must be first line to capture $?
    local top seg bg fg text out='' i n
    local -a segs=() bgs=() fgs=()
    __dottod_find_git || :
    top="${__DG_TOP:-${PWD}}"

    for seg in ${__DOTTOD_THEME_SEGS:-}; do
        IFS=: read -r seg bg fg <<<"${seg}"
        segs+=("${seg}")
        bgs+=("${bg}")
        fgs+=("${fg}")
    done
    n=${#segs[@]}
    ((n > 0)) || return "${last_status}"

    case "${__DOTTOD_THEME_HEAD:-none}" in
        cap)
            __dottod_glyph_r cap_left
            out+="\\[\\e[0m\\e[38;5;${bgs[0]}m\\]${REPLY}"
            ;;
        fade)
            __dottod_glyph_r fade
            out+="\\[\\e[0m\\e[38;5;${bgs[0]}m\\]${REPLY}"
            ;;
    esac
    for ((i = 0; i < n; i++)); do
        __dottod_seg_text_r "${segs[i]}" "${top}"
        text="${REPLY}"
        out+="\\[\\e[48;5;${bgs[i]}m\\e[38;5;${fgs[i]}m\\]"
        if [[ -n "${text}" ]]; then
            out+=" ${text} "
        elif [[ "${DOT_PROMPT_GLYPHS:-nerd}" == ascii ]]; then
            # Folded without separator glyphs: one colored space shows it.
            out+=' '
        fi
        if ((i + 1 < n)); then
            __dottod_seg_sep_r "${__DOTTOD_THEME_SEP:-arrow}"
            out+="\\[\\e[48;5;${bgs[i + 1]}m\\e[38;5;${bgs[i]}m\\]${REPLY}"
        else
            __dottod_seg_sep_r "${__DOTTOD_THEME_TAIL:-arrow}"
            out+="\\[\\e[0m\\e[38;5;${bgs[i]}m\\]${REPLY}\\[\\e[0m\\]"
        fi
    done

    # Second line: the duration of a slow command (PS0 stamps its start),
    # then the prompt character, green or red by the last status.
    local line2='' dur
    if [[ -n "${__dottod_seg_t0:-}" ]]; then
        dur=$((SECONDS - __dottod_seg_t0))
        if ((dur >= ${DOT_PROMPT_SLOW:-2})); then
            __dottod_duration_r "${dur}"
            line2+="\\[\\e[38;5;244m\\]took ${REPLY}\\[\\e[0m\\] "
        fi
        unset __dottod_seg_t0
    fi
    __dottod_glyph_r prompt_char
    if ((last_status == 0)); then
        line2+="\\[\\e[1;32m\\]${REPLY}\\[\\e[0m\\]"
    else
        line2+="\\[\\e[1;31m\\]${REPLY}\\[\\e[0m\\]"
    fi
    PS1="${out}\\n${line2} "
    return "${last_status}"
}

# Called by each theme file after declaring its data: registers the hook
# once, and stamps each command's start in PS0 (bash 4.4+; elsewhere no
# duration is shown). The stamp is a side effect of evaluating a substring
# offset; the substring itself is always empty. Bash skips the offset of an
# unset variable, so it slices a constant that is always set.
__DOTTOD_SEG_PS0='-'
__dottod_seg_register() {
    # shellcheck disable=SC2016 # expanded by bash at each command, not here
    local stamp='${__DOTTOD_SEG_PS0:$((__dottod_seg_t0 = SECONDS)):0}'
    case "${PS0:-}" in
        *__dottod_seg_t0*) ;;
        *) PS0="${PS0:-}${stamp}" ;;
    esac
    case ";${PROMPT_COMMAND:-};" in
        *";__dottod_prompt_segments;"*) ;;
        *) PROMPT_COMMAND="__dottod_prompt_segments${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
    esac
}
