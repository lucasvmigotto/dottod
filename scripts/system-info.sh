#!/usr/bin/env bash
#
# system-info.sh — cache-assisted Linux system metrics for the Spaceship prompt.
#
# Prints a single compact line such as:
#   <cpu> 23% │ <mem> 7.8/15.6G 50% │ <net> ↓12.4M/s ↑1.8M/s
#
# Design notes:
#   * Linux kernel interfaces only (/proc, /sys); no top/free/ip calls.
#   * Rate-based metrics (CPU %, net throughput) need two samples, so the
#     previous sample is kept in a state file. A first/cold run prints only
#     the metrics available without history (RAM, load, temperature).
#   * Output is cached (TTL 1-2s) so every prompt render is a cheap file read.
#     All cache/state writes are atomic (mktemp in same dir + mv).
#   * Best effort: any missing/unparseable input only drops that metric.
#     This script always exits 0 and never prints errors for missing data.
#   * No ANSI colors: presentation is left to the Spaceship section.
#   * No `set -e` on purpose: this is prompt-runtime code, partial output
#     beats a dead prompt. Every fallible read is guarded explicitly.
#
# Configuration (all optional, dottod `_DOT_*` convention):
#   _DOT_SYSTEM_INFO_TTL        cache TTL in seconds (default: 2)
#   _DOT_SYSTEM_INFO_SHOW_LOAD  1 to append load average (default: 0)
#   _DOT_SYSTEM_INFO_SHOW_TEMP  1 to append CPU temperature when a sensor
#                               exists (default: 0)
#
# Testing hooks (honored when set; point at fixture files instead of /proc):
#   _DOT_SYSINFO_PROC_STAT _DOT_SYSINFO_PROC_MEMINFO _DOT_SYSINFO_PROC_NET_DEV
#   _DOT_SYSINFO_PROC_NET_ROUTE _DOT_SYSINFO_PROC_LOADAVG _DOT_SYSINFO_SYS_DIR
#   _DOT_SYSINFO_CACHE_DIR _DOT_SYSINFO_NOW_NS (fake clock, nanoseconds)
#
# NOTE: this file is a bash *program*, not a shell library, but the
# .custom.zshrc glob sources every scripts/*.sh file into interactive zsh.
# Bail out immediately under zsh so sourcing is a silent no-op (and, in
# particular, `set -u` below never leaks NO_UNSET into the interactive shell).

