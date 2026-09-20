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

function _color_supported() {
    [[ -n "${DOT_FORCE_COLOR:-}" ]] && return 0
    [[ -n "${NO_COLOR:-}" ]] && return 1
    [[ -t 2 ]] || return 1
    case "${TERM:-}" in
        ''|dumb) return 1 ;;
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

function log_step()  { printf "${DOT_C_BOLD}${DOT_C_CYAN}${DOT_SYM_STEP} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_info()  { printf "${DOT_C_BLUE}  ${DOT_SYM_INFO} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_ok()    { printf "${DOT_C_GREEN}  ${DOT_SYM_OK} %s${DOT_C_RESET}\n" "$*" >&2; }
function log_warn()  { printf "${DOT_C_YELLOW}  ${DOT_SYM_WARN} %s${DOT_C_RESET}\n" "$*" >&2; }
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
    cat > "${DOT_SUDO_ASKPASS_FILE}" <<EOF
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

        printf '%s\n' "${password}" > "${DOT_SUDO_PASS_FILE}"
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

function _install_packages() {
    local package_list=${1:?'Package list not provided'}
    local no_recommends=${2:-0}

    if [[ "${_DOT_NO_PACKAGES:-0}" == 1 ]]; then
        return 0
    fi

    if declare -F _pkg_install >/dev/null 2>&1; then
        if declare -F _pkg_update >/dev/null 2>&1; then
            _pkg_update
        fi
        _pkg_install ${package_list}
        if declare -F _pkg_clean >/dev/null 2>&1; then
            _pkg_clean
        fi
        return 0
    fi

    if [[ -z "${DEBIAN_FRONTEND:-}" ]]; then
        export DEBIAN_FRONTEND=noninteractive
    fi

    _priv apt-get update -qq --yes >/dev/null 2>&1

    local -a install_args=(apt-get install -qq --yes)
    if [[ "${no_recommends}" == 1 ]]; then
        install_args+=(--no-install-recommends)
    fi
    # Split the space-separated list robustly: a bare ${package_list}
    # expansion would also glob-expand package names containing wildcards.
    local -a extra_packages=()
    read -ra extra_packages <<<"${package_list}" || true
    install_args+=("${extra_packages[@]}")

    _priv "${install_args[@]}" >/dev/null 2>&1
    _priv rm -rf /var/lib/apt/lists/*

    return 0
}

function _is_installed() {
    command -v "${1}" >/dev/null 2>&1
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
    url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -oE '"browser_download_url": *"[^"]+"' \
        | cut -d'"' -f4 \
        | grep -E "${pattern}" \
        | head -n1)"

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
        x86_64|amd64) echo 'x86_64' ;;
        arm64|aarch64) echo 'arm64' ;;
        *) echo "$(uname -m)" ;;
    esac
}

function _rust_arch() {
    case "$(uname -m)" in
        x86_64) echo 'amd64' ;;
        arm64|aarch64) echo 'arm64' ;;
        *) echo "$(uname -m)" ;;
    esac
}
