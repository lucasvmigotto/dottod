#!/usr/bin/env bats
#
# test-promote.bats — scripts/promote.sh (spec 022, story 9) against a
# throwaway origin and a stub gh: each refusal, and the full promotion with
# a simulated release commit.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
    git config --global user.email t@t
    git config --global user.name t
    git config --global init.defaultBranch main
    git config --global protocol.file.allow always

    O="$BATS_TEST_TMPDIR/origin.git"
    git init -q --bare "$O"
    W="$BATS_TEST_TMPDIR/w"
    git clone -q "$O" "$W" 2>/dev/null
    cd "$W" || return 1
    git commit -q --allow-empty -m "chore: start"
    git push -q origin main
    git checkout -q -b develop
    git commit -q --allow-empty -m "feat: something"
    git push -q origin develop

    # gh stub: develop runs from $GH_DEVELOP (rows "name<TAB>status<TAB>conclusion",
    # {SHA} expanded); the release run from $GH_RELEASE, which also lands the
    # bot's release commit on origin/main the first time it is asked.
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/gh" <<'EOS'
#!/usr/bin/env bash
case "$*" in
    *"--branch develop"*) printf '%b' "${GH_DEVELOP:-}" ;;
    *"--branch main"*)
        if [[ -n "${GH_RELEASE:-}" ]]; then
            if [[ "${GH_BOT:-1}" == 1 && ! -e "$BATS_TEST_TMPDIR/bot-done" ]]; then
                (
                    d="$(mktemp -d)"
                    git clone -q "$ORIGIN" "$d" 2>/dev/null
                    cd "$d"
                    git commit -q --allow-empty -m "chore(release): 1.0.0"
                    git tag 1.0.0
                    git push -q origin main --tags
                )
                : >"$BATS_TEST_TMPDIR/bot-done"
            fi
            printf '%b' "${GH_RELEASE}"
        fi
        ;;
esac
EOS
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    export GH_DEVELOP GH_RELEASE GH_BOT ORIGIN="$O" PROMOTE_GH="$BATS_TEST_TMPDIR/bin/gh" PROMOTE_POLL=0 PROMOTE_TIMEOUT=1
}

# The stub ignores the sha filter (gh does it), so rows are just rows.
promote() { run "$REPO_ROOT/scripts/promote.sh" "$@"; }

@test "refuses off develop, with a dirty tree, or unpushed" {
    git checkout -q main
    promote --dry-run
    assert_eq 'rc' '1' "$status"
    assert_contains 'branch' 'not on develop' "$output"
    git checkout -q develop
    : >dirty
    promote --dry-run
    assert_contains 'dirty' 'working tree is not clean' "$output"
    rm dirty
    git commit -q --allow-empty -m "feat: unpushed"
    promote --dry-run
    assert_contains 'unpushed' 'differ' "$output"
}

@test "refuses when develop does not contain origin/main" {
    local d
    d="$(mktemp -d)"
    git clone -q "$O" "$d" 2>/dev/null
    (cd "$d" && git commit -q --allow-empty -m "chore(release): 0.9.0" && git push -q origin main)
    GH_DEVELOP="shell\tcompleted\tsuccess\n"
    promote --dry-run
    assert_eq 'rc' '1' "$status"
    assert_contains 'says merge' 'does not contain origin/main' "$output"
}

@test "refuses when there is nothing to promote" {
    git checkout -q main
    git merge -q --ff-only develop
    git push -q origin main
    git checkout -q develop
    GH_DEVELOP="shell\tcompleted\tsuccess\n"
    promote --dry-run
    assert_contains 'nothing' 'nothing to promote' "$output"
}

@test "refuses on a failed run, no run, or a run that never finishes" {
    GH_DEVELOP="shell\tcompleted\tsuccess\ncontainer\tcompleted\tfailure\n"
    promote --dry-run
    assert_eq 'rc' '1' "$status"
    assert_contains 'failed' 'CI is not green on develop: container (failure)' "$output"
    GH_DEVELOP=""
    promote --dry-run
    assert_contains 'none' 'no CI run for' "$output"
    GH_DEVELOP="shell\tcompleted\tsuccess\nneovim\tin_progress\t\n"
    promote --dry-run
    assert_contains 'pending' 'CI still running' "$output"
}

@test "--dry-run on green stops before the push" {
    GH_DEVELOP="shell\tcompleted\tsuccess\ncontainer\tcompleted\tskipped\n"
    promote --dry-run
    assert_eq 'rc' '0' "$status"
    assert_contains 'carries' 'feat: something' "$output"
    assert_contains 'stops' 'stopping before the push' "$output"
    assert_eq 'main untouched' "$(git rev-parse origin/main)" "$(git --git-dir="$O" rev-parse main)"
}

@test "promotes, waits for the release and fast-forwards develop" {
    GH_DEVELOP="shell\tcompleted\tsuccess\n"
    GH_RELEASE="completed\tsuccess\n"
    promote
    assert_eq 'rc' '0' "$status"
    assert_contains 'pushed' 'pushed to main' "$output"
    assert_contains 'done' 'chore(release): 1.0.0' "$output"
    assert_contains 'tag' '(1.0.0)' "$output"
    assert_eq 'develop at main' "$(git --git-dir="$O" rev-parse main)" "$(git --git-dir="$O" rev-parse develop)"
    assert_eq 'local develop' "$(git rev-parse origin/main)" "$(git rev-parse develop)"
}

@test "a failed release run is reported, not hidden" {
    GH_DEVELOP="shell\tcompleted\tsuccess\n"
    GH_RELEASE="completed\tfailure\n"
    GH_BOT=0
    promote
    assert_eq 'rc' '1' "$status"
    assert_contains 'reports' 'the release run ended failure' "$output"
}