if [[ -n "${ZSH_VERSION:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

set -uo pipefail

# ---------------------------------------------------------------------------
# Nerd Font / Unicode glyphs (explicit code-point notation; Nerd Fonts 3.x,
# Material Design Icons code points verified against glyphnames.json)
# ---------------------------------------------------------------------------
readonly _SYSINFO_GLYPH_CPU=$'\uF061A'    # md-chip
readonly _SYSINFO_GLYPH_MEM=$'\uF035B'    # md-memory
readonly _SYSINFO_GLYPH_NET=$'\uF06F3'    # md-network
readonly _SYSINFO_GLYPH_LOAD=$'\uF029A'   # md-gauge
readonly _SYSINFO_GLYPH_TEMP=$'\uF050F'   # md-thermometer
readonly _SYSINFO_GLYPH_DOWN=$'\u2193'    # ↓ southwards arrow
readonly _SYSINFO_GLYPH_UP=$'\u2191'      # ↑ northwards arrow
readonly _SYSINFO_SEP=$'\u2502'           # │ box-drawings light vertical

# ---------------------------------------------------------------------------
# Input paths. Resolved dynamically (not captured) so tests can point them
# at fixtures via _DOT_SYSINFO_* overrides at any time. _sysinfo_paths
# refreshes the derived cache/state locations from the environment.
# ---------------------------------------------------------------------------
function _sysinfo_paths() {
    _SYSINFO_PROC_STAT="${_DOT_SYSINFO_PROC_STAT:-/proc/stat}"
    _SYSINFO_PROC_MEMINFO="${_DOT_SYSINFO_PROC_MEMINFO:-/proc/meminfo}"
    _SYSINFO_PROC_NET_DEV="${_DOT_SYSINFO_PROC_NET_DEV:-/proc/net/dev}"
    _SYSINFO_PROC_NET_ROUTE="${_DOT_SYSINFO_PROC_NET_ROUTE:-/proc/net/route}"
    _SYSINFO_PROC_LOADAVG="${_DOT_SYSINFO_PROC_LOADAVG:-/proc/loadavg}"
    _SYSINFO_SYS_DIR="${_DOT_SYSINFO_SYS_DIR:-/sys}"
    _SYSINFO_CACHE_DIR="${_DOT_SYSINFO_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/dottod}"
    _SYSINFO_TTL="${_DOT_SYSTEM_INFO_TTL:-2}"

    _SYSINFO_CACHE_FILE="${_SYSINFO_CACHE_DIR}/sysinfo.cache"
    _SYSINFO_STATE_FILE="${_SYSINFO_CACHE_DIR}/sysinfo.state"
}

function _sysinfo_now_ns() {
    if [[ -n "${_DOT_SYSINFO_NOW_NS:-}" ]]; then
        printf '%s' "${_DOT_SYSINFO_NOW_NS}"
        return 0
    fi
    date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)"
}

function _sysinfo_cache_mtime() {
    _sysinfo_paths
    [[ -f "${_SYSINFO_CACHE_FILE}" ]] || return 1
    stat -c %Y "${_SYSINFO_CACHE_FILE}" 2>/dev/null \
        || date -r "${_SYSINFO_CACHE_FILE}" +%s 2>/dev/null \
        || return 1
}

function _sysinfo_cache_fresh() {
    local mtime now
    mtime="$(_sysinfo_cache_mtime)" || return 1
    now="$(date +%s)"
    [[ "${_SYSINFO_TTL}" =~ ^[0-9]+$ ]] || _SYSINFO_TTL=2
    (( now - mtime <= _SYSINFO_TTL ))
}

function _sysinfo_write_atomic() {
    local dest=${1:?'dest required'} content=${2-}
    local dir tmp
    dir="$(dirname "${dest}")"
    mkdir -p "${dir}" 2>/dev/null || return 1
    tmp="$(mktemp "${dir}/.tmp.XXXXXX")" || return 1
    printf '%s' "${content}" >"${tmp}"
    mv -f "${tmp}" "${dest}"
}

# ---------------------------------------------------------------------------
# Formatting helpers (pure functions — unit tested)
# ---------------------------------------------------------------------------
function _sysinfo_fmt_bytes() {
    local n=${1:?'bytes required'}
    [[ "${n}" =~ ^[0-9]+$ ]] || return 1
    awk -v n="${n}" 'BEGIN {
        if (n >= 1073741824) printf "%.1fG", n/1073741824;
        else if (n >= 1048576) printf "%.1fM", n/1048576;
        else if (n >= 1024) printf "%.1fK", n/1024;
        else printf "%d", n;
    }'
}

function _sysinfo_fmt_rate() {
    local n=${1:?'bytes required'}
    printf '%s/s' "$(_sysinfo_fmt_bytes "${n}")"
}

# cpu line -> "total idle"; usage needs two samples.
function _sysinfo_read_cpu() {
    _sysinfo_paths
    awk '/^cpu / {
        total = $2+$3+$4+$5+$6+$7+$8;
        idle = $5+$6;
        print total, idle;
        exit;
    }' "${_SYSINFO_PROC_STAT}" 2>/dev/null
}

function _sysinfo_cpu_pct() {
    local old_total=${1} old_idle=${2} new_total=${3} new_idle=${4}
    [[ "${old_total}" =~ ^[0-9]+$ && "${old_idle}" =~ ^[0-9]+$ \
        && "${new_total}" =~ ^[0-9]+$ && "${new_idle}" =~ ^[0-9]+$ ]] || return 1
    local dt=$((new_total - old_total)) di=$((new_idle - old_idle))
    (( dt > 0 && di >= 0 && di <= dt )) || return 1
    printf '%d' "$(( (100 * (dt - di)) / dt ))"
}

# meminfo -> "used_kb total_kb pct"
function _sysinfo_read_mem() {
    _sysinfo_paths
    awk '
        $1 == "MemTotal:" { total = $2 }
        $1 == "MemAvailable:" { avail = $2 }
        END {
            if (total > 0 && avail != "" && avail <= total)
                printf "%d %d %d", total-avail, total, (100*(total-avail))/total;
        }' "${_SYSINFO_PROC_MEMINFO}" 2>/dev/null
}

function _sysinfo_fmt_gib() {
    local kb=${1:?'kib required'}
    awk -v kb="${kb}" 'BEGIN { printf "%.1f", kb/1024/1024 }'
}

