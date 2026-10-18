#!/usr/bin/env bats
#
# test-gate.bats — the gate's file lists cover every shell file in git.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "dottod_test_env: poisoned outer values never reach a test" {
    run env CLAUDE_PROFILE=x CODES_ROOTS=/nope DOT_PROMPT_STYLE=kali XDG_STATE_HOME=/nope \
        PROMPT_COMMAND=boom PS0=boom bash -c "source '$REPO_ROOT/tests/helpers.bash'; printf '%s|' \"\${CLAUDE_PROFILE-}\" \"\${CODES_ROOTS-}\" \"\${DOT_PROMPT_STYLE-}\" \"\${XDG_STATE_HOME-}\" \"\${PROMPT_COMMAND-}\" \"\${PS0-}\""
    assert_eq 'all cleared' '||||||' "$output"
}

@test "every tracked shell file is in the syntax, lint and fmt lists" {
    local f kind list
    for kind in syntax lint fmt; do
        list="$("$REPO_ROOT/tests/files.sh" "$kind")"
        while IFS= read -r f; do
            case "$f" in
                bin/*.sh | lib/*.sh | scripts/*.sh | scripts/.*.sh | styles/*.sh | tests/*.sh | config/.custom.bashrc)
                    assert_contains "$kind lists $f" "$f" "$list"
                    ;;
            esac
        done < <(git -C "$REPO_ROOT" ls-files)
    done
}

@test "run.sh falls back to bunx when bats is not on PATH" {
    grep -q 'bunx bats@' "$REPO_ROOT/tests/run.sh"
}
