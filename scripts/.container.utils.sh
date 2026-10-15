#!/usr/bin/env bash
#
# .container.utils.sh — shared container-runtime helpers (Podman only).
#
# Consumers (bin/container.sh, the shell listing helpers) use these
# functions instead of probing podman themselves.
#
# Vocabulary:
#   installed  = podman binary present on PATH
#   usable     = rootless `podman info` works for the current user right now
#
# Shell compatibility: this file is sourced by bash task scripts, tests,
# and interactive shells (via config/.custom.bashrc). Keep it to portable
# constructs only: no arrays, no mapfile, no printf -v, no ${var,,},
# no [[ =~ ]], no %q. Sourcing must be side-effect free.

# _ctr_installed: podman present on PATH.
function _ctr_installed() {
    command -v podman >/dev/null 2>&1
}

# Usability probe: rootless info must succeed as the current user (no sudo).
function _ctr_usable() {
    _ctr_installed || return 1
    podman info >/dev/null 2>&1
}

# _ctr_version: prints the podman version number (e.g. 5.4.2).
function _ctr_version() {
    local out ver
    out="$(podman --version 2>/dev/null)" || return 1
    ver="$(printf '%s' "${out}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')" || return 1
    ver="${ver%%$'\n'*}"
    [[ -n "${ver}" ]] || return 1
    printf '%s' "${ver}"
}

# Interactive shorthand: `ctr ps`, `ctr run ...`.
function ctr() {
    podman "$@"
}

# _ctr_have_subids <user>: 0 when the user has subuid AND subgid ranges.
# subuid/subgid are plain shadow-utils files, not NSS databases (getent
# cannot see them), so they are read directly; a missing or unreadable
# file counts as no ranges. Overrides for tests:
# _DOT_CONTAINER_SUBUID_FILE / _DOT_CONTAINER_SUBGID_FILE.
function _ctr_have_subids() {
    local user=${1:?'User must be informed'}
    grep -q -- "^${user}:" "${_DOT_CONTAINER_SUBUID_FILE:-${_DOT_CTR_ROOT:-}/etc/subuid}" 2>/dev/null || return 1
    grep -q -- "^${user}:" "${_DOT_CONTAINER_SUBGID_FILE:-${_DOT_CTR_ROOT:-}/etc/subgid}" 2>/dev/null || return 1
    return 0
}

# _ctr_rootless_findings [user]: what rootless Podman needs from the host,
# one "ok|warn<TAB>message" line per check. Read-only: it reports and
# hints, it never changes sysctls, /etc/rc.conf or the subid files.
# _DOT_CTR_ROOT prefixes /proc, /sys, /run and /etc (tests).
function _ctr_rootless_findings() {
    local user=${1:-$(id -un)}
    local root=${_DOT_CTR_ROOT:-} v

    v="$(cat "${root}/proc/sys/user/max_user_namespaces" 2>/dev/null)" || v=''
    if [ "${v}" = '0' ]; then
        printf 'warn\tuser namespaces disabled: user.max_user_namespaces=0 (raise it with sysctl)\n'
    elif [ "$(cat "${root}/proc/sys/kernel/unprivileged_userns_clone" 2>/dev/null)" = '0' ]; then
        printf 'warn\tunprivileged user namespaces disabled: kernel.unprivileged_userns_clone=0\n'
    else
        printf 'ok\tuser namespaces available\n'
    fi

    if _ctr_have_subids "${user}"; then
        printf 'ok\tsubuid/subgid ranges for %s\n' "${user}"
    else
        printf 'warn\tno subuid/subgid ranges for %s (bin/container.sh allocates them)\n' "${user}"
    fi

    if command -v newuidmap >/dev/null 2>&1; then
        printf 'ok\tnewuidmap present\n'
    else
        printf 'warn\tnewuidmap missing (bin/container.sh installs the rootless helpers)\n'
    fi

    if [ -f "${root}/sys/fs/cgroup/cgroup.controllers" ]; then
        printf 'ok\tcgroup v2\n'
    elif [ -d "${root}/run/openrc" ]; then
        printf 'warn\tcgroup v1/hybrid under OpenRC: set rc_cgroup_mode="unified" in /etc/rc.conf, then reboot\n'
    else
        printf 'warn\tcgroup v1/hybrid: rootless Podman needs cgroup v2 (systemd.unified_cgroup_hierarchy=1)\n'
    fi
}
