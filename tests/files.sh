#!/usr/bin/env bash
#
# files.sh — the shell files each gate recipe checks, derived from git so a
# new script is covered without editing the justfile.
#   files.sh syntax|lint|fmt

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Not shell (or not ours to format): none today; list exclusions here.
_exclude_re='^$'

_sources() {
    git ls-files -- 'bin/*.sh' 'lib/*.sh' 'lib/packages/*.sh' 'scripts/*.sh' \
        'scripts/.*.sh' 'styles/*.sh' 'tests/*.sh' 'tests/integration/*.sh' \
        config/.custom.bashrc | grep -Ev "${_exclude_re}"
}

case "${1:-}" in
    syntax | fmt) _sources ;;
    lint)
        _sources
        git ls-files -- 'tests/*.bats' tests/helpers.bash
        ;;
    *)
        printf 'usage: files.sh syntax|lint|fmt\n' >&2
        exit 2
        ;;
esac
