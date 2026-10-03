#!/usr/bin/env bats
#
# test-bootstrap.bats — hermetic tests for bin/bootstrap.sh interface.
#
# Covers: the task list (order, no removed tasks), the --ui/--no-ui flag
# pair (and the removal of --no-ui-support), and default UI skipping via
# stub task scripts. Real task scripts never run here.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "bootstrap lists the twelve tasks in order" {
    run "$REPO_ROOT/bin/bootstrap.sh" --list
    assert_eq 'list rc 0' '0' "$status"
    assert_eq 'task order' \
        "$(printf 'shell\nfonts\nvim\nneovim\ncontainer\nzed\nghostty\ngitconfig\nssh\ntools\ncargo\nbun')" \
        "$output"
}

@test "bootstrap help documents the ui flag pair" {
    run "$REPO_ROOT/bin/bootstrap.sh" --help
    assert_eq 'help rc 0' '0' "$status"
    assert_contains 'ui flag' '--ui' "$output"
    assert_contains 'no-ui flag' '--no-ui' "$output"
    assert_contains 'zed row' 'zed' "$output"
}

@test "bootstrap rejects the retired no-ui-support flag" {
    run "$REPO_ROOT/bin/bootstrap.sh" --no-ui-support --list
    assert_eq 'retired flag rc 1' '1' "$status"
    assert_contains 'unknown option' 'Unknown option' "$output"
}

@test "bootstrap default run skips UI tasks" {
    # Passwordless sudo stub: _sudo_preflight must succeed headlessly.
    mkdir -p "$BATS_TEST_TMPDIR/stubbin"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/stubbin/sudo"
    chmod +x "$BATS_TEST_TMPDIR/stubbin/sudo"
    export PATH="$BATS_TEST_TMPDIR/stubbin:$PATH"
    local fakeroot="$BATS_TEST_TMPDIR/fakeroot"
    mkdir -p "$fakeroot/bin"
    cp "$REPO_ROOT/bin/bootstrap.sh" "$REPO_ROOT/bin/utils.sh" "$fakeroot/bin/"
    for t in shell zed ghostty; do
        { printf '#!/usr/bin/env bash\n'; printf 'echo "RAN:$(basename "$0")" >>"%s/calls.log"\n' "$BATS_TEST_TMPDIR"; } >"$fakeroot/bin/$t.sh"
        chmod +x "$fakeroot/bin/$t.sh"
    done
    run env _DOT_NO_PACKAGES=1 "$fakeroot/bin/bootstrap.sh" --only zed,shell --verbose
    assert_eq 'run rc 0' '0' "$status"
    assert_contains 'ui skipped' 'Skipping UI task (pass --ui to include): zed' "$output"
    assert_contains 'shell ran' 'shell: PASS' "$output"
    assert_eq 'zed script never executed' '0' "$(grep -c 'RAN:zed' "$BATS_TEST_TMPDIR/calls.log" 2>/dev/null || true)"
}

@test "bootstrap --ui includes UI tasks" {
    mkdir -p "$BATS_TEST_TMPDIR/stubbin"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/stubbin/sudo"
    chmod +x "$BATS_TEST_TMPDIR/stubbin/sudo"
    export PATH="$BATS_TEST_TMPDIR/stubbin:$PATH"
    local fakeroot="$BATS_TEST_TMPDIR/fakeroot"
    mkdir -p "$fakeroot/bin"
    cp "$REPO_ROOT/bin/bootstrap.sh" "$REPO_ROOT/bin/utils.sh" "$fakeroot/bin/"
    for t in shell zed ghostty; do
        { printf '#!/usr/bin/env bash\n'; printf 'echo "RAN:$(basename "$0")" >>"%s/calls.log"\n' "$BATS_TEST_TMPDIR"; } >"$fakeroot/bin/$t.sh"
        chmod +x "$fakeroot/bin/$t.sh"
    done
    run env _DOT_NO_PACKAGES=1 "$fakeroot/bin/bootstrap.sh" --ui --only zed,ghostty --verbose
    assert_eq 'run rc 0' '0' "$status"
    assert_eq 'zed executed' '1' "$(grep -c 'RAN:zed' "$BATS_TEST_TMPDIR/calls.log" || true)"
    assert_eq 'ghostty executed' '1' "$(grep -c 'RAN:ghostty' "$BATS_TEST_TMPDIR/calls.log" || true)"
}
