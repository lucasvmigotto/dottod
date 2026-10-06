#!/usr/bin/env bash
#
# promptlib.sh — shared prompt collectors for the styles/* variants.
#
# Pure function definitions, silent on source, safe in non-interactive
# shells (no PROMPT_COMMAND registration here — each styles/prompt-*.sh
# variant registers its own). Plain bash only: no arrays of doom, no
# associative arrays (macOS ships bash 3.2), no external deps beyond git.

# __dottod_glyph <name>: prints the Nerd Font glyph for <name>, or an ASCII
# fallback when DOT_PROMPT_GLYPHS=ascii. Keeps variant files readable.
__dottod_glyph() {
    local name="${1:?glyph name required}"
    if [[ "${DOT_PROMPT_GLYPHS:-nerd}" == "ascii" ]]; then
        case "${name}" in
            sep_left | sep_right | sep_left_thin | sep_right_thin) printf '' ;;
            branch) printf '' ;;
            folder) printf '' ;;
            user) printf '' ;;
            clock) printf '' ;;
            disk) printf '' ;;
            lang_*) printf '%s' "${name#lang_}" ;;
            *) printf '' ;;
        esac
        return 0
    fi
    case "${name}" in
        sep_left) printf '\ue0b0' ;;
        sep_right) printf '\ue0b2' ;;
        sep_left_thin) printf '\ue0b1' ;;
        sep_right_thin) printf '\ue0b3' ;;
        branch) printf '\ue0a0' ;;
        folder) printf '\uf07b' ;;
        user) printf '\uf007' ;;
        clock) printf '\uf017' ;;
        disk) printf '\uf0a0' ;;
        lang_node) printf '\ue718' ;;
        lang_rust) printf '\ue7a8' ;;
        lang_go) printf '\ue627' ;;
        lang_python) printf '\ue606' ;;
        lang_ruby) printf '\ue791' ;;
        lang_php) printf '\ue73d' ;;
        lang_java) printf '\ue738' ;;
        *) printf '' ;;
    esac
}

# __dottod_git_info: short git fragment for inline prompts.
# ` git:(branch) ✗` — empty (and false) outside a repo. Kept byte-identical
# to the original .custom.bashrc rendering for the default style.
__dottod_git_info() {
    local ref
    ref=$(git symbolic-ref --short -q HEAD 2>/dev/null) \
        || ref=$(git describe --tags --exact-match HEAD 2>/dev/null) \
        || ref=$(git rev-parse --short HEAD 2>/dev/null) \
        || return

    local dirty=""
    if [[ $(git config --get dottod.hide-dirty 2>/dev/null) != 1 ]]; then
        if [[ -n $(git status --porcelain --ignore-submodules=dirty 2>/dev/null | head -n 1) ]]; then
            dirty=' \[\e[33m\]✗'
        fi
    fi

    printf '%s' ' \[\e[1;34m\]git:(\[\e[0;31m\]'"$ref"'\[\e[34m\])'"$dirty"'\[\e[0m\]'
}

# __dottod_git_segments: machine-friendly git state for segmented prompts.
# Prints `branch|ahead|behind|staged|unstaged|untracked|stash`; empty branch
# (and false) outside a repo. One `git status` call, no index locks.
__dottod_git_segments() {
    local gd
    gd="$(git rev-parse --absolute-git-dir 2>/dev/null)" || return 1

    local line head oid up
    local ahead behind staged unstaged untracked stash
    head=""
    oid=""
    up=""
    ahead=0
    behind=0
    staged=0
    unstaged=0
    untracked=0
    while IFS= read -r line; do
        case "${line}" in
            '# branch.head '*) head="${line#'# branch.head '}" ;;
            '# branch.oid '*) oid="${line#'# branch.oid '}" ;;
            '# branch.upstream '*) up="${line#'# branch.upstream '}" ;;
            '# branch.ab +'*)
                line="${line#'# branch.ab +'}"
                ahead="${line%% *}"
                behind="${line##* -}"
                ;;
            [12]' '*)
                line="${line:2:2}"
                [[ "${line:0:1}" != "." ]] && staged=$((staged + 1))
                [[ "${line:1:1}" != "." ]] && unstaged=$((unstaged + 1))
                ;;
            'u '*) staged=$((staged + 1)) ;;
            '? '*) untracked=$((untracked + 1)) ;;
        esac
    done < <(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --branch --untracked-files=normal 2>/dev/null) || return 1

    if [[ "${head}" == "(detached)" ]]; then
        head="@${oid:0:7}"
    elif [[ -z "${head}" ]]; then
        return 1
    fi
    # A branch with no upstream shows no .ab line: surface that as `local`.
    if [[ -z "${up}" ]]; then
        up="local"
    fi

    stash=0
    if [[ -s "${gd}/logs/refs/stash" ]]; then
        stash=$(wc -l <"${gd}/logs/refs/stash")
        stash="${stash//[[:space:]]/}"
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%s' "${head}" "${ahead}" "${behind}" "${staged}" "${unstaged}" "${untracked}" "${stash}" "${up}"
}

# __dottod_project_dir: `project[/sub/path]` inside a repo, `~`/basename out.
__dottod_project_dir() {
    local dir="${PWD}" top name sub
    if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        name="${top##*/}"
        if [[ "${dir}" == "${top}" ]]; then
            printf '%s' "${name}"
        else
            sub="${dir#"${top}/"}"
            printf '%s' "${name}/${sub}"
        fi
        return 0
    fi
    if [[ "${dir}" == "${HOME:-/nonexistent}" ]]; then
        printf '~'
    else
        printf '%s' "${dir##*/}"
    fi
}

# __dottod_lang: language key of the current project (`node`, `rust`, …),
# nearest marker file from $PWD up to the repo root; empty outside projects.
# Marker walk only — never invokes toolchains (prompt must stay fast).
__dottod_lang() {
    local dir="${PWD}" top marker
    if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        :
    else
        top="${PWD}"
    fi
    while true; do
        for marker in package.json Cargo.toml go.mod pyproject.toml setup.py requirements.txt Gemfile composer.json pom.xml; do
            if [[ -f "${dir}/${marker}" ]]; then
                case "${marker}" in
                    package.json) printf 'node' ;;
                    Cargo.toml) printf 'rust' ;;
                    go.mod) printf 'go' ;;
                    pyproject.toml | setup.py | requirements.txt) printf 'python' ;;
                    Gemfile) printf 'ruby' ;;
                    composer.json) printf 'php' ;;
                    pom.xml) printf 'java' ;;
                esac
                return 0
            fi
        done
        [[ "${dir}" == "${top}" || "${dir}" == "/" ]] && break
        dir="$(dirname "${dir}")"
    done
    return 1
}

# __dottod_disk_avail: free space on / in df -h form (`27G`); empty on error.
__dottod_disk_avail() {
    local avail
    avail="$(df -h / --output=avail 2>/dev/null | tail -n 1 | tr -d '[:space:]')" || return 1
    [[ -n "${avail}" && "${avail}" != "Avail" ]] || return 1
    printf '%s' "${avail}"
}

# __dottod_duration <seconds>: `3s`, `2m 05s`, `1h 02m`.
__dottod_duration() {
    local total="${1:-0}" h m s
    h=$((total / 3600))
    m=$(((total % 3600) / 60))
    s=$((total % 60))
    if ((h > 0)); then
        printf '%dh %02dm' "${h}" "${m}"
    elif ((m > 0)); then
        printf '%dm %02ds' "${m}" "${s}"
    else
        printf '%ds' "${s}"
    fi
}
