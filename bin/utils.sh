#!/usr/bin/env bash

set -Eeuo pipefail

DOT_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOT_REPO_ROOT
# Consumed by the scripts that source this file (e.g. bin/ssh.sh,
# bin/gitconfig.sh); shellcheck only sees this file in isolation.
# shellcheck disable=SC2034
readonly DOT_CONFIG_DIR="${DOT_REPO_ROOT}/config"
readonly DOT_LOG_DIR="/tmp/dottod"

mkdir -p "${DOT_LOG_DIR}"

# Platform detection and package backends (spec 015): definitions only;
# nothing runs on source.
# shellcheck source=../lib/os.sh
source "${DOT_REPO_ROOT}/lib/os.sh"
# shellcheck source=../lib/package.sh
source "${DOT_REPO_ROOT}/lib/package.sh"
# shellcheck source=../lib/packages/debian.sh
source "${DOT_REPO_ROOT}/lib/packages/debian.sh"
# shellcheck source=../lib/packages/gentoo.sh
source "${DOT_REPO_ROOT}/lib/packages/gentoo.sh"
# shellcheck source=../lib/packages/arch.sh
source "${DOT_REPO_ROOT}/lib/packages/arch.sh"
# shellcheck source=../lib/packages/redhat.sh
source "${DOT_REPO_ROOT}/lib/packages/redhat.sh"
# shellcheck source=../lib/packages/alpine.sh
source "${DOT_REPO_ROOT}/lib/packages/alpine.sh"

function _color_supported() {
    [[ -n "${DOT_FORCE_COLOR:-}" ]] && return 0
    [[ -n "${NO_COLOR:-}" ]] && return 1
    [[ -t 2 ]] || return 1
    case "${TERM:-}" in
        '' | dumb) return 1 ;;
    esac
    if command -v tput >/dev/null 2>&1; then
        [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]] || return 1
    fi
    return 0
}

if _color_supported; then
    readonly DOT_C_RESET=$'\033[0m'
    readonly DOT_C_BOLD=$'\033[1m'
    readonly DOT_C_RED=$'\033[31m'
    readonly DOT_C_GREEN=$'\033[32m'
    readonly DOT_C_YELLOW=$'\033[33m'
    readonly DOT_C_BLUE=$'\033[34m'
    readonly DOT_C_CYAN=$'\033[36m'
    readonly DOT_SYM_STEP='▶'
    readonly DOT_SYM_INFO='›'
    readonly DOT_SYM_OK='✔'
    readonly DOT_SYM_WARN='⚠'
    readonly DOT_SYM_ERR='✗'
else
    readonly DOT_C_RESET=''
    readonly DOT_C_BOLD=''
    readonly DOT_C_RED=''
    readonly DOT_C_GREEN=''
    readonly DOT_C_YELLOW=''
    readonly DOT_C_BLUE=''
    readonly DOT_C_CYAN=''
    readonly DOT_SYM_STEP='==>'
    readonly DOT_SYM_INFO='->'
    readonly DOT_SYM_OK='OK'
    readonly DOT_SYM_WARN='!!'
    readonly DOT_SYM_ERR='XX'
fi

