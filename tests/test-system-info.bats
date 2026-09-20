#!/usr/bin/env bats
#
# test-system-info.bats — hermetic tests for scripts/system-info.sh.
# Fixture files + _DOT_SYSINFO_* overrides; never touches real /proc.
# Sourcing contract: `source system-info.sh` must NOT run main (guarded by
# BASH_SOURCE check). Each test is hermetic: fresh cache, fixtures and
# state via setup(), no ordering coupling between tests.

load helpers

setup() {
    FIX="$BATS_TEST_TMPDIR/fix"
    mkdir -p "$FIX"
    export _DOT_SYSINFO_CACHE_DIR="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$_DOT_SYSINFO_CACHE_DIR"
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat"
    export _DOT_SYSINFO_PROC_MEMINFO="$FIX/meminfo"
    export _DOT_SYSINFO_PROC_NET_DEV="$FIX/netdev"
    export _DOT_SYSINFO_PROC_NET_ROUTE="$FIX/route"
    export _DOT_SYSINFO_PROC_LOADAVG="$FIX/loadavg"
    export _DOT_SYSINFO_SYS_DIR="$FIX/sys"
    unset _DOT_SYSINFO_NOW_NS
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/system-info.sh"
    # The library enables `set -u`; drop it so the framework teardown
    # never trips on an unset variable. Guarded expansions keep the
    # code under test exact.
    set +u
}

@test "formatting: bytes, rates and gibibytes" {
    assert_eq 'bytes 0' '0' "$(_sysinfo_fmt_bytes 0)"
    assert_eq 'bytes 512' '512' "$(_sysinfo_fmt_bytes 512)"
    assert_eq 'bytes 1023' '1023' "$(_sysinfo_fmt_bytes 1023)"
    assert_eq 'bytes 1K' '1.0K' "$(_sysinfo_fmt_bytes 1024)"
    assert_eq 'bytes 12.4M' '12.4M' "$(_sysinfo_fmt_bytes 13002342)"
    assert_eq 'bytes GiB' '7.8G' "$(_sysinfo_fmt_bytes 8375186227)"
    assert_eq 'rate' '1.8M/s' "$(_sysinfo_fmt_rate 1887436)"
    assert_eq 'gib' '15.6' "$(_sysinfo_fmt_gib 16384000)"
}

@test "cpu: totals, utilization and zero-delta guard" {
    cat >"$FIX/stat1" <<'EOF'
cpu  100 0 100 800 0 0 0 0 0 0
EOF
    cat >"$FIX/stat2" <<'EOF'
cpu  150 0 150 900 0 0 0 0 0 0
EOF
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat1"
    read -r t1 i1 <<<"$(_sysinfo_read_cpu)"
    assert_eq 'cpu totals snap1' '1000 800' "$t1 $i1"
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat2"
    read -r t2 i2 <<<"$(_sysinfo_read_cpu)"
    assert_eq 'cpu pct 50%' '50' "$(_sysinfo_cpu_pct "$t1" "$i1" "$t2" "$i2")"
    run _sysinfo_cpu_pct "$t2" "$i2" "$t2" "$i2"
    assert_eq 'zero-delta cpu fails' '1' "$status"
}

@test "mem: used, total and percent from meminfo" {
    cat >"$FIX/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemFree:         2000000 kB
MemAvailable:    8192000 kB
EOF
    export _DOT_SYSINFO_PROC_MEMINFO="$FIX/meminfo"
    assert_eq 'mem used/total/pct' '8192000 16384000 50' "$(_sysinfo_read_mem)"
}

