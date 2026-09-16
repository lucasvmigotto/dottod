#!/usr/bin/env bash
#
# podman-hello.sh — real Podman container lifecycle (integration test).
#
# Gated: runs only with DOTTOD_TEST_INTEGRATION=1 (otherwise SKIP, rc 0),
# so the fast suite never needs a container engine. Requires network to
# pull hello-world. Cleans up only what it creates: the test container
# always, the image only if this run pulled it.

set -Eeuo pipefail

readonly IMG='docker.io/library/hello-world:latest'

if [[ "${DOTTOD_TEST_INTEGRATION:-0}" != 1 ]]; then
    echo 'SKIP: set DOTTOD_TEST_INTEGRATION=1 to run the Podman integration test'
    exit 0
fi

if ! command -v podman >/dev/null 2>&1; then
    echo 'FAIL: podman binary missing' >&2
    exit 1
fi

if ! podman info >/dev/null 2>&1; then
    echo 'FAIL: podman present but unusable (rootless check: podman info)' >&2
    exit 1
fi

NAME="dottod-test-podman-$$"
HAD_IMAGE=0
if podman image exists "${IMG}" >/dev/null 2>&1; then
    HAD_IMAGE=1
fi

function _cleanup() {
    podman rm -f "${NAME}" >/dev/null 2>&1 || true
    if [[ "${HAD_IMAGE}" == 0 ]]; then
        podman rmi "${IMG}" >/dev/null 2>&1 || true
    fi
}
trap _cleanup EXIT

OUT="$(podman run --label dottod-test=1 --name "${NAME}" "${IMG}" 2>&1)"
printf '%s\n' "${OUT}" | grep -q 'Hello from Docker!' || {
    printf 'FAIL: unexpected hello-world output:\n%s\n' "${OUT}" >&2
    exit 1
}

echo 'PASS: podman hello-world lifecycle'
