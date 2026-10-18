#!/usr/bin/env bash
#
# .claude-mv.sh — move a directory and bring its Claude Code sessions along
# (spec 021).
#
#   claude-mv [--dry-run] OLD NEW     mv OLD NEW, then repoint the sessions
#   claude-mv --fixup [--dry-run] OLD NEW
#                                      OLD was already moved to NEW by hand
#
# Claude Code ties a conversation to its directory in:
#   <store>/projects/<key>/      transcripts, session dirs, memory/ — <key>
#                                is the path, non-alphanumerics as '-'
#   transcript lines             "cwd":"<path>" (also in subdirectories)
#   <store>/history.jsonl        "project":"<path>" (prompt history)
#   <config>/.claude.json        projects["<path>"] (trust, tools, last
#                                session) and githubRepoPaths — one per
#                                profile, plus ~/.claude.json
# Sessions started in subdirectories of OLD move too. Only those path
# fields change: conversation text keeps the paths it mentions. dottod's
# codes visit list is repointed as well.
#
# Safety: refuses while a Claude Code process works inside OLD; copies
# every file it rewrites (and the project folders) to
# ${XDG_STATE_HOME:-~/.local/state}/dottod/claude-mv/<time>/ first; writes
# through a temporary file renamed into place.

# __dottod_mv_key <path>: Claude Code's projects/ folder name for a path.
__dottod_mv_key() {
    printf '%s' "${1//[^A-Za-z0-9]/-}"
}

