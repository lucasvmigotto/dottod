#!/usr/bin/env zsh
#
# test-container.zsh — zsh-side tests for the container runtime integration:
# scripts/.container.utils.sh under zsh, spaceship_container rendering, and
# prompt-order registration. Run via tests/run.sh (needs zsh).

set -u

_TEST_DIR="${${(%):-%N}:A:h}"
_PASS=0
_FAIL=0

function assert_eq() {
    local desc=${1} expected=${2} actual=${3}
    if [[ "${expected}" == "${actual}" ]]; then
        _PASS=$((_PASS + 1))
    else
        _FAIL=$((_FAIL + 1))
        print -u2 -r -- "FAIL: ${desc}"
        print -u2 -r -- "  expected: ${(q)expected}"
        print -u2 -r -- "  actual:   ${(q)actual}"
    fi
}

_FIX="$(mktemp -d)"
trap 'rm -rf "${_FIX}"' EXIT
mkdir "${_FIX}/bin"
printf '#!/usr/bin/env bash\necho "podman-stub $*" | tee -a "${STUB_CALLS}"\nexit "${PODMAN_STUB_RC:-0}"\n' >"${_FIX}/bin/podman"
printf '#!/usr/bin/env bash\necho "docker-stub $*" | tee -a "${STUB_CALLS}"\nexit "${DOCKER_STUB_RC:-0}"\n' >"${_FIX}/bin/docker"
chmod +x "${_FIX}/bin/podman" "${_FIX}/bin/docker"
export STUB_CALLS="${_FIX}/calls.log"
export PATH="${_FIX}/bin:${PATH}"

SPACESHIP_PROMPT_DEFAULT_PREFIX="via "
SPACESHIP_PROMPT_DEFAULT_SUFFIX=" "
SPACESHIP_CAPTURED=""
function spaceship::section() {
    SPACESHIP_CAPTURED="$*"
}

source "${_TEST_DIR}/../scripts/.container.utils.sh"
source "${_TEST_DIR}/../scripts/.sysinfo.prompt.sh"

# Expected glyph in code-point notation (md-cube, mirrors the section file).
GLYPH=$'\uF01A6'

# --- lib under zsh ------------------------------------------------------------
unset _DOT_CONTAINER_RUNTIME
assert_eq 'zsh default podman' 'podman' "$(_ctr_selected)"
assert_eq 'zsh resolve podman' 'podman' "$(_ctr_resolve)"
export _DOT_CONTAINER_RUNTIME=docker
assert_eq 'zsh explicit docker' 'docker' "$(_ctr_selected)"
export PODMAN_STUB_RC=0
unset _DOT_CONTAINER_RUNTIME
out="$(ctr ps)"; rc=$?
assert_eq 'zsh ctr dispatches' 'podman-stub ps' "${out}"
assert_eq 'zsh ctr rc' '0' "${rc}"
export _DOT_CONTAINER_RUNTIME=docker
out="$(ctr ps)"; rc=$?
assert_eq 'zsh ctr follows explicit docker' 'docker-stub ps' "${out}"
unset _DOT_CONTAINER_RUNTIME

# --- section rendering ----------------------------------------------------------
unset _DOT_CONTAINER_RUNTIME
SPACESHIP_CAPTURED=""
spaceship_container >/dev/null; rc=$?
assert_eq 'renders podman token' "--color cyan --prefix via  --suffix   --symbol ${GLYPH} podman" "${SPACESHIP_CAPTURED}"
assert_eq 'render rc 0' '0' "${rc}"

export _DOT_CONTAINER_RUNTIME=docker
SPACESHIP_CAPTURED=""
spaceship_container >/dev/null
assert_eq 'renders docker token' "--color cyan --prefix via  --suffix   --symbol ${GLYPH} docker" "${SPACESHIP_CAPTURED}"
unset _DOT_CONTAINER_RUNTIME

export _DOT_CONTAINER_RUNTIME=bogus
out="$(spaceship_container)"; rc=$?
assert_eq 'invalid hides' '' "${out}"
assert_eq 'invalid rc 0' '0' "${rc}"
unset _DOT_CONTAINER_RUNTIME

SPACESHIP_CONTAINER_SHOW=false out="$(spaceship_container)"; rc=$?
assert_eq 'SHOW=false hides' '' "${out}"
assert_eq 'SHOW=false rc 0' '0' "${rc}"
unset SPACESHIP_CONTAINER_SHOW

unfunction _ctr_selected
out="$(spaceship_container)"; rc=$?
assert_eq 'missing lib hides' '' "${out}"
assert_eq 'missing lib rc 0' '0' "${rc}"
source "${_TEST_DIR}/../scripts/.container.utils.sh"

unfunction spaceship::section
out="$(spaceship_container)"; rc=$?
assert_eq 'fallback without API' "${GLYPH} podman " "${out}"
assert_eq 'fallback rc 0' '0' "${rc}"

# --- registration ---------------------------------------------------------------
SPACESHIP_PROMPT_ORDER=(dir git line_sep battery char)
_dottod_sysinfo_register
_dottod_container_register
_dottod_container_register
assert_eq 'container after sysinfo' 'dir git sysinfo container line_sep battery char' "${SPACESHIP_PROMPT_ORDER[*]}"

SPACESHIP_PROMPT_ORDER=(dir git char)
_dottod_container_register
assert_eq 'appended without sysinfo/line_sep' 'dir git char container' "${SPACESHIP_PROMPT_ORDER[*]}"

SPACESHIP_PROMPT_ORDER=(dir git sysinfo)
_dottod_container_register
assert_eq 'sysinfo-last edge' 'dir git sysinfo container' "${SPACESHIP_PROMPT_ORDER[*]}"

SPACESHIP_PROMPT_ORDER=(container dir git)
_dottod_container_register
assert_eq 'existing entry untouched' 'container dir git' "${SPACESHIP_PROMPT_ORDER[*]}"

unset SPACESHIP_PROMPT_ORDER
_dottod_container_register; rc=$?
assert_eq 'unset order safe rc 0' '0' "${rc}"

print -r -- "tests: ${_PASS} passed, ${_FAIL} failed"
exit $(( _FAIL > 0 ))
