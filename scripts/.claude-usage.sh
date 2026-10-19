#!/usr/bin/env bash
#
# .claude-usage.sh — the usage numbers behind the profile panel: reset
# stamps ("in 4h 12m", a date beyond a day), the "updated 2h ago" note, the
# cached-usage lines, and the background `claude -p /usage` refresh.
# Split out of .claude.sh (spec 022); loaded by it, safe to source alone.

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

# __dottod_claude_usage_lines <dir>: the 5h/7d usage bars from the
# profile's cached numbers (cachedUsageUtilization in .claude.json, which
# Claude Code writes, and __dottod_claude_usage_refresh asks it to), and
# how old they are. Nothing when there are none. With a second argument
# (the panel), the labels become glyphs: a chart for the bars, a refresh
# arrow for the age.
__dottod_claude_usage_lines() {
    local d="${1:?dir required}" mode="${2:-}" l5='usage    5h' l7='         7d' ago
    if [[ -n "${mode}" ]]; then
        l5=$'\uf080  5h'
        l7='   7d'
    fi
    [[ -s "${d}/.claude.json" ]] && command -v jq >/dev/null 2>&1 || return 0
    local five five_reset seven seven_reset fetched
    five="$(jq -r '.cachedUsageUtilization.utilization.five_hour.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
    five_reset="$(jq -r '.cachedUsageUtilization.utilization.five_hour.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
    seven="$(jq -r '.cachedUsageUtilization.utilization.seven_day.utilization // empty' "${d}/.claude.json" 2>/dev/null)"
    seven_reset="$(jq -r '.cachedUsageUtilization.utilization.seven_day.resets_at // empty' "${d}/.claude.json" 2>/dev/null)"
    fetched="$(jq -r '.cachedUsageUtilization.fetchedAtMs // empty' "${d}/.claude.json" 2>/dev/null)"
    # A window with nothing used yet has no reset time: the bar, no glyph.
    if [[ "${five}" =~ ^[0-9]+$ ]]; then
        printf '%s %s %3s%%' "${l5}" "$(__dottod_claude_bar "${five}")" "${five}"
        [[ -z "${five_reset}" ]] || printf '  \uf1da %s' "$(__dottod_claude_until "${five_reset}")"
        printf '\n'
    fi
    if [[ "${seven}" =~ ^[0-9]+$ ]]; then
        printf '%s %s %3s%%' "${l7}" "$(__dottod_claude_bar "${seven}")" "${seven}"
        [[ -z "${seven_reset}" ]] || printf '  \uf1da %s' "$(__dottod_claude_until "${seven_reset}")"
        printf '\n'
    fi
    if [[ -n "${fetched}" ]]; then
        if [[ -n "${mode}" ]]; then
            ago="$(__dottod_claude_ago "${fetched}")"
            [[ -z "${ago}" ]] || printf '\uf021  %s\n' "${ago#updated }"
        else
            __dottod_claude_ago "${fetched}" && printf '\n'
        fi
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
