#!/usr/bin/env bash
#
# run.sh — run every tests/test-*.bats (via bats) and tests/test-*.zsh
# (via zsh) and report a summary.

set -Eeuo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_failures=0
_total=0

# Plain-bash suites are retired: every tests/test-*.sh must have a .bats
# twin. Fail loudly instead of silently skipping, so a stray .sh suite
# can never go unexecuted.
if compgen -G "${_TEST_DIR}/test-*.sh" > /dev/null; then
    printf -- 'ERROR: tests/test-*.sh suites must be ported to .bats:\n' >&2
    compgen -G "${_TEST_DIR}/test-*.sh" >&2
    exit 1
fi

for t in "${_TEST_DIR}"/test-*.bats "${_TEST_DIR}"/test-*.zsh; do
    [[ -e "${t}" ]] || continue
    _total=$((_total + 1))
    printf '=== %s ===\n' "$(basename "${t}")"
    case "${t}" in
        *.bats)
            if ! command -v bats >/dev/null 2>&1; then
                printf -- '--- ERROR: %s needs `bats` (Debian: sudo apt-get install -y bats)\n' "$(basename "${t}")"
                _failures=$((_failures + 1))
                continue
            fi
            runner=(bats "${t}") ;;
        *.zsh)
            if ! command -v zsh >/dev/null 2>&1; then
                printf -- '--- SKIP: %s (zsh not installed)\n' "$(basename "${t}")"
                continue
            fi
            runner=(zsh "${t}") ;;
        *) printf -- '--- ERROR: unknown suite type: %s\n' "$(basename "${t}")" >&2
            _failures=$((_failures + 1))
            continue ;;
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
