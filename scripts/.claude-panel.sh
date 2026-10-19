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

# __dottod_claude_org_label <org> <email>: the organization, simplified.
# Claude names a personal org "<email>'s Organization"; that is noise, so
# it becomes "personal" (a named org like "Acme" is kept as is).
__dottod_claude_org_label() {
    local org="${1:-}" email="${2:-}"
    org="${org%\'s Organization}"
    org="${org%’s Organization}"
    if [[ -z "${org}" || "${org}" == "n/a" ]]; then
        printf 'n/a'
    elif [[ "${org}" == "${email}" || "${org}" == *@* ]]; then
        printf 'personal'
    else
        printf '%s' "${org}"
    fi
}

# __dottod_claude_profile_info <dir>: prints the account summary for the
# fzf side panel, one glyph per fact instead of a label:
#   org (first) · role, then the account with a link glyph (green chain
#   when logged in, red broken chain when not) and the name as its tree
#   sub-line, the plan, the 5h/7d usage bars (the clock-rotate glyph marks
#   when each resets) with the cache age, and last the settings.json as
#   indented, colored JSON with anything secret-looking masked.
# Best effort: missing or unreadable files degrade to fewer lines.
__dottod_claude_profile_info() {
    local d="${1:?dir required}"
    local dim=$'\e[2m' green=$'\e[32m' red=$'\e[31m' off=$'\e[0m'
    local authed=0 email="" name="" org="" role="" plan="" fields
    [[ -s "${d}/.credentials.json" ]] && authed=1
    if command -v jq >/dev/null 2>&1; then
        if [[ -s "${d}/.claude.json" ]]; then
            fields="$(jq -r '
                (.oauthAccount // {}) as $o |
                [$o.emailAddress // "", $o.displayName // $o.fullName // "",
                 $o.organizationName // "", $o.organizationRole // $o.workspaceRole // ""]
                | join("\u001f")' "${d}/.claude.json" 2>/dev/null)"
            IFS=$'\x1f' read -r email name org role <<<"${fields}"
        fi
        if ((authed)); then
            plan="$(jq -r '(.claudeAiOauth // {}) as $c |
                "\($c.subscriptionType // "n/a") · \($c.rateLimitTier // "n/a")"' \
                "${d}/.credentials.json" 2>/dev/null)"
        fi
    fi
    if [[ -n "${org}" ]]; then
        printf '\uf1ad  %s' "$(__dottod_claude_org_label "${org}" "${email}")"
        [[ -z "${role}" ]] || printf '  %s\uf132 %s%s' "${dim}" "${role}" "${off}"
        printf '\n'
    fi
    if ((authed)); then
        printf '%s\uf0c1%s  %s\n' "${green}" "${off}" "${email:-authenticated}"
    else
        printf '%s\uf127%s  %s  %snot authenticated — run and /login%s\n' \
            "${red}" "${off}" "${email:-—}" "${dim}" "${off}"
    fi
    [[ -z "${name}" ]] || printf ' %s└%s \uf007 %s\n' "${dim}" "${off}" "${name}"
    [[ -z "${plan}" ]] || printf '\uf09d  %s\n' "${plan}"
    command -v jq >/dev/null 2>&1 || return 0
    __dottod_claude_usage_lines "${d}" panel
    # Settings last, as written: every env value and any string under a
    # token/key/secret/password/credential/auth-looking name is masked.
    if [[ -s "${d}/settings.json" ]]; then
        printf '\n\uf013\n'
        jq -C '
            walk(if type == "object" then with_entries(
                if (.value | type) == "string"
                    and (.key | test("token|secret|passw|api.?key|credential|auth|cookie"; "i"))
                then .value = "•••" else . end) else . end)
            | if (.env | type) == "object" then .env |= map_values("•••") else . end
        ' "${d}/settings.json" 2>/dev/null | sed 's/^/  /'
    fi
}

# __dottod_claude_week_pct <dir>: the 7-day utilization (integer) from the
# cached usage, nothing when there is none or its window already reset
# (the number would describe a week that is over).
__dottod_claude_week_pct() {
    local d="${1:?dir required}" pct reset target now
    [[ -s "${d}/.claude.json" ]] && command -v jq >/dev/null 2>&1 || return 0
    pct="$(jq -r '.cachedUsageUtilization.utilization.seven_day.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
    [[ "${pct}" =~ ^[0-9]+$ ]] || return 0
    reset="$(jq -r '.cachedUsageUtilization.utilization.seven_day.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
    if [[ -n "${reset}" ]] && target="$(__dottod_claude_epoch "${reset}")"; then
        now="$(date +%s 2>/dev/null)" || now=0
        ((target > now)) || return 0
    fi
    printf '%s' "${pct}"
}

# __dottod_claude_list_line <name>: one picker row, "name<TAB>label". The
# label is styled by how much of the week is used, with a glyph besides
# the color so it reads without one:
#   100%+  white bold on red     (limit exceeded)
#   >= 90  bold red              (about to hit it)
#   >= 75  amber                 (getting close)
# Thresholds: CLAUDE_WEEK_WARN (75) and CLAUDE_WEEK_CRIT (90).
__dottod_claude_list_line() {
    local name="${1:?name required}" pct label
    local warn="${CLAUDE_WEEK_WARN:-75}" crit="${CLAUDE_WEEK_CRIT:-90}"
    pct="$(__dottod_claude_week_pct "${HOME}/.claude-${name}")"
    if [[ -z "${pct}" ]]; then
        label="   ${name}"
    elif ((pct >= 100)); then
        label=$'\e[1;97;41m \uf05e '"${name} "$'\e[0m'
    elif ((pct >= crit)); then
        label=$'\e[1;31m\uf071  '"${name}"$'\e[0m'
    elif ((pct >= warn)); then
        label=$'\e[38;5;214m\uf06a  '"${name}"$'\e[0m'
    else
        label="   ${name}"
    fi
    printf '%s\t%s\n' "${name}" "${label}"
}

# __dottod_claude_fzf: profile picker, prints the chosen name (fails on esc
# or when no profiles exist yet).
__dottod_claude_fzf() {
    local names choice n lines=""
    names="$(__dottod_claude_profiles)"
    [[ -n "${names}" ]] || return 1
    while IFS= read -r n; do
        lines+="$(__dottod_claude_list_line "${n}")"$'\n'
    done <<<"${names}"
    # The preview subshell inherits only exported functions — export every
    # callee of __dottod_claude_profile_info, or the picker logs
    # "command not found" for the bar/until/ago helpers.
    export -f __dottod_claude_profile_info __dottod_claude_bar __dottod_claude_org_label \
        __dottod_claude_epoch __dottod_claude_until __dottod_claude_ago __dottod_claude_usage_lines \
        __dottod_claude_usage_refresh __dottod_claude_binary
    # Stale numbers refresh in the background; moving the cursor (or
    # ctrl-r, which refreshes the highlighted profile now) redraws them.
    __dottod_claude_usage_spawn
    choice="$(printf '%s' "${lines}" | fzf --prompt='profile> ' --ansi \
        --delimiter=$'\t' --with-nth=2 \
        --height=40% --layout=reverse --border \
        --header='enter: launch   ctrl-r: refresh usage   esc: cancel' \
        --bind='ctrl-r:execute-silent(bash -c '"'"'__dottod_claude_usage_refresh "$HOME/.claude-{1}"'"'"')+refresh-preview' \
        --preview='bash -c '"'"'__dottod_claude_profile_info "$HOME/.claude-{1}"'"'"'')" || return $?
    [[ -n "${choice}" ]] || return 130
    printf '%s' "${choice%%$'\t'*}"
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
