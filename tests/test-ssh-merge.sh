#!/usr/bin/env bash
#
# test-ssh-merge.sh — tests for the GitHub SSH merge in bin/ssh.sh.
# All cases run against temporary directories; the real user ~/.ssh is
# never touched. OpenSSH parsing is validated with `ssh -G -F` (no network).

set -uo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_TEST_DIR}/.." && pwd)"
_TEMPLATE="${_REPO_ROOT}/config/.ssh.config"
_PASS=0
_FAIL=0

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
        printf 'FAIL: %s\n  missing: %q\n' "${desc}" "${needle}" >&2
    fi
}

# shellcheck disable=SC1091
source "${_REPO_ROOT}/bin/ssh.sh"

_FIX="$(mktemp -d)"
trap 'rm -rf "${_FIX}"' EXIT

function fresh_target() {
    local d
    d="$(mktemp -d -p "${_FIX}")"
    printf '%s' "${d}/config"
}

# --- template: single source of truth ---------------------------------------
mapfile -t _want < <(_github_wanted_options "${_TEMPLATE}")
assert_eq 'template yields 6 options' '6' "${#_want[@]}"
assert_eq 'template key order' \
    $'HostName\tgithub.com\nUser\tgit\nIdentityFile\t~/.ssh/github\nIdentitiesOnly\tyes\nAddKeysToAgent\tyes\nLogLevel\tVERBOSE' \
    "$(printf '%s\n' "${_want[@]}")"

# --- Case A: no config --------------------------------------------------------
T="$(fresh_target)"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'case A matches template' "$(cat "${_TEMPLATE}")" "$(cat "${T}")"
assert_eq 'case A mode 600' '600' "$(stat -c %a "${T}")"
assert_eq 'case A no backup' '0' "$([[ -e "${T}.dottod.bak" ]] && echo 1 || echo 0)"

# --- Case B: unrelated config preserved, block appended ----------------------
T="$(fresh_target)"
printf 'Host myserver\n    HostName example.com\n    User me\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_contains 'unrelated host kept' 'Host myserver' "$(cat "${T}")"
assert_contains 'unrelated value kept' 'HostName example.com' "$(cat "${T}")"
assert_contains 'github block added' 'Host github.com' "$(cat "${T}")"
assert_contains 'github user added' 'User git' "$(cat "${T}")"
assert_eq 'backup created' '1' "$([[ -e "${T}.dottod.bak" ]] && echo 1 || echo 0)"
assert_eq 'backup holds original' 'Host myserver' "$(head -n1 "${T}.dottod.bak")"
before="$(cat "${T}")"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'second run byte-identical' "${before}" "$(cat "${T}")"
assert_eq 'single Host github.com' '1' "$(grep -ci '^Host github.com' "${T}")"

# --- complete block: untouched, no backup ------------------------------------
T="$(fresh_target)"
cp "${_TEMPLATE}" "${T}"
chmod 600 "${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'complete block unchanged' "$(cat "${_TEMPLATE}")" "$(cat "${T}")"
assert_eq 'complete block no backup' '0' "$([[ -e "${T}.dottod.bak" ]] && echo 1 || echo 0)"

# --- partial block: only missing keys added ----------------------------------
T="$(fresh_target)"
printf 'Host github.com\n    HostName github.com\n    User git\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'partial gets 4 missing keys' '7' "$(wc -l <"${T}")"
assert_contains 'identity added' 'IdentityFile ~/.ssh/github' "$(cat "${T}")"
assert_contains 'agent added' 'AddKeysToAgent yes' "$(cat "${T}")"

# --- conflicting values: never overwritten -----------------------------------
T="$(fresh_target)"
printf 'Host github.com\n    HostName github.com\n    User deploy\n    IdentityFile ~/.ssh/id_rsa\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_contains 'user value preserved' 'User deploy' "$(cat "${T}")"
assert_eq 'user not duplicated' '1' "$(grep -ci '^[[:space:]]*user[[:space:]=]' "${T}")"
assert_contains 'identity value preserved' 'IdentityFile ~/.ssh/id_rsa' "$(cat "${T}")"
assert_contains 'missing still added' 'IdentitiesOnly yes' "$(cat "${T}")"

# --- wildcards are not treated as github.com ---------------------------------
T="$(fresh_target)"
printf 'Host *\n    ForwardAgent yes\n\nHost *.example.com\n    User me\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'wildcard untouched + block appended' '1' "$(grep -ci '^Host github.com' "${T}")"
assert_contains 'wildcard kept' 'ForwardAgent yes' "$(cat "${T}")"

