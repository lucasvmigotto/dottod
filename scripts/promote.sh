#!/usr/bin/env bash
#
# promote.sh — promote develop to main and wait for the release (spec 022).
#
#   scripts/promote.sh [--dry-run] [--no-wait]      (just promote)
#
# Refuses unless: you are on develop; the tree is clean; develop is pushed;
# develop contains origin/main (a release commit landed there since — merge
# it first); develop's CI runs are all green. Then pushes develop to main,
# waits for the release workflow, and fast-forwards develop to the release
# commit (and the local main). --dry-run runs the checks and stops.
#
# Environment: PROMOTE_GH (the gh binary, default gh), PROMOTE_POLL
# (seconds between polls, 20), PROMOTE_TIMEOUT (seconds to wait for CI and
# for the release, 1800).

set -Eeuo pipefail

GH="${PROMOTE_GH:-gh}"
POLL="${PROMOTE_POLL:-20}"
TIMEOUT="${PROMOTE_TIMEOUT:-1800}"

dry=0 wait=1
for a in "$@"; do
    case "${a}" in
        --dry-run) dry=1 ;;
        --no-wait) wait=0 ;;
        -h | --help)
            sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'promote: unknown option %s\n' "${a}" >&2
            exit 2
            ;;
    esac
done

die() {
    printf 'promote: %s\n' "$*" >&2
    exit 1
}

cd "$(git rev-parse --show-toplevel)"

[[ "$(git rev-parse --abbrev-ref HEAD)" == develop ]] || die 'not on develop'
[[ -z "$(git status --porcelain)" ]] || die 'the working tree is not clean'
git fetch -q origin || die 'cannot fetch origin'
sha="$(git rev-parse HEAD)"
[[ "${sha}" == "$(git rev-parse origin/develop)" ]] || die 'develop and origin/develop differ (push or pull first)'
git merge-base --is-ancestor origin/main develop ||
    die 'develop does not contain origin/main (a release landed there: merge origin/main into develop first)'
[[ "${sha}" != "$(git rev-parse origin/main)" ]] || die 'nothing to promote: develop is main'

# develop's runs for this exact commit: all completed, none failed. In
# progress or not yet registered waits (up to PROMOTE_TIMEOUT).
runs_state() {
    "${GH}" run list --branch develop --limit 40 --json headSha,name,status,conclusion \
        --jq ".[] | select(.headSha == \"${sha}\") | [.name, .status, .conclusion] | @tsv"
}
deadline=$((SECONDS + TIMEOUT))
while true; do
    state="$(runs_state)" || die 'cannot read the CI runs (gh)'
    if [[ -z "${state}" ]]; then
        # Just pushed: the runs register a few seconds late.
        ((SECONDS < deadline)) || die "no CI run for ${sha:0:7}"
        printf 'promote: waiting for CI runs to appear\n'
        sleep "${POLL}"
        continue
    fi
    if bad="$(awk -F'\t' '$2 == "completed" && $3 != "success" && $3 != "skipped" { print $1 " (" $3 ")" }' <<<"${state}")" && [[ -n "${bad}" ]]; then
        die "CI is not green on develop: ${bad//$'\n'/, }"
    fi
    pending="$(awk -F'\t' '$2 != "completed" { print $1 }' <<<"${state}")"
    [[ -n "${pending}" ]] || break
    ((SECONDS < deadline)) || die "CI still running after ${TIMEOUT}s: ${pending//$'\n'/, }"
    printf 'promote: waiting for CI: %s\n' "${pending//$'\n'/, }"
    sleep "${POLL}"
done

printf 'promote: develop %s is green; it carries:\n' "${sha:0:7}"
git log --oneline origin/main..develop | head -n 30
((dry == 0)) || {
    printf 'promote: --dry-run: stopping before the push\n'
    exit 0
}

git push -q origin develop:main
printf 'promote: pushed to main\n'
((wait == 1)) || exit 0

# The release workflow tags and commits "chore(release): X" on main (or
# finds nothing to release and leaves main at the pushed commit).
deadline=$((SECONDS + TIMEOUT))
while true; do
    state="$("${GH}" run list --branch main --workflow release --limit 10 --json headSha,status,conclusion \
        --jq ".[] | select(.headSha == \"${sha}\") | [.status, .conclusion] | @tsv")" || state=''
    if [[ "${state}" == completed$'\t'* ]]; then
        [[ "${state}" == $'completed\tsuccess' ]] || die "the release run ended ${state#*$'\t'}; main is at ${sha:0:7}"
        break
    fi
    ((SECONDS < deadline)) || die "the release is still running after ${TIMEOUT}s"
    printf 'promote: waiting for the release workflow\n'
    sleep "${POLL}"
done

git fetch -q --tags origin
if [[ "$(git rev-parse origin/main)" != "${sha}" ]]; then
    git merge -q --ff-only origin/main || die 'develop cannot fast-forward to origin/main'
    git push -q origin develop
fi
git branch -f main origin/main 2>/dev/null || true
printf 'promote: done — main and develop at %s' "$(git log --oneline -1 origin/main)"
tag="$(git tag --points-at origin/main | head -n 1)"
printf '%s\n' "${tag:+ (${tag})}"
