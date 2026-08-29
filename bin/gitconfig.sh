#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _main() {
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
    } >> "${target}"

    log_ok 'git config written'
    return 0
}

_main "$@"
