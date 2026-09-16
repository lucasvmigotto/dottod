#!/usr/bin/env bash
#
# container.sh — dottod container runtime task (Podman default, Docker
# alternative). Ensures the selected runtime is installed, configured and
# usable, without ever migrating or destroying the other runtime's setup.
#
# Selection: _DOT_CONTAINER_RUNTIME=podman|docker|auto (default: podman).
# An explicit selection is never silently switched; usability problems
# fail loudly with actionable messages.
#
# Usage: container.sh [status]
#   (no args)  ensure the selected runtime
#   status     print selection/installation/usability report (cheap probes)

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"
source "${DOT_REPO_ROOT}/scripts/.container.utils.sh"

function _usage() {
    cat <<'EOF'
Usage: container.sh [status]

Ensures dottod's container runtime (Podman by default, Docker when
explicitly selected via _DOT_CONTAINER_RUNTIME=podman|docker|auto).

  (no args)  install/configure/validate the selected runtime (idempotent)
  status     print the runtime report without changing anything
EOF
}

# Path to the explicit-Docker task script. Separate helper so tests can
# redirect it at a stub; production always uses the real bin/docker.sh.
function _container_docker_script() {
    printf '%s' "${DOT_REPO_ROOT}/bin/docker.sh"
}

function _podman_have_subids() {
    local user=${1:?'User must be informed'}
    [[ -n "$(getent subuid "${user}" 2>/dev/null)" \
        && -n "$(getent subgid "${user}" 2>/dev/null)" ]]
}

function _podman_ensure_subids() {
    local user=${1:?'User must be informed'}

    if _podman_have_subids "${user}"; then
        log_info "subuid/subgid already allocated for ${user}, skipping..."
        return 0
    fi

    log_step "Allocating subuid/subgid ranges for ${user}"
    if ! _priv usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "${user}"; then
        log_error 'Could not allocate subuid/subgid ranges.'
        log_error 'Rootless Podman needs them; ask an administrator to run:'
        log_error "  usermod --add-subuids 100000-165535 --add-subgids 100000-165535 ${user}"
        return 1
    fi
    log_ok "subuid/subgid allocated for ${user}"
    return 0
}

function _podman_ensure() {
    if _ctr_usable_podman; then
        log_info 'Podman already usable, skipping...'
        return 0
    fi

    if ! _ctr_installed podman; then
        log_step 'Installing Podman (uidmap for rootless operation)'
        _install_packages 'podman uidmap'
    fi

    _podman_ensure_subids "$(id -un)"

    if ! _ctr_usable_podman; then
        log_error 'Podman is installed but not usable rootlessly.'
        log_error 'Check user namespaces and subuid/subgid:'
        log_error '  getent subuid "$(id -un)"; podman info'
        return 1
    fi

    log_ok 'Podman ready (rootless)'
    return 0
}

function _docker_ensure() {
    local script
    script="$(_container_docker_script)"

    # Explicit Docker selection: the existing task owns installation and
    # group setup. Podman is never installed on this path.
    "${script}"

    if ! _ctr_usable_docker; then
        log_warn 'Docker is selected but its daemon is unreachable.'
        log_warn 'A fresh install needs a re-login (docker group) or a daemon restart.'
    fi
    return 0
}

function _container_ensure() {
    local runtime
    runtime="$(_ctr_resolve)" || return 1

    # No trailing `return 0`: the case result (ensure success/failure)
    # must propagate to the caller.
    case "${runtime}" in
        podman) _podman_ensure ;;
        docker) _docker_ensure ;;
    esac
}

function _container_status() {
    local configured selected
    configured="${_DOT_CONTAINER_RUNTIME:-<unset>}"
    if ! selected="$(_ctr_resolve)"; then
        return 1
    fi

    local podman_state='missing' docker_state='missing' rootless='n/a' usable='no'
    local ver
    if ver="$(_ctr_version podman 2>/dev/null)"; then
        podman_state="installed ${ver}"
    fi
    if ver="$(_ctr_version docker 2>/dev/null)"; then
        docker_state="installed ${ver}"
    fi
    if _ctr_usable_podman; then
        rootless='yes'
    elif _ctr_installed podman; then
        rootless='no'
    fi
    case "${selected}" in
        podman) _ctr_usable_podman && usable='yes' || true ;;
        docker) _ctr_usable_docker && usable='yes' || true ;;
    esac

    cat <<EOF
Container runtime
-----------------
Configured: ${configured} (default: podman)
Selected:   ${selected}
Podman:     ${podman_state}
Docker:     ${docker_state}
Rootless:   ${rootless}
Usable:     ${usable}
EOF
    return 0
}

function _main() {
    case "${1:-}" in
        '' )
            log_step 'Ensuring container runtime'
            _container_ensure
            log_ok 'Container runtime ready'
            return 0
            ;;
        status )
            _container_status
            return 0
            ;;
        --help|-h )
            _usage
            return 0
            ;;
        * )
            log_error "Unknown action: ${1} (want empty or 'status')"
            _usage
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
