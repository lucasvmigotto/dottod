#!/usr/bin/env bash
#
# .claude.sh — named Claude Code profiles sharing one store.
#
# Layout (all directly under $HOME):
#   ~/.claude              shared store (memory, skills, plugins, projects, …)
#   ~/.claude-<name>       one overlay per profile: settings.json and
#                          .credentials.json real, identity dirs real and
#                          locked down, everything shared symlinked to
#                          ~/.claude/… — recognized by a .dottod-profile marker
#
# Usage: `claude` picks a profile (fzf when interactive), `claude -P <name>`
# (or --profile) and CLAUDE_PROFILE=<name> jump straight in. Manage with
# `claude-profile add|ls|rm`.
#
# Config (environment variables):
#   CLAUDE_PROFILE         profile name (bypasses the picker)
#   CLAUDE_DEFAULT_PROFILE fallback when no picker (default personal)
#   CLAUDE_NO_PICKER       set (any value) to never show the picker

# Entries shared from ~/.claude into each overlay (symlinked when present).
# Identity-bearing dirs stay OUT on purpose: backups/ (holds oauthAccount
# snapshots), state/, sessions/ and session-env/ are per-profile, otherwise
# one profile's login recovery restores another profile's account.
__DOTTOD_CLAUDE_SHARED="projects plans plugins skills history.jsonl file-history downloads cache paste-cache shell-snapshots"

# Marker file that promotes a ~/.claude-<name> dir to a profile (its
# content is the profile name). Anything without it (stray copies, backups)
# is invisible to discovery.
__DOTTOD_CLAUDE_MARKER=".dottod-profile"

# __dottod_claude_valid_name <name>: true for safe profile names.
__dottod_claude_valid_name() {
    [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]
}

# __dottod_claude_profile_dir <name>: prints the overlay dir (no checks).
__dottod_claude_profile_dir() {
    local name="${1:?profile required}"
    __dottod_claude_valid_name "${name}" || return 1
    printf '%s' "${HOME}/.claude-${name}"
}

# __dottod_claude_profiles: prints every discovered profile name, one per
# line (a ~/.claude-<name> dir carrying the marker file).
__dottod_claude_profiles() {
    local d name
    [[ -n "${HOME:-}" ]] || return 0
    for d in "${HOME}"/.claude-*/; do
        [[ -d "${d}" ]] || continue
        [[ -f "${d}/${__DOTTOD_CLAUDE_MARKER}" ]] || continue
        name="${d%/}"
        name="${name##*/}"
        name="${name#.claude-}"
        [[ -n "${name}" ]] || continue
        printf '%s\n' "${name}"
    done
}

# __dottod_claude_binary: prints the real claude binary path, ignoring this
# file's claude() wrapper. Fails when no binary is on PATH.
__dottod_claude_binary() {
    local d IFS=:
    for d in ${PATH:-/usr/bin:/bin}; do
        if [[ -f "${d}/claude" && -x "${d}/claude" ]]; then
            printf '%s' "${d}/claude"
            return 0
        fi
    done
    return 1
}

