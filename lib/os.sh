#!/usr/bin/env bash
#
# os.sh — platform detection for dottod (spec 015).
#
# Sourced by bin/utils.sh; sourcing only defines functions. Callers run
# _os_detect once, then read the DOTTOD_OS_* / DOTTOD_PKG / DOTTOD_ARCH /
# DOTTOD_LIBC globals (plain shell variables, not exported: every task
# process detects for itself).
#
# /etc/os-release is parsed line by line, never sourced: values are data.
#
# Families and their package managers:
#   debian  apt-get   (debian, ubuntu; ID_LIKE debian/ubuntu)
#   gentoo  emerge
#   arch    pacman
#   redhat  dnf       (fedora; ID_LIKE fedora/rhel)
#   alpine  apk
# Anything else is unsupported: _os_detect fails and sets no manager, so
# no package command can be chosen for it.
#
# Test seams (never needed by users):
#   _DOT_OS_RELEASE_FILE   os-release path (default /etc/os-release,
#                          then /usr/lib/os-release)
#   _DOT_LIBC_ROOT         root for the musl loader probe (default /)

# _os_release_get <file> <KEY>: prints KEY's unquoted value; rc 1 when
# absent. Handles KEY=value, KEY="value" and KEY='value'; in double
# quotes, \" \\ \$ \` unescape as the os-release spec says.
function _os_release_get() {
    local file=${1:?'os-release file required'}
    local key=${2:?'key required'}
    local line value found=1

    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" == "${key}="* ]] || continue
        value="${line#"${key}="}"
        if [[ "${value}" == \"*\" && ${#value} -ge 2 ]]; then
            value="${value:1:${#value}-2}"
            value="${value//\\\"/\"}"
            value="${value//\\\$/\$}"
            value="${value//\\\`/\`}"
            value="${value//\\\\/\\}"
        elif [[ "${value}" == \'*\' && ${#value} -ge 2 ]]; then
            value="${value:1:${#value}-2}"
        fi
        found=0
    done <"${file}"

    [[ "${found}" == 0 ]] || return 1
    printf '%s' "${value}"
}

# _os_valid_id <value>: os-release ID charset (lowercase, digits, . _ -).
function _os_valid_id() {
    [[ -n "${1}" && "${1}" != *[!a-z0-9._-]* ]]
}

# _os_family_of <id>: prints the family for one ID token; rc 1 when the
# token is not a supported distro.
function _os_family_of() {
    case "${1}" in
        debian | ubuntu) printf 'debian' ;;
        gentoo) printf 'gentoo' ;;
        arch) printf 'arch' ;;
        fedora | rhel) printf 'redhat' ;;
        alpine) printf 'alpine' ;;
        *) return 1 ;;
    esac
}

# _os_pkg_of <family>: prints the family's package manager command.
function _os_pkg_of() {
    case "${1}" in
        debian) printf 'apt-get' ;;
        gentoo) printf 'emerge' ;;
        arch) printf 'pacman' ;;
        redhat) printf 'dnf' ;;
        alpine) printf 'apk' ;;
        *) return 1 ;;
    esac
}

# _os_arch: normalized userspace architecture (x86_64 | aarch64 | raw).
function _os_arch() {
    local m
    m="$(uname -m 2>/dev/null)" || m=''
    case "${m}" in
        x86_64 | amd64) printf 'x86_64' ;;
        aarch64 | arm64) printf 'aarch64' ;;
        '') printf 'unknown' ;;
        *) printf '%s' "${m}" ;;
    esac
}

# _os_libc: glibc | musl | unknown. Conservative: unknown is never
# treated as glibc by callers.
function _os_libc() {
    local root=${_DOT_LIBC_ROOT:-/} loader
    for loader in "${root%/}"/lib/ld-musl-*.so.1; do
        if [[ -e "${loader}" ]]; then
            printf 'musl'
            return 0
        fi
    done
    if getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
        printf 'glibc'
        return 0
    fi
    printf 'unknown'
}