function _sysinfo_default_iface() {
    _sysinfo_paths
    local iface=""
    if [[ -r "${_SYSINFO_PROC_NET_ROUTE}" ]]; then
        iface="$(awk 'NR > 1 && $2 == "00000000" { print $1; exit }' \
            "${_SYSINFO_PROC_NET_ROUTE}" 2>/dev/null)"
    fi
    if [[ -z "${iface}" && -r "${_SYSINFO_PROC_NET_DEV}" ]]; then
        iface="$(awk -F: 'NF == 2 {
                name = $1; gsub(/[ \t]/, "", name);
                if (name != "" && name != "lo") { print name; exit }
            }' "${_SYSINFO_PROC_NET_DEV}" 2>/dev/null)"
    fi
    printf '%s' "${iface}"
}

# iface -> "rx_bytes tx_bytes"
function _sysinfo_read_iface_bytes() {
    _sysinfo_paths
    local iface=${1:?'iface required'}
    [[ -r "${_SYSINFO_PROC_NET_DEV}" ]] || return 1
    awk -v want="${iface}" -F: 'NF == 2 {
        name = $1; gsub(/[ \t]/, "", name);
        if (name == want) { split($2, a, " "); print a[1], a[9]; exit }
    }' "${_SYSINFO_PROC_NET_DEV}" 2>/dev/null
}

function _sysinfo_rate() {
    local old_v=${1} new_v=${2} dt_ns=${3}
    [[ "${old_v}" =~ ^[0-9]+$ && "${new_v}" =~ ^[0-9]+$ \
        && "${dt_ns}" =~ ^[0-9]+$ ]] || return 1
    (( new_v >= old_v && dt_ns > 0 )) || return 1
    awk -v d=$((new_v - old_v)) -v ns="${dt_ns}" \
        'BEGIN { printf "%d", (d * 1000000000) / ns }'
}

function _sysinfo_read_load() {
    _sysinfo_paths
    awk '{ print $1; exit }' "${_SYSINFO_PROC_LOADAVG}" 2>/dev/null
}

# Best-effort max CPU temperature in whole degrees C; prints nothing if none.
function _sysinfo_read_temp() {
    _sysinfo_paths
    local best="" f raw
    for f in "${_SYSINFO_SYS_DIR}"/class/thermal/thermal_zone*/temp \
             "${_SYSINFO_SYS_DIR}"/class/hwmon/hwmon*/temp*_input; do
        [[ -r "${f}" ]] || continue
        raw="$(<"${f}")" 2>/dev/null || continue
        [[ "${raw}" =~ ^[0-9]+$ ]] || continue
        (( raw > 0 && raw < 125000 )) || continue
        if [[ -z "${best}" || "${raw}" -gt "${best}" ]]; then
            best="${raw}"
        fi
    done
    [[ -n "${best}" ]] || return 1
    printf '%d' "$(( (best + 500) / 1000 ))"
}

# ---------------------------------------------------------------------------
# Collection
# ---------------------------------------------------------------------------
function _sysinfo_load_state() {
    _sysinfo_paths
    _ST_IFACE=""; _ST_RX=""; _ST_TX=""; _ST_CPU_TOTAL=""; _ST_CPU_IDLE=""; _ST_TS=""
    [[ -f "${_SYSINFO_STATE_FILE}" ]] || return 1
    local key val
    while IFS='=' read -r key val; do
        case "${key}" in
            TS) [[ "${val}" =~ ^[0-9]+$ ]] && _ST_TS="${val}" ;;
            IFACE) [[ "${val}" =~ ^[a-zA-Z0-9._-]+$ ]] && _ST_IFACE="${val}" ;;
            RX|TX|CPU_TOTAL|CPU_IDLE)
                [[ "${val}" =~ ^[0-9]+$ ]] && printf -v "_ST_${key}" '%s' "${val}" ;;
        esac
    done <"${_SYSINFO_STATE_FILE}" 2>/dev/null
    [[ -n "${_ST_TS}" ]]
}