# --- case-insensitive host token ---------------------------------------------
T="$(fresh_target)"
printf 'HOST GitHub.COM\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/github\n    IdentitiesOnly yes\n    AddKeysToAgent yes\n    LogLevel VERBOSE\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'recognized block not duplicated' '1' "$(grep -ci '^host[[:space:]]\+github\.com$' "${T}")"
assert_eq 'no backup when complete' '0' "$([[ -e "${T}.dottod.bak" ]] && echo 1 || echo 0)"

# --- double-quoted host token -------------------------------------------------
T="$(fresh_target)"
printf 'Host "github.com"\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/github\n    IdentitiesOnly yes\n    AddKeysToAgent yes\n    LogLevel VERBOSE\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'quoted block not duplicated' '1' "$(grep -ci '^host[[:space:]]\+"github\.com"$' "${T}")"
assert_eq 'quoted block no backup' '0' "$([[ -e "${T}.dottod.bak" ]] && echo 1 || echo 0)"

T="$(fresh_target)"
printf 'Host "github.com"\n    User git\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_contains 'quoted partial gets missing keys' 'IdentityFile ~/.ssh/github' "$(cat "${T}")"
assert_eq 'quoted partial single host line' '1' "$(grep -ci '^host[[:space:]]' "${T}")"

T="$(fresh_target)"
printf 'Host "*.example.com"\n    User me\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'quoted wildcard gets appended block' '1' "$(grep -ci '^Host github.com' "${T}")"
assert_contains 'quoted wildcard kept' 'Host "*.example.com"' "$(cat "${T}")"

# --- insertion stays inside the block (before Match) --------------------------
T="$(fresh_target)"
printf 'Host github.com\n    User git\n\nMatch host myserver\n    ForwardAgent yes\n' >"${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
github_line="$(grep -n '^Host github.com' "${T}" | cut -d: -f1)"
match_line="$(grep -n '^Match' "${T}" | cut -d: -f1)"
ident_line="$(grep -n 'IdentityFile' "${T}" | head -n1 | cut -d: -f1)"
if (( ident_line > github_line && ident_line < match_line )); then
    _PASS=$((_PASS + 1))
else
    _FAIL=$((_FAIL + 1)); printf 'FAIL: inserted keys must stay inside block\n' >&2
fi

# --- legacy symlink to template -> replaced by real file ----------------------
T="$(fresh_target)"
ln -s "${_TEMPLATE}" "${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'legacy symlink replaced' '0' "$([[ -L "${T}" ]] && echo 1 || echo 0)"
assert_contains 'replacement has github block' 'Host github.com' "$(cat "${T}")"

# --- user symlink elsewhere -> preserved, target merged -----------------------
T="$(fresh_target)"
printf 'Host myserver\n    User me\n' >"${T}.real"
ln -s "${T}.real" "${T}"
_merge_github_config "${T}" "${_TEMPLATE}" >/dev/null
assert_eq 'user symlink kept' '1' "$([[ -L "${T}" ]] && echo 1 || echo 0)"
assert_contains 'link target merged' 'Host github.com' "$(cat "${T}.real")"

# --- OpenSSH accepts every result ---------------------------------------------
for cfg in "${T}" "${T}.real"; do
    if ssh -G -F "${cfg}" github.com >/dev/null 2>&1; then
        _PASS=$((_PASS + 1))
    else
        _FAIL=$((_FAIL + 1)); printf 'FAIL: ssh -G -F rejects %s\n' "${cfg}" >&2
    fi
done
eff="$(ssh -G -F "${T}.real" github.com 2>/dev/null)"
assert_contains 'effective hostname' 'hostname github.com' "${eff}"
assert_contains 'effective identityfile' 'identityfile ~/.ssh/github' "${eff}"
assert_contains 'effective identitiesonly' 'identitiesonly yes' "${eff}"
# NB: `ssh -G` canonicalizes yes -> true in its output.
assert_contains 'effective addkeystoagent' 'addkeystoagent true' "${eff}"

# --- _main end-to-end with isolated dir ---------------------------------------
export _DOT_SSH_DIR="${_FIX}/dotssh"
_main >/dev/null
assert_eq 'main creates config' '1' "$([[ -f "${_DOT_SSH_DIR}/config" ]] && echo 1 || echo 0)"
assert_eq 'main dir 700' '700' "$(stat -c %a "${_DOT_SSH_DIR}")"
assert_eq 'main config 600' '600' "$(stat -c %a "${_DOT_SSH_DIR}/config")"
_main >/dev/null
assert_eq 'main idempotent' '1' "$(grep -ci '^Host github.com' "${_DOT_SSH_DIR}/config")"

printf 'tests: %d passed, %d failed\n' "${_PASS}" "${_FAIL}"
exit $(( _FAIL > 0 ))