# _os_release_file: the os-release file to read; rc 1 when none exists.
function _os_release_file() {
    local f
    if [[ -n "${_DOT_OS_RELEASE_FILE:-}" ]]; then
        [[ -r "${_DOT_OS_RELEASE_FILE}" ]] || return 1
        printf '%s' "${_DOT_OS_RELEASE_FILE}"
        return 0
    fi
    for f in /etc/os-release /usr/lib/os-release; do
        if [[ -r "${f}" ]]; then
            printf '%s' "${f}"
            return 0
        fi
    done
    return 1
}

# _os_detect: fills DOTTOD_OS_ID, DOTTOD_OS_ID_LIKE, DOTTOD_OS_VERSION_ID,
# DOTTOD_OS_NAME, DOTTOD_OS_FAMILY, DOTTOD_PKG, DOTTOD_ARCH, DOTTOD_LIBC.
# Fails (rc 1, message on stderr) on a missing file, an invalid ID or an
# unsupported distro; DOTTOD_OS_FAMILY is then 'unknown' and DOTTOD_PKG
# empty.
# The globals are read by the scripts that source this file.
# shellcheck disable=SC2034
function _os_detect() {
    local file id like token family=''

    DOTTOD_OS_ID=''
    DOTTOD_OS_ID_LIKE=''
    DOTTOD_OS_VERSION_ID=''
    DOTTOD_OS_NAME=''
    DOTTOD_OS_FAMILY='unknown'
    DOTTOD_PKG=''
    DOTTOD_ARCH="$(_os_arch)"
    DOTTOD_LIBC="$(_os_libc)"

    if ! file="$(_os_release_file)"; then
        printf 'dottod: no readable os-release file; cannot detect the distribution\n' >&2
        return 1
    fi

    id="$(_os_release_get "${file}" ID)" || id=''
    if ! _os_valid_id "${id}"; then
        printf "dottod: invalid or missing ID in %s\n" "${file}" >&2
        return 1
    fi
    like="$(_os_release_get "${file}" ID_LIKE)" || like=''

    DOTTOD_OS_ID="${id}"
    DOTTOD_OS_ID_LIKE="${like}"
    DOTTOD_OS_VERSION_ID="$(_os_release_get "${file}" VERSION_ID)" || DOTTOD_OS_VERSION_ID=''
    DOTTOD_OS_NAME="$(_os_release_get "${file}" NAME)" || DOTTOD_OS_NAME=''

    # ID first; ID_LIKE only as a fallback, first supported token wins.
    if ! family="$(_os_family_of "${id}")"; then
        family=''
        local -a tokens=()
        read -ra tokens <<<"${like}" || true
        for token in "${tokens[@]}"; do
            if family="$(_os_family_of "${token}")"; then
                break
            fi
            family=''
        done
    fi

    if [[ -z "${family}" ]]; then
        printf "dottod: unsupported distribution '%s' (supported: debian, gentoo, arch, fedora, alpine)\n" "${id}" >&2
        return 1
    fi

    DOTTOD_OS_FAMILY="${family}"
    DOTTOD_PKG="$(_os_pkg_of "${family}")"
    return 0
}

# _os_require_pkg: after _os_detect, the family's package manager must be
# on PATH; an ID that says fedora without dnf is inconsistent, and dottod
# never tries another manager instead.
function _os_require_pkg() {
    if [[ -z "${DOTTOD_PKG:-}" ]]; then
        printf 'dottod: no package manager for this distribution (run detection first)\n' >&2
        return 1
    fi
    if ! command -v "${DOTTOD_PKG}" >/dev/null 2>&1; then
        printf "dottod: %s detected (%s) but '%s' is not on PATH\n" \
            "${DOTTOD_OS_FAMILY}" "${DOTTOD_OS_ID}" "${DOTTOD_PKG}" >&2
        return 1
    fi
    return 0
}
