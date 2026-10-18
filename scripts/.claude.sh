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
# `claude-profile add|ls|rm`. `claude -c` or a bare `claude -r` where nothing
# was saved asks whether to start a new conversation instead.
#
# Config (environment variables):
#   CLAUDE_PROFILE         profile name (bypasses the picker)
#   CLAUDE_DEFAULT_PROFILE fallback when no picker (default personal)
#   CLAUDE_NO_PICKER       set (any value) to never show the picker
#   CLAUDE_USAGE_REFRESH   0 = never refresh usage numbers in the background
#   CLAUDE_USAGE_TTL       seconds before cached usage counts as stale (300)

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
    mkdir -p -- "${HOME}/.claude" 2>/dev/null || true
    # shellcheck disable=SC2086 # intentional word splitting on the entry list
    for entry in ${__DOTTOD_CLAUDE_SHARED}; do
        src="${HOME}/.claude/${entry}"
        if [[ -L "${dir}/${entry}" ]]; then
            continue
        elif [[ -e "${dir}/${entry}" ]]; then
            # The store lacks it: adopt the overlay's copy as the store's.
            if [[ ! -e "${src}" ]] && mv -- "${dir}/${entry}" "${src}" 2>/dev/null; then
                ln -s -- "${src}" "${dir}/${entry}" || printf 'claude: cannot link %s\n' "${entry}" >&2
                continue
            fi
            # Never quiet: a private copy splits the history between profiles
            # (Claude Code recreates a real dir whenever the link goes missing).
            printf 'claude: %s is a private copy, not shared (run claude-profile init)\n' "${dir}/${entry}" >&2
            continue
        fi
        # Create the store entry up front: Claude Code would otherwise write
        # a private copy inside the overlay on first run.
        if [[ ! -e "${src}" ]]; then
            if [[ "${entry}" == *.jsonl ]]; then
                : >>"${src}" 2>/dev/null && chmod 600 -- "${src}" 2>/dev/null
            else
                mkdir -p -- "${src}" 2>/dev/null
            fi
        fi
        [[ -e "${src}" ]] || continue
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

