#!/usr/bin/env bats
#
# test-gwork.bats — hermetic tests for scripts/.gwork.sh (spec 016).
#
# Every URL form of the spec's acceptance table is cloned for real, with
# no network: the fake HOME's gitconfig maps each URL to a local bare repo
# through url.<base>.insteadOf, so git (and gwork) see the URL as typed.

load helpers

# The spec 016 acceptance table: SSH and HTTPS forms per host.
URLS=(
    'git@ssh.dev.azure.com:v3/org/proj/repo'
    'https://dev.azure.com/org/proj/_git/repo'
    'git@bitbucket.org:team/repo.git'
    'https://bitbucket.org/team/repo.git'
    'git@gitlab.com:group/sub/repo.git'
    'https://gitlab.com/group/sub/repo.git'
    'git@github.com:org/repo.git'
    'https://github.com/org/repo'
    'ssh://git@host:2222/path/repo.git'
    'https://host/path/repo.git/'
)

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    unset GIT_WORK_NAME GIT_WORK_EMAIL
    git config --global user.name 'Personal'
    git config --global user.email 'personal@example.com'
    printf '[user]\n    name = Work\n    email = work@example.com\n' >"$HOME/.gitconfig-work"

    SRC="$BATS_TEST_TMPDIR/src.git"
    git init -q --bare "$SRC"
    local seed="$BATS_TEST_TMPDIR/seed"
    git init -q "$seed"
    git -C "$seed" commit -q --allow-empty -m init
    git -C "$seed" push -q "$SRC" HEAD:refs/heads/main 2>/dev/null
    git -C "$SRC" symbolic-ref HEAD refs/heads/main
    local u
    for u in "${URLS[@]}"; do
        git config --global --add "url.$SRC.insteadOf" "$u"
    done

    WORK="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK"
    cd "$WORK" || return 1
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/.gwork.sh"
}

@test "default directory is git's humanish name for every URL form" {
    local u
    for u in "${URLS[@]}"; do
        assert_eq "dir for $u" 'repo' "$(__gwork_humanish "$u")"
    done
}

@test "clone gets the work identity locally for every URL form, then cds in" {
    local u where
    for u in "${URLS[@]}"; do
        where="$(gwork clone "$u" >/dev/null 2>&1 && pwd)" || {
            printf 'FAIL: clone of %s\n' "$u" >&2
            return 1
        }
        assert_eq "cd into clone of $u" "$WORK/repo" "$where"
        assert_eq "local work email for $u" 'work@example.com' "$(git -C "$WORK/repo" config --local user.email)"
        assert_eq "local work name for $u" 'Work' "$(git -C "$WORK/repo" config --local user.name)"
        rm -rf "$WORK/repo"
    done
}

@test "clone passes options and an explicit directory to git" {
    run gwork clone -o upstream 'git@bitbucket.org:team/repo.git' mine --no-tags
    assert_eq 'clone rc 0' '0' "$status"
    assert_eq 'explicit dir' 'work@example.com' "$(git -C "$WORK/mine" config --local user.email)"
    assert_eq 'option reached git' 'upstream' "$(git -C "$WORK/mine" remote)"
}

@test "a failed clone configures nothing and keeps git's error" {
    run gwork clone "$BATS_TEST_TMPDIR/missing.git"
    assert_eq 'clone fails' '1' "$((status != 0))"
    assert_contains 'git error visible' 'fatal:' "$output"
    assert_eq 'no directory' '0' "$([[ -e "$WORK/missing" ]] && echo 1 || echo 0)"
}

@test "clone without a work identity stops before cloning" {
    rm "$HOME/.gitconfig-work"
    run gwork clone 'git@github.com:org/repo.git'
    assert_eq 'rc 1' '1' "$status"
    assert_contains 'hint' 'GIT_WORK_NAME and GIT_WORK_EMAIL' "$output"
    assert_eq 'nothing cloned' '0' "$([[ -e "$WORK/repo" ]] && echo 1 || echo 0)"
}

@test "GIT_WORK_* take precedence over ~/.gitconfig-work" {
    export GIT_WORK_NAME='Env Work' GIT_WORK_EMAIL='env@example.com'
    gwork clone 'git@github.com:org/repo.git' >/dev/null 2>&1
    assert_eq 'env email' 'env@example.com' "$(git -C "$WORK/repo" config --local user.email)"
}

@test "set marks a checkout as work and unset returns it to personal" {
    git init -q "$WORK/p"
    run gwork status "$WORK/p"
    assert_contains 'personal by default' 'personal — Personal <personal@example.com> (global config)' "$output"
    run gwork set "$WORK/p"
    assert_eq 'set rc 0' '0' "$status"
    assert_contains 'now work' 'work — Work <work@example.com> (local config)' "$output"
    assert_eq 'local email' 'work@example.com' "$(git -C "$WORK/p" config --local user.email)"
    run gwork unset "$WORK/p"
    assert_eq 'unset rc 0' '0' "$status"
    assert_contains 'back to personal' 'personal — Personal <personal@example.com> (global config)' "$output"
    run gwork unset "$WORK/p"
    assert_eq 'unset twice is fine' '0' "$status"
}

@test "status reports a repo with no identity at all" {
    git config --global --unset user.email
    git init -q "$WORK/p"
    run gwork status "$WORK/p"
    assert_contains 'no identity' 'no identity' "$output"
}

@test "status and set outside a repository fail with git's error" {
    run gwork set "$BATS_TEST_TMPDIR"
    assert_eq 'set fails' '1' "$((status != 0))"
    assert_contains 'git error' 'not a git repository' "$output"
}

@test "unknown subcommands fail" {
    run gwork frobnicate
    assert_eq 'rc 2' '2' "$status"
}
