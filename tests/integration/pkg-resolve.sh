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
# Distros: debian ubuntu gentoo arch fedora alpine. Gentoo needs a
# Portage tree: a stopped `dottod-portage` container holding it is created
# on first use (podman run --name dottod-portage gentoo/portage) and
# reused through --volumes-from.

set -Eeuo pipefail

readonly ALL_DISTROS=(debian ubuntu gentoo arch fedora alpine)

function _image() {
    case "${1}" in
        debian) printf 'docker.io/library/debian:trixie' ;;
        ubuntu) printf 'docker.io/library/ubuntu:24.04' ;;
        gentoo) printf 'docker.io/gentoo/stage3:latest' ;;
        arch) printf 'docker.io/library/archlinux:latest' ;;
        fedora) printf 'docker.io/library/fedora:42' ;;
        alpine) printf 'docker.io/library/alpine:3.22' ;;
        *) return 1 ;;
    esac
}

# Index preparation for the throwaway container only (dottod itself never
# runs a lone pacman -Sy; this container is discarded afterwards).
function _prep() {
    case "${1}" in
        debian | ubuntu) printf 'apt-get update -qq >/dev/null' ;;
        arch) printf 'pacman -Sy --noconfirm >/dev/null' ;;
        alpine) printf 'apk add -q bash >/dev/null && apk update -q >/dev/null' ;;
        *) printf 'true' ;;
    esac
}

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

function _ensure_portage() {
    podman container exists dottod-portage && return 0
    podman run --name dottod-portage docker.io/gentoo/portage:latest >/dev/null
}

function _host() {
    local repo distro image failures=0
    local -a extra=()
    repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    command -v podman >/dev/null 2>&1 || {
        echo 'FAIL: podman binary missing' >&2
        return 1
    }

    for distro in "${@:-${ALL_DISTROS[@]}}"; do
        image="$(_image "${distro}")" || {
            echo "FAIL: unknown distro '${distro}' (want: ${ALL_DISTROS[*]})" >&2
            return 1
        }
        extra=()
        if [[ "${distro}" == gentoo ]]; then
            _ensure_portage
            extra=(--volumes-from dottod-portage)
        fi
        printf '=== %s\n' "${distro}"
        if ! podman run --rm "${extra[@]}" \
            -v "${repo}:/w:ro,Z" -e DOTTOD_TEST_INTEGRATION=1 \
            "${image}" sh -c "$(_prep "${distro}") && bash /w/tests/integration/pkg-resolve.sh --inside"; then
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
