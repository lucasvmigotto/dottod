#!/usr/bin/env bats
#
# test-shell.bats — hermetic tests for the plain-bash shell task.
#
# Covers: the task installs no zsh/oh-my-zsh/spaceship remnants, links
# config/.custom.bashrc to ~/.bashrc, and keeps bash as the login shell.
# Probes run in a fresh bash per test via `probe` (same isolation pattern
# as tests/test-toolchain.bats).

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALLS"
    export _DOT_NO_PACKAGES=1
    unset _DOT_TARGET_USER
}

# Run a snippet in a fresh bash with the shell task sourced (its
# BASH_SOURCE guard keeps _main from running on source).
probe() {
    local snippet=${1}
    run bash -c "
        set -Eeuo pipefail
        source '${REPO_ROOT}/bin/shell.sh'
        _install_packages() { return 0; }
        ${snippet}
    "
}

@test "shell task has no zsh/oh-my-zsh/spaceship remnants" {
    # Functional identifiers only — the header comment names the removed
    # stack explicitly, so it is excluded from the search.
    local leftovers
    leftovers="$(grep -v '^#.*\bno zsh\b' "$REPO_ROOT/bin/shell.sh" | grep -niE "zsh|oh-my-zsh|ohmyzsh|spaceship|SPACESHIP" || true)"
    assert_eq 'no remnants in shell.sh' '' "$leftovers"
    leftovers="$(grep -rniE "oh-my-zsh|ohmyzsh|spaceship|SPACESHIP|ZSH_VERSION" "$REPO_ROOT/config/.custom.bashrc" || true)"
    assert_eq 'no remnants in .custom.bashrc' '' "$leftovers"
}

@test "custom.bashrc is valid bash with an exit-aware prompt" {
    run bash -n "$REPO_ROOT/config/.custom.bashrc"
    assert_eq 'bash syntax clean' '0' "$status"
    run grep -q "PROMPT_COMMAND" "$REPO_ROOT/config/.custom.bashrc"
    assert_eq 'prompt hook present' '0' "$status"
}

@test "custom.bashrc sets PS1 on an interactive shell without errors" {
    local ihome="$BATS_TEST_TMPDIR/ihome"
    mkdir -p "$ihome"
    run env HOME="$ihome" bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; __dottod_prompt; printf '%s' \"\$PS1\"" 2>/dev/null
    assert_eq 'interactive source rc 0' '0' "$status"
    assert_contains 'PS1 has the arrow prompt' '➜' "$output"
}

@test "custom.bashrc exposes the ctr dispatcher" {
    local ihome="$BATS_TEST_TMPDIR/ihome2"
    mkdir -p "$ihome"
    run env HOME="$ihome" bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; command -v ctr" 2>/dev/null
    assert_eq 'ctr defined rc 0' '0' "$status"
    assert_contains 'ctr resolves to a function' 'ctr' "$output"
}

@test "custom.bashrc restores tool paths without duplicates" {
    local ihome="$BATS_TEST_TMPDIR/ihome3"
    mkdir -p "$ihome/.local/bin" "$ihome/.opencode/bin" "$ihome/.bun/bin" "$ihome/.cargo/bin"
    run env HOME="$ihome" bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; printf '%s' \"\$PATH\"" 2>/dev/null
    assert_eq 'path setup rc 0' '0' "$status"
    local want="$ihome/.local/bin:$ihome/.opencode/bin:$ihome/.bun/bin:$ihome/.cargo/bin"
    assert_contains 'tool dirs first, in order' "$want" "$output"
    assert_eq 'no duplicates on re-source' '1' "$(printf '%s' "$output" | tr ':' '\n' | grep -cx "$ihome/.opencode/bin" || true)"
}

@test "custom.bashrc loads the utility libraries" {
    local ihome="$BATS_TEST_TMPDIR/ihome4"
    mkdir -p "$ihome"
    run env HOME="$ihome" bash -i -c "source '$REPO_ROOT/config/.custom.bashrc' >/dev/null 2>&1; alias lll; command -v mkcd; command -v ocresume; command -v ctr; printf 'EDITOR=%s' \"\$EDITOR\"" 2>/dev/null
    assert_eq 'utilities rc 0' '0' "$status"
    assert_contains 'lll alias' "alias lll=" "$output"
    assert_contains 'mkcd function' 'mkcd' "$output"
    assert_contains 'ocresume function' 'ocresume' "$output"
    assert_contains 'ctr function' 'ctr' "$output"
    assert_contains 'editor default' 'EDITOR=vim' "$output"
}

@test "custom.bashrc never executes scripts programs" {
    local ihome="$BATS_TEST_TMPDIR/ihome5"
    mkdir -p "$ihome"
    run env HOME="$ihome" bash -i -c "source '$REPO_ROOT/config/.custom.bashrc'; echo SURVIVED" 2>&1
    assert_eq 'source rc 0' '0' "$status"
    assert_contains 'shell survives sourcing' 'SURVIVED' "$output"
    assert_eq 'no battery output' '0' "$(printf '%s' "$output" | grep -c 'headless checks' || true)"
}

@test "bash stays the login shell when already set" {
    probe '
        getent() { printf "testuser:x:1000:1000::/home/testuser:/usr/bin/bash\n"; }
        command() { [[ "$1" == "-v" && "$2" == "bash" ]] && printf "/usr/bin/bash\n" || return 1; }
        _bash_use_as_shell testuser >/dev/null
    '
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message' 'already installed and in use' "$output"
}

@test "custom bashrc links to the repo file with a backup" {
    # _custom_bashrc targets /home/<user> by design (it manages the real
    # login account), so record the link arguments instead of touching the
    # real home: _link_file itself is covered by the neovim suites.
    probe '
        _link_file() { printf "%s\t%s\n" "$1" "$2" >>"$CALLS"; }
        _custom_bashrc someuser >/dev/null
        cat "$CALLS"
    '
    assert_eq 'link rc 0' '0' "$status"
    assert_contains 'source is the repo bashrc' "$REPO_ROOT/config/.custom.bashrc" "$output"
    assert_contains 'target is the user bashrc' '/home/someuser/.bashrc' "$output"
}

@test "link primitive backs up once, rerun is a no-op" {
    printf 'old rc\n' >"$FAKE_HOME/.bashrc"
    probe '
        _link_file "$REPO_ROOT/config/.custom.bashrc" "$FAKE_HOME/.bashrc" >/dev/null
        _link_file "$REPO_ROOT/config/.custom.bashrc" "$FAKE_HOME/.bashrc" >/dev/null
    '
    assert_eq 'rerun rc 0' '0' "$status"
    assert_contains 'already linked' 'Already linked' "$output"
    assert_eq 'target is a symlink' '1' "$([[ -L "$FAKE_HOME/.bashrc" ]] && echo 1 || echo 0)"
    assert_eq 'old file backed up' '1' "$([[ -f "$FAKE_HOME/.bashrc.dottod.bak" ]] && echo 1 || echo 0)"
}