function _sysinfo_collect() {
    _sysinfo_paths
    local now_ns cpu_now mem load temp
    now_ns="$(_sysinfo_now_ns)"
    [[ "${now_ns}" =~ ^[0-9]+$ ]] || now_ns="$(date +%s%N)"

    local parts=()

    # CPU %
    cpu_now="$(_sysinfo_read_cpu)"
    local cpu_pct=""
    if [[ -n "${cpu_now}" && -n "${_ST_CPU_TOTAL:-}" && -n "${_ST_CPU_IDLE:-}" ]]; then
        cpu_pct="$(_sysinfo_cpu_pct ${_ST_CPU_TOTAL} ${_ST_CPU_IDLE} ${cpu_now})" || cpu_pct=""
    fi
    if [[ -n "${cpu_pct}" ]]; then
        parts+=("${_SYSINFO_GLYPH_CPU} ${cpu_pct}%")
    fi

    # RAM
    mem="$(_sysinfo_read_mem)"
    if [[ -n "${mem}" ]]; then
        local used total pct
        read -r used total pct <<<"${mem}"
        parts+=("${_SYSINFO_GLYPH_MEM} $(_sysinfo_fmt_gib "${used}")/$(_sysinfo_fmt_gib "${total}")G ${pct}%")
    fi

    # Network throughput (default route interface)
    local iface rx_tx rx tx
    iface="$(_sysinfo_default_iface)"
    if [[ -n "${iface}" ]]; then
        rx_tx="$(_sysinfo_read_iface_bytes "${iface}")" || rx_tx=""
        if [[ -n "${rx_tx}" ]]; then
            read -r rx tx <<<"${rx_tx}"
            if [[ -n "${_ST_TS:-}" && "${_ST_IFACE:-}" == "${iface}" \
                    && -n "${_ST_RX:-}" && -n "${_ST_TX:-}" ]]; then
                local dt_ns=$((now_ns - _ST_TS))
                local rx_r tx_r
                rx_r="$(_sysinfo_rate "${_ST_RX}" "${rx}" "${dt_ns}")" || rx_r=""
                tx_r="$(_sysinfo_rate "${_ST_TX}" "${tx}" "${dt_ns}")" || tx_r=""
                if [[ -n "${rx_r}" && -n "${tx_r}" ]]; then
                    parts+=("${_SYSINFO_GLYPH_NET} ${_SYSINFO_GLYPH_DOWN}$(_sysinfo_fmt_rate "${rx_r}") ${_SYSINFO_GLYPH_UP}$(_sysinfo_fmt_rate "${tx_r}")")
                fi
            fi
        fi
    fi

    # Load average (opt-in)
    if [[ "${_DOT_SYSTEM_INFO_SHOW_LOAD:-0}" == "1" ]]; then
        load="$(_sysinfo_read_load)"
        [[ -n "${load}" ]] && parts+=("${_SYSINFO_GLYPH_LOAD} ${load}")
    fi

    # Temperature (opt-in, only when a sensor exists)
    if [[ "${_DOT_SYSTEM_INFO_SHOW_TEMP:-0}" == "1" ]]; then
        temp="$(_sysinfo_read_temp)" || temp=""
        [[ -n "${temp}" ]] && parts+=("${_SYSINFO_GLYPH_TEMP} ${temp}°C")
    fi

    # Persist state for the next sample (best effort, atomic).
    if [[ -n "${cpu_now}" && -n "${iface:-}" && -n "${rx:-}" && -n "${tx:-}" ]]; then
        local ct ci
        read -r ct ci <<<"${cpu_now}"
        _sysinfo_write_atomic "${_SYSINFO_STATE_FILE}" \
            "TS=${now_ns}
IFACE=${iface}
RX=${rx}
TX=${tx}
CPU_TOTAL=${ct}
CPU_IDLE=${ci}
" || true
    fi

    # Join with separator.
    local out="" p
    for p in "${parts[@]:-}"; do
        if [[ -z "${out}" ]]; then
            out="${p}"
        else
            out+="${_SYSINFO_SEP} ${p}"
        fi
    done
    printf '%s' "${out}"
}

function _sysinfo_main() {
    _sysinfo_paths
    local force=0
    for arg in "$@"; do
        case "${arg}" in
            --collect) force=1 ;;
            --help|-h)
                printf 'Usage: system-info.sh [--collect]\n'
                return 0 ;;
        esac
    done

    if (( force == 0 )) && _sysinfo_cache_fresh; then
        cat "${_SYSINFO_CACHE_FILE}" 2>/dev/null || true
        return 0
    fi

    _sysinfo_load_state || true
    local out
    out="$(_sysinfo_collect)"
    _sysinfo_write_atomic "${_SYSINFO_CACHE_FILE}" "${out}" || true
    printf '%s' "${out}"
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _sysinfo_main "$@"
fi
