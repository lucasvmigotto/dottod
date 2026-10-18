#!/usr/bin/env bash
#
# run.sh — run every tests/test-*.bats (via bats) and report a summary.

set -Eeuo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_failures=0
_total=0

# bats from PATH, else bunx, else a clear error (per suite, below).
_bats=()
if command -v bats >/dev/null 2>&1; then
    _bats=(bats)
elif command -v bunx >/dev/null 2>&1; then
    _bats=(bunx bats@1.11.1)
fi

# Plain-bash suites are retired: every tests/test-*.sh must have a .bats
# twin. Fail loudly instead of silently skipping, so a stray .sh suite
# can never go unexecuted.
if compgen -G "${_TEST_DIR}/test-*.sh" >/dev/null; then
    printf -- 'ERROR: tests/test-*.sh suites must be ported to .bats:\n' >&2
    compgen -G "${_TEST_DIR}/test-*.sh" >&2
    exit 1
fi

for t in "${_TEST_DIR}"/test-*.bats; do
    [[ -e "${t}" ]] || continue
    _total=$((_total + 1))
    printf '=== %s ===\n' "$(basename "${t}")"
    if ((${#_bats[@]} == 0)); then
        printf -- '--- ERROR: %s needs `bats` or `bunx` (install bats from your distro, or run: just tools)\n' "$(basename "${t}")"
        _failures=$((_failures + 1))
        continue
    fi
    if "${_bats[@]}" "${t}"; then
        printf -- '--- PASS: %s\n' "$(basename "${t}")"
    else
        printf -- '--- FAIL: %s\n' "$(basename "${t}")"
        _failures=$((_failures + 1))
    fi
done

printf 'suites: %d run, %d failed\n' "${_total}" "${_failures}"
exit $((_failures > 0))
