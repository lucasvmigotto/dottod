#!/usr/bin/env bash
#
# run.sh — run every tests/test-*.sh and report a summary.

set -Eeuo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_failures=0
_total=0

for t in "${_TEST_DIR}"/test-*.sh; do
    _total=$((_total + 1))
    printf '=== %s ===\n' "$(basename "${t}")"
    if bash "${t}"; then
        printf -- '--- PASS: %s\n' "$(basename "${t}")"
    else
        printf -- '--- FAIL: %s\n' "$(basename "${t}")"
        _failures=$((_failures + 1))
    fi
done

printf 'suites: %d run, %d failed\n' "${_total}" "${_failures}"
exit $(( _failures > 0 ))
