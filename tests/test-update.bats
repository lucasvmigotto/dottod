#!/usr/bin/env bats
#
# test-update.bats — hermetic tests for scripts/.update.sh (self-update
# check). Network is stubbed with a fake `curl`; time via crafted cache
# timestamps; git remotes via local bare repos. No network, no clock games.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    mkdir -p "$XDG_STATE_HOME"
    unset DOT_NO_UPDATE_CHECK DOT_UPDATE_DAYS DOT_UPDATE_REPO DOT_UPDATE_ROOT
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN"
    export PATH="$STUBBIN:$PATH"
}

# Fake curl: always reports release 9.9.9 (quoted heredoc keeps the JSON
# double quotes intact).
stub_curl() {
    cat >"$STUBBIN/curl" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s' '{"tag_name": "9.9.9"}'
STUBEOF
    chmod +x "$STUBBIN/curl"
}

make_repo() {
    local d=${1} tag=${2:-}
    mkdir -p "$d"
    git -C "$d" init -q
    git -C "$d" config user.email t@t
    git -C "$d" config user.name t
    git -C "$d" commit -q --allow-empty -m init
    if [[ -n "$tag" ]]; then
        git -C "$d" tag "$tag"
    fi
}

# Interactive shells print job-control noise without a tty; silence means
# "no update notice", never byte-empty output.
assert_no_notice() {
    local desc=${1} output=${2}
    if printf '%s' "$output" | grep -q 'update available'; then
        printf 'FAIL: %s\nunexpected notice in: %q\n' "$desc" "$output" >&2
        return 1
    fi
}

@test "version comparison orders triples, v prefix and short forms" {
    run bash -c "
        source '$REPO_ROOT/scripts/.update.sh'
        _dottod_ver_gt 1.3.0 1.2.0 && echo gt1
        _dottod_ver_gt 1.2.0 1.2.0 || echo eq1
        _dottod_ver_gt 1.2.0 1.3.0 || echo lt1
        _dottod_ver_gt v2.0.0 1.9.9 && echo gt2
        _dottod_ver_gt 1.10.0 1.9.9 && echo gt3
        _dottod_ver_gt 1.2 1.2.0 || echo eq2
        _dottod_ver_gt 1.2.1 1.2 && echo gt4
    "
    assert_eq 'compare rc 0' '0' "$status"
    local want
    for want in gt1 eq1 lt1 gt2 gt3 eq2 gt4; do
        assert_contains "comparison $want" "$want" "$output"
    done
}

@test "local tag resolves newest tag in the checkout" {
    local repo="$BATS_TEST_TMPDIR/repo"
    make_repo "$repo"
    git -C "$repo" tag 1.1.0
    git -C "$repo" tag 1.2.0
    run bash -c "
        source '$REPO_ROOT/scripts/.update.sh'
        _dottod_local_tag '$repo'
    "
    assert_eq 'tag rc 0' '0' "$status"
    assert_eq 'newest tag' '1.2.0' "$output"
}

@test "repo slug prefers override, then origin, then default" {
    local repo="$BATS_TEST_TMPDIR/repo2"
    make_repo "$repo"
    run bash -c "
        source '$REPO_ROOT/scripts/.update.sh'
        DOT_UPDATE_REPO=someone/else _dottod_repo_slug '$repo'
        echo
        git -C '$repo' remote add origin 'git@github.com:acme/widget.git'
        _dottod_repo_slug '$repo'
        echo
        git -C '$repo' remote set-url origin 'https://github.com/acme/gadget'
        _dottod_repo_slug '$repo'
    "
    assert_eq 'slug rc 0' '0' "$status"
    assert_contains 'override wins' 'someone/else' "$output"
    assert_contains 'ssh origin parsed' 'acme/widget' "$output"
    assert_contains 'https origin parsed' 'acme/gadget' "$output"
}