@test "net: default iface, counters, rates, reset guard and fallback" {
    cat >"$FIX/route" <<'EOF'
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
eth0	00000000	0101A8C0	0003	0	0	100	00000000	0	0	0
wlan0	0001A8C0	00000000	0001	0	0	100	00FFFFFF	0	0	0
EOF
    cat >"$FIX/netdev" <<'EOF'
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 100 0 0 0 0 0 0 0 100 0 0 0 0 0 0 0
  eth0: 1000000 0 0 0 0 0 0 0 2000000 0 0 0 0 0 0 0
EOF
    export _DOT_SYSINFO_PROC_NET_ROUTE="$FIX/route"
    export _DOT_SYSINFO_PROC_NET_DEV="$FIX/netdev"
    assert_eq 'default iface' 'eth0' "$(_sysinfo_default_iface)"
    assert_eq 'iface bytes' '1000000 2000000' "$(_sysinfo_read_iface_bytes eth0)"
    assert_eq 'rate 1MB/s' '1000000' "$(_sysinfo_rate 1000000 2000000 1000000000)"
    run _sysinfo_rate 2000000 1000000 1000000000
    assert_eq 'counter reset fails' '1' "$status"
    printf 'Iface\tDestination\n' >"$FIX/route2"
    export _DOT_SYSINFO_PROC_NET_ROUTE="$FIX/route2"
    assert_eq 'fallback iface' 'eth0' "$(_sysinfo_default_iface)"
}

@test "load and temperature, including absent sensors" {
    printf '0.42 0.31 0.15 1/234 5678\n' >"$FIX/loadavg"
    export _DOT_SYSINFO_PROC_LOADAVG="$FIX/loadavg"
    assert_eq 'load' '0.42' "$(_sysinfo_read_load)"
    mkdir -p "$FIX/sys/class/thermal/thermal_zone0" "$FIX/sys/class/hwmon/hwmon0"
    printf '54000' >"$FIX/sys/class/thermal/thermal_zone0/temp"
    printf '48000' >"$FIX/sys/class/hwmon/hwmon0/temp1_input"
    export _DOT_SYSINFO_SYS_DIR="$FIX/sys"
    assert_eq 'temp max' '54' "$(_sysinfo_read_temp)"
    rm -rf "$FIX/sys"
    run _sysinfo_read_temp
    assert_eq 'missing sensors fail' '1' "$status"
}

@test "cold run shows RAM (no pct/net by default) and persists CPU state" {
    cat >"$FIX/stat1" <<'EOF'
cpu  100 0 100 800 0 0 0 0 0 0
EOF
    cat >"$FIX/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:    8192000 kB
EOF
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat1"
    export _DOT_SYSINFO_PROC_MEMINFO="$FIX/meminfo"
    export _DOT_SYSINFO_NOW_NS="1000000000000"
    # Net fixtures deliberately absent: net is opt-in and must not be required.
    export _DOT_SYSINFO_PROC_NET_DEV=/nonexistent
    export _DOT_SYSINFO_PROC_NET_ROUTE=/nonexistent
    out="$(_sysinfo_main --collect)"
    assert_match 'cold run shows mem used/total' '7\.8/15\.6' "$out"
    if [[ "$out" == *'%'* || "$out" == *"↓"* ]]; then
        printf 'FAIL: cold run must not show pct/net by default: %q\n' "$out" >&2
        return 1
    fi
    # Regression: CPU state must persist even without net data (the state
    # write was historically gated on iface/rx/tx, so SHOW_NET=0 killed CPU %).
    assert_match 'state file persists cpu totals' 'CPU_TOTAL=1000' "$(cat "$_DOT_SYSINFO_CACHE_DIR/sysinfo.state")"
    assert_match 'state file persists cpu idle' 'CPU_IDLE=800' "$(cat "$_DOT_SYSINFO_CACHE_DIR/sysinfo.state")"
}

@test "second collect shows CPU % from persisted state (net disabled)" {
    cat >"$FIX/stat1" <<'EOF'
cpu  100 0 100 800 0 0 0 0 0 0
EOF
    cat >"$FIX/stat2" <<'EOF'
cpu  150 0 150 900 0 0 0 0 0 0
EOF
    cat >"$FIX/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:    8192000 kB
EOF
    export _DOT_SYSINFO_PROC_MEMINFO="$FIX/meminfo"
    export _DOT_SYSINFO_PROC_NET_DEV=/nonexistent
    export _DOT_SYSINFO_PROC_NET_ROUTE=/nonexistent
    # First sample at t=1e12 ns.
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat1"
    export _DOT_SYSINFO_NOW_NS="1000000000000"
    _sysinfo_main --collect >/dev/null
    # Second sample 2s later: CPU 50%, still no net by default.
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat2"
    export _DOT_SYSINFO_NOW_NS="1002000000000"
    out="$(_sysinfo_main --collect)"
    assert_match 'second run shows cpu pct' '50%' "$out"
    if [[ "$out" == *"↓"* ]]; then
        printf 'FAIL: net must stay hidden without SHOW_NET=1: %q\n' "$out" >&2
        return 1
    fi
}

