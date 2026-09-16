#!/usr/bin/env bash
#
# test-container.sh — tests for scripts/.container.utils.sh + bin/container.sh.
#
# Hermetic: stub podman/docker/getent binaries on a prepended PATH, plus
# _DOT_NO_PACKAGES=1 so no apt call is possible. Privilege safety: _priv is
# redefined below to record-only (it never executes anything), so usermod
# paths are asserted without ever touching the system.

set -uo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_TEST_DIR}/.." && pwd)"
_PASS=0
_FAIL=0

# Output slots filled by run_case via printf -v (pre-declared so the
# assignment is visible to static analysis as well as to `set -u`).
got=''
rc=''

function assert_eq() {
    local desc=${1} expected=${2} actual=${3}
    if [[ "${expected}" == "${actual}" ]]; then
        _PASS=$((_PASS + 1))
    else
        _FAIL=$((_FAIL + 1))
        printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "${desc}" "${expected}" "${actual}" >&2
    fi
}

function assert_contains() {
    local desc=${1} needle=${2} haystack=${3}
    if [[ "${haystack}" == *"${needle}"* ]]; then
        _PASS=$((_PASS + 1))
    else
        _FAIL=$((_FAIL + 1))
        printf 'FAIL: %s\n  missing: %q\n  in: %q\n' "${desc}" "${needle}" "${haystack}" >&2
    fi
}

_FIX="$(mktemp -d)"
trap 'rm -rf "${_FIX}"' EXIT
_STUBBIN="${_FIX}/bin"
_CALLS="${_FIX}/calls.log"
mkdir -p "${_STUBBIN}"
: >"${_CALLS}"

export STUB_CALLS="${_CALLS}"
export _DOT_NO_PACKAGES=1
export PATH="${_STUBBIN}:${PATH}"

# --- stubs ---------------------------------------------------------------
cat >"${_STUBBIN}/podman" <<'EOF'
#!/usr/bin/env bash
echo "podman $*" >>"${STUB_CALLS}"
case "${1:-}" in
    info) exit "${PODMAN_STUB_INFO_RC:-0}" ;;
    --version) printf 'podman version %s\n' "${PODMAN_STUB_VERSION:-5.4.2}"; exit 0 ;;
    *) exit 0 ;;
esac
EOF
cat >"${_STUBBIN}/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >>"${STUB_CALLS}"
case "${1:-}" in
    info) exit "${DOCKER_STUB_INFO_RC:-0}" ;;
    --version) printf 'Docker version %s, build stub\n' "${DOCKER_STUB_VERSION:-29.7.2}"; exit 0 ;;
    *) exit 0 ;;
esac
EOF
cat >"${_STUBBIN}/getent" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == subuid || "${1:-}" == subgid ]]; then
    if [[ "${GETENT_STUB_HAVE_SUBIDS:-1}" == 1 ]]; then
        printf '%s:100000:65536\n' "${2:-user}"
        exit 0
    fi
    exit 2
fi
exec "${REAL_GETENT:-/usr/bin/getent}" "$@"
EOF
cat >"${_STUBBIN}/docker-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo "docker-script invoked" >>"${STUB_CALLS}"
exit "${DOCKER_SCRIPT_RC:-0}"
EOF
chmod +x "${_STUBBIN}/podman" "${_STUBBIN}/docker" "${_STUBBIN}/getent" "${_STUBBIN}/docker-stub.sh"
export REAL_GETENT
REAL_GETENT="$(command -v getent || printf '/usr/bin/getent')"

function reset_calls() { : >"${_CALLS}"; }

# shellcheck disable=SC1091
source "${_REPO_ROOT}/scripts/.container.utils.sh"
# shellcheck disable=SC1091
source "${_REPO_ROOT}/bin/container.sh"

