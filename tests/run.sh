#!/usr/bin/env bash
#
# run.sh — run every tests/test-*.sh and report a summary.

set -Eeuo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_failures=0
_total=0

for t in "${_TEST_DIR}"/test-*.sh "${_TEST_DIR}"/test-*.zsh; do
    [[ -e "${t}" ]] || continue
    _total=$((_total + 1))
    printf '=== %s ===\n' "$(basename "${t}")"
    case "${t}" in
        *.zsh)
            if ! command -v zsh >/dev/null 2>&1; then
                printf -- '--- SKIP: %s (zsh not installed)\n' "$(basename "${t}")"
                continue
            fi
            runner=(zsh "${t}") ;;
        *) runner=(bash "${t}") ;;
    esac
    if "${runner[@]}"; then
        printf -- '--- PASS: %s\n' "$(basename "${t}")"
    else
        printf -- '--- FAIL: %s\n' "$(basename "${t}")"
        _failures=$((_failures + 1))
    fi
done

printf 'suites: %d run, %d failed\n' "${_total}" "${_failures}"
exit $(( _failures > 0 ))