@test "warm run shows cpu percent and net throughput when opted in" {
    cat >"$FIX/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:    8192000 kB
EOF
    export _DOT_SYSINFO_PROC_MEMINFO="$FIX/meminfo"
    cat >"$FIX/stat2" <<'EOF'
cpu  150 0 150 900 0 0 0 0 0 0
EOF
    cat >"$FIX/netdev2" <<'EOF'
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  eth0: 3000000 0 0 0 0 0 0 0 5000000 0 0 0 0 0 0 0
EOF
    cat >"$FIX/route" <<'EOF'
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
eth0	00000000	0101A8C0	0003	0	0	100	00000000	0	0	0
EOF
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat2"
    export _DOT_SYSINFO_PROC_NET_DEV="$FIX/netdev2"
    export _DOT_SYSINFO_PROC_NET_ROUTE="$FIX/route"
    # Seeded previous sample: cpu total 1000/idle 800 at t=1e12 ns.
    printf 'TS=1000000000000\nIFACE=eth0\nRX=1000000\nTX=2000000\nCPU_TOTAL=1000\nCPU_IDLE=800\n' \
        >"$_DOT_SYSINFO_CACHE_DIR/sysinfo.state"
    export _DOT_SYSINFO_NOW_NS="1002000000000"
    export _DOT_SYSTEM_INFO_SHOW_NET=1
    out="$(_sysinfo_main --collect)"
    assert_match 'warm run shows cpu' '50%' "$out"
    assert_match 'warm run shows net' '↓.*↑' "$out"
    unset _DOT_SYSTEM_INFO_SHOW_NET
}

@test "mem pct is opt-in via SHOW_MEM_PCT" {
    cat >"$FIX/stat1" <<'EOF'
cpu  100 0 100 800 0 0 0 0 0 0
EOF
    cat >"$FIX/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemAvailable:    8192000 kB
EOF
    export _DOT_SYSINFO_PROC_STAT="$FIX/stat1"
    export _DOT_SYSINFO_PROC_MEMINFO="$FIX/meminfo"
    export _DOT_SYSINFO_PROC_NET_DEV=/nonexistent
    export _DOT_SYSINFO_PROC_NET_ROUTE=/nonexistent
    export _DOT_SYSINFO_NOW_NS="1000000000000"
    export _DOT_SYSTEM_INFO_SHOW_MEM_PCT=1
    out="$(_sysinfo_main --collect)"
    assert_match 'mem pct when opted in' '7\.8/15\.6 50%' "$out"
    unset _DOT_SYSTEM_INFO_SHOW_MEM_PCT
}

@test "fresh cache is served without readable inputs" {
    printf 'CACHED-LINE' >"$_DOT_SYSINFO_CACHE_DIR/sysinfo.cache"
    export _DOT_SYSINFO_PROC_STAT=/nonexistent _DOT_SYSINFO_PROC_MEMINFO=/nonexistent
    export _DOT_SYSINFO_PROC_NET_DEV=/nonexistent _DOT_SYSINFO_PROC_NET_ROUTE=/nonexistent
    export _DOT_SYSINFO_PROC_LOADAVG=/nonexistent
    assert_eq 'fresh cache passthrough' 'CACHED-LINE' "$(_sysinfo_main)"
}

@test "corrupt cache with missing inputs yields empty output, rc 0" {
    printf 'not a cache{{{' >"$_DOT_SYSINFO_CACHE_DIR/sysinfo.cache"
    touch -d '10 seconds ago' "$_DOT_SYSINFO_CACHE_DIR/sysinfo.cache"
    export _DOT_SYSINFO_PROC_STAT=/nonexistent _DOT_SYSINFO_PROC_MEMINFO=/nonexistent
    export _DOT_SYSINFO_PROC_NET_DEV=/nonexistent _DOT_SYSINFO_PROC_NET_ROUTE=/nonexistent
    export _DOT_SYSINFO_PROC_LOADAVG=/nonexistent
    run _sysinfo_main
    assert_eq 'corrupt+missing rc 0' '0' "$status"
    assert_eq 'corrupt+missing empty' '' "$output"
}