# __dottod_claude_ensure_profile <name> [quiet]: builds the overlay
# (idempotent, never overwrites real files), stamps the marker, and prints
# its dir. With a second arg, cosmetic layout chatter is suppressed — the
# launch path uses it so `claude --continue` stays silent. Migrates the
# shared personal token into the personal overlay once.
__dottod_claude_ensure_profile() {
    local name="${1:?profile required}" quiet="${2:-}" dir entry src
    dir="$(__dottod_claude_profile_dir "${name}")" || return 1
    [[ -n "${HOME:-}" ]] || {
        echo 'claude: HOME is empty' >&2
        return 1
    }
    mkdir -p -- "${dir}" || {
        echo "claude: cannot create ${dir}" >&2
        return 1
    }
    chmod 700 -- "${dir}" 2>/dev/null || true
    # shellcheck disable=SC2086 # intentional word splitting on the entry list
    for entry in ${__DOTTOD_CLAUDE_SHARED}; do
        src="${HOME}/.claude/${entry}"
        [[ -e "${src}" ]] || continue
        if [[ -L "${dir}/${entry}" ]]; then
            continue
        elif [[ -e "${dir}/${entry}" ]]; then
            [[ -n "${quiet}" ]] || printf 'claude: keeping existing %s (not replacing with a link)\n' "${dir}/${entry}" >&2
            continue
        fi
        ln -s -- "${src}" "${dir}/${entry}" || printf 'claude: cannot link %s\n' "${entry}" >&2
    done
    if [[ ! -e "${dir}/settings.json" && -f "${HOME}/.claude/settings.json" ]]; then
        cp -- "${HOME}/.claude/settings.json" "${dir}/settings.json" 2>/dev/null || true
    fi
    if [[ "${name}" == "personal" && -f "${HOME}/.claude/.credentials.json" ]]; then
        if [[ ! -e "${dir}/.credentials.json" ]]; then
            mv -- "${HOME}/.claude/.credentials.json" "${dir}/.credentials.json" 2>/dev/null &&
                chmod 600 -- "${dir}/.credentials.json" 2>/dev/null &&
                { [[ -n "${quiet}" ]] || printf 'claude: adopted the shared login into the personal profile\n' >&2; } || true
        elif ! cmp -s -- "${HOME}/.claude/.credentials.json" "${dir}/.credentials.json" 2>/dev/null; then
            [[ -n "${quiet}" ]] || printf 'claude: ignoring a login in the shared store (log in through a profile instead)\n' >&2
        fi
    fi
    if [[ ! -f "${dir}/${__DOTTOD_CLAUDE_MARKER}" ]]; then
        printf '%s\n' "${name}" >"${dir}/${__DOTTOD_CLAUDE_MARKER}" 2>/dev/null || true
    fi
    printf '%s' "${dir}"
}

# __dottod_claude_bar <pct> <width>: a usage bar, colored by level
# (green <50, yellow <80, red at/above). fzf renders the ANSI colors.
__dottod_claude_bar() {
    local pct="${1:-0}" width="${2:-10}" filled i bar color
    ((pct < 0)) && pct=0
    ((pct > 100)) && pct=100
    filled=$((pct * width / 100))
    bar=""
    for ((i = 0; i < filled; i++)); do bar+=$'\u2588'; done
    for ((i = filled; i < width; i++)); do bar+=$'\u2591'; done
    if ((pct < 50)); then
        color=$'\e[32m'
    elif ((pct < 80)); then
        color=$'\e[33m'
    else
        color=$'\e[31m'
    fi
    printf '%s%s%s' "${color}" "${bar}" $'\e[0m'
}

# __dottod_claude_until <iso8601>: resets_at stamp as "today 20:00 (in 6h)".
# Past stamps show "(any moment)"; unparseable stamps print raw.
__dottod_claude_until() {
    local iso="${1:?stamp required}" now target diff h when mwhen
    now="$(date +%s 2>/dev/null)" || {
        printf '%s' "${iso}"
        return 0
    }
    target="$(date -d "${iso}" +%s 2>/dev/null)" || {
        printf '%s' "${iso}"
        return 0
    }
    when="$(date -d "${iso}" +"%a %H:%M" 2>/dev/null || printf '%s' "${iso}")"
    diff=$((target - now))
    if ((diff <= 0)); then
        mwhen="any moment"
    elif ((diff < 3600)); then
        mwhen="in $((diff / 60))m"
    elif ((diff < 172800)); then
        h=$((diff / 3600))
        mwhen="in ${h}h"
    else
        mwhen="in $((diff / 86400))d"
    fi
    printf '%s (%s)' "${when}" "${mwhen}"
}

# __dottod_claude_ago <epoch_ms>: fetchedAtMs stamp as "updated 2h ago".
__dottod_claude_ago() {
    local ms="${1:?stamp required}" now diff
    now="$(date +%s 2>/dev/null)" || return 0
    [[ "${ms}" =~ ^[0-9]+$ ]] || return 0
    diff=$((now - ms / 1000))
    ((diff < 0)) && diff=0
    if ((diff < 300)); then
        printf 'updated just now'
    elif ((diff < 3600)); then
        printf 'updated %dm ago' $((diff / 60))
    elif ((diff < 86400)); then
        printf 'updated %dh ago' $((diff / 3600))
    else
        printf 'updated %dd ago' $((diff / 86400))
    fi
}

