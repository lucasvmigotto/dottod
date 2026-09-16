#!/usr/bin/env zsh
#
# test-spaceship-sysinfo.zsh — tests for scripts/.sysinfo.prompt.sh
# Run via tests/run.sh (needs zsh). Uses stub collectors + stub
# spaceship::section; never requires oh-my-zsh or Spaceship installed.

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

# Stub collector printing a fixed segment.
printf '#!/usr/bin/env bash\nprintf "STUB-SEGMENT"\n' >"${_FIX}/collector-ok"
chmod +x "${_FIX}/collector-ok"
printf '#!/usr/bin/env bash\nexit 3\n' >"${_FIX}/collector-fail"
chmod +x "${_FIX}/collector-fail"
printf '#!/usr/bin/env bash\nprintf ""\n' >"${_FIX}/collector-empty"
chmod +x "${_FIX}/collector-empty"

# Stub Spaceship API capturing its arguments.
SPACESHIP_CAPTURED=""
SPACESHIP_PROMPT_DEFAULT_PREFIX="via "
SPACESHIP_PROMPT_DEFAULT_SUFFIX=" "
function spaceship::section() {
    SPACESHIP_CAPTURED="$*"
}

export _DOT_SYSINFO_COLLECTOR="${_FIX}/collector-ok"
source "${_TEST_DIR}/../scripts/.sysinfo.prompt.sh"

# --- rendering ---------------------------------------------------------------
# NOTE: no command substitution here — the stub records args in a variable,
# which a subshell would discard.
spaceship_sysinfo >/dev/null; rc=$?
assert_eq 'renders stub via section API' '--color cyan --prefix via  --suffix   STUB-SEGMENT' "${SPACESHIP_CAPTURED}"
assert_eq 'render rc 0' '0' "${rc}"

SPACESHIP_SYSINFO_COLOR="magenta" SPACESHIP_SYSINFO_SYMBOL="S" spaceship_sysinfo >/dev/null
assert_eq 'color/symbol overrides' '--color magenta --prefix via  --suffix   --symbol S STUB-SEGMENT' "${SPACESHIP_CAPTURED}"
unset SPACESHIP_SYSINFO_COLOR SPACESHIP_SYSINFO_SYMBOL

SPACESHIP_SYSINFO_SHOW=false out="$(spaceship_sysinfo)"; rc=$?
assert_eq 'SHOW=false hides' '' "${out}"
assert_eq 'SHOW=false rc 0' '0' "${rc}"
unset SPACESHIP_SYSINFO_SHOW

_DOT_SYSTEM_INFO_ENABLED=false out="$(spaceship_sysinfo)"; rc=$?
assert_eq 'ENABLED=false hides' '' "${out}"
assert_eq 'ENABLED=false rc 0' '0' "${rc}"
export _DOT_SYSTEM_INFO_ENABLED=true

export _DOT_SYSINFO_COLLECTOR="${_FIX}/collector-fail"
out="$(spaceship_sysinfo)"; rc=$?
assert_eq 'failing collector hides' '' "${out}"
assert_eq 'failing collector rc 0' '0' "${rc}"

export _DOT_SYSINFO_COLLECTOR="${_FIX}/collector-empty"
out="$(spaceship_sysinfo)"; rc=$?
assert_eq 'empty collector hides' '' "${out}"
assert_eq 'empty collector rc 0' '0' "${rc}"

export _DOT_SYSINFO_COLLECTOR=/nonexistent/collector
out="$(spaceship_sysinfo)"; rc=$?
assert_eq 'missing collector hides' '' "${out}"
assert_eq 'missing collector rc 0' '0' "${rc}"

# No Spaceship API -> plain fallback output.
unfunction spaceship::section
export _DOT_SYSINFO_COLLECTOR="${_FIX}/collector-ok"
out="$(spaceship_sysinfo)"; rc=$?
assert_eq 'fallback without API' 'STUB-SEGMENT ' "${out}"
assert_eq 'fallback rc 0' '0' "${rc}"

# --- registration ------------------------------------------------------------
SPACESHIP_PROMPT_ORDER=(dir git line_sep battery char)
_dottod_sysinfo_register
_dottod_sysinfo_register
assert_eq 'inserted once before line_sep' 'dir git sysinfo line_sep battery char' "${SPACESHIP_PROMPT_ORDER[*]}"

SPACESHIP_PROMPT_ORDER=(dir git char)
_dottod_sysinfo_register
assert_eq 'appended without line_sep' 'dir git char sysinfo' "${SPACESHIP_PROMPT_ORDER[*]}"

SPACESHIP_PROMPT_ORDER=(sysinfo dir git)
_dottod_sysinfo_register
assert_eq 'existing entry untouched' 'sysinfo dir git' "${SPACESHIP_PROMPT_ORDER[*]}"

unset SPACESHIP_PROMPT_ORDER
_dottod_sysinfo_register; rc=$?
assert_eq 'unset order safe rc 0' '0' "${rc}"

# The collector is a bash program living under scripts/*.sh, so the
# .custom.zshrc glob sources it into interactive zsh: assert that is a
# silent no-op and leaks no shell options (notably NO_UNSET from set -u).
out="$(zsh -c 'source "'"${_TEST_DIR}/../scripts/system-info.sh"'"; print -r -- "sourced-ok"; [[ -o NO_UNSET ]] && print -r -- POLLUTED' 2>&1)"
assert_eq 'collector zsh-source no-op' 'sourced-ok' "${out}"

print -r -- "tests: ${_PASS} passed, ${_FAIL} failed"
exit $(( _FAIL > 0 ))
