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
