#!/usr/bin/env bats
#
# test-pass-run.bats — hermetic tests for scripts/pass-run.sh (spec 017).
# `pass` is a stub serving fixture entries; nothing touches a real store.

load helpers

readonly SECRET='s3cr3t-never-printed'

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    PASS_RUN="$REPO_ROOT/scripts/pass-run.sh"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN"
    # pass stub: `pass show <path>` prints a fixture; unknown paths fail.
    cat >"$STUBBIN/pass" <<STUB
#!/usr/bin/env bash
[[ "\$1" == show ]] || exit 64
case "\$2" in
    github/pat) printf '%s\nlogin: someone\n' '$SECRET' ;;
    other/token) printf 'second-secret\n' ;;
    empty/entry) printf '\n' ;;
    *) echo "Error: \$2 is not in the password store." >&2; exit 1 ;;
esac
STUB
    chmod +x "$STUBBIN/pass"
    export PATH="$STUBBIN:$PATH"
}

@test "the command gets the first line of each secret" {
    run "$PASS_RUN" GH_TOKEN=github/pat OTHER=other/token -- bash -c '[[ "$GH_TOKEN" == '"$SECRET"' && "$OTHER" == second-secret ]] && echo ok'
    assert_eq 'rc' '0' "$status"
    assert_eq 'both set, first line only' 'ok' "$output"
}

@test "pass-run itself never prints the secret" {
    run "$PASS_RUN" GH_TOKEN=github/pat -- true
    assert_eq 'rc' '0' "$status"
    assert_eq 'no output at all' '' "$output"
}

@test "the caller's shell never gets the variable" {
    run bash -c "'$PASS_RUN' GH_TOKEN=github/pat -- true; printf '[%s]' \"\${GH_TOKEN:-}\""
    assert_eq 'unset afterwards' '[]' "$output"
}

@test "a missing entry fails, names the path, runs nothing" {
    run "$PASS_RUN" GH_TOKEN=nope/missing -- touch "$BATS_TEST_TMPDIR/ran"
    assert_eq 'rc 1' '1' "$status"
    assert_contains 'names the path' "cannot read 'nope/missing'" "$output"
    assert_eq 'command not run' '0' "$([[ -e "$BATS_TEST_TMPDIR/ran" ]] && echo 1 || echo 0)"
}

@test "an empty entry fails" {
    run "$PASS_RUN" X=empty/entry -- true
    assert_eq 'rc 1' '1' "$status"
    assert_contains 'says empty' "'empty/entry' is empty" "$output"
}

@test "bad names, escaping paths and options are refused" {
    local bad
    for bad in '1X=github/pat' 'X-Y=github/pat' 'X=../github/pat' 'X=/etc/passwd' 'X=-c' 'X=a/../../b' 'X='; do
        run "$PASS_RUN" "$bad" -- true
        assert_eq "refused: $bad" '2' "$status"
    done
}

@test "usage errors: no assignment, no --, no command" {
    run "$PASS_RUN" -- true
    assert_eq 'no assignment' '2' "$status"
    run "$PASS_RUN" GH_TOKEN=github/pat true
    assert_eq 'no --' '2' "$status"
    run "$PASS_RUN" GH_TOKEN=github/pat --
    assert_eq 'no command' '2' "$status"
    run "$PASS_RUN" --help
    assert_eq 'help rc 0' '0' "$status"
}