# Privilege safety: record-only, never executes (usermod paths stay safe).
function _priv() {
    printf 'PRIV:%s\n' "$*" >>"${_CALLS}"
    return "${PRIV_STUB_RC:-0}"
}
function _container_docker_script() {
    printf '%s' "${_STUBBIN}/docker-stub.sh"
}

function run_case() {
    # run_case <varname-out> <varname-rc> -- <cmd...>: capture output+rc
    # under set -e safely.
    local out_var=${1} rc_var=${2}
    shift 2
    if [[ "${1:-}" == -- ]]; then
        shift
    fi
    set +e
    local _out _rc
    _out="$("$@" 2>/dev/null)"
    _rc=$?
    set -e
    printf -v "${out_var}" '%s' "${_out}"
    printf -v "${rc_var}" '%s' "${_rc}"
    return 0
}

# --- configured ------------------------------------------------------------
unset _DOT_CONTAINER_RUNTIME
assert_eq 'default configured podman' 'podman' "$(_ctr_configured)"
export _DOT_CONTAINER_RUNTIME=docker
assert_eq 'explicit docker' 'docker' "$(_ctr_configured)"
export _DOT_CONTAINER_RUNTIME=Docker
assert_eq 'case-insensitive' 'docker' "$(_ctr_configured)"
export _DOT_CONTAINER_RUNTIME=auto
assert_eq 'auto passthrough' 'auto' "$(_ctr_configured)"
export _DOT_CONTAINER_RUNTIME=bogus
run_case got rc -- _ctr_configured
assert_eq 'invalid rc 1' '1' "${rc}"
assert_eq 'invalid empty out' '' "${got}"
unset _DOT_CONTAINER_RUNTIME

# --- installed / version / usable -------------------------------------------
export PODMAN_STUB_INFO_RC=0 PODMAN_STUB_VERSION=5.4.2
export DOCKER_STUB_INFO_RC=0 DOCKER_STUB_VERSION=29.7.2
assert_eq 'podman installed' '0' "$(_ctr_installed podman; echo $?)"
assert_eq 'podman version' '5.4.2' "$(_ctr_version podman)"
assert_eq 'docker version' '29.7.2' "$(_ctr_version docker)"
_ctr_usable_podman; assert_eq 'podman usable rc' '0' "$?"
_ctr_usable_docker; assert_eq 'docker usable rc' '0' "$?"
export PODMAN_STUB_INFO_RC=1
if _ctr_usable_podman; then _FAIL=$((_FAIL + 1)); printf 'FAIL: unusable podman must fail\n' >&2
else _PASS=$((_PASS + 1)); fi
export PODMAN_STUB_INFO_RC=0

# --- selected is cheap (no probing) ------------------------------------------
export _DOT_CONTAINER_RUNTIME=auto
reset_calls
assert_eq 'auto displays podman default' 'podman' "$(_ctr_selected)"
assert_eq 'no probe for display' '0' "$(grep -c 'info' "${_CALLS}" || true)"
unset _DOT_CONTAINER_RUNTIME

# --- resolve matrix -----------------------------------------------------------
unset _DOT_CONTAINER_RUNTIME
assert_eq 'unset resolves podman' 'podman' "$(_ctr_resolve)"
export _DOT_CONTAINER_RUNTIME=docker
export DOCKER_STUB_INFO_RC=1
export PODMAN_STUB_INFO_RC=0
assert_eq 'explicit docker never switches' 'docker' "$(_ctr_resolve)"
export _DOT_CONTAINER_RUNTIME=podman
export PODMAN_STUB_INFO_RC=1
assert_eq 'explicit podman never switches' 'podman' "$(_ctr_resolve)"
export _DOT_CONTAINER_RUNTIME=auto
export PODMAN_STUB_INFO_RC=0
assert_eq 'auto prefers podman' 'podman' "$(_ctr_resolve)"
export PODMAN_STUB_INFO_RC=1
export DOCKER_STUB_INFO_RC=0
assert_eq 'auto falls to docker' 'docker' "$(_ctr_resolve)"
export DOCKER_STUB_INFO_RC=1
assert_eq 'auto with neither targets podman' 'podman' "$(_ctr_resolve)"
export PODMAN_STUB_INFO_RC=0
export DOCKER_STUB_INFO_RC=0
unset _DOT_CONTAINER_RUNTIME

