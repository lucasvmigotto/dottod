#!/usr/bin/env bash
#
# prompt.sh — median render time of every prompt style, in a fixture repo.
#   tests/bench/prompt.sh [runs]    (default 31; prints "style  median-ms")
# Needs bash >= 5 (EPOCHREALTIME). Not part of the gate: timings depend on
# the machine; tests/test-prompt-perf.bats asserts the machine-independent
# part (git invocations per render).

set -Eeuo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runs="${1:-31}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

export HOME="${tmp}/home" XDG_CACHE_HOME="${tmp}/cache"
mkdir -p "${HOME}" "${tmp}/repo/src"
git -C "${tmp}/repo" init -q -b main
git -C "${tmp}/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
: >"${tmp}/repo/package.json"
: >"${tmp}/repo/untracked"

cat >"${tmp}/one.sh" <<'SH'
source "${ROOT}/config/.custom.bashrc" >/dev/null 2>&1
cd "${REPO}/src"
hook="${PROMPT_COMMAND%%;*}"
${hook}
times=()
for ((i = 0; i < RUNS; i++)); do
    s=${EPOCHREALTIME/./}
    ${hook}
    e=${EPOCHREALTIME/./}
    times+=($((e - s)))
done
sorted=($(printf '%s\n' "${times[@]}" | sort -n))
printf '%d.%d' $((sorted[RUNS / 2] / 1000)) $((sorted[RUNS / 2] % 1000 / 100))
SH

for style in robbyrussell kali powerline pastel tokyonight gruvbox catppuccin; do
    ms="$(ROOT="${root}" REPO="${tmp}/repo" RUNS="${runs}" DOT_PROMPT_STYLE="${style}" DOT_PROMPT_CONTAINERS=0 bash -i "${tmp}/one.sh" 2>/dev/null | tail -n 1)"
    printf '%-12s %s ms\n' "${style}" "${ms}"
done
