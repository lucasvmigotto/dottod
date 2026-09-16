#!/usr/bin/env bash
#
# docker-hello.sh — real Docker container lifecycle (integration test).
#
# Gated: runs only with DOTTOD_TEST_INTEGRATION=1 (otherwise SKIP, rc 0),
# so the fast suite never needs a container engine. Requires network to
# pull hello-world and a reachable daemon. Cleans up only what it creates:
# the test container always, the image only if this run pulled it.

set -Eeuo pipefail

readonly IMG='docker.io/library/hello-world:latest'

if [[ "${DOTTOD_TEST_INTEGRATION:-0}" != 1 ]]; then
    echo 'SKIP: set DOTTOD_TEST_INTEGRATION=1 to run the Docker integration test'
    exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
    echo 'FAIL: docker binary missing' >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo 'FAIL: docker present but daemon unreachable (docker info)' >&2
    exit 1
fi

NAME="dottod-test-docker-$$"
HAD_IMAGE=0
if docker image inspect "${IMG}" >/dev/null 2>&1; then
    HAD_IMAGE=1
fi

function _cleanup() {
    docker rm -f "${NAME}" >/dev/null 2>&1 || true
    if [[ "${HAD_IMAGE}" == 0 ]]; then
        docker rmi "${IMG}" >/dev/null 2>&1 || true
    fi
}
trap _cleanup EXIT

OUT="$(docker run --label dottod-test=1 --name "${NAME}" "${IMG}" 2>&1)"
printf '%s\n' "${OUT}" | grep -q 'Hello from Docker!' || {
    printf 'FAIL: unexpected hello-world output:\n%s\n' "${OUT}" >&2
    exit 1
}

echo 'PASS: docker hello-world lifecycle'
