#!/usr/bin/env bash
#
# test-system-info.sh — hermetic tests for scripts/system-info.sh
# Uses fixture files + _DOT_SYSINFO_* overrides; never touches real /proc.
# Sourcing contract: `source system-info.sh` must NOT run main (guarded by
# BASH_SOURCE check) and must NOT fail under `set -u`.

set -uo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PASS=0
_FAIL=0

function assert_eq() {
    local desc=${1} expected=${2} actual=${3}
    if [[ "${expected}" == "${actual}" ]]; then
        _PASS=$((_PASS + 1))
    else
        _FAIL=$((_FAIL + 1))
        printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "${desc}" "${expected}" "${actual}" >&2
    fi
}

function assert_match() {
    local desc=${1} pattern=${2} actual=${3}
    if [[ "${actual}" =~ ${pattern} ]]; then
        _PASS=$((_PASS + 1))
    else
        _FAIL=$((_FAIL + 1))
        printf 'FAIL: %s\n  pattern: %s\n  actual:  %q\n' "${desc}" "${pattern}" "${actual}" >&2
    fi
}

# Isolated cache + fixtures. NOTE: _DOT_SYSINFO_* input paths are captured by
# system-info.sh at source time, so every override must be exported BEFORE
# sourcing it below.
export _DOT_SYSINFO_CACHE_DIR="$(mktemp -d)"
_FIX="$(mktemp -d)"
trap 'rm -rf "${_DOT_SYSINFO_CACHE_DIR}" "${_FIX}"' EXIT

export _DOT_SYSINFO_PROC_STAT="${_FIX}/stat"
export _DOT_SYSINFO_PROC_MEMINFO="${_FIX}/meminfo"
export _DOT_SYSINFO_PROC_NET_DEV="${_FIX}/netdev"
export _DOT_SYSINFO_PROC_NET_ROUTE="${_FIX}/route"
export _DOT_SYSINFO_PROC_LOADAVG="${_FIX}/loadavg"
export _DOT_SYSINFO_SYS_DIR="${_FIX}/sys"

# shellcheck disable=SC1091
source "${_TEST_DIR}/../scripts/system-info.sh"

# --- formatting -------------------------------------------------------------
assert_eq 'bytes 0' '0' "$(_sysinfo_fmt_bytes 0)"
assert_eq 'bytes 512' '512' "$(_sysinfo_fmt_bytes 512)"
assert_eq 'bytes 1023' '1023' "$(_sysinfo_fmt_bytes 1023)"
assert_eq 'bytes 1K' '1.0K' "$(_sysinfo_fmt_bytes 1024)"
assert_eq 'bytes 12.4M' '12.4M' "$(_sysinfo_fmt_bytes 13002342)"
assert_eq 'bytes GiB' '7.8G' "$(_sysinfo_fmt_bytes 8375186227)"
assert_eq 'rate' '1.8M/s' "$(_sysinfo_fmt_rate 1887436)"
assert_eq 'gib' '15.6' "$(_sysinfo_fmt_gib 16384000)"

# --- cpu --------------------------------------------------------------------
cat >"${_FIX}/stat1" <<'EOF'
cpu  100 0 100 800 0 0 0 0 0 0
EOF
cat >"${_FIX}/stat2" <<'EOF'
cpu  150 0 150 900 0 0 0 0 0 0
EOF
export _DOT_SYSINFO_PROC_STAT="${_FIX}/stat1"
read -r t1 i1 <<<"$(_sysinfo_read_cpu)"
assert_eq 'cpu totals snap1' '1000 800' "${t1} ${i1}"
export _DOT_SYSINFO_PROC_STAT="${_FIX}/stat2"
read -r t2 i2 <<<"$(_sysinfo_read_cpu)"
assert_eq 'cpu pct 50%' '50' "$(_sysinfo_cpu_pct "${t1}" "${i1}" "${t2}" "${i2}")"
if _sysinfo_cpu_pct "${t2}" "${i2}" "${t2}" "${i2}" >/dev/null 2>&1; then
    _FAIL=$((_FAIL + 1)); printf 'FAIL: zero-delta cpu must fail\n' >&2
else
    _PASS=$((_PASS + 1))
fi

# --- mem --------------------------------------------------------------------
cat >"${_FIX}/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemFree:         2000000 kB
MemAvailable:    8192000 kB
EOF
export _DOT_SYSINFO_PROC_MEMINFO="${_FIX}/meminfo"
assert_eq 'mem used/total/pct' '8192000 16384000 50' "$(_sysinfo_read_mem)"

# --- net --------------------------------------------------------------------
cat >"${_FIX}/route" <<'EOF'
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
eth0	00000000	0101A8C0	0003	0	0	100	00000000	0	0	0
wlan0	0001A8C0	00000000	0001	0	0	100	00FFFFFF	0	0	0
EOF
cat >"${_FIX}/netdev" <<'EOF'
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 100 0 0 0 0 0 0 0 100 0 0 0 0 0 0 0
  eth0: 1000000 0 0 0 0 0 0 0 2000000 0 0 0 0 0 0 0
