#!/usr/bin/env bash
#
# .container.utils.sh — shared container-runtime abstraction.
#
# Podman is dottod's default runtime; Docker is the supported alternative.
# All runtime branching lives here; consumers (bin/container.sh, shell
# helpers, the prompt) use these functions instead of scattering
# `command -v podman ... else docker ...` conditionals.
#
# Vocabulary:
#   configured = _DOT_CONTAINER_RUNTIME value (podman|docker|auto)
#   installed  = runtime binary present on PATH
#   usable     = works for the current user right now
#                (podman: rootless `podman info`; docker: daemon reachable)
#   selected   = resolution result actually used
#
# Selection policy:
#   explicit podman/docker -> that runtime, untouched. Usability problems
#     surface as loud errors in ensure/validate paths, never as silent
#     switches to the other runtime.
#   auto (or unset -> podman default) -> podman if usable, else docker if
#     usable, else podman (the install target).
#
# Shell compatibility: this file is sourced by bash (bin scripts, tests)
# AND by interactive zsh (scripts/*.sh glob). Keep it to portable
# constructs only: no arrays, no mapfile, no printf -v, no ${var,,},
# no [[ =~ ]], no %q. Sourcing must be side-effect free.

# Prints the normalized configured runtime (podman|docker|auto),
# defaulting to podman. Fails on invalid values.
function _ctr_configured() {
    local raw norm
    raw="${_DOT_CONTAINER_RUNTIME:-podman}"
    norm="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]')"
    case "${norm}" in
        podman|docker|auto)
            printf '%s' "${norm}"
            return 0
            ;;
        *)
            printf "dottod: invalid container runtime '%s' (want podman|docker|auto)\n" "${raw}" >&2
            return 1
            ;;
    esac
}

# _ctr_installed <podman|docker>: binary present on PATH.
function _ctr_installed() {
    case "${1:?'runtime required'}" in
        podman|docker) command -v "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# Usability probes. podman: rootless info must succeed as the current user
# (no sudo). docker: the daemon/socket must answer as the current user.
function _ctr_usable_podman() {
    _ctr_installed podman || return 1
    podman info >/dev/null 2>&1
}

function _ctr_usable_docker() {
    _ctr_installed docker || return 1
    docker info >/dev/null 2>&1
}

# _ctr_version <podman|docker>: prints the version number (e.g. 5.4.2).
function _ctr_version() {
    local out ver
    case "${1:?'runtime required'}" in
        podman) out="$(podman --version 2>/dev/null)" || return 1 ;;
        docker) out="$(docker --version 2>/dev/null)" || return 1 ;;
        *) return 1 ;;
    esac
    ver="$(printf '%s' "${out}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
    [[ -n "${ver}" ]] || return 1
    printf '%s' "${ver}"
}

# Cheap selection for latency-sensitive contexts (prompt): the configured
# value, or the podman default. No probing, no subprocess beyond tr.
# Displays the selection outcome, not a live probe. Fails on invalid config.
function _ctr_selected() {
    local cfg
    cfg="$(_ctr_configured)" || return 1
    case "${cfg}" in
        auto) printf 'podman' ;;
        *) printf '%s' "${cfg}" ;;
    esac
}

# Full resolution. Explicit values pass through untouched (usability is
# validated separately, loudly). Auto probes in Podman-first order.
function _ctr_resolve() {
    local cfg
    cfg="$(_ctr_configured)" || return 1
    case "${cfg}" in
        podman|docker)
            printf '%s' "${cfg}"
            ;;
        auto)
            if _ctr_usable_podman; then
                printf 'podman'
            elif _ctr_usable_docker; then
                printf 'docker'
            else
                printf 'podman'
            fi
            ;;
    esac
    return 0
}

# Interactive dispatcher: `ctr ps`, `ctr run ...` use the resolved runtime.
function ctr() {
    local rt
    rt="$(_ctr_resolve)" || return 1
    "${rt}" "$@"
}