# __dottod_mv_abs <path>: absolute, normalized, symlinks resolved where
# the path exists (realpath -m); fails on paths JSON would escape.
__dottod_mv_abs() {
    local p
    p="$(realpath -m -- "${1}" 2>/dev/null)" || p="$(__dottod_mv_realpath "${1}")" || return 1
    [[ "${p}" == /* && "${p}" != *[\"\\]* && "${p}" != *$'\n'* ]] || return 1
    printf '%s' "${p}"
}

# realpath -m for userlands without it (BusyBox): the path made absolute and
# lexically collapsed, its deepest existing directory resolved physically.
__dottod_mv_realpath() {
    local p="${1}" part rest='' base IFS=/
    [[ "${p}" == /* ]] || p="${PWD}/${p}"
    local -a out=()
    set -f
    for part in ${p}; do
        case "${part}" in
            '' | .) ;;
            ..) ((${#out[@]} > 0)) && unset "out[${#out[@]}-1]" ;;
            *) out+=("${part}") ;;
        esac
    done
    set +f
    p="/${out[*]}"
    while [[ ! -d "${p}" && "${p}" != / ]]; do
        rest="/${p##*/}${rest}"
        p="${p%/*}"
        [[ -n "${p}" ]] || p=/
    done
    base="$(cd -P -- "${p}" 2>/dev/null && pwd -P)" || return 1
    [[ "${base}" == / ]] && base=''
    p="${base}${rest}"
    printf '%s' "${p:-/}"
}

# __dottod_mv_prune <backups dir> <keep>: removes all but the newest <keep>
# timestamped backups (YYYYMMDD-HHMMSS, so name order is age order); other
# entries are left alone. A non-numeric or zero <keep> means the default, 5.
__dottod_mv_prune() {
    local dir="${1}" keep="${2}" d n=0
    [[ "${keep}" =~ ^[0-9]+$ ]] && ((keep > 0)) || keep=5
    local -a all=()
    for d in "${dir}"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]; do
        [[ -d "${d}" ]] && all+=("${d}")
    done
    n=${#all[@]}
    ((n > keep)) || return 0
    for d in "${all[@]:0:n-keep}"; do
        rm -rf -- "${d}"
    done
}

# __dottod_mv_under <path> <dir>: 0 when path is dir or inside it.
__dottod_mv_under() {
    [[ "${1}" == "${2}" || "${1}" == "${2}/"* ]]
}

# __dottod_mv_live <dir> [procdir]: pids of Claude Code processes (the
# claude binary or a versions/ build) working inside dir.
__dottod_mv_live() {
    local dir="${1}" procdir="${2:-/proc}" p pid exe cwd
    [[ -d "${procdir}" ]] || return 0
    for p in "${procdir}"/[0-9]*; do
        pid="${p##*/}"
        exe="$(readlink -- "${p}/exe" 2>/dev/null)" || continue
        [[ "${exe}" == */claude || "${exe}" == */claude/versions/* ]] || continue
        cwd="$(readlink -- "${p}/cwd" 2>/dev/null)" || continue
        __dottod_mv_under "${cwd}" "${dir}" && printf '%s\n' "${pid}"
    done
    return 0
}

# __dottod_mv_stores: every distinct projects/ root and history.jsonl,
# and every .claude.json (the default config, ~/.claude, each profile).
# Prints "<kind>\t<path>" lines; symlinked entries count once.
__dottod_mv_stores() {
    local c real
    local -A seen=()
    local -a configs=("${HOME}/.claude")
    while IFS= read -r c; do
        configs+=("${HOME}/.claude-${c}")
    done < <(__dottod_claude_profiles 2>/dev/null)
    for c in "${configs[@]}"; do
        if [[ -d "${c}/projects" ]]; then
            real="$(realpath -- "${c}/projects")"
            [[ -n "${seen[${real}]:-}" ]] || printf 'projects\t%s\n' "${real}"
            seen[${real}]=1
        fi
        if [[ -f "${c}/history.jsonl" ]]; then
            real="$(realpath -- "${c}/history.jsonl")"
            [[ -n "${seen[${real}]:-}" ]] || printf 'history\t%s\n' "${real}"
            seen[${real}]=1
        fi
        [[ -f "${c}/.claude.json" ]] && printf 'config\t%s\n' "${c}/.claude.json"
    done
    [[ -f "${HOME}/.claude.json" ]] && printf 'config\t%s\n' "${HOME}/.claude.json"
    return 0
}

# __dottod_claude_compat: do the Claude Code internals dottod reads still
# look the way it expects? Prints "ok <what>" / "warn <what>" lines (the
# first names the Claude Code version) and fails when any is a warn.
# Checked on the newest few transcripts, so it stays fast on big stores:
#   key      a projects/ folder is its path with non-alphanumerics as "-"
#   cwd      transcript lines carry a compact "cwd":"…" field
#   config   .claude.json keeps a "projects" object
#   usage    cachedUsageUtilization keeps five_hour/seven_day and fetchedAtMs
#   history  history.jsonl lines keep a "project" string
__dottod_claude_compat() {
    local kind path v bad=0 n sampled mism nocwd pretty f d key hit c cfg line
    v="$(command claude --version 2>/dev/null | head -n 1)"
    printf 'ok claude version: %s\n' "${v:-not on PATH (stores checked anyway)}"

    local -a roots=() hists=() cfgs=() files=()
    while IFS=$'\t' read -r kind path; do
        case "${kind}" in
            projects) roots+=("${path}") ;;
            history) hists+=("${path}") ;;
            config) cfgs+=("${path}") ;;
        esac
    done < <(__dottod_mv_stores)

    if ((${#roots[@]} == 0)); then
        echo 'ok no saved sessions yet (nothing to compare)'
    else
        # The newest 20 non-empty transcripts across the stores.
        for path in "${roots[@]}"; do
            while IFS= read -r f; do
                [[ -s "${f}" ]] && files+=("${f}")
            done < <(ls -t "${path}"/*/*.jsonl 2>/dev/null | head -n 20)
        done
        sampled=${#files[@]}
        mism=0 nocwd=0 pretty=0
        for f in "${files[@]}"; do
            d="${f%/*}"
            key="${d##*/}"
            hit=0
            if grep -q '"cwd":"' "${f}" 2>/dev/null; then
                while IFS= read -r c; do
                    [[ "$(__dottod_mv_key "${c}")" == "${key}" ]] && hit=1 && break
                done < <(grep -oh '"cwd":"[^"]*"' "${f}" 2>/dev/null | sort -u | sed 's/^"cwd":"//; s/"$//')
                ((hit == 1)) || mism=$((mism + 1))
            elif grep -q '"cwd" *: *"' "${f}" 2>/dev/null; then
                pretty=$((pretty + 1))
            else
                nocwd=$((nocwd + 1))
            fi
        done
        if ((sampled == 0)); then
            echo 'ok no transcripts yet (nothing to compare)'
        else
            if ((pretty * 2 > sampled)); then
                echo "warn transcripts are pretty-printed (${pretty}/${sampled}): the cwd rewrite would miss them"
                bad=1
            elif ((nocwd * 2 > sampled)); then
                echo "warn no \"cwd\" field in ${nocwd}/${sampled} recent transcripts (renamed?)"
                bad=1
            else
                echo "ok transcripts carry a compact cwd (${sampled} checked)"
            fi
            if ((mism * 2 > sampled)); then
                echo "warn project folder names are not the path with non-alphanumerics as '-' (${mism}/${sampled}): hashed keys?"
                bad=1
            else
                echo 'ok project folders follow the path-key rule'
            fi
        fi
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo 'warn jq missing: .claude.json and usage checks skipped'
        bad=1
    else
        n=0 mism=0
        for cfg in "${cfgs[@]}"; do
            n=$((n + 1))
            jq -e '(.projects // {}) | type == "object"' "${cfg}" >/dev/null 2>&1 || mism=$((mism + 1))
        done
        if ((mism > 0)); then
            echo "warn .claude.json: \"projects\" is not an object in ${mism}/${n} file(s)"
            bad=1
        else
            echo "ok .claude.json keeps its projects map (${n} file(s))"
        fi
        n=0 mism=0
        for cfg in "${cfgs[@]}"; do
            jq -e 'has("cachedUsageUtilization")' "${cfg}" >/dev/null 2>&1 || continue
            n=$((n + 1))
            jq -e '.cachedUsageUtilization | (.fetchedAtMs | type == "number") and (.utilization | type == "object") and (.utilization | has("five_hour") and has("seven_day"))' "${cfg}" >/dev/null 2>&1 || mism=$((mism + 1))
        done
        if ((mism > 0)); then
            echo "warn usage cache changed shape in ${mism}/${n} file(s): the panel bars may be empty"
            bad=1
        elif ((n > 0)); then
            echo "ok usage cache shape (${n} file(s))"
        fi
        mism=0 n=0
        for path in "${hists[@]}"; do
            line="$(tail -n 1 "${path}" 2>/dev/null)"
            [[ -n "${line}" ]] || continue
            n=$((n + 1))
            printf '%s\n' "${line}" | jq -e '.project | type == "string"' >/dev/null 2>&1 || mism=$((mism + 1))
        done
        if ((mism > 0)); then
            echo "warn history.jsonl lost its \"project\" field in ${mism}/${n} file(s)"
            bad=1
        elif ((n > 0)); then
            echo "ok history.jsonl keeps its project field (${n} file(s))"
        fi
    fi
    return "${bad}"
}

# __dottod_mv_folders <projects root> <old>: the folders that belong to
# old or a directory inside it, as "<folder>\t<path it was started in>".
# A key is lossy (/a/b and /a/b-c both start "-a-b"), so a folder counts
# only when one of its transcripts' cwd values maps back to its key; a
# folder with no transcripts counts on an exact key match only.
__dottod_mv_folders() {
    local root="${1}" old="${2}" okey f key p found
    okey="$(__dottod_mv_key "${old}")"
    for f in "${root}/${okey}" "${root}/${okey}"-*; do
        [[ -d "${f}" ]] || continue
        key="${f##*/}"
        found=""
        while IFS= read -r p; do
            __dottod_mv_under "${p}" "${old}" || continue
            [[ "$(__dottod_mv_key "${p}")" == "${key}" ]] && found="${p}" && break
        done < <(find "${f}" -name '*.jsonl' -type f -exec grep -oh '"cwd":"[^"]*"' {} + 2>/dev/null |
            sort -u | sed 's/^"cwd":"//; s/"$//')
        if [[ -z "${found}" && "${key}" == "${okey}" ]] &&
            [[ -z "$(find "${f}" -name '*.jsonl' -type f -print -quit 2>/dev/null)" ]]; then
            found="${old}"
        fi
        [[ -n "${found}" ]] && printf '%s\t%s\n' "${f}" "${found}"
    done
    return 0
}

# __dottod_mv_prefix <file> <field> <old> <new>: rewrites "field":"old"
# and "field":"old/..." to new in a JSON-lines file (a literal match on
# the compact form Claude Code writes; nothing else on the line changes).
# Prints how many lines changed; the file is replaced only when some did.
__dottod_mv_prefix() {
    local file="${1}" field="${2}" old="${3}" new="${4}" tmp n
    tmp="${file}.claude-mv.$$"
    n="$(awk -v a="\"${field}\":\"${old}" -v b="\"${field}\":\"${new}" -v out="${tmp}" '
        function swap(s,    i, r, c, done) {
            r = ""
            while ((i = index(s, a)) > 0) {
                c = substr(s, i + length(a), 1)
                if (c == "\"" || c == "/") { r = r substr(s, 1, i - 1) b; done = 1 }
                else r = r substr(s, 1, i - 1 + length(a))
                s = substr(s, i + length(a))
            }
            if (done) changed++
            return r s
        }
        { print swap($0) > out }
        END { close(out); print changed + 0 }' "${file}")" || {
        rm -f -- "${tmp}"
        return 1
    }
    if ((n > 0)); then
        chmod --reference="${file}" -- "${tmp}" 2>/dev/null || chmod 600 -- "${tmp}"
        mv -f -- "${tmp}" "${file}" || return 1
    else
        rm -f -- "${tmp}"
    fi
    printf '%s' "${n}"
}

# __dottod_mv_config <file> <old> <new> [dry]: repoints projects keys and
# githubRepoPaths in one .claude.json (an entry already under the new
# path is kept). Prints how many entries changed.
__dottod_mv_config() {
    local file="${1}" old="${2}" new="${3}" dry="${4:-}" n tmp
    command -v jq >/dev/null 2>&1 || {
        echo "claude-mv: jq is needed to update ${file}" >&2
        return 1
    }
    # shellcheck disable=SC2016 # jq program
    local prog='
        def mv: if . == $o then $n elif startswith($o + "/") then $n + .[($o | length):] else . end;
        def keys_under: [(.projects // {} | keys[]), (.githubRepoPaths // {} | .[] | .[]?)]
            | map(select(. == $o or startswith($o + "/"))) | length;'
    n="$(jq -r --arg o "${old}" --arg n "${new}" "${prog}"' keys_under' "${file}" 2>/dev/null)" || {
        echo "claude-mv: cannot read ${file}" >&2
        return 1
    }
    if [[ -z "${dry}" ]] && ((n > 0)); then
        tmp="${file}.claude-mv.$$"
        jq --arg o "${old}" --arg n "${new}" "${prog}"'
            (if .projects then .projects |= (to_entries
                | (map(select((.key | mv) == .key)) + map(select((.key | mv) != .key)))
                | reduce .[] as $e ({}; ($e.key | mv) as $k | if has($k) then . else .[$k] = $e.value end))
            else . end)
            | (if .githubRepoPaths then .githubRepoPaths |= map_values(map(mv) | unique) else . end)
        ' "${file}" >"${tmp}" 2>/dev/null && [[ -s "${tmp}" ]] || {
            rm -f -- "${tmp}"
            echo "claude-mv: could not update ${file}" >&2
            return 1
        }
        chmod 600 -- "${tmp}"
        mv -f -- "${tmp}" "${file}" || return 1
    fi
    printf '%s' "${n}"
}

claude-mv() {
    local fixup=0 dry=0 force=0
    local -a args=()
    while (($# > 0)); do
        case "${1}" in
            --fixup) fixup=1 ;;
            --dry-run | -n) dry=1 ;;
            --force) force=1 ;;
            -h | --help)
                cat <<'EOF'
usage: claude-mv [--dry-run] [--force] OLD NEW  move OLD to NEW and its Claude sessions with it
       claude-mv --fixup [--dry-run] OLD NEW  OLD was already moved to NEW: repoint the sessions

Repoints, for OLD and every directory inside it: the projects/ folders
(transcripts, memory), the cwd of each transcript line, the prompt
history, and every profile's .claude.json (plus ~/.claude.json); also the
codes visit list. Conversation text is left as written. Refuses while a
Claude Code session works inside OLD; backs up what it rewrites first.
First checks that the stores still look the way claude-mv expects
(dottod-doctor lists them) and refuses otherwise, unless --force.
EOF
                return 0
                ;;
            -*)
                echo "claude-mv: unknown option ${1}" >&2
                return 2
                ;;
            *) args+=("${1}") ;;
        esac
        shift
    done
    if ((${#args[@]} != 2)); then
        echo 'usage: claude-mv [--fixup] [--dry-run] [--force] OLD NEW' >&2
        return 2
    fi
    local old new
    old="$(__dottod_mv_abs "${args[0]}")" && new="$(__dottod_mv_abs "${args[1]}")" || {
        echo 'claude-mv: paths must be plain absolute-able paths (no quotes, backslashes or newlines)' >&2
        return 2
    }
    [[ "${old}" != / && "${new}" != / ]] || {
        echo 'claude-mv: refusing to move /' >&2
        return 2
    }
    if __dottod_mv_under "${new}" "${old}"; then
        echo "claude-mv: ${new} is ${old} or inside it" >&2
        return 2
    fi
    if ((fixup)); then
        [[ ! -e "${old}" ]] || {
            echo "claude-mv: --fixup: ${old} still exists (drop --fixup to move it)" >&2
            return 1
        }
        [[ -d "${new}" ]] || {
            echo "claude-mv: --fixup: ${new} is not a directory" >&2
            return 1
        }
    else
        [[ -d "${old}" ]] || {
            echo "claude-mv: ${old} is not a directory (already moved? use --fixup)" >&2
            return 1
        }
        [[ ! -e "${new}" ]] || {
            echo "claude-mv: ${new} already exists" >&2
            return 1
        }
        [[ -d "$(dirname -- "${new}")" ]] || {
            echo "claude-mv: $(dirname -- "${new}") does not exist" >&2
            return 1
        }
    fi
    local live
    # After a move by hand a live session shows the new path.
    live="$({
        __dottod_mv_live "${old}"
        ((fixup)) && __dottod_mv_live "${new}"
    } | sort -u | paste -sd' ' -)"
    if [[ -n "${live}" ]]; then
        printf 'claude-mv: Claude Code is running inside %s (pid %s); exit it first\n' "$( ((fixup)) && echo "${new}" || echo "${old}")" "${live}" >&2
        return 1
    fi

    local compat
    if ! compat="$(__dottod_claude_compat)"; then
        grep '^warn ' <<<"${compat}" | sed 's/^warn /claude-mv: /' >&2
        if ((force)); then
            echo 'claude-mv: --force: going on anyway' >&2
        else
            echo 'claude-mv: the stores do not look the way this claude-mv expects; refusing (--force overrides)' >&2
            return 1
        fi
    fi

    # The plan.
    local kind path folder started dest n total=0
    local -a folders=() histories=() configs=()
    while IFS=$'\t' read -r kind path; do
        case "${kind}" in
            projects)
                while IFS=$'\t' read -r folder started; do
                    folders+=("${folder}"$'\t'"${started}")
                done < <(__dottod_mv_folders "${path}" "${old}")
                ;;
            history) histories+=("${path}") ;;
            config) configs+=("${path}") ;;
        esac
    done < <(__dottod_mv_stores)
    local visits="${XDG_STATE_HOME:-${HOME}/.local/state}/codes/visits"

    ((dry)) && echo "claude-mv: dry run — nothing changes"
    if ((fixup)); then
        printf 'directory: already at %s\n' "${new}"
    else
        printf 'directory: %s -> %s\n' "${old}" "${new}"
    fi
    for folder in "${folders[@]}"; do
        started="${folder#*$'\t'}"
        folder="${folder%%$'\t'*}"
        dest="$(dirname -- "${folder}")/$(__dottod_mv_key "${new}${started#"${old}"}")"
        printf 'sessions:  %s -> %s%s\n' "${folder##*/}" "${dest##*/}" "$([[ -e "${dest}" ]] && echo ' (merged)')"
    done
    ((${#folders[@]} > 0)) || echo 'sessions:  none saved under it'
    for path in "${histories[@]}"; do
        n="$(grep -cF -e "\"project\":\"${old}\"" -e "\"project\":\"${old}/" "${path}" 2>/dev/null)"
        printf 'history:   %s line(s) in %s\n' "${n:-0}" "${path/#"${HOME}"/\~}"
    done
    for path in "${configs[@]}"; do
        n="$(__dottod_mv_config "${path}" "${old}" "${new}" dry)" || return 1
        printf 'config:    %s entr%s in %s\n' "${n}" "$( ((n == 1)) && echo y || echo ies)" "${path/#"${HOME}"/\~}"
    done
    if [[ -f "${visits}" ]]; then
        n="$(awk -F'\t' -v o="${old}" '$2 == o || index($2, o "/") == 1 { c++ } END { print c + 0 }' "${visits}")"
        printf 'codes:     %s visit(s)\n' "${n}"
    fi
    ((dry)) && return 0

    # Backup, then the move, then the records.
    local backup
    backup="${XDG_STATE_HOME:-${HOME}/.local/state}/dottod/claude-mv/$(date +%Y%m%d-%H%M%S)"
    mkdir -p -- "${backup}" && chmod 700 -- "${backup}" || {
        echo "claude-mv: cannot create the backup in ${backup}" >&2
        return 1
    }
    for folder in "${folders[@]}"; do
        folder="${folder%%$'\t'*}"
        cp -a -- "${folder}" "${backup}/" || return 1
    done
    for path in "${histories[@]}" "${configs[@]}"; do
        cp -a -- "${path}" "${backup}/$(__dottod_mv_key "${path}")" || return 1
    done
    [[ -f "${visits}" ]] && cp -a -- "${visits}" "${backup}/codes-visits"

    if ((!fixup)); then
        mv -- "${old}" "${new}" || {
            echo "claude-mv: mv failed; nothing else changed (backup: ${backup})" >&2
            return 1
        }
    fi
    local f
    for folder in "${folders[@]}"; do
        started="${folder#*$'\t'}"
        folder="${folder%%$'\t'*}"
        dest="$(dirname -- "${folder}")/$(__dottod_mv_key "${new}${started#"${old}"}")"
        while IFS= read -r -d '' f; do
            n="$(__dottod_mv_prefix "${f}" cwd "${old}" "${new}")" || {
                echo "claude-mv: could not rewrite ${f} (backup: ${backup})" >&2
                return 1
            }
            total=$((total + n))
        done < <(find "${folder}" -name '*.jsonl' -type f -print0)
        if [[ -e "${dest}" ]]; then
            __dottod_claude_merge_dir "${folder}" "${dest}" claude-mv || {
                echo "claude-mv: could not merge into ${dest} (backup: ${backup})" >&2
                return 1
            }
        else
            mv -- "${folder}" "${dest}" || return 1
        fi
    done
    for path in "${histories[@]}"; do
        __dottod_mv_prefix "${path}" project "${old}" "${new}" >/dev/null || return 1
    done
    for path in "${configs[@]}"; do
        __dottod_mv_config "${path}" "${old}" "${new}" >/dev/null || return 1
    done
    if [[ -f "${visits}" ]]; then
        awk -F'\t' -v OFS='\t' -v o="${old}" -v n="${new}" '
            $2 == o { $2 = n } index($2, o "/") == 1 { $2 = n substr($2, length(o) + 1) } { print }
        ' "${visits}" >"${visits}.claude-mv.$$" && mv -f -- "${visits}.claude-mv.$$" "${visits}"
    fi
    printf 'claude-mv: done — %s transcript line(s) repointed; backup in %s\n' "${total}" "${backup/#"${HOME}"/\~}"
    __dottod_mv_prune "${backup%/*}" "${CLAUDE_MV_KEEP:-5}"
    return 0
}

complete -o dirnames claude-mv 2>/dev/null