@test "fresh newer cache notifies, same version stays silent" {
    local repo="$BATS_TEST_TMPDIR/repo3"
    make_repo "$repo" 1.2.0
    local now state
    now="$(date +%s)"
    state="$XDG_STATE_HOME/dottod/update-check"
    mkdir -p "${state%/*}"
    printf '%s 1.3.0\n' "$now" >"$state"
    run bash -i -c "
        source '$REPO_ROOT/scripts/.update.sh' >/dev/null 2>&1
        DOT_UPDATE_ROOT='$repo' _dottod_update_check
    " 2>/dev/null
    assert_eq 'check rc 0' '0' "$status"
    assert_contains 'notice names versions' '1.2.0 → 1.3.0' "$output"
    assert_contains 'notice names command' 'dottod-update' "$output"
    printf '%s 1.2.0\n' "$now" >"$state"
    run bash -i -c "
        source '$REPO_ROOT/scripts/.update.sh' >/dev/null 2>&1
        DOT_UPDATE_ROOT='$repo' _dottod_update_check
    " 2>/dev/null
    assert_eq 'same-version rc 0' '0' "$status"
    assert_no_notice 'same version silent' "$output"
}

@test "opt-out disables the notice" {
    local repo="$BATS_TEST_TMPDIR/repo4"
    make_repo "$repo" 1.2.0
    local state="$XDG_STATE_HOME/dottod/update-check"
    mkdir -p "${state%/*}"
    printf '%s 1.3.0\n' "$(date +%s)" >"$state"
    run bash -i -c "
        source '$REPO_ROOT/scripts/.update.sh' >/dev/null 2>&1
        DOT_UPDATE_ROOT='$repo' DOT_NO_UPDATE_CHECK=1 _dottod_update_check
    " 2>/dev/null
    assert_eq 'opt-out rc 0' '0' "$status"
    assert_no_notice 'opt-out silent' "$output"
}

@test "refresh stores the remote tag from stubbed curl" {
    stub_curl
    run bash -c "
        source '$REPO_ROOT/scripts/.update.sh'
        DOT_UPDATE_ROOT='$REPO_ROOT' _dottod_update_refresh
        cat '$XDG_STATE_HOME/dottod/update-check'
    "
    assert_eq 'refresh rc 0' '0' "$status"
    assert_match 'state holds tag' '[0-9]+ 9\.9\.9' "$output"
}

@test "refresh is silent without curl" {
    run bash -c "
        curl() { return 127; }
        export -f curl
        source '$REPO_ROOT/scripts/.update.sh'
        DOT_UPDATE_ROOT='$REPO_ROOT' _dottod_update_refresh
        test ! -e '$XDG_STATE_HOME/dottod/update-check'
    "
    assert_eq 'no-curl rc 0' '0' "$status"
}

@test "dottod-update fast-forwards a git checkout" {
    local origin="$BATS_TEST_TMPDIR/origin.git" work="$BATS_TEST_TMPDIR/work" other="$BATS_TEST_TMPDIR/other"
    git init -q --bare "$origin"
    git clone -q "$origin" "$work" 2>/dev/null
    git -C "$work" config user.email t@t
    git -C "$work" config user.name t
    git -C "$work" commit -q --allow-empty -m one
    git -C "$work" tag 1.2.0
    git -C "$work" push -q -u origin HEAD 2>/dev/null
    git -C "$work" push -q origin 1.2.0
    git clone -q "$origin" "$other" 2>/dev/null
    git -C "$other" config user.email t@t
    git -C "$other" config user.name t
    git -C "$other" commit -q --allow-empty -m two
    git -C "$other" tag 1.3.0
    git -C "$other" push -q origin HEAD 1.3.0
    run bash -c "
        source '$REPO_ROOT/scripts/.update.sh'
        DOT_UPDATE_ROOT='$work' dottod-update
    "
    assert_eq 'update rc 0' '0' "$status"
    assert_contains 'update reports version' '1.3.0' "$output"
}

@test "dottod-update fails gracefully without a remote" {
    local repo="$BATS_TEST_TMPDIR/lonely"
    make_repo "$repo" 1.2.0
    run bash -c "
        source '$REPO_ROOT/scripts/.update.sh'
        DOT_UPDATE_ROOT='$repo' dottod-update
    "
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero without a remote\n%s\n' "$output" >&2
        return 1
    fi
    assert_contains 'graceful message' 'fast-forward failed' "$output"
}
