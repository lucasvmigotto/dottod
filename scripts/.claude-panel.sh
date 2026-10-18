#!/usr/bin/env bash
#
# .claude-panel.sh — the profile picker and its info panel: usage bars,
# identity, prefs, the fzf preview and ctrl-r refresh.
# Split out of .claude.sh (spec 022); loaded by it, safe to source alone.

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
