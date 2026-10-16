#!/usr/bin/env bash
#
# dottod-fetch — a fetch-style card of what dottod sees on a system: the
# distribution, its family and package manager, libc, shell, prompt style,
# and what a few logical packages are called there. Everything comes from
# dottod itself (lib/os.sh, lib/packages/*); nothing is installed.
#
# Usage: dottod-fetch.sh [--os-release FILE]
#   --os-release FILE   describe the system that file describes (e.g. one of
#                       tests/fixtures/os-release/*) instead of this one
#
# Logos: the small distribution logos of neofetch (MIT, Dylan Araps).

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/utils.sh"

# Logical packages shown on the card, in this order.
readonly FETCH_PACKAGES=(git vim neovim openssh_client podman pass bats)

function _fetch_logo() {
    case "${1}" in
        debian)
            cat <<'EOF'
  _____
 /  __ \
|  /    |
|  \___-
-_
  --_
EOF
            ;;
        arch)
            cat <<'EOF'
      /\
     /  \
    /\   \
   /      \
  /   ,,   \
 /   |  |  -\
/_-''    ''-_\
EOF
            ;;
        gentoo)
            cat <<'EOF'
 _-----_
(       \
\    0   \
 \        )
 /      _/
(     _-
\____-
EOF
            ;;
        redhat)
            cat <<'EOF'
      _____
     /   __)\
     |  /  \ \
  ___|  |__/ /
 / (_    _)_/
/ /  |  |
\ \__/  |
 \(_____/
EOF
            ;;
        alpine)
            cat <<'EOF'
   /\ /\
  // \  \
 //   \  \
///    \  \
//      \  \
         \
EOF
            ;;
        *)
            cat <<'EOF'
    .--.
   |o_o |
   |:_/ |
  //   \ \
 (|     | )
/'\_   _/`\
\___)=(___/
EOF
            ;;
    esac
}

function _fetch_color() {
    if [[ -n "${NO_COLOR:-}" || ! -t 1 ]] && [[ -z "${DOT_FORCE_COLOR:-}" ]]; then
        return 0
    fi
    case "${1}" in
        debian) printf '\033[31m' ;;
        arch) printf '\033[36m' ;;
        gentoo) printf '\033[35m' ;;
        redhat) printf '\033[34m' ;;
        alpine) printf '\033[34m' ;;
        *) printf '\033[33m' ;;
    esac
}

function _fetch_version() {
    local v
    v="$(git -C "${DOT_REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null)" || v='dev'
    printf '%s' "${v}"
}

function _fetch_main() {
    local simulated=0
    while (($# > 0)); do
        case "$1" in
            --os-release)
                export _DOT_OS_RELEASE_FILE="${2:?'--os-release needs a file'}"
                simulated=1
                shift 2
                ;;
            -h | --help)
                sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    _os_detect 2>/dev/null || true
    local family="${DOTTOD_OS_FAMILY:-unknown}" libc name native shell
    # A simulated system can't be probed: report the libc it ships.
    if ((simulated)); then
        [[ "${family}" == alpine ]] && libc='musl' || libc='glibc'
    else
        libc="${DOTTOD_LIBC:-unknown}"
    fi

    local -a lines=()
    lines+=("dottod $(_fetch_version)")
    lines+=('-------------')
    lines+=("Distro    ${DOTTOD_OS_NAME:-unknown} ${DOTTOD_OS_VERSION_ID:-}")
    if [[ "${family}" == unknown ]]; then
        lines+=('Family    unsupported (no package command would run)')
    else
        lines+=("Family    ${family} (${DOTTOD_PKG})")
    fi
    lines+=("Libc      ${libc}")
    # The shell dottod sets up; its version only for this real system.
    shell='bash'
    ((simulated)) || shell="bash ${BASH_VERSION%%(*}"
    lines+=("Shell     ${shell}")
    lines+=("Prompt    ${DOT_PROMPT_STYLE:-robbyrussell}")
    if [[ "${family}" != unknown ]]; then
        lines+=('Packages')
        for name in "${FETCH_PACKAGES[@]}"; do
            native="$("_pkgmap_${family}" "${name}" 2>/dev/null)" || native='?'
            [[ "${native}" == '-' ]] && native='(not packaged)'
            lines+=("  ${name} -> ${native}")
        done
    fi

    local color reset='' i=0 logo_line
    local -a logo=()
    color="$(_fetch_color "${family}")"
    [[ -n "${color}" ]] && reset=$'\033[0m'
    mapfile -t logo < <(_fetch_logo "${family}")
    local rows=$((${#logo[@]} > ${#lines[@]} ? ${#logo[@]} : ${#lines[@]}))
    for ((i = 0; i < rows; i++)); do
        logo_line="${logo[$i]:-}"
        printf '%s%-15s%s  %s\n' "${color}" "${logo_line}" "${reset}" "${lines[$i]:-}"
    done
}

_fetch_main "$@"
