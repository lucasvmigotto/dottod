#!/usr/bin/env bash
#
# gitconfig.sh — dottod git task: ~/.gitconfig with the personal identity
# (none with GIT_GLOBAL_IDENTITY=0), plus ~/.gitconfig-work holding the work
# identity that `gwork` applies to chosen repos (spec 016).
#
# Usage: gitconfig.sh [""] | status | --help|-h
#   ("")     write the git config (asks for a missing identity)
#   status   print the git report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _gitconfig_status() {
    local work_file="${HOME}/.gitconfig-work" work='none'
    if [[ -f "${work_file}" ]]; then
        work="$(git config --file "${work_file}" user.name 2>/dev/null || echo '?') <$(git config --file "${work_file}" user.email 2>/dev/null || echo '?')> (gwork)"
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

# An includeIf an older dottod wrote: it gave every repo under ~/codes the
# work identity. Its presence makes the task rewrite ~/.gitconfig.
function _gitconfig_has_include() {
    git config --file "${HOME}/.gitconfig" --get 'includeIf.gitdir:~/codes/**.path' >/dev/null 2>&1
}

# ~/.gitconfig-work: plain data for `gwork` (included by nothing). Written
# only from GIT_WORK_NAME + GIT_WORK_EMAIL; never prompted, never removed.
function _gitconfig_work() {
    local name=${GIT_WORK_NAME:-} email=${GIT_WORK_EMAIL:-}
    local file="${HOME}/.gitconfig-work"
    [[ -z "${name}" && -z "${email}" ]] && return 0
    if [[ -z "${name}" || -z "${email}" ]]; then
        log_error 'Set both GIT_WORK_NAME and GIT_WORK_EMAIL (or neither)'
        return 1
    fi
    if [[ "$(git config --file "${file}" user.name 2>/dev/null || true)" == "${name}" &&
    "$(git config --file "${file}" user.email 2>/dev/null || true)" == "${email}" ]]; then
        log_info 'Work identity already set, skipping...'
        return 0
    fi
    if [[ -e "${file}" || -L "${file}" ]]; then
        log_warn "Backing up existing ${file} to ${file}.dottod.bak"
        mv -f "${file}" "${file}.dottod.bak"
    fi
    {
        echo '# Work identity for gwork (scripts/.gwork.sh); included by nothing.'
        echo '[user]'
        echo "    name = ${name}"
        echo "    email = ${email}"
    } >"${file}"
    if [[ "$(git config --file "${file}" user.email 2>/dev/null || true)" != "${email}" ]]; then
        log_error 'Work identity write could not be verified.'
        return 1
    fi
    log_ok 'work identity written to ~/.gitconfig-work'
}

function _usage() {
    cat <<'EOF'
Usage: gitconfig.sh [status]

  (no args)  write ~/.gitconfig (GIT_NAME/GIT_EMAIL, or asked;
             GIT_GLOBAL_IDENTITY=0 writes no global identity) and, with
             GIT_WORK_NAME/GIT_WORK_EMAIL, ~/.gitconfig-work for gwork
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

    local global="${GIT_GLOBAL_IDENTITY:-1}"
    if [[ "${global}" != 0 && "${global}" != 1 ]]; then
        log_error "GIT_GLOBAL_IDENTITY must be 0 or 1, got '${global}'"
        return 1
    fi

    _gitconfig_work || return 1

    local git_name='' git_email=''
    if [[ "${global}" == 1 ]]; then
        git_name=${GIT_NAME:-}
        git_email=${GIT_EMAIL:-}
        [[ -z "${git_name}" ]] && git_name="$(git config --global user.name 2>/dev/null || true)"
        [[ -z "${git_email}" ]] && git_email="$(git config --global user.email 2>/dev/null || true)"

        if [[ -z "${git_name}" || -z "${git_email}" ]]; then
            log_step 'Git identity missing; please provide it'
        fi

        [[ -z "${git_name}" ]] && git_name="$(_prompt 'Git user.name' "$(id -un)")"
        [[ -z "${git_email}" ]] && git_email="$(_prompt 'Git user.email' '')"

        if [[ -z "${git_name}" || -z "${git_email}" ]]; then
            log_error 'Git name and email are required (set GIT_NAME/GIT_EMAIL, pass them interactively, or GIT_GLOBAL_IDENTITY=0 for none)'
            return 1
        fi
    fi

    local target="${HOME}/.gitconfig"

    # Idempotent: skip when the global identity is already what was asked
    # for (none, with GIT_GLOBAL_IDENTITY=0) and no includeIf from an older
    # dottod is left behind.
    if [[ -f "${target}" ]] && ! _gitconfig_has_include &&
        [[ "$(git config --global user.name 2>/dev/null || true)" == "${git_name}" &&
        "$(git config --global user.email 2>/dev/null || true)" == "${git_email}" ]]; then
        log_info 'Git identity already set, skipping...'
        return 0
    fi

    if [[ -e "${target}" || -L "${target}" ]]; then
        local backup="${target}.dottod.bak"
        log_warn "Backing up existing ${target} to ${backup}"
        mv -f "${target}" "${backup}"
    fi

    cp "${DOT_CONFIG_DIR}/.gitconfig" "${target}"
    if [[ "${global}" == 1 ]]; then
        {
            echo ''
            echo '[user]'
            echo "    name = ${git_name}"
            echo "    email = ${git_email}"
        } >>"${target}"
    fi

    # Post-verification: the values must read back (a bare `git config`
    # write never fails loudly, so check instead of assuming).
    if [[ "$(git config --global user.name 2>/dev/null || true)" != "${git_name}" ]] ||
        [[ "$(git config --global user.email 2>/dev/null || true)" != "${git_email}" ]]; then
        log_error 'Git identity write could not be verified.'
        return 1
    fi

    if [[ "${global}" == 1 ]]; then
        log_ok 'git config written'
    else
        log_ok 'git config written without a global identity (set one per repo, or gwork set)'
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