# __dottod_claude_profile_info <dir>: prints a short account summary for the
# fzf side panel — auth state, account, org, plan, preferences and usage
# (5h/7d bars with reset times). Best effort: missing or unreadable files
# degrade to fewer lines, never fail.
__dottod_claude_profile_info() {
    local d="${1:?dir required}"
    if [[ -s "${d}/.credentials.json" ]]; then
        printf 'authenticated\n'
    else
        printf 'not authenticated — run and /login\n'
    fi
    command -v jq >/dev/null 2>&1 || return 0
    if [[ -s "${d}/.claude.json" ]]; then
        jq -r '
            (.oauthAccount // {}) as $o |
            "account  \($o.emailAddress // "n/a")",
            "name     \($o.displayName // $o.fullName // "n/a")",
            "org      \($o.organizationName // "n/a")",
            "role     \($o.organizationRole // $o.workspaceRole // "n/a")"
        ' "${d}/.claude.json" 2>/dev/null
    fi
    if [[ -s "${d}/.credentials.json" ]]; then
        jq -r '
            (.claudeAiOauth // {}) as $c |
            "plan     \($c.subscriptionType // "n/a") · \($c.rateLimitTier // "n/a")"
        ' "${d}/.credentials.json" 2>/dev/null
    fi
    if [[ -s "${d}/settings.json" ]]; then
        jq -r '"prefs    " + (to_entries | map("\(.key)=\(.value)") | join(" "))' "${d}/settings.json" 2>/dev/null
    fi
    if [[ -s "${d}/.claude.json" ]]; then
        local five five_reset seven seven_reset fetched
        five="$(jq -r '.cachedUsageUtilization.utilization.five_hour.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
        five_reset="$(jq -r '.cachedUsageUtilization.utilization.five_hour.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
        seven="$(jq -r '.cachedUsageUtilization.utilization.seven_day.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
        seven_reset="$(jq -r '.cachedUsageUtilization.utilization.seven_day.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
        fetched="$(jq -r '.cachedUsageUtilization.fetchedAtMs // empty' "${d}/.claude.json" 2>/dev/null)"
        if [[ "${five}" =~ ^[0-9]+$ && -n "${five_reset}" ]]; then
            printf 'usage    5h %s %s%% \u00b7 resets %s\n' "$(__dottod_claude_bar "${five}")" "${five}" "$(__dottod_claude_until "${five_reset}")"
        fi
        if [[ "${seven}" =~ ^[0-9]+$ && -n "${seven_reset}" ]]; then
            printf '         7d %s %s%% \u00b7 resets %s\n' "$(__dottod_claude_bar "${seven}")" "${seven}" "$(__dottod_claude_until "${seven_reset}")"
        fi
        if [[ -n "${fetched}" ]]; then
            __dottod_claude_ago "${fetched}" && printf '\n'
        fi
    fi
}

# __dottod_claude_fzf: profile picker, prints the chosen name (fails on esc
# or when no profiles exist yet).
__dottod_claude_fzf() {
    local names choice
    names="$(__dottod_claude_profiles)"
    [[ -n "${names}" ]] || return 1
    # The preview subshell inherits only exported functions — export every
    # callee of __dottod_claude_profile_info, or the picker logs
    # "command not found" for the bar/until/ago helpers.
    export -f __dottod_claude_profile_info __dottod_claude_bar \
        __dottod_claude_until __dottod_claude_ago
    choice="$(printf '%s\n' "${names}" | fzf --prompt='profile> ' \
        --height=40% --layout=reverse --border \
        --header='enter: launch   esc: cancel' \
        --preview='bash -c '"'"'__dottod_claude_profile_info "$HOME/.claude-{}"'"'"'')" || return $?
    [[ -n "${choice}" ]] || return 130
    printf '%s' "${choice}"
}

# __dottod_claude_pick_profile: prints the profile to use (fails on esc, on
# an unknown CLAUDE_PROFILE value, or when the named profile is missing).
__dottod_claude_pick_profile() {
    local choice="${CLAUDE_PROFILE:-}" picked
    if [[ -n "${choice}" ]]; then
        if ! __dottod_claude_valid_name "${choice}"; then
            printf 'claude: bad profile name %s\n' "${choice}" >&2
            return 2
        fi
        printf '%s' "${choice}"
        return 0
    fi
    if [[ $- == *i* ]] && [[ -t 0 ]] && [[ -z "${CLAUDE_NO_PICKER:-}" ]] && command -v fzf >/dev/null 2>&1; then
        if picked="$(__dottod_claude_fzf)"; then
            printf '%s' "${picked}"
            return 0
        fi
        # Empty registry (or esc): fall through to the default below.
    fi
    printf '%s' "${CLAUDE_DEFAULT_PROFILE:-personal}"
}

# claude-profile: manage overlays — add <name> | ls | rm [--force] <name>.
# __dottod_claude_live_pid <dir> [procdir]: PID of a running claude process
# whose environment pins CLAUDE_CONFIG_DIR to <dir>, or empty when none.
# Scans procdir/*/environ (/proc on Linux, same-user processes); unreadable
# entries are skipped silently (other users' processes must never print
# "Permission denied" noise). Returns empty — no refusal — when the proc
# tree is unavailable, so the guard degrades instead of blocking renames on
# non-Linux or locked-down systems.
__dottod_claude_live_pid() {
    local dir="${1:?dir required}" procdir="${2:-/proc}" pid envfile
    [[ -d "${procdir}" ]] || return 0
    for pid in "${procdir}"/[0-9]*; do
        [[ -d "${pid}" ]] || continue
        pid="${pid##*/}"
        envfile="${procdir}/${pid}/environ"
        [[ -r "${envfile}" ]] || continue
        if tr '\0' '\n' 2>/dev/null <"${envfile}" | grep -Fqx "CLAUDE_CONFIG_DIR=${dir}"; then
            printf '%s' "${pid}"
            return 0
        fi
    done
    return 0
}

claude-profile() {
    local cmd="${1:-ls}"
    case "${cmd}" in
        add)
            local name="${2:?usage: claude-profile add <name>}"
            __dottod_claude_valid_name "${name}" || {
                echo "claude-profile: bad profile name ${name}" >&2
                return 2
            }
            __dottod_claude_ensure_profile "${name}" >/dev/null || return 1
            printf 'claude profile ready: %s\n' "${name}"
            ;;
        ls | list)
            local n d
            while IFS= read -r n; do
                d="$(__dottod_claude_profile_dir "${n}")"
                if [[ -s "${d}/.credentials.json" ]]; then
                    printf '%s (authenticated)\n' "${n}"
                else
                    printf '%s (needs /login)\n' "${n}"
                fi
            done < <(__dottod_claude_profiles)
            ;;
        rm | remove)
            local force=0 name
            if [[ "${2:-}" == "--force" ]]; then
                force=1
                name="${3:?usage: claude-profile rm [--force] <name>}"
            else
                name="${2:?usage: claude-profile rm [--force] <name>}"
            fi
            __dottod_claude_valid_name "${name}" || {
                echo "claude-profile: bad profile name ${name}" >&2
                return 2
            }
            dir="$(__dottod_claude_profile_dir "${name}")"
            if [[ ! -f "${dir}/${__DOTTOD_CLAUDE_MARKER}" ]]; then
                echo "claude-profile: not a profile: ${name}" >&2
                return 1
            fi
            local live
            live="$(__dottod_claude_live_pid "${dir}")"
            if [[ -n "${live}" ]]; then
                printf 'claude-profile: %s is in use by claude (pid %s); close the session first\n' "${name}" "${live}" >&2
                return 1
            fi
            local entry bn real
            if ((force == 0)); then
                real=""
                for entry in "${dir}"/*; do
                    [[ -e "${entry}" ]] || continue
                    bn="${entry##*/}"
                    [[ "${bn}" == "${__DOTTOD_CLAUDE_MARKER}" ]] && continue
                    [[ -L "${entry}" ]] && continue
                    real="${real} ${bn}"
                done
                for entry in "${dir}"/.[!.]*; do
                    [[ -e "${entry}" ]] || continue
                    bn="${entry##*/}"
                    [[ "${bn}" == "${__DOTTOD_CLAUDE_MARKER}" ]] && continue
                    case "${bn}" in
                        .credentials.json | settings.json | .claude.json) real="${real} ${bn}" ;;
                    esac
                done
                if [[ -n "${real}" ]]; then
                    printf 'claude-profile: %s holds real files (%s); rm --force to delete\n' "${name}" "${real}" >&2
                    return 1
                fi
            fi
            rm -rf -- "${dir}" || {
                echo "claude-profile: cannot remove ${dir}" >&2
                return 1
            }
            printf 'claude profile removed: %s\n' "${name}"
            ;;
        rename | mv)
            local old new olddir newdir
            old="${2:?usage: claude-profile rename <old> <new>}"
            new="${3:?usage: claude-profile rename <old> <new>}"
            __dottod_claude_valid_name "${old}" || {
                echo "claude-profile: bad profile name ${old}" >&2
                return 2
            }
            __dottod_claude_valid_name "${new}" || {
                echo "claude-profile: bad profile name ${new}" >&2
                return 2
            }
            olddir="$(__dottod_claude_profile_dir "${old}")"
            newdir="$(__dottod_claude_profile_dir "${new}")"
            if [[ ! -f "${olddir}/${__DOTTOD_CLAUDE_MARKER}" ]]; then
                echo "claude-profile: not a profile: ${old}" >&2
                return 1
            fi
            if [[ -e "${newdir}" ]]; then
                echo "claude-profile: ${new} already exists" >&2
                return 1
            fi
            local live
            live="$(__dottod_claude_live_pid "${olddir}")"
            if [[ -n "${live}" ]]; then
                printf 'claude-profile: %s is in use by claude (pid %s); close the session first\n' "${old}" "${live}" >&2
                return 1
            fi
            mv -- "${olddir}" "${newdir}" || {
                echo "claude-profile: cannot rename ${old}" >&2
                return 1
            }
            printf '%s\n' "${new}" >"${newdir}/${__DOTTOD_CLAUDE_MARKER}" || {
                echo "claude-profile: renamed dir but could not update marker" >&2
                return 1
            }
            printf 'claude profile renamed: %s -> %s\n' "${old}" "${new}"
            ;;
        -h | --help | help)
            printf '%s\n' "usage: claude-profile add <name> | ls | rename <old> <new> | rm [--force] <name>"
            printf '%s\n' "rename/rm refuse while a claude session is using the profile."
            ;;
        *)
            printf 'claude-profile: unknown command %s\n' "${cmd}" >&2
            return 2
            ;;
    esac
}

