#!/usr/bin/env bash
#
# pkg-resolve.sh — package mapping gate (spec 015, T030).
#
# Proves every logical package in DOT_PKG_LOGICAL resolves to a real
# package in each distro's repository, using dottod's own candidate
# lookups (lib/package.sh). Nothing is installed.
#
# Gated: runs only with DOTTOD_TEST_INTEGRATION=1 (otherwise SKIP, rc 0).
#
#   pkg-resolve.sh [distro...]   on the host: one throwaway Podman
#                                container per distro (default: all)
#   pkg-resolve.sh --inside      inside a container (the host mode calls it)
#
# Distros and images: tests/integration/distros.sh.

set -Eeuo pipefail

# shellcheck source=distros.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/distros.sh"

function _inside() {
    cd /w
    # shellcheck source=../../bin/utils.sh
    source bin/utils.sh
    set +e
    _os_detect || exit 1
    printf '%s (%s, %s/%s)\n' "${DOTTOD_OS_NAME}" "${DOTTOD_OS_VERSION_ID:-rolling}" "${DOTTOD_OS_FAMILY}" "${DOTTOD_PKG}"

    local name native pkg ver failures=0
    local -a words=()
    for name in "${DOT_PKG_LOGICAL[@]}"; do
        native="$("_pkgmap_${DOTTOD_OS_FAMILY}" "${name}")"
        if [[ "${native}" == '-' ]]; then
            printf '  %-16s %-28s unsupported (by design)\n' "${name}" '-'
            continue
        fi
        read -ra words <<<"${native}"
        for pkg in "${words[@]}"; do
            ver="$("_pkg_${DOTTOD_OS_FAMILY}_candidate" "${pkg}")"
            if [[ -n "${ver}" && "${ver}" != '(none)' ]]; then
                printf '  %-16s %-28s %s\n' "${name}" "${pkg}" "${ver}"
            else
                printf '  %-16s %-28s MISSING\n' "${name}" "${pkg}"
                failures=$((failures + 1))
            fi
        done
    done
    printf '%s: %d missing\n' "${DOTTOD_OS_ID}" "${failures}"
    ((failures == 0))
}

function _host() {
    local repo distro image failures=0
    local -a extra=()
    repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    command -v podman >/dev/null 2>&1 || {
        echo 'FAIL: podman binary missing' >&2
        return 1
    }

    for distro in "${@:-${DOT_IT_DISTROS[@]}}"; do
        image="$(_it_image "${distro}")" || {
            echo "FAIL: unknown distro '${distro}' (want: ${DOT_IT_DISTROS[*]})" >&2
            return 1
        }
        mapfile -t extra < <(_it_extra_args "${distro}")
        printf '=== %s\n' "${distro}"
        if ! podman run --rm "${extra[@]}" \
            -v "${repo}:/w:ro,Z" -e DOTTOD_TEST_INTEGRATION=1 \
            "${image}" sh -c "$(_it_prep "${distro}" index) && bash /w/tests/integration/pkg-resolve.sh --inside"; then
            failures=$((failures + 1))
        fi
    done

    printf 'distros failing: %d\n' "${failures}"
    ((failures == 0))
}

if [[ "${DOTTOD_TEST_INTEGRATION:-0}" != 1 ]]; then
    echo 'SKIP: set DOTTOD_TEST_INTEGRATION=1 to run the package mapping gate'
    exit 0
fi

if [[ "${1:-}" == --inside ]]; then
    _inside
else
    _host "$@"
fi
