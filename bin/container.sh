#!/usr/bin/env bash
#
# container.sh — dottod container runtime task (rootless Podman). Ensures
# Podman is installed, configured and usable; usability problems fail
# loudly with actionable messages.
#
# Usage: container.sh [status]
#   (no args)  ensure Podman
#   status     print selection/installation/usability report (cheap probes)

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"
source "${DOT_REPO_ROOT}/scripts/.container.utils.sh"

function _usage() {
    cat <<'EOF'
Usage: container.sh [status]

Ensures dottod's container runtime (rootless Podman).

  (no args)  install/configure/validate Podman (idempotent)
  status     print the runtime report without changing anything
EOF
}

# subuid/subgid are plain shadow-utils files, NOT NSS databases, so `getent`
# cannot see them ("Unknown database"). Read the files directly; a missing
# or unreadable file counts as missing ranges. Paths are overridable for
# tests (_DOT_CONTAINER_SUBUID_FILE / _DOT_CONTAINER_SUBGID_FILE).
function _podman_have_subids() {
    local user=${1:?'User must be informed'}
    local subuid_file=${_DOT_CONTAINER_SUBUID_FILE:-/etc/subuid}
    local subgid_file=${_DOT_CONTAINER_SUBGID_FILE:-/etc/subgid}
    # Contract: 0 = ranges present, 1 = absent for any reason (no match,
    # missing or unreadable file — grep itself exits 2 on file errors).
    grep -q -- "^${user}:" "${subuid_file}" 2>/dev/null || return 1
    grep -q -- "^${user}:" "${subgid_file}" 2>/dev/null || return 1
    return 0
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
    if _ctr_usable; then
        log_info 'Podman already usable, skipping...'
        return 0
    fi

    if ! _ctr_installed; then
        log_step 'Installing Podman (uidmap for rootless operation)'
        _install_packages podman podman_rootless
    fi

    _podman_ensure_subids "$(id -un)"

    if ! _ctr_usable; then
        log_error 'Podman is installed but not usable rootlessly.'
        log_error 'Check user namespaces and subuid/subgid:'
        log_error '  grep "^$(id -un):" /etc/subuid /etc/subgid; podman info'
        return 1
    fi

    log_ok 'Podman ready (rootless)'
    return 0
}

function _container_status() {
    local podman_state='missing' rootless='no' ver
    if ver="$(_ctr_version 2>/dev/null)"; then
        podman_state="installed ${ver}"
    fi
    _ctr_usable && rootless='yes' || true

    cat <<EOF
Container runtime
-----------------
Podman:     ${podman_state}
Rootless:   ${rootless}
EOF
    return 0
}

function _main() {
    case "${1:-}" in
        '')
            log_step 'Ensuring container runtime'
            _podman_ensure
            log_ok 'Container runtime ready'
            return 0
            ;;
        status)
            _container_status
            return 0
            ;;
        --help | -h)
            _usage
            return 0
            ;;
        *)
            log_error "Unknown action: ${1} (want empty or 'status')"
            _usage
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