function log_step() { printf "${DOT_C_BOLD}${DOT_C_CYAN}${DOT_SYM_STEP} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_info() { printf "${DOT_C_BLUE}  ${DOT_SYM_INFO} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_ok() { printf "${DOT_C_GREEN}  ${DOT_SYM_OK} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_warn() { printf "${DOT_C_YELLOW}  ${DOT_SYM_WARN} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_error() { printf "${DOT_C_RED}  ${DOT_SYM_ERR} %s${DOT_C_RESET}\n" "$*" >&2; }

readonly DOT_SUDO_PASS_FILE="${DOT_LOG_DIR}/.sudo-pass"
readonly DOT_SUDO_ASKPASS_FILE="${DOT_LOG_DIR}/.sudo-askpass.sh"

_DOT_SUDO_TOOL=''
_DOT_SUDO_READY=0
_DOT_SUDO_ASKPASS_MODE=0
_DOT_SUDO_OWNS_ASKPASS=0
_POWER_GIVER_TOOL=''

function _sudo_cleanup() {
    if [[ "${_DOT_SUDO_OWNS_ASKPASS}" == 1 ]]; then
        rm -f "${DOT_SUDO_PASS_FILE}" "${DOT_SUDO_ASKPASS_FILE}"
    fi
}
trap _sudo_cleanup EXIT

function _power_giver() {
    if [[ ${EUID} -eq 0 ]]; then
        _POWER_GIVER_TOOL=''
        return 0
    fi

    if [[ -z "${_DOT_SUDO_TOOL}" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            _DOT_SUDO_TOOL='sudo'
        elif command -v doas >/dev/null 2>&1; then
            _DOT_SUDO_TOOL='doas'
        fi
    fi

    if [[ -z "${_DOT_SUDO_TOOL}" ]]; then
        if [[ "${1:-}" == 'panic' ]]; then
            echo 'Neither `sudo` nor `doas` installed. Install one of them and retry.' >&2
            exit 1
        fi
        _POWER_GIVER_TOOL=''
        return 0
    fi

    _POWER_GIVER_TOOL="${_DOT_SUDO_TOOL}"
    return 0
}

function _sudo_nopasswd() {
    local tool=${1}
    case "${tool}" in
        sudo) sudo -n true >/dev/null 2>&1 ;;
        doas) doas -n true >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

function _sudo_askpass_script() {
    cat >"${DOT_SUDO_ASKPASS_FILE}" <<EOF
#!/usr/bin/env bash
cat '${DOT_SUDO_PASS_FILE}'
EOF
    chmod 700 "${DOT_SUDO_ASKPASS_FILE}"
    export SUDO_ASKPASS="${DOT_SUDO_ASKPASS_FILE}"
}

function _sudo_preflight() {
    if [[ ${EUID} -eq 0 ]] || [[ "${_DOT_SUDO_READY}" == 1 ]]; then
        return 0
    fi

    _power_giver panic
    local tool="${_POWER_GIVER_TOOL}"

    if _sudo_nopasswd "${tool}"; then
        _DOT_SUDO_READY=1
        return 0
    fi

    if [[ "${tool}" == 'sudo' ]]; then
        if [[ -f "${DOT_SUDO_PASS_FILE}" && -x "${DOT_SUDO_ASKPASS_FILE}" ]]; then
            export SUDO_ASKPASS="${DOT_SUDO_ASKPASS_FILE}"
            if sudo -A -v >/dev/null 2>&1; then
                _DOT_SUDO_READY=1
                _DOT_SUDO_ASKPASS_MODE=1
                return 0
            fi
            rm -f "${DOT_SUDO_PASS_FILE}" "${DOT_SUDO_ASKPASS_FILE}"
        fi

        if [[ ! (-t 0 || -t 1) ]]; then
            log_error 'sudo requires a password but no TTY is available.'
            log_error 'Enable passwordless sudo (NOPASSWD), run as root, or run interactively.'
            exit 1
        fi

        local password
        log_warn 'sudo is not passwordless; the password will be cached for this run only.'
        read -rsp 'sudo password: ' password
        printf '\n' >&2

        printf '%s\n' "${password}" >"${DOT_SUDO_PASS_FILE}"
        chmod 600 "${DOT_SUDO_PASS_FILE}"
        _sudo_askpass_script

        if ! sudo -A -v >/dev/null 2>&1; then
            log_error 'Incorrect sudo password.'
            rm -f "${DOT_SUDO_PASS_FILE}" "${DOT_SUDO_ASKPASS_FILE}"
            exit 1
        fi

        _DOT_SUDO_READY=1
        _DOT_SUDO_ASKPASS_MODE=1
        _DOT_SUDO_OWNS_ASKPASS=1
        return 0
    fi

    if [[ ! (-t 0 || -t 1) ]]; then
        log_error 'doas requires a password but no TTY is available.'
        log_error 'Configure doas with `permit nopass` or run interactively.'
        exit 1
    fi

    log_warn 'doas is not passwordless; prompting once.'
    doas true
    _DOT_SUDO_READY=1
    return 0
}

function _priv() {
    if [[ ${EUID} -eq 0 ]]; then
        "$@"
        return $?
    fi

    _sudo_preflight

    if [[ "${_POWER_GIVER_TOOL}" == 'sudo' && "${_DOT_SUDO_ASKPASS_MODE}" == 1 ]]; then
        sudo -A "$@"
    else
        "${_POWER_GIVER_TOOL}" "$@"
    fi
}

# _install_packages <logical...>: packages through lib/package.sh, by
# logical name (DOT_PKG_LOGICAL).
# Accepts separate arguments or one space-separated string (the original
# form); words are split without glob expansion. _DOT_NO_PACKAGES=1 is the
# test seam: nothing is detected or installed.
function _install_packages() {
    (($# > 0)) || {
        log_error 'Package list not provided'
        return 1
    }
    if [[ "${_DOT_NO_PACKAGES:-0}" == 1 ]]; then
        return 0
    fi

    local -a packages=() words=()
    local arg
    for arg in "$@"; do
        read -ra words <<<"${arg}" || true
        packages+=("${words[@]}")
    done

    _pkg_install "${packages[@]}"
}

# _dot_passwd_entry <user>: the user's passwd line, from getent or, when
# getent is absent, /etc/passwd (_DOT_PASSWD_FILE overrides it for tests).
function _dot_passwd_entry() {
    local user=${1:?'User must be informed'}
    if command -v getent >/dev/null 2>&1; then
        getent passwd "${user}" 2>/dev/null
    else
        grep -m1 -- "^${user}:" "${_DOT_PASSWD_FILE:-/etc/passwd}" 2>/dev/null
    fi
}

# _dot_user_home <user>: the user's home directory. The current user gets
# $HOME (so tests and sudo -E keep their redirection); any other user gets
# the passwd entry. Never eval ~user, never guess /home/<user>: an unknown
# user or an empty home fails.
function _dot_user_home() {
    local user=${1:?'User must be informed'}
    local home=''

    if [[ "${user}" == "$(id -un)" ]]; then
        home="${HOME:-}"
    else
        home="$(_dot_passwd_entry "${user}" | cut -d: -f6)" || home=''
    fi

    if [[ "${home}" != /* ]]; then
        log_error "Cannot resolve the home directory of '${user}'"
        return 1
    fi
    printf '%s' "${home}"
}

function _is_installed() {
    command -v "${1}" >/dev/null 2>&1
}

# Stronger than _is_installed: the binary must not only be on PATH but
# execute (a broken shim counts as missing). Only for tools known to
# support `--version` (cargo, bun, zed, devcontainer).
function _is_runnable() {
    local bin=${1:?'Binary must be informed'}
    command -v "${bin}" >/dev/null 2>&1 && "${bin}" --version >/dev/null 2>&1
}

function _ensure_local_bin() {
    local local_bin="${HOME}/.local/bin"
    mkdir -p "${local_bin}"
    echo "${local_bin}"
}

function _download() {
    local url=${1:?'URL must be informed'}
    local destination=${2:?'Destination must be informed'}

    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 30 -o "${destination}" "${url}"
}

function _github_asset_url() {
    local repo=${1:?'GitHub repo (owner/name) must be informed'}
    local pattern=${2:?'Asset name pattern must be informed'}

    local url
    url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" |
        grep -oE '"browser_download_url": *"[^"]+"' |
        cut -d'"' -f4 |
        grep -E "${pattern}" |
        head -n1)"

    if [[ -z "${url}" ]]; then
        log_error "No release asset matching '${pattern}' for ${repo}"
        return 1
    fi

    echo "${url}"
}

function _link_file() {
    local source_file=${1:?'Source file must be informed'}
    local target_file=${2:?'Target file must be informed'}

    if [[ -L "${target_file}" ]] && [[ "$(readlink "${target_file}")" == "${source_file}" ]]; then
        log_info "Already linked: ${target_file}"
        return 0
    fi

    if [[ -e "${target_file}" || -L "${target_file}" ]]; then
        local backup="${target_file}.dottod.bak"
        log_warn "Backing up existing ${target_file} to ${backup}"
        mv -f "${target_file}" "${backup}"
    fi

    mkdir -p "$(dirname "${target_file}")"
    ln -s "${source_file}" "${target_file}"
    log_ok "Linked ${target_file} -> ${source_file}"

    return 0
}

# _dot_path_state <path> [dottod source]: how a managed path stands, for
# status reports (read-only): "symlink -> X (dottod)" when it links to the
# given source, "symlink -> X", "file (user-managed)", "directory
# (user-managed)" or "missing".
function _dot_path_state() {
    local path=${1:?'Path must be informed'} source=${2:-}
    if [[ -L "${path}" ]]; then
        local dest
        dest="$(readlink "${path}")"
        if [[ -n "${source}" && "${dest}" == "${source}" ]]; then
            printf 'symlink -> %s (dottod)' "${dest}"
        else
            printf 'symlink -> %s' "${dest}"
        fi
    elif [[ -d "${path}" ]]; then
        printf 'directory (user-managed)'
    elif [[ -e "${path}" ]]; then
        printf 'file (user-managed)'
    else
        printf 'missing'
    fi
}

# _dot_first_line <cmd...>: the first line of a command's output (stdout and
# stderr). Reads it all first: `| head` would end the pipe early and fail
# under pipefail.
function _dot_first_line() {
    local out
    out="$("$@" 2>&1)" || true
    printf '%s' "${out%%$'\n'*}"
}

# _dot_have <cmd>: "present" or "missing", for status reports.
function _dot_have() {
    if command -v "${1:?'Command must be informed'}" >/dev/null 2>&1; then
        printf 'present'
    else
        printf 'missing'
    fi
}

function _prompt() {
    local message=${1} default=${2:-}
    local input

    if [[ -t 0 ]]; then
        read -r -p "${message} [${default}]: " input
    fi

    echo "${input:-${default}}"
}

function _go_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo 'x86_64' ;;
        arm64 | aarch64) echo 'arm64' ;;
        *) echo "$(uname -m)" ;;
    esac
}

function _rust_arch() {
    case "$(uname -m)" in
        x86_64) echo 'amd64' ;;
        arm64 | aarch64) echo 'arm64' ;;
        *) echo "$(uname -m)" ;;
    esac
}