# --- ctr dispatcher ------------------------------------------------------------
reset_calls
ctr ps -a >/dev/null
assert_contains 'ctr dispatches to podman' 'podman ps -a' "$(cat "${_CALLS}")"
export _DOT_CONTAINER_RUNTIME=docker
ctr images >/dev/null
assert_contains 'ctr dispatches to docker' 'docker images' "$(cat "${_CALLS}")"
unset _DOT_CONTAINER_RUNTIME

# --- ensure podman: already usable -> no changes --------------------------------
export PODMAN_STUB_INFO_RC=0
export GETENT_STUB_HAVE_SUBIDS=1
reset_calls
_container_ensure >/dev/null
assert_eq 'ready rc 0' '0' "$?"
assert_eq 'ready makes no priv calls' '0' "$(grep -c '^PRIV:' "${_CALLS}" || true)"

# --- ensure podman: missing pieces fail loudly ----------------------------------
mv "${_STUBBIN}/podman" "${_STUBBIN}/podman.hidden"
reset_calls
run_case got rc -- _container_ensure
assert_eq 'missing podman rc 1' '1' "${rc}"
assert_eq 'no priv calls on missing' '0' "$(grep -c '^PRIV:' "${_CALLS}" || true)"
mv "${_STUBBIN}/podman.hidden" "${_STUBBIN}/podman"

# --- ensure podman: subids missing -> exactly one usermod attempt ---------------
export GETENT_STUB_HAVE_SUBIDS=0
export PODMAN_STUB_INFO_RC=1
reset_calls
run_case got rc -- _container_ensure
assert_eq 'subid path rc 1 (still unusable)' '1' "${rc}"
assert_eq 'usermod attempted once' '1' "$(grep -c '^PRIV:.*usermod' "${_CALLS}" || true)"
export GETENT_STUB_HAVE_SUBIDS=1
export PODMAN_STUB_INFO_RC=0

# --- ensure docker: delegates, never touches podman path -------------------------
export _DOT_CONTAINER_RUNTIME=docker
export DOCKER_STUB_INFO_RC=1
reset_calls
_container_ensure >/dev/null 2>&1
assert_eq 'docker delegates rc 0' '0' "$?"
assert_contains 'docker script ran' 'docker-script invoked' "$(cat "${_CALLS}")"
assert_eq 'no usermod on docker path' '0' "$(grep -c 'usermod' "${_CALLS}" || true)"
unset _DOT_CONTAINER_RUNTIME
export DOCKER_STUB_INFO_RC=0

# --- status -----------------------------------------------------------------------
out="$(_container_status)"
assert_contains 'status configured' 'Configured:' "${out}"
assert_contains 'status selected podman' 'Selected:   podman' "${out}"
assert_contains 'status podman ver' 'Podman:     installed 5.4.2' "${out}"
assert_contains 'status docker ver' 'Docker:     installed 29.7.2' "${out}"
assert_contains 'status rootless' 'Rootless:   yes' "${out}"
assert_contains 'status usable' 'Usable:     yes' "${out}"
export _DOT_CONTAINER_RUNTIME=bogus
run_case got rc -- _container_status
assert_eq 'status invalid rc 1' '1' "${rc}"
unset _DOT_CONTAINER_RUNTIME

# --- idempotency ---------------------------------------------------------------------
reset_calls
_container_ensure >/dev/null
_container_ensure >/dev/null
assert_eq 'double ensure makes no priv calls' '0' "$(grep -c '^PRIV:' "${_CALLS}" || true)"

printf 'tests: %d passed, %d failed\n' "${_PASS}" "${_FAIL}"
exit $(( _FAIL > 0 ))