# __dottod_claude_epoch <iso8601>: epoch seconds of `2030-01-16T01:00:00Z`,
# `…+00:00`, `….123456+02:00` — parsed in bash, since BusyBox date -d takes
# no ISO form; anything else is left to `date -d`. Fails when unparseable.
__dottod_claude_epoch() {
    local iso="${1:?stamp required}" y m d hh mm ss off=0 sign hz mz days
    local re='^([0-9]{4})-([0-9]{2})-([0-9]{2})[T ]([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]+)?(Z|([+-])([0-9]{2}):?([0-9]{2}))?$'
    if [[ "${iso}" =~ ${re} ]]; then
        y=$((10#${BASH_REMATCH[1]}))
        m=$((10#${BASH_REMATCH[2]}))
        d=$((10#${BASH_REMATCH[3]}))
        hh=$((10#${BASH_REMATCH[4]}))
        mm=$((10#${BASH_REMATCH[5]}))
        ss=$((10#${BASH_REMATCH[6]}))
        if [[ -n "${BASH_REMATCH[9]}" ]]; then
            sign="${BASH_REMATCH[9]}"
            hz=$((10#${BASH_REMATCH[10]}))
            mz=$((10#${BASH_REMATCH[11]}))
            off=$((hz * 3600 + mz * 60))
            [[ "${sign}" == - ]] && off=$((-off))
        fi
        # days from civil (Howard Hinnant): proleptic Gregorian to 1970-01-01.
        ((m <= 2)) && y=$((y - 1))
        local era=$((y >= 0 ? y / 400 : (y - 399) / 400))
        local yoe=$((y - era * 400))
        local doy=$(((153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1))
        local doe=$((yoe * 365 + yoe / 4 - yoe / 100 + doy))
        days=$((era * 146097 + doe - 719468))
        printf '%s' $((days * 86400 + hh * 3600 + mm * 60 + ss - off))
        return 0
    fi
    date -d "${iso}" +%s 2>/dev/null
}

# __dottod_claude_until <iso8601>: a resets_at stamp as the time left
# ("in 4h 12m", "in 35m") up to one day away, as the full date beyond
# ("Sat 24 Oct 20:00"). Past stamps show "any moment"; unparseable stamps
# print raw.
__dottod_claude_until() {
    local iso="${1:?stamp required}" now target diff
    now="$(date +%s 2>/dev/null)" || {
        printf '%s' "${iso}"
        return 0
    }
    target="$(__dottod_claude_epoch "${iso}")" || {
        printf '%s' "${iso}"
        return 0
    }
    diff=$((target - now))
    if ((diff <= 0)); then
        printf 'any moment'
    elif ((diff < 3600)); then
        printf 'in %dm' $((diff / 60))
    elif ((diff <= 86400)); then
        printf 'in %dh %dm' $((diff / 3600)) $((diff % 3600 / 60))
    else
        date -d "@${target}" +'%a %d %b %H:%M' 2>/dev/null || printf '%s' "${iso}"
    fi
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
# fzf side panel — auth state, account, org, plan, usage (5h/7d bars; the
# clock-rotate glyph marks when each resets: the time left, or the date
# when more than a day away) and, last, settings.json as indented, colored JSON with anything
# secret-looking masked. Best effort: missing or unreadable files degrade
# to fewer lines, never fail.
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
    __dottod_claude_usage_lines "${d}"
    # Settings last, as written: every env value and any string under a
    # token/key/secret/password/credential/auth-looking name is masked.
    if [[ -s "${d}/settings.json" ]]; then
        printf '\nprefs\n'
        jq -C '
            walk(if type == "object" then with_entries(
                if (.value | type) == "string"
                    and (.key | test("token|secret|passw|api.?key|credential|auth|cookie"; "i"))
                then .value = "•••" else . end) else . end)
            | if (.env | type) == "object" then .env |= map_values("•••") else . end
        ' "${d}/settings.json" 2>/dev/null | sed 's/^/  /'
    fi
}

# __dottod_claude_usage_lines <dir>: the 5h/7d usage bars from the
# profile's cached numbers (cachedUsageUtilization in .claude.json, which
# Claude Code writes, and __dottod_claude_usage_refresh asks it to), and
# how old they are. Nothing when there are none.
__dottod_claude_usage_lines() {
    local d="${1:?dir required}"
    [[ -s "${d}/.claude.json" ]] && command -v jq >/dev/null 2>&1 || return 0
    local five five_reset seven seven_reset fetched
    five="$(jq -r '.cachedUsageUtilization.utilization.five_hour.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
    five_reset="$(jq -r '.cachedUsageUtilization.utilization.five_hour.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
    seven="$(jq -r '.cachedUsageUtilization.utilization.seven_day.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
    seven_reset="$(jq -r '.cachedUsageUtilization.utilization.seven_day.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
    fetched="$(jq -r '.cachedUsageUtilization.fetchedAtMs // empty' "${d}/.claude.json" 2>/dev/null)"
    # A window with nothing used yet has no reset time: the bar, no glyph.
    if [[ "${five}" =~ ^[0-9]+$ ]]; then
        printf 'usage    5h %s %3s%%' "$(__dottod_claude_bar "${five}")" "${five}"
        [[ -z "${five_reset}" ]] || printf '  \uf1da %s' "$(__dottod_claude_until "${five_reset}")"
        printf '\n'
    fi
    if [[ "${seven}" =~ ^[0-9]+$ ]]; then
        printf '         7d %s %3s%%' "$(__dottod_claude_bar "${seven}")" "${seven}"
        [[ -z "${seven_reset}" ]] || printf '  \uf1da %s' "$(__dottod_claude_until "${seven_reset}")"
        printf '\n'
    fi
    if [[ -n "${fetched}" ]]; then
        __dottod_claude_ago "${fetched}" && printf '\n'
    fi
}

# __dottod_claude_usage_stale <dir>: 0 when the profile is logged in and
# its cached usage is missing or older than CLAUDE_USAGE_TTL seconds
# (default 300).
__dottod_claude_usage_stale() {
    local d="${1:?dir required}" fetched now
    [[ -s "${d}/.credentials.json" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    fetched="$(jq -r '.cachedUsageUtilization.fetchedAtMs // 0' "${d}/.claude.json" 2>/dev/null)"
    [[ "${fetched}" =~ ^[0-9]+$ ]] || fetched=0
    now="$(date +%s)"
    ((now - fetched / 1000 >= ${CLAUDE_USAGE_TTL:-300}))
}

# __dottod_claude_usage_refresh <dir>: asks Claude Code itself for fresh
# numbers — `claude -p /usage` runs locally (no model turn, no cost) and
# rewrites the cache — under a lock (one refresh per profile at a time; a
# lock older than a minute is taken over) and a 30s timeout, from $HOME
# with no session saved. Silent; rc 1 when it did not run or failed.
__dottod_claude_usage_refresh() {
    local d="${1:?dir required}" bin lock="${1}/.dottod-usage.lock" rc
    bin="$(__dottod_claude_binary)" || return 1
    if ! mkdir -- "${lock}" 2>/dev/null; then
        [[ -n "$(find "${lock}" -maxdepth 0 -mmin +1 2>/dev/null)" ]] || return 1
        rm -rf -- "${lock}"
        mkdir -- "${lock}" 2>/dev/null || return 1
    fi
    (
        cd -- "${HOME}" 2>/dev/null || exit 1
        CLAUDE_CONFIG_DIR="${d}" timeout 30 "${bin}" -p /usage --no-session-persistence
    ) </dev/null >/dev/null 2>&1
    rc=$?
    rmdir -- "${lock}" 2>/dev/null
    return "${rc}"
}

# __dottod_claude_usage_spawn: refreshes every stale profile in the
# background, detached (never waited on); CLAUDE_USAGE_REFRESH=0 turns it
# off. The picker calls it as it opens.
__dottod_claude_usage_spawn() {
    [[ "${CLAUDE_USAGE_REFRESH:-1}" != 0 ]] || return 0
    local n d
    while IFS= read -r n; do
        d="$(__dottod_claude_profile_dir "${n}")" || continue
        __dottod_claude_usage_stale "${d}" || continue
        (__dottod_claude_usage_refresh "${d}" &)
    done < <(__dottod_claude_profiles)
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
        __dottod_claude_epoch __dottod_claude_until __dottod_claude_ago __dottod_claude_usage_lines \
        __dottod_claude_usage_refresh __dottod_claude_binary
    # Stale numbers refresh in the background; moving the cursor (or
    # ctrl-r, which refreshes the highlighted profile now) redraws them.
    __dottod_claude_usage_spawn
    choice="$(printf '%s\n' "${names}" | fzf --prompt='profile> ' \
        --height=40% --layout=reverse --border \
        --header='enter: launch   ctrl-r: refresh usage   esc: cancel' \
        --bind='ctrl-r:execute-silent(bash -c '"'"'__dottod_claude_usage_refresh "$HOME/.claude-{}"'"'"')+refresh-preview' \
        --preview='bash -c '"'"'__dottod_claude_profile_info "$HOME/.claude-{}"'"'"'')" || return $?
    [[ -n "${choice}" ]] || return 130
    printf '%s' "${choice}"
}

# __dottod_claude_pick_profile: prints the profile to use (fails on esc, on
# an unknown CLAUDE_PROFILE value, or when the named profile is missing).
__dottod_claude_pick_profile() {
    local choice="${CLAUDE_PROFILE:-}" picked rc
    if [[ -n "${choice}" ]]; then
        if ! __dottod_claude_valid_name "${choice}"; then
            printf 'claude: bad profile name %s\n' "${choice}" >&2
            return 2
        fi
        printf '%s' "${choice}"
        return 0
    fi
    if [[ $- == *i* ]] && [[ -t 0 ]] && [[ -z "${CLAUDE_NO_PICKER:-}" ]] && command -v fzf >/dev/null 2>&1; then
        picked="$(__dottod_claude_fzf)"
        rc=$?
        if ((rc == 0)); then
            printf '%s' "${picked}"
            return 0
        elif ((rc == 130)); then
            return 130 # user cancelled: abort the launch, never default
        fi
        # Any other failure (e.g. empty registry): fall through to default.
    fi
    printf '%s' "${CLAUDE_DEFAULT_PROFILE:-personal}"
}

# __dottod_claude_merge_dir <from> <into> <tag>: moves every file of <from>
# into <into>, keeping relative paths. Moves (not copies) so files open in a
# live session keep their inode. Identical duplicates are dropped; a
# differing .jsonl transcript (a session resumed in both places) gets the
# lines it lacks appended, in order; other differing files land beside the
# store's copy as <file>.from-<tag>. Removes <from>.
__dottod_claude_merge_dir() {
    local from="${1:?from required}" into="${2:?into required}" tag="${3:?tag required}" f rel t
    mkdir -p -- "${into}" || return 1
    while IFS= read -r -d '' f; do
        rel="${f#"${from}"/}"
        t="${into}/${rel}"
        mkdir -p -- "${t%/*}" || return 1
        if [[ ! -e "${t}" && ! -L "${t}" ]]; then
            mv -- "${f}" "${t}" || return 1
        elif cmp -s -- "${f}" "${t}"; then
            rm -f -- "${f}"
        elif [[ "${t}" == *.jsonl && -f "${t}" ]]; then
            [[ -z "$(tail -c 1 -- "${t}")" ]] || printf '\n' >>"${t}"
            # awk reads all of ${t} before the first line of ${f} is written.
            # shellcheck disable=SC2094
            awk 'NR == FNR { seen[$0] = 1; next } !($0 in seen)' "${t}" "${f}" >>"${t}" || return 1
            rm -f -- "${f}"
        else
            mv -- "${f}" "${t}.from-${tag}" || return 1
            printf 'claude-profile: conflict kept as %s\n' "${t}.from-${tag}" >&2
        fi
    done < <(find "${from}" \( -type f -o -type l \) -print0)
    find "${from}" -depth -type d -empty -delete 2>/dev/null
    [[ ! -e "${from}" ]]
}

# __dottod_claude_merge_history <from> <into>: appends the prompt history of
# <from> to <into>, deduplicated and ordered by timestamp (plain append when
# jq is missing). Removes <from>.
__dottod_claude_merge_history() {
    local from="${1:?from required}" into="${2:?into required}" tmp
    tmp="${into}.merge.$$"
    if command -v jq >/dev/null 2>&1 &&
        cat -- "${into}" "${from}" 2>/dev/null | jq -c -s 'unique | sort_by(.timestamp // 0) | .[]' >"${tmp}" 2>/dev/null; then
        cat -- "${tmp}" >"${into}" && rm -f -- "${tmp}"
    else
        rm -f -- "${tmp}"
        cat -- "${from}" >>"${into}" || return 1
    fi
    chmod 600 -- "${into}" 2>/dev/null
    rm -f -- "${from}"
}

# __dottod_claude_consolidate <name> [force]: folds every shared entry the
# overlay holds as a real file/dir into the store, then links it. Refuses a
# profile in use unless forced.
__dottod_claude_consolidate() {
    local name="${1:?profile required}" force="${2:-}" dir entry src live f
    dir="$(__dottod_claude_profile_dir "${name}")" || return 2
    if [[ ! -f "${dir}/${__DOTTOD_CLAUDE_MARKER}" ]]; then
        echo "claude-profile: not a profile: ${name}" >&2
        return 1
    fi
    live="$(__dottod_claude_live_pid "${dir}")"
    if [[ -n "${live}" && -z "${force}" ]]; then
        printf 'claude-profile: %s is in use by claude (pid %s); close it or pass --force\n' "${name}" "${live}" >&2
        return 1
    fi
    mkdir -p -- "${HOME}/.claude" || return 1
    # Plugin manifests record absolute paths; point them at the store first,
    # so manifests that only differ by profile path merge as duplicates.
    for f in "${HOME}"/.claude/plugins/*.json "${dir}"/plugins/*.json; do
        [[ -f "${f}" ]] || continue
        sed -i -E "s#${HOME}/\\.claude-[A-Za-z0-9_-]+/plugins#${HOME}/.claude/plugins#g" -- "${f}" 2>/dev/null || true
    done
    # shellcheck disable=SC2086 # intentional word splitting on the entry list
    for entry in ${__DOTTOD_CLAUDE_SHARED}; do
        src="${HOME}/.claude/${entry}"
        [[ -e "${dir}/${entry}" && ! -L "${dir}/${entry}" ]] || continue
        if [[ ! -e "${src}" ]]; then
            mv -- "${dir}/${entry}" "${src}" || return 1
        elif [[ -d "${dir}/${entry}" ]]; then
            __dottod_claude_merge_dir "${dir}/${entry}" "${src}" "${name}" || {
                printf 'claude-profile: could not fully merge %s\n' "${dir}/${entry}" >&2
                return 1
            }
        elif [[ "${entry}" == history.jsonl ]]; then
            __dottod_claude_merge_history "${dir}/${entry}" "${src}" || return 1
        else
            mv -- "${dir}/${entry}" "${src}.from-${name}" || return 1
        fi
        ln -s -- "${src}" "${dir}/${entry}" || return 1
        printf 'claude-profile: %s/%s now shared\n' "${name}" "${entry}"
    done
    __dottod_claude_ensure_profile "${name}" quiet >/dev/null
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
        init)
            __dottod_claude_init
            ;;
        consolidate | sync)
            local force="" n rc=0
            local -a names=()
            shift
            while (($# > 0)); do
                case "$1" in
                    --force) force=1 ;;
                    *) names+=("$1") ;;
                esac
                shift
            done
            if ((${#names[@]} == 0)); then
                mapfile -t names < <(__dottod_claude_profiles)
            fi
            for n in "${names[@]}"; do
                __dottod_claude_consolidate "${n}" "${force}" || rc=1
            done
            ((rc == 0)) && printf 'claude profiles consolidated into %s/.claude\n' "${HOME}"
            return "${rc}"
            ;;
        usage)
            # usage [name...]: refresh now (in parallel), then print the
            # bars of the named profiles, or of all of them.
            shift
            local -a names=() pids=()
            local n d first=1 pid
            if (($# > 0)); then
                names=("$@")
            else
                while IFS= read -r n; do names+=("${n}"); done < <(__dottod_claude_profiles)
            fi
            for n in "${names[@]}"; do
                d="$(__dottod_claude_profile_dir "${n}")" || {
                    echo "claude-profile: bad profile name ${n}" >&2
                    return 2
                }
                [[ -f "${d}/${__DOTTOD_CLAUDE_MARKER}" ]] || {
                    echo "claude-profile: not a profile: ${n}" >&2
                    return 1
                }
                if [[ -s "${d}/.credentials.json" ]]; then
                    __dottod_claude_usage_refresh "${d}" &
                    pids+=($!)
                fi
            done
            for pid in "${pids[@]}"; do wait "${pid}"; done
            for n in "${names[@]}"; do
                d="$(__dottod_claude_profile_dir "${n}")"
                ((first)) || printf '\n'
                first=0
                printf '%s\n' "${n}"
                if [[ ! -s "${d}/.credentials.json" ]]; then
                    printf 'not authenticated — run and /login\n'
                    continue
                fi
                __dottod_claude_usage_lines "${d}"
            done
            ;;
        -h | --help | help)
            printf '%s\n' "usage: claude-profile add <name> | ls | usage [name...] | init | consolidate [--force] [name...] | rename <old> <new> | rm [--force] <name>"
            printf '%s\n' "init builds every profile, repairs split ones not in use and seeds the profiles memory note."
            printf '%s\n' "consolidate folds a profile's private history/projects/plugins into the shared store."
            printf '%s\n' "consolidate/rename/rm refuse while a claude session is using the profile."
            ;;
        *)
            printf 'claude-profile: unknown command %s\n' "${cmd}" >&2
            return 2
            ;;
    esac
}

# __dottod_claude_seed_memory: writes the profile-layout note into the
# home directory's memory in the store (Claude Code's projects/<$HOME,
# non-alphanumerics as '-'>/memory), so a session started in ~ knows how
# profiles share history and how to repair a split. Never overwrites the
# note; indexes it in MEMORY.md once.
__dottod_claude_seed_memory() {
    local mem note index
    mem="${HOME}/.claude/projects/${HOME//[^A-Za-z0-9]/-}/memory"
    note="${mem}/claude-profiles.md"
    index="${mem}/MEMORY.md"
    mkdir -p -- "${mem}" || return 1
    if [[ ! -e "${note}" ]]; then
        cat >"${note}" <<'EOF' || return 1
---
name: claude-profiles
description: dottod Claude profiles — ~/.claude-<name> overlays share history through symlinks into ~/.claude; how to repair a split
metadata:
  type: reference
---

dottod runs Claude Code under named profiles: each `~/.claude-<name>` overlay (marked by `.dottod-profile`, picked through `CLAUDE_CONFIG_DIR`) keeps its own login, settings, `.claude.json`, `backups/`, `sessions/` and `session-env/`, and symlinks everything else — `projects`, `history.jsonl`, `file-history`, `plans`, `plugins`, `skills`, `shell-snapshots`, `paste-cache`, `cache`, `downloads` — to the shared store `~/.claude/`.

A split happens when one of those links goes missing while a session runs: Claude Code then recreates a real directory in the overlay and that profile's transcripts and memory stop reaching the others. Symptom: `claude: … is a private copy, not shared` at launch, or a session missing from the other profiles.

**How to apply:** to check, `find ~/.claude-* -maxdepth 1 -mindepth 1 ! -type l`; only the per-profile entries above should be listed. To repair, close the profile's sessions and run `claude-profile init` (or `claude-profile consolidate <name>`): it moves the private files into the store, appends the missing lines of a transcript resumed in both places, keeps other differing files as `<file>.from-<name>`, and puts the link back. Never edit the store while a session of the affected profile is running.
EOF
    fi
    grep -qsF '(claude-profiles.md)' -- "${index}" ||
        printf '%s\n' '- [Claude profiles](claude-profiles.md) — overlays symlink shared history into ~/.claude; repair a split with claude-profile init' >>"${index}"
}

# __dottod_claude_init: builds every discovered profile (plus the default
# when none exists yet), consolidates every split one not in use, and seeds
# the profile-layout memory. Fails when a profile is left split.
__dottod_claude_init() {
    local n rc=0 live
    local -a names=()
    mapfile -t names < <(__dottod_claude_profiles)
    ((${#names[@]} > 0)) || names=("${CLAUDE_DEFAULT_PROFILE:-personal}")
    for n in "${names[@]}"; do
        # A split profile in use is left untouched: building it would move
        # its private copy into the store under a running session.
        if __dottod_claude_split "${n}" >/dev/null; then
            live="$(__dottod_claude_live_pid "$(__dottod_claude_profile_dir "${n}")")"
            if [[ -n "${live}" ]]; then
                printf 'claude-profile: %s is split but in use by claude (pid %s); close it and run init again\n' "${n}" "${live}" >&2
                rc=1
                continue
            fi
        fi
        __dottod_claude_ensure_profile "${n}" quiet >/dev/null 2>&1 || {
            printf 'claude-profile: cannot build %s\n' "${n}" >&2
            rc=1
            continue
        }
        if __dottod_claude_split "${n}" >/dev/null; then
            __dottod_claude_consolidate "${n}" || rc=1
        fi
    done
    __dottod_claude_seed_memory || {
        echo 'claude-profile: cannot write the profiles memory' >&2
        rc=1
    }
    ((rc == 0)) && printf 'claude profiles ready (shared store %s/.claude)\n' "${HOME}"
    return "${rc}"
}

# __dottod_claude_split <name>: prints the shared entries the overlay holds
# as real files/dirs instead of links; rc 1 when there are none.
__dottod_claude_split() {
    local dir entry found=1
    dir="$(__dottod_claude_profile_dir "${1:?profile required}")" || return 1
    # shellcheck disable=SC2086 # intentional word splitting on the entry list
    for entry in ${__DOTTOD_CLAUDE_SHARED}; do
        if [[ -e "${dir}/${entry}" && ! -L "${dir}/${entry}" ]]; then
            printf '%s\n' "${entry}"
            found=0
        fi
    done
    return "${found}"
}

# claude-profiles-init: kept for older setups; same as claude-profile init.
claude-profiles-init() {
    __dottod_claude_init
}

# __dottod_claude_session_flag <args...>: prints "continue" for
# -c/--continue, "resume" for a bare -r/--resume (no session id or search
# term after it: that one Claude Code resolves itself); rc 1 for neither.
# Options only: anything after `--` is left alone.
__dottod_claude_session_flag() {
    while (($# > 0)); do
        case "${1}" in
            --) return 1 ;;
            -c | --continue)
                printf 'continue'
                return 0
                ;;
            -r | --resume)
                if (($# == 1)) || [[ "${2}" == -* ]]; then
                    printf 'resume'
                    return 0
                fi
                ;;
        esac
        shift
    done
    return 1
}

# __dottod_claude_has_conversation <config_dir> [cwd]: 0 when Claude Code
# has a saved conversation for cwd (default: the physical working dir) —
# a <session>.jsonl under projects/<cwd, non-alphanumerics as '-'>. Paths
# past 200 characters are keyed with a hash dottod cannot rebuild, so they
# count as having one (Claude Code decides).
__dottod_claude_has_conversation() {
    local dir="${1:?dir required}" cwd="${2:-}" key f
    [[ -n "${cwd}" ]] || cwd="$(pwd -P)"
    key="${cwd//[^A-Za-z0-9]/-}"
    ((${#key} <= 200)) || return 0
    for f in "${dir}/projects/${key}"/*.jsonl; do
        [[ -f "${f}" ]] && return 0
    done
    return 1
}

# __dottod_claude_can_ask: 0 when a y/N question can be asked (an
# interactive shell on a terminal); a seam for tests.
__dottod_claude_can_ask() {
    [[ $- == *i* ]] && [[ -t 0 ]]
}

# __dottod_claude_offer_new <continue|resume>: asks whether to start a
# new conversation where there is none to continue or resume; 0 on y/Y.
__dottod_claude_offer_new() {
    local answer
    printf 'claude: no conversation to %s in %s. Start a new one? [y/N] ' "${1:-continue}" "${PWD}" >&2
    read -r answer || return 1
    [[ "${answer}" == y || "${answer}" == Y ]]
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
    # --continue / a bare --resume with nothing saved here: offer a new
    # conversation rather than Claude Code's bare "No conversation found".
    # Without a terminal to ask on, the arguments go through untouched.
    local session
    if session="$(__dottod_claude_session_flag "${args[@]}")" &&
        ! __dottod_claude_has_conversation "${dir}" &&
        __dottod_claude_can_ask; then
        __dottod_claude_offer_new "${session}" || return 1
        local -a kept=()
        local i n=${#args[@]} dashdash=0
        for ((i = 0; i < n; i++)); do
            if ((dashdash == 0)); then
                case "${args[i]}" in
                    --) dashdash=1 ;;
                    -c | --continue) continue ;;
                    -r | --resume)
                        # Only a bare one: -r <id> stays as typed.
                        if ((i + 1 == n)) || [[ "${args[i + 1]}" == -* ]]; then
                            continue
                        fi
                        ;;
                esac
            fi
            kept+=("${args[i]}")
        done
        args=("${kept[@]}")
    fi
    CLAUDE_CONFIG_DIR="${dir}" command claude "${args[@]}"
}
