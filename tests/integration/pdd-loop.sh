#!/usr/bin/env bash
#
# pdd-loop.sh — `pdd` against a real block device (spec 022, story 8): the
# stubbed unit tests cannot prove the refusals protect a disk. A loop
# device stands in for the USB stick.
#
# Needs root (losetup, mount), pv, xz and e2fsprogs. Gated: runs only with
# DOTTOD_TEST_INTEGRATION=1 (otherwise SKIP, rc 0); SKIP too without root.
#
#   sudo DOTTOD_TEST_INTEGRATION=1 ./tests/integration/pdd-loop.sh

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "${DOTTOD_TEST_INTEGRATION:-}" != 1 ]]; then
    printf 'SKIP: pdd-loop (set DOTTOD_TEST_INTEGRATION=1)\n'
    exit 0
fi
if ((EUID != 0)); then
    printf 'SKIP: pdd-loop needs root (losetup, mount)\n'
    exit 0
fi

WORK="$(mktemp -d)"
LOOPS=()
FAILURES=0

function _cleanup() {
    local l
    umount "${WORK}/mnt" 2>/dev/null || true
    for l in "${LOOPS[@]}"; do losetup -d "${l}" 2>/dev/null || true; done
    rm -rf "${WORK}"
}
trap _cleanup EXIT

function _check() {
    local desc=${1}
    shift
    if "$@" >/dev/null 2>&1; then
        printf '  ok    %s\n' "${desc}"
    else
        printf '  FAIL  %s\n' "${desc}"
        FAILURES=$((FAILURES + 1))
    fi
}

function _loop() {
    local img="${WORK}/$1.img" dev
    truncate -s "${2}" "${img}"
    dev="$(losetup --find --show "${img}")"
    LOOPS+=("${dev}")
    printf '%s' "${dev}"
}

# _pdd <answer> <image> <device>: pdd with <answer> typed at the prompt.
function _pdd() {
    local answer=${1}
    shift
    printf '%s\n' "${answer}" | bash -c 'source "$1"; shift; pdd "$@"' _ "${ROOT}/scripts/.progress.sh" "$@"
}

# _pdd_refused <answer> <image> <device>: succeeds when pdd refuses.
function _pdd_refused() {
    ! _pdd "$@"
}

function _sum() { sha256sum <"$1" | cut -d' ' -f1; }

# Same bytes: the first N of the device equal the image.
function _same() { cmp -n "$(stat -c %s "$1")" "$1" "$2"; }

mkdir -p "${WORK}/mnt"
head -c $((4 * 1024 * 1024)) /dev/urandom >"${WORK}/payload.img"
xz -k -c "${WORK}/payload.img" >"${WORK}/payload.img.xz"
head -c $((12 * 1024 * 1024)) /dev/urandom >"${WORK}/toobig.img"

printf -- '--- write\n'
DEV="$(_loop target 8M)"
_check 'plain image is written byte for byte' _pdd "${DEV##*/}" "${WORK}/payload.img" "${DEV}"
_check '… and the device holds it' _same "${WORK}/payload.img" "${DEV}"
dd if=/dev/zero of="${DEV}" bs=1M count=8 status=none
_check '.xz image is decompressed on the way' _pdd "${DEV##*/}" "${WORK}/payload.img.xz" "${DEV}"
_check '… and the device holds the original' _same "${WORK}/payload.img" "${DEV}"

printf -- '--- refusals leave the device alone\n'
BEFORE="$(_sum "${DEV}")"
_check 'a wrong confirmation aborts' _pdd_refused nope "${WORK}/payload.img" "${DEV}"
_check 'an image larger than the device is refused' _pdd_refused "${DEV##*/}" "${WORK}/toobig.img" "${DEV}"
_check 'a regular file is not a device' _pdd_refused x "${WORK}/payload.img" "${WORK}/payload.img"
_check 'the device is unchanged' test "$(_sum "${DEV}")" = "${BEFORE}"

printf -- '--- a mounted device is refused\n'
MDEV="$(_loop mounted 16M)"
mkfs.ext4 -q "${MDEV}"
mount "${MDEV}" "${WORK}/mnt"
MBEFORE="$(dd if="${MDEV}" bs=1M count=1 status=none | sha256sum)"
_check 'pdd refuses it' _pdd_refused "${MDEV##*/}" "${WORK}/payload.img" "${MDEV}"
_check '… and wrote nothing' test "$(dd if="${MDEV}" bs=1M count=1 status=none | sha256sum)" = "${MBEFORE}"

if ((FAILURES > 0)); then
    printf 'pdd-loop: %d check(s) failed\n' "${FAILURES}"
    exit 1
fi
printf 'pdd-loop: all checks passed\n'
