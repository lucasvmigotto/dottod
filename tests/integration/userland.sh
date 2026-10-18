#!/usr/bin/env bash
#
# userland.sh — the bats suites on userlands unlike the dev host (spec 022):
# Alpine (BusyBox coreutils/awk/sed, no GNU extras) and Debian (mawk). The
# portability bugs of dottod live here (byte-counting awk, BusyBox flags).
#
#   userland.sh [alpine|debian ...]    default: both
#   userland.sh --inside <distro>      inside the container (host mode calls it)
#
# DOTTOD_USERLAND_SUITES overrides the suite list (default: all). Images are
# pinned in distros.sh. Needs network for the package install.

set -Eeuo pipefail

# shellcheck source=distros.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/distros.sh"

function _inside() {
    local distro="${1}"
    case "${distro}" in
        alpine) apk add -q bash bats git jq curl openssh-client python3 gnupg pass pv xz shadow >/dev/null ;;
        debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null
            apt-get install -y -qq bats git jq curl openssh-client python3 gnupg pass pv xz-utils >/dev/null
            ;;
        *) return 2 ;;
    esac
    # Not the host's coreutils: report which awk/sed this run exercises.
    printf 'userland: %s, awk=%s, sed=%s\n' "${distro}" \
        "$(readlink -f "$(command -v awk)" | sed 's|.*/||')" \
        "$(readlink -f "$(command -v sed)" | sed 's|.*/||')"
    # Unprivileged, UTF-8: like a real login (root changes prompts, status
    # and permissions; the bare image has no locale).
    useradd -m -s /bin/bash tester
    cp -a /w /home/tester/w
    chown -R tester /home/tester/w
    local -a suites=()
    read -ra suites <<<"${DOTTOD_USERLAND_SUITES:-}"
    # shellcheck disable=SC2016 # expanded by the tester's shell
    su -s /bin/bash tester -c 'export LANG=C.UTF-8 LC_ALL=C.UTF-8; cd ~/w && git config --global --add safe.directory "*" && { (($# > 0)) || set -- tests/test-*.bats; } && exec bats "$@"' _ "${suites[@]}"
}

function _host() {
    local root distro rc=0
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local -a distros=("$@") limits=()
    ((${#distros[@]} > 0)) || distros=(alpine debian)
    read -ra limits <<<"${DOT_IT_PODMAN_ARGS---memory 3g --cpus 2}"
    for distro in "${distros[@]}"; do
        printf '=== userland: %s ===\n' "${distro}"
        podman run --rm "${limits[@]}" -v "${root}:/w:ro" \
            -e DOTTOD_USERLAND_SUITES="${DOTTOD_USERLAND_SUITES:-}" \
            "$(_it_image "${distro}")" \
            sh -c 'command -v bash >/dev/null || apk add -q bash >/dev/null; exec bash /w/tests/integration/userland.sh --inside '"${distro}" || rc=1
    done
    return "${rc}"
}

if [[ "${1:-}" == --inside ]]; then
    _inside "${2}"
else
    _host "$@"
fi
