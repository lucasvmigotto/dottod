#!/usr/bin/env bats
#
# test-prompt-perf.bats — a prompt render runs git at most once (spec 022):
# the machine-independent half of the speed budget; tests/bench/prompt.sh
# holds the timings.

load helpers

STYLES=(robbyrussell kali powerline pastel tokyonight gruvbox catppuccin)

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$HOME"
    export REAL_GIT
    REAL_GIT="$(command -v git)"
    export GIT_CALLS="$BATS_TEST_TMPDIR/git-calls"
    mkdir -p "$BATS_TEST_TMPDIR/stubs"
    printf '#!/usr/bin/env bash\necho "$*" >>"$GIT_CALLS"\nexec "$REAL_GIT" "$@"\n' >"$BATS_TEST_TMPDIR/stubs/git"
    chmod +x "$BATS_TEST_TMPDIR/stubs/git"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/src"
    "$REAL_GIT" -C "$PROJ" init -q -b main
    "$REAL_GIT" -C "$PROJ" config user.email t@t
    "$REAL_GIT" -C "$PROJ" config user.name t
    "$REAL_GIT" -C "$PROJ" commit -q --allow-empty -m init
    : >"$PROJ/package.json"
    : >"$PROJ/untracked"
}

# Renders <style> in <dir> with the counting git first on PATH; prints PS1.
render() {
    local style="$1" dir="$2"
    : >"$GIT_CALLS"
    (cd "$dir" && PATH="$BATS_TEST_TMPDIR/stubs:$PATH" DOT_PROMPT_STYLE="$style" DOT_PROMPT_CONTAINERS=0 DOT_NO_UPDATE_CHECK=1 \
        bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; : >\"\$GIT_CALLS\"; \${PROMPT_COMMAND%%;*}; printf '%s' \"\$PS1\"" 2>/dev/null)
}

calls() { grep -c . "$GIT_CALLS" || true; }

@test "every style runs git at most once per render, in a repo" {
    local s out
    for s in "${STYLES[@]}"; do
        out="$(render "$s" "$PROJ/src")"
        [ "$(calls)" -le 1 ] || {
            echo "$s: $(calls) git calls" >&2
            cat "$GIT_CALLS" >&2
            return 1
        }
        assert_contains "$s shows the branch" main "$out"
    done
}

@test "outside a repo no style runs git" {
    local s
    mkdir -p "$BATS_TEST_TMPDIR/plain"
    for s in "${STYLES[@]}"; do
        render "$s" "$BATS_TEST_TMPDIR/plain" >/dev/null
        assert_eq "$s: no git outside a repo" 0 "$(calls)"
    done
}

@test "dottod.hide-dirty skips git entirely and still shows the branch" {
    "$REAL_GIT" -C "$PROJ" config --local dottod.hide-dirty 1
    local out
    out="$(render robbyrussell "$PROJ")"
    assert_eq 'no git call' 0 "$(calls)"
    assert_contains 'branch shown' main "$out"
    [[ "$out" != *'✗'* ]]
}

@test "a worktree's .git file is followed" {
    "$REAL_GIT" -C "$PROJ" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
    local out
    out="$(render robbyrussell "$BATS_TEST_TMPDIR/wt")"
    assert_contains 'worktree branch' wt "$out"
}
