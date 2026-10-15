#!/usr/bin/env bash
#
# .containers.sh — container listing helpers on the runtime dispatcher.
#
# Thin wrappers around scripts/.container.utils.sh: every command checks
# podman is installed and usable first, and fails loudly when it is not.
# Destructive commands confirm.

# _csh_ready: prints the runtime (podman) after verifying it is installed
# and usable right now; fails loudly otherwise (never a bare
# "command not found" from deep inside a listing).
_csh_ready() {
    _ctr_installed || {
        echo "containers: 'podman' not found on PATH (bin/container.sh installs it)" >&2
        return 1
    }
    _ctr_usable || {
        echo "containers: 'podman' is not usable right now" >&2
        return 1
    }
    printf 'podman'
}

# cps: running + stopped containers, compact table.
cps() {
    local rt
    rt="$(_csh_ready)" || return 1
    "${rt}" container ls -a --format 'table {{.ID}} | {{.Names}}\t | {{.State}}\t| {{.Ports}}' "$@"
}

# cimg: local images, compact table.
cimg() {
    local rt
    rt="$(_csh_ready)" || return 1
    "${rt}" image ls -a --format 'table {{.ID}} | {{.Tag}}\t | {{.Repository}}' "$@"
}

# cprune: drop unused containers, networks and images. Asks first unless
# --yes is given (never one typo away from a listing alias again).
cprune() {
    local rt answer
    rt="$(_csh_ready)" || return 1
    if [[ "${1:-}" == "--yes" ]]; then
        shift
    else
        printf 'cprune: run `%s system prune -af` (drops ALL unused data)? [y/N] ' "${rt}"
        read -r answer || return 1
        [[ "${answer}" == "y" || "${answer}" == "Y" ]] || {
            echo 'cprune: aborted'
            return 1
        }
    fi
    "${rt}" system prune -af "$@"
}

# csh <name> [cmd]: open a shell (or run cmd) in a running container.
csh() {
    local rt name
    rt="$(_csh_ready)" || return 1
    name="${1:?'usage: csh <container> [command]'}"
    shift
    if (($# > 0)); then
        "${rt}" exec -it "${name}" "$@"
    else
        "${rt}" exec -it "${name}" /bin/sh -c "command -v bash >/dev/null && exec bash || exec sh"
    fi
}

# clog <name>: follow a container's logs.
clog() {
    local rt
    rt="$(_csh_ready)" || return 1
    "${rt}" logs -f "${1:?'usage: clog <container>'}"
}
