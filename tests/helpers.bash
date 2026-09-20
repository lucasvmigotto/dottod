#!/usr/bin/env bash
#
# helpers.bash — shared BATS assertions for dottod suites.
#
# Loaded once per suite with `load helpers` (bats resolves it relative to
# the test file). Deliberately no `set -euo pipefail`: BATS manages errexit
# itself and `set -u` fights its internals. Use ${VAR:-} defensively.
#
# Conventions mirror the retired plain-bash suites: every assertion prints
# a FAIL block with expected/actual and returns 1, which fails the test.
#
# Suites that source bin/*.sh must keep errexit enabled and re-arm bats'
# EXIT trap after sourcing (the sourced utils.sh replaces it); otherwise a
# failing assertion can vanish from the report (bats 1.14: "Executed N-1
# instead of N tests"). See tests/test-neovim.bats setup() for the recipe.

function assert_eq() {
    local desc=${1} expected=${2} actual=${3}
    if [[ "${expected}" == "${actual}" ]]; then
        return 0
    fi
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "${desc}" "${expected}" "${actual}" >&2
    return 1
}

function assert_contains() {
    local desc=${1} needle=${2} haystack=${3}
    if [[ "${haystack}" == *"${needle}"* ]]; then
        return 0
    fi
    printf 'FAIL: %s\n  missing: %q\n  in: %q\n' "${desc}" "${needle}" "${haystack}" >&2
    return 1
}

function assert_match() {
    local desc=${1} pattern=${2} actual=${3}
    if [[ "${actual}" =~ ${pattern} ]]; then
        return 0
    fi
    printf 'FAIL: %s\n  pattern: %s\n  actual:  %q\n' "${desc}" "${pattern}" "${actual}" >&2
    return 1
}