# claude-profiles-init: builds every discovered profile (plus the default
# when none exists yet).
claude-profiles-init() {
    local n found=0
    while IFS= read -r n; do
        found=1
        __dottod_claude_ensure_profile "${n}" >/dev/null || return 1
    done < <(__dottod_claude_profiles)
    if ((found == 0)); then
        __dottod_claude_ensure_profile "${CLAUDE_DEFAULT_PROFILE:-personal}" >/dev/null || return 1
    fi
    printf 'claude profiles ready (shared store %s/.claude)\n' "${HOME}"
}

# claude: launch Claude Code under a profile. -P/--profile <name> selects
# one for this invocation only (stripped before forwarding the rest).
claude() {
    local profile dir
    local -a args=()
    if ! __dottod_claude_binary >/dev/null; then
        echo 'claude: binary not found on PATH' >&2
        return 127
    fi
    while (($# > 0)); do
        case "$1" in
            -P | --profile)
                if (($# < 2)); then
                    echo 'claude: -P needs a profile name' >&2
                    return 2
                fi
                CLAUDE_PROFILE="$2"
                shift 2
                ;;
            --profile=*)
                CLAUDE_PROFILE="${1#--profile=}"
                shift
                ;;
            --)
                args+=("$1")
                shift
                while (($# > 0)); do
                    args+=("$1")
                    shift
                done
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    profile="$(__dottod_claude_pick_profile)" || return $?
    dir="$(__dottod_claude_ensure_profile "${profile}" quiet)" || return $?
    CLAUDE_CONFIG_DIR="${dir}" command claude "${args[@]}"
}
