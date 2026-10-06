#!/usr/bin/env bash
#
# .wsl.sh — WSL-only ssh-agent bootstrap.
#
# Sourced by config/.custom.bashrc on every interactive shell (along with
# the other scripts/.*.sh libraries). Must stay silent and side-effect
# free on native Linux: it returns immediately when not running under WSL.

# Not sourced (executed directly): nothing to do.
[[ -n "${BASH_SOURCE[0]:-}" ]] || return 0 2>/dev/null || exit 0

# Already have an agent forwarded (e.g. Windows-side agent): keep it.
[[ -n "${SSH_AUTH_SOCK:-}" ]] && return 0 2>/dev/null || true

# WSL-only: $WSL_DISTRO_NAME / $WSL_INTEROP are set on WSL2, and
# /proc/version contains "Microsoft"/"WSL" on WSL1 and WSL2.
# A bare /mnt/c check is not enough (false positives on native Linux).
__dottod_is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] && return 0
    [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

if ! __dottod_is_wsl; then
    unset -f __dottod_is_wsl 2>/dev/null
    return 0 2>/dev/null || true
fi
unset -f __dottod_is_wsl 2>/dev/null

# From here on we are on WSL without SSH_AUTH_SOCK: ensure a usable agent.
command -v ssh-agent >/dev/null 2>&1 || return 0 2>/dev/null || true
command -v ssh-add >/dev/null 2>&1 || return 0 2>/dev/null || true

__dottod_wsl_agent_file="${HOME}/.ssh/ssh-agent"
mkdir -p "${HOME}/.ssh" 2>/dev/null || true

# Reuse the persisted agent when it still answers.
# ssh-add -l: 0 = keys loaded, 1 = agent running with no keys (both reusable),
# 2 = no agent reachable.
if [[ -s "${__dottod_wsl_agent_file}" ]]; then
    # shellcheck disable=SC1090 # persisted ssh-agent output by design
    eval "$(cat "${__dottod_wsl_agent_file}")" >/dev/null 2>&1 || true
    ssh-add -l >/dev/null 2>&1
    __dottod_wsl_ssh_add_status="$?"
    if [[ "${__dottod_wsl_ssh_add_status}" -eq 0 || "${__dottod_wsl_ssh_add_status}" -eq 1 ]]; then
        unset __dottod_wsl_agent_file __dottod_wsl_ssh_add_status 2>/dev/null || true
        return 0 2>/dev/null || true
    fi
    unset __dottod_wsl_ssh_add_status 2>/dev/null || true
fi

# No live agent: start one and persist its environment for the next shell.
if ssh-agent -s >"${__dottod_wsl_agent_file}" 2>/dev/null; then
    # shellcheck disable=SC1090 # just written above
    eval "$(cat "${__dottod_wsl_agent_file}")" >/dev/null 2>&1 || true
fi
unset __dottod_wsl_agent_file 2>/dev/null || true
return 0 2>/dev/null || true