EOF
export _DOT_SYSINFO_PROC_NET_ROUTE="${_FIX}/route"
export _DOT_SYSINFO_PROC_NET_DEV="${_FIX}/netdev"
assert_eq 'default iface' 'eth0' "$(_sysinfo_default_iface)"
assert_eq 'iface bytes' '1000000 2000000' "$(_sysinfo_read_iface_bytes eth0)"
assert_eq 'rate 1MB/s' '1000000' "$(_sysinfo_rate 1000000 2000000 1000000000)"
if _sysinfo_rate 2000000 1000000 1000000000 >/dev/null 2>&1; then
    _FAIL=$((_FAIL + 1)); printf 'FAIL: counter reset must fail\n' >&2
else
    _PASS=$((_PASS + 1))
fi
# no default route -> first non-lo iface
cat >"${_FIX}/route2" <<'EOF'
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
EOF
export _DOT_SYSINFO_PROC_NET_ROUTE="${_FIX}/route2"
assert_eq 'fallback iface' 'eth0' "$(_sysinfo_default_iface)"

# --- load / temp ------------------------------------------------------------
printf '0.42 0.31 0.15 1/234 5678\n' >"${_FIX}/loadavg"
export _DOT_SYSINFO_PROC_LOADAVG="${_FIX}/loadavg"
assert_eq 'load' '0.42' "$(_sysinfo_read_load)"

mkdir -p "${_FIX}/sys/class/thermal/thermal_zone0" "${_FIX}/sys/class/hwmon/hwmon0"
printf '54000' >"${_FIX}/sys/class/thermal/thermal_zone0/temp"
printf '48000' >"${_FIX}/sys/class/hwmon/hwmon0/temp1_input"
export _DOT_SYSINFO_SYS_DIR="${_FIX}/sys"
assert_eq 'temp max' '54' "$(_sysinfo_read_temp)"
rm -rf "${_FIX}/sys"
if _sysinfo_read_temp >/dev/null 2>&1; then
    _FAIL=$((_FAIL + 1)); printf 'FAIL: missing sensors must fail\n' >&2
else
    _PASS=$((_PASS + 1))
fi
unset _DOT_SYSINFO_SYS_DIR
export _DOT_SYSINFO_PROC_NET_ROUTE="${_FIX}/route"

# --- end-to-end: cold run has RAM, no CPU/net --------------------------------
export _DOT_SYSINFO_NOW_NS="1000000000000"
out="$(_sysinfo_main --collect)"
assert_match 'cold run shows mem pct' '50%' "${out}"
if [[ "${out}" == *"% "* ]] && [[ "${out}" == *"↓"* ]]; then
    : # both present only if state existed; cold run must NOT have them
    _FAIL=$((_FAIL + 1)); printf 'FAIL: cold run must not show cpu/net rates: %q\n' "${out}" >&2
else
    _PASS=$((_PASS + 1))
fi

# --- second sample: cpu + net appear ----------------------------------------
cat >"${_FIX}/stat3" <<'EOF'
cpu  200 0 200 1000 0 0 0 0 0 0
EOF
cat >"${_FIX}/netdev2" <<'EOF'
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  eth0: 3000000 0 0 0 0 0 0 0 5000000 0 0 0 0 0 0 0
EOF
export _DOT_SYSINFO_PROC_STAT="${_FIX}/stat3"
export _DOT_SYSINFO_PROC_NET_DEV="${_FIX}/netdev2"
export _DOT_SYSINFO_NOW_NS="1002000000000"
out="$(_sysinfo_main --collect)"
assert_match 'warm run shows cpu' '50%' "${out}"
assert_match 'warm run shows net' '↓.*↑' "${out}"

# --- cache: fresh cache wins without readable inputs ------------------------
export _DOT_SYSINFO_PROC_STAT=/nonexistent _DOT_SYSINFO_PROC_MEMINFO=/nonexistent
export _DOT_SYSINFO_PROC_NET_DEV=/nonexistent _DOT_SYSINFO_PROC_NET_ROUTE=/nonexistent
export _DOT_SYSINFO_PROC_LOADAVG=/nonexistent
cached="$(_sysinfo_main)"
assert_eq 'fresh cache passthrough' "${out}" "${cached}"

# --- cache: corrupt cache is ignored, missing inputs -> empty but rc 0 -----
printf 'not a cache{{{' >"${_DOT_SYSINFO_CACHE_DIR}/sysinfo.cache"
touch -d '10 seconds ago' "${_DOT_SYSINFO_CACHE_DIR}/sysinfo.cache"
rm -f "${_DOT_SYSINFO_CACHE_DIR}/sysinfo.state"
out2="$(_sysinfo_main)"
rc=$?
assert_eq 'corrupt+missing rc 0' '0' "${rc}"
assert_eq 'corrupt+missing empty' '' "${out2}"

printf 'tests: %d passed, %d failed\n' "${_PASS}" "${_FAIL}"
exit $(( _FAIL > 0 ))
