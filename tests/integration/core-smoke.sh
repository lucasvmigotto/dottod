#!/usr/bin/env bash
#
# core-smoke.sh — core bootstrap on real distros (spec 015, milestone G1).
#
# Runs the real `bin/bootstrap.sh --only shell,vim,gitconfig,ssh,fonts`
# twice in a throwaway container per distro, as root, then checks the
# results and that the second run installed nothing and changed no file
# in $HOME. Needs network (packages, Nerd Fonts, vim-plug).
#
# Gated: runs only with DOTTOD_TEST_INTEGRATION=1 (otherwise SKIP, rc 0).
#
#   core-smoke.sh [distro...]   on the host (default: all; see distros.sh)
#   core-smoke.sh --inside      inside a container (the host mode calls it)

set -Eeuo pipefail

# shellcheck source=distros.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/distros.sh"

readonly TASKS='shell,vim,gitconfig,ssh,fonts'

function _check() {
    local desc=${1}
    shift
    if "$@" >/dev/null 2>&1; then
        printf '  ok    %s\n' "${desc}"
    else
        printf '  FAIL  %s\n' "${desc}"
        _FAILURES=$((_FAILURES + 1))
    fi
}

function _inside() {
    _FAILURES=0
    export GIT_NAME='dottod smoke' GIT_EMAIL='smoke@example.invalid'
    cd /w

    printf -- '--- run 1\n'
    ./bin/bootstrap.sh --only "${TASKS}" --verbose >/tmp/run1.log 2>&1 || {
        tail -40 /tmp/run1.log
        printf 'run 1 FAILED\n'
        return 1
    }
    grep -E 'PASS|FAIL|!!|Installing with' /tmp/run1.log || true

    : >/tmp/marker
    printf -- '--- run 2\n'
    ./bin/bootstrap.sh --only "${TASKS}" --verbose >/tmp/run2.log 2>&1 || {
        tail -40 /tmp/run2.log
        printf 'run 2 FAILED\n'
        return 1
    }
    grep -E 'PASS|FAIL|!!' /tmp/run2.log || true

    printf -- '--- checks\n'
    local shell
    shell="$(getent passwd root 2>/dev/null | cut -d: -f7)" || shell="$(grep '^root:' /etc/passwd | cut -d: -f7)"
    _check 'HOME/.bashrc links to the repo' test "$(readlink -f "${HOME}/.bashrc")" = /w/config/.custom.bashrc
    if [[ "${shell##*/}" == bash ]]; then
        _check "login shell is bash (${shell})" true
    else
        _check "login shell kept (${shell}) with a warning" grep -q 'login shell stays' /tmp/run1.log
    fi
    _check 'git identity set' test "$(git config --global user.email)" = smoke@example.invalid
    _check 'ssh key generated' test -f "${HOME}/.ssh/github"
    _check 'nerd fonts installed' sh -c "ls '${HOME}/.local/share/fonts' | grep -q ."
    _check 'vim-plug and plugins present' test -d "${HOME}/.vim/plugged"
    _check 'run 2 installed no packages' sh -c '! grep -q "Installing with" /tmp/run2.log'
    # Timestamps alone miss re-extracted fonts (Info-ZIP unzip keeps the
    # archive's mtimes), so check the downloads directly too.
    _check 'run 2 downloaded nothing' sh -c '! grep -q "Downloading" /tmp/run2.log'
    _check 'run 2 changed no file in $HOME' sh -c "[ -z \"\$(find '${HOME}' -newer /tmp/marker -type f ! -path '*/.cache/*' ! -name '*.log' 2>/dev/null)\" ]"

    printf '%s: %d failed checks\n' "$(. /etc/os-release && printf '%s' "${ID}")" "${_FAILURES}"
    ((_FAILURES == 0))
}

function _host() {
    local repo distro image failures=0
    local -a extra=()
    repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    command -v podman >/dev/null 2>&1 || {
        echo 'FAIL: podman binary missing' >&2
        return 1
    }

    for distro in "${@:-${DOT_IT_DISTROS[@]}}"; do
        image="$(_it_image "${distro}")" || {
            echo "FAIL: unknown distro '${distro}' (want: ${DOT_IT_DISTROS[*]})" >&2
            return 1
        }
        mapfile -t extra < <(_it_run_args "${distro}")
        printf '=== %s\n' "${distro}"
        if ! podman run --rm "${extra[@]}" \
            -v "${repo}:/w:ro,Z" -e DOTTOD_TEST_INTEGRATION=1 \
            "${image}" sh -c "$(_it_prep "${distro}" system) && bash /w/tests/integration/core-smoke.sh --inside"; then
            failures=$((failures + 1))
        fi
    done

    printf 'distros failing: %d\n' "${failures}"
    ((failures == 0))
}

if [[ "${DOTTOD_TEST_INTEGRATION:-0}" != 1 ]]; then
    echo 'SKIP: set DOTTOD_TEST_INTEGRATION=1 to run the core smoke test'
    exit 0
fi

if [[ "${1:-}" == --inside ]]; then
    _inside
else
    _host "$@"
fi
