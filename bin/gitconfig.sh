#!/usr/bin/env bash
#
# gitconfig.sh — dottod git task: ~/.gitconfig with the personal identity,
# plus ~/.gitconfig-work for repositories under ~/codes when it differs.
#
# Usage: gitconfig.sh [""] | status | --help|-h
#   ("")     write the git config (asks for a missing identity)
#   status   print the git report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _gitconfig_status() {
    local work_file="${HOME}/.gitconfig-work" work='none'
    if [[ -f "${work_file}" ]]; then
        work="$(git config --file "${work_file}" user.name 2>/dev/null || echo '?') <$(git config --file "${work_file}" user.email 2>/dev/null || echo '?')> (in ~/codes)"
    fi
    cat <<EOF
Git
---
Installed: $(command -v git >/dev/null 2>&1 && git --version 2>/dev/null || echo missing)
Config:    ${HOME}/.gitconfig ($(_dot_path_state "${HOME}/.gitconfig"))
Name:      $(git config --global user.name 2>/dev/null || echo '<unset>')
Email:     $(git config --global user.email 2>/dev/null || echo '<unset>')
Work:      ${work}
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: gitconfig.sh [status]

  (no args)  write ~/.gitconfig (GIT_NAME/GIT_EMAIL, or asked)
  status     print the git report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '') ;;
        status)
            _gitconfig_status
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

    local git_name=${GIT_NAME:-}
    local git_email=${GIT_EMAIL:-}

    [[ -z "${git_name}" ]] && git_name="$(git config --global user.name 2>/dev/null || true)"
    [[ -z "${git_email}" ]] && git_email="$(git config --global user.email 2>/dev/null || true)"

    if [[ -z "${git_name}" || -z "${git_email}" ]]; then
        log_step 'Git identity missing; please provide it'
    fi

    [[ -z "${git_name}" ]] && git_name="$(_prompt 'Git user.name' "$(id -un)")"
    [[ -z "${git_email}" ]] && git_email="$(_prompt 'Git user.email' '')"

    if [[ -z "${git_name}" || -z "${git_email}" ]]; then
        log_error 'Git name and email are required (set GIT_NAME/GIT_EMAIL or pass them interactively)'
        return 1
    fi

    # Work identity is optional and falls back to personal: env, then an
    # existing work file, then the personal values — never a prompt, so a
    # non-interactive run can't hang on it.
    local work_name=${GIT_WORK_NAME:-}
    local work_email=${GIT_WORK_EMAIL:-}
    local work_file="${HOME}/.gitconfig-work"
    [[ -z "${work_name}" ]] && work_name="$(git config --file "${work_file}" user.name 2>/dev/null || true)"
    [[ -z "${work_email}" ]] && work_email="$(git config --file "${work_file}" user.email 2>/dev/null || true)"
    [[ -z "${work_name}" ]] && work_name="${git_name}"
    [[ -z "${work_email}" ]] && work_email="${git_email}"

    local work_needed=0
    [[ "${work_name}" != "${git_name}" || "${work_email}" != "${git_email}" ]] && work_needed=1

    # Idempotent: skip only when the personal identity already matches AND,
    # when a distinct work identity is needed, the work file matches too.
    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || true)"
    current_email="$(git config --global user.email 2>/dev/null || true)"
    if [[ "${current_name}" == "${git_name}" && "${current_email}" == "${git_email}" ]]; then
        if [[ ${work_needed} -eq 0 ]]; then
            rm -f "${work_file}"
            log_info 'Git identity already set, skipping...'
            return 0
        fi
        if [[ "$(git config --file "${work_file}" user.name 2>/dev/null || true)" == "${work_name}" &&
        "$(git config --file "${work_file}" user.email 2>/dev/null || true)" == "${work_email}" ]]; then
            log_info 'Git identity already set, skipping...'
            return 0
        fi
    fi

    local target="${HOME}/.gitconfig"

    if [[ -e "${target}" || -L "${target}" ]]; then
        local backup="${target}.dottod.bak"
        log_warn "Backing up existing ${target} to ${backup}"
        mv -f "${target}" "${backup}"
    fi

    cp "${DOT_CONFIG_DIR}/.gitconfig" "${target}"
    {
        echo ''
        echo '[user]'
        echo "    name = ${git_name}"
        echo "    email = ${git_email}"
    } >>"${target}"

    if [[ ${work_needed} -eq 1 ]]; then
        {
            echo ''
            echo '[includeIf "gitdir:~/codes/**"]'
            echo '    path = ~/.gitconfig-work'
        } >>"${target}"
        if [[ -e "${work_file}" || -L "${work_file}" ]]; then
            local wbackup="${work_file}.dottod.bak"
            log_warn "Backing up existing ${work_file} to ${wbackup}"
            mv -f "${work_file}" "${wbackup}"
        fi
        {
            echo '[user]'
            echo "    name = ${work_name}"
            echo "    email = ${work_email}"
        } >"${work_file}"
    else
        rm -f "${work_file}"
    fi

    # Post-verification: the values must read back (a bare `git config`
    # write never fails loudly, so check instead of assuming).
    if [[ "$(git config --global user.name 2>/dev/null)" != "${git_name}" ]] ||
        [[ "$(git config --global user.email 2>/dev/null)" != "${git_email}" ]]; then
        log_error 'Git identity write could not be verified.'
        return 1
    fi
    if [[ ${work_needed} -eq 1 ]] &&
        { [[ "$(git config --file "${work_file}" user.name 2>/dev/null)" != "${work_name}" ]] ||
            [[ "$(git config --file "${work_file}" user.email 2>/dev/null)" != "${work_email}" ]]; }; then
        log_error 'Work identity write could not be verified.'
        return 1
    fi

    log_ok 'git config written'
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
