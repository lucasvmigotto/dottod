#!/usr/bin/env bats
#
# test-xclip.bats — hermetic tests for scripts/.xclip.utils.sh: clipboard
# helpers call xclip with the clipboard selection. xclip is stubbed.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export XCALLS="$BATS_TEST_TMPDIR/xcalls.log"
    mkdir -p "$STUBBIN"
    : >"$XCALLS"
    cat >"$STUBBIN/xclip" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${XCALLS:?}"
EOF
    chmod +x "$STUBBIN/xclip"
    export PATH="$STUBBIN:$PATH"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/.xclip.utils.sh"
}

@test "eclip copies arguments to the clipboard" {
    run eclip hello world
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'clipboard selection' '-sel clipboard' "$(cat "$XCALLS")"
}

@test "fclip copies a file to the clipboard" {
    printf 'file-bytes\n' >"$BATS_TEST_TMPDIR/f.txt"
    run fclip "$BATS_TEST_TMPDIR/f.txt"
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'clipboard selection' '-sel clipboard' "$(cat "$XCALLS")"
}

@test "fclip rejects a missing file" {
    run fclip "$BATS_TEST_TMPDIR/nope.txt"
    if [[ "$status" == "0" ]]; then
        printf 'FAIL: expected nonzero for missing file\n' >&2
        return 1
    fi
    assert_contains 'error message' 'does not exist' "$output"
}

@test "clip, pclip and cclip aliases are defined" {
    run alias clip pclip cclip
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'clip alias' "clip='xclip -sel clipboard'" "$output"
    assert_contains 'pclip alias' "pclip='xclip -sel clipboard -o'" "$output"
    assert_contains 'cclip alias' "cclip='xclip -sel clipboard < /dev/null'" "$output"
}
