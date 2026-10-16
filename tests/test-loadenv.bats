#!/usr/bin/env bats
#
# test-loadenv.bats — hermetic tests for loadenv (scripts/.dev.utils.sh).
# The .env file is data: nothing in it may execute. `pass` is a stub.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN"
    cat >"$STUBBIN/pass" <<'STUB'
#!/usr/bin/env bash
case "$2" in
    github/pat) printf 'from-pass-value\nsecond line\n' ;;
    *) echo "Error: $2 is not in the password store." >&2; exit 1 ;;
esac
STUB
    chmod +x "$STUBBIN/pass"
    export PATH="$STUBBIN:$PATH"
    ENV_FILE="$BATS_TEST_TMPDIR/test.env"
}

# probe <snippet>: fresh bash with the utilities sourced.
probe() {
    run bash -c "source '$REPO_ROOT/scripts/.dev.utils.sh'; $1"
}

@test "plain, quoted and exported values load; comments and blanks skip" {
    printf '# comment\n\nA=plain\nB="double quoted"\nC='"'"'single'"'"'\nexport D=exported\n  E=indented\n' >"$ENV_FILE"
    probe "loadenv '$ENV_FILE' 2>/dev/null; printf '%s|' \"\$A\" \"\$B\" \"\$C\" \"\$D\" \"\$E\""
    assert_eq 'values' 'plain|double quoted|single|exported|indented|' "$output"
}

@test "nothing in the file is executed" {
    printf 'X=$(touch %s/pwned)\nY=`touch %s/pwned2`\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >"$ENV_FILE"
    probe "loadenv '$ENV_FILE' 2>/dev/null; printf '%s' \"\$X\""
    assert_eq 'value kept literally' "\$(touch $BATS_TEST_TMPDIR/pwned)" "$output"
    local -a pwned=("$BATS_TEST_TMPDIR"/pwned*)
    assert_eq 'no command ran' '0' "$([[ -e "${pwned[0]}" ]] && echo 1 || echo 0)"
}

@test "pass: values come from pass, first line; names reported, not values" {
    printf 'GH_TOKEN=pass:github/pat\nPLAIN=x\n' >"$ENV_FILE"
    probe "loadenv '$ENV_FILE'; printf 'VALUE=%s' \"\$GH_TOKEN\""
    assert_contains 'resolved' 'VALUE=from-pass-value' "$output"
    assert_contains 'names reported' 'loadenv: 2 from' "$output"
    assert_contains 'pass names marked' '(from pass: GH_TOKEN)' "$output"
    assert_eq 'value not in the report' '1' "$(grep -c 'from-pass-value' <<<"$output")"
}

@test "a failing pass lookup loads nothing" {
    printf 'FIRST=ok\nGH_TOKEN=pass:missing/entry\n' >"$ENV_FILE"
    probe "loadenv '$ENV_FILE'; echo \"rc=\$? FIRST=[\${FIRST:-}]\""
    assert_contains 'explains' "cannot read 'missing/entry'" "$output"
    assert_contains 'nothing exported' 'rc=1 FIRST=[]' "$output"
}

@test "a malformed line loads nothing" {
    printf 'GOOD=1\nthis is not an assignment\n' >"$ENV_FILE"
    probe "loadenv '$ENV_FILE'; echo \"rc=\$? GOOD=[\${GOOD:-}]\""
    assert_contains 'names the line' 'test.env:2: not KEY=value' "$output"
    assert_contains 'nothing exported' 'rc=1 GOOD=[]' "$output"
}

@test "a missing file fails" {
    probe "loadenv '$BATS_TEST_TMPDIR/nope.env'"
    assert_eq 'rc 1' '1' "$status"
}
