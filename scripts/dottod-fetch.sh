#!/usr/bin/env bash
#
# dottod-fetch — a fetch card of what dottod sees on a system: the
# distribution, its family and package manager, libc, shell, prompt style,
# and what a few logical packages are called there. The facts come from
# dottod itself (lib/os.sh, lib/packages/*); nothing is installed.
#
# Usage: dottod-fetch.sh [--os-release FILE] [--plain]
#   --os-release FILE   describe the system that file describes (e.g. one of
#                       tests/fixtures/os-release/*) instead of this one
#   --plain             the text card, even when fastfetch is installed
#
# With fastfetch installed (./bin/bootstrap.sh --only tools --extras
# fastfetch), it draws the card: the distribution's real logo, and — on
# this system, not a simulated one — its kernel, uptime, CPU and memory.

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/utils.sh"

# The fastfetch to draw with (a seam for tests).
FETCH_CMD="${_DOT_FETCH_CMD:-fastfetch}"

# Logical packages shown on the card, in this order.
readonly FETCH_PACKAGES=(git vim neovim openssh_client podman pass bats)

function _fetch_color_on() {
    [[ -n "${DOT_FORCE_COLOR:-}" ]] && return 0
    [[ -z "${NO_COLOR:-}" && -t 1 ]]
}

# The prompt style that applies: DOT_PROMPT_STYLE, else the one saved in
# ~/.prompt-style (prompt-style <name>), else robbyrussell.
function _fetch_prompt_style() {
    local style="${DOT_PROMPT_STYLE:-}" file="${DOT_PROMPT_STYLE_FILE:-${HOME}/.prompt-style}"
    if [[ -z "${style}" && -r "${file}" ]]; then
        IFS= read -r style <"${file}" || true
        style="${style//[[:space:]]/}"
    fi
    printf '%s' "${style:-robbyrussell}"
}

function _fetch_version() {
    local v
    v="$(git -C "${DOT_REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null)" || v='dev'
    printf '%s' "${v}"
}

# A JSON string body: backslashes, quotes and control characters escaped.
function _fetch_json_escape() {
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/\\t}"
    printf '%s' "${s//$'\n'/\\n}"
}

# fastfetch config: the card as custom modules (key + text), then — only
# for this system — fastfetch's own probes.
# args: <real: 0|1>, then the card as key<TAB>value lines on stdin.
function _fetch_fastfetch_config() {
    local real="${1}" key value
    printf '{\n  "display": {"separator": "  ", "key": {"width": 18}},\n  "modules": [\n'
    printf '    {"type": "custom", "format": "{#1}dottod{#} %s"},\n' "$(_fetch_json_escape "$(_fetch_version)")"
    printf '    "separator"'
    while IFS=$'\t' read -r key value; do
        printf ',\n    {"type": "custom", "key": "%s", "format": "%s"}' \
            "$(_fetch_json_escape "${key}")" "$(_fetch_json_escape "${value}")"
    done
    if ((real)); then
        printf ',\n    "kernel",\n    "uptime",\n    "cpu",\n    "memory"'
    fi
    printf '\n  ]\n}\n'
}

function _fetch_plain() {
    local key value
    printf 'dottod %s\n-------------\n' "$(_fetch_version)"
    while IFS=$'\t' read -r key value; do
        printf '%-18s%s\n' "${key}" "${value}"
    done
}

function _fetch_main() {
    local simulated=0 plain=0
    while (($# > 0)); do
        case "$1" in
            --os-release)
                export _DOT_OS_RELEASE_FILE="${2:?'--os-release needs a file'}"
                simulated=1
                shift 2
                ;;
            --plain)
                plain=1
                shift
                ;;
            -h | --help)
                sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

    # The card, as key<TAB>value lines.
    local -a card=()
    card+=("Distro"$'\t'"${DOTTOD_OS_NAME:-unknown} ${DOTTOD_OS_VERSION_ID:-}")
    if [[ "${family}" == unknown ]]; then
        card+=("Family"$'\t''unsupported (no package command would run)')
    else
        card+=("Family"$'\t'"${family} (${DOTTOD_PKG})")
    fi
    card+=("Libc"$'\t'"${libc}")
    # The shell dottod sets up; its version only for this real system.
    shell='bash'
    ((simulated)) || shell="bash ${BASH_VERSION%%(*}"
    card+=("Shell"$'\t'"${shell}")
    card+=("Prompt"$'\t'"$(_fetch_prompt_style)")
    if [[ "${family}" != unknown ]]; then
        card+=("Packages"$'\t')
        for name in "${FETCH_PACKAGES[@]}"; do
            native="$("_pkgmap_${family}" "${name}" 2>/dev/null)" || native='?'
            [[ "${native}" == '-' ]] && native='(not packaged)'
            card+=("  ${name}"$'\t'"${native}")
        done
    fi

    if ((plain)) || ! command -v "${FETCH_CMD}" >/dev/null 2>&1; then
        printf '%s\n' "${card[@]}" | _fetch_plain
        return 0
    fi

    local cfg rc=0
    local -a args=()
    cfg="$(mktemp "${TMPDIR:-/tmp}/dottod-fetch.XXXXXX.jsonc")"
    printf '%s\n' "${card[@]}" | _fetch_fastfetch_config "$((!simulated))" >"${cfg}"
    args=(--config "${cfg}")
    # A simulated system gets its own logo; a real one, fastfetch's pick.
    ((simulated)) && args+=(--logo "${DOTTOD_OS_ID:-linux}")
    if _fetch_color_on; then
        args+=(--pipe false)
    else
        args+=(--pipe true)
    fi
    "${FETCH_CMD}" "${args[@]}" || rc=$?
    rm -f "${cfg}"
    return "${rc}"
}

_fetch_main "$@"
