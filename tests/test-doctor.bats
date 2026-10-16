#!/usr/bin/env bats
#
# test-doctor.bats — hermetic tests for scripts/.doctor.sh. Fixtures for
# the repo, codes roots, update state and Claude overlays; no network.

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
    unset DOT_PROMPT_STYLE DOT_DOCTOR_TOOLS CLAUDE_PROFILE CLAUDE_NO_PICKER
    unset CODES_ROOTS CODES_GROUP CODES_SUBMODULES
    export FIXREPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FIXREPO"
    git -C "$FIXREPO" init -q
    git -C "$FIXREPO" config user.email t@t
    git -C "$FIXREPO" config user.name t
    git -C "$FIXREPO" commit -q --allow-empty -m init
    git -C "$FIXREPO" tag 1.2.0
}

doctor_run() {
    bash -i -c "
        source '$REPO_ROOT/scripts/.doctor.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.codes.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.update.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.claude.sh' >/dev/null 2>&1
        PROMPT_COMMAND='__dottod_prompt'
        dottod-doctor
    " 2>/dev/null
}

seed_profiles() {
    mkdir -p "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude-work" "$FAKE_HOME/.claude-personal"
    printf 'x' >"$FAKE_HOME/.claude-work/.credentials.json"
    printf 'x' >"$FAKE_HOME/.claude-personal/.credentials.json"
    printf 'work\n' >"$FAKE_HOME/.claude-work/.dottod-profile"
    printf 'personal\n' >"$FAKE_HOME/.claude-personal/.dottod-profile"
    ln -s "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude-work/projects"
    ln -s "$FAKE_HOME/.claude/projects" "$FAKE_HOME/.claude-personal/projects"
}

seed_update_state() {
    local tag=${1}
    mkdir -p "$XDG_STATE_HOME/dottod"
    printf '%s %s\n' "$(date +%s)" "$tag" >"$XDG_STATE_HOME/dottod/update-check"
}

@test "healthy tree reports ok and exits zero" {
    export CODES_ROOTS="$FIXREPO" DOT_UPDATE_ROOT="$FIXREPO"
    mkdir -p "$FIXREPO/proj"
    git -C "$FIXREPO/proj" init -q
    seed_profiles
    seed_update_state 1.2.0
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'bash ok' '[ok] bash' "$output"
    assert_contains 'prompt ok' 'prompt robbyrussell installed' "$output"
    assert_contains 'projects counted' 'projects found' "$output"
    assert_contains 'claude work ok' 'claude work logged in' "$output"
    assert_contains 'summary line' 'doctor:' "$output"
}

@test "tool override surfaces a missing tool as a warning" {
    export DOT_DOCTOR_TOOLS="git definitely-not-a-tool-xyz"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'git ok' '[ok] git on PATH' "$output"
    assert_contains 'missing tool warns' 'definitely-not-a-tool-xyz missing' "$output"
}

@test "legacy shared-identity layout warns" {
    seed_profiles
    mkdir -p "$FAKE_HOME/.claude/backups"
    ln -s "$FAKE_HOME/.claude/backups" "$FAKE_HOME/.claude-work/backups"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'identity warning' 'shares identity dirs' "$output"
}

@test "broken overlay link warns" {
    seed_profiles
    ln -s "$FAKE_HOME/.claude/nope" "$FAKE_HOME/.claude-work/skills"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'broken link warns' 'has broken links' "$output"
}

@test "unknown prompt style warns" {
    export DOT_PROMPT_STYLE="bogus"
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'style warns' 'unknown prompt style bogus (from DOT_PROMPT_STYLE)' "$output"
}

@test "the new themes and the saved style are known to the doctor" {
    export DOT_PROMPT_STYLE="catppuccin"
    run doctor_run
    assert_contains 'theme ok' 'prompt catppuccin installed' "$output"
    unset DOT_PROMPT_STYLE
    printf 'gruvbox\n' >"$HOME/.prompt-style"
    run doctor_run
    assert_contains 'saved style ok' 'prompt gruvbox installed' "$output"
    printf '../../etc/x\n' >"$HOME/.prompt-style"
    run doctor_run
    assert_contains 'bad saved style warns' 'unknown prompt style ../../etc/x (from ~/.prompt-style)' "$output"
}

@test "pending update warns with both versions" {
    export DOT_UPDATE_ROOT="$FIXREPO"
    seed_update_state 1.3.0
    run doctor_run
    assert_eq 'doctor rc 0' '0' "$status"
    assert_contains 'pending update warns' '1.2.0 → 1.3.0' "$output"
}

# doctor_with_containers <podman: 1|0>: doctor with the container helpers
# loaded (as config/.custom.bashrc does) against a fake host.
doctor_with_containers() {
    local bin="$BATS_TEST_TMPDIR/ctrbin" root="$BATS_TEST_TMPDIR/host"
    mkdir -p "$bin" "$root/proc/sys/user" "$root/sys/fs/cgroup" "$root/run/openrc" "$root/etc"
    printf '15000\n' >"$root/proc/sys/user/max_user_namespaces"
    printf '%s:100000:65536\n' "$(id -un)" | tee "$root/etc/subuid" >"$root/etc/subgid"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/newuidmap"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/podman"
    chmod +x "$bin"/*
    # Presence decided here, whatever the host has: without podman,
    # `command -v podman` is answered "absent" (a host /usr/bin/podman
    # can't be hidden through PATH without hiding /usr/bin itself).
    local hide=''
    [[ "$1" == 1 ]] || hide='command() { [[ "$1 $2" == "-v podman" ]] && return 1; builtin command "$@"; }'
    _DOT_CTR_ROOT="$root" PATH="$bin:$PATH" bash -i -c "
        source '$REPO_ROOT/scripts/.container.utils.sh' >/dev/null 2>&1
        source '$REPO_ROOT/scripts/.doctor.sh' >/dev/null 2>&1
        ${hide}
        dottod-doctor
    " 2>/dev/null
}

@test "podman section reports rootless prerequisites when podman is installed" {
    run doctor_with_containers 1
    assert_contains 'subids ok' "[ok] podman: subuid/subgid ranges for $(id -un)" "$output"
    assert_contains 'openrc cgroup hint' '[warn] podman: cgroup v1/hybrid under OpenRC' "$output"
}

@test "podman section stays quiet without podman" {
    run doctor_with_containers 0
    assert_eq 'no podman lines' '0' "$(grep -c 'podman:' <<<"$output" || true)"
}

# doctor_distro <fixture> [manager to stub]: doctor against an os-release
# fixture, with only the named package manager stubbed on PATH.
doctor_distro() {
    local bin="$BATS_TEST_TMPDIR/distrobin"
    mkdir -p "$bin"
    if [[ -n "${2:-}" ]]; then
        printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/$2"
        chmod +x "$bin/$2"
    fi
    _DOT_OS_RELEASE_FILE="$REPO_ROOT/tests/fixtures/os-release/$1" PATH="$bin:$PATH" doctor_run
}

@test "distro line names the family, manager and libc" {
    run doctor_distro gentoo emerge
    assert_contains 'gentoo ok' '[ok] distro: gentoo 2.18 (gentoo family, emerge,' "$output"
}

@test "distro line warns when the family's manager is missing" {
    # Hide dnf whatever the host has (exported into the doctor's shell).
    command() { [[ "$1 $2" == "-v dnf" ]] && return 1; builtin command "$@"; }
    export -f command
    run doctor_distro fedora
    unset -f command
    assert_contains 'missing dnf' "dnf not on PATH" "$output"
    assert_contains 'is a warning' '[warn] distro: fedora' "$output"
}

@test "distro line warns on an unsupported distribution" {
    run doctor_distro unknown
    assert_contains 'unsupported' "[warn] distro: unsupported distribution 'nixos'" "$output"
}

@test "secrets: store state and plaintext registry names, never values" {
    local bin="$BATS_TEST_TMPDIR/passbin"
    mkdir -p "$bin" "$FAKE_HOME/.docker"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/pass"
    chmod +x "$bin/pass"
    printf '{"auths":{"docker.io":{"auth":"bm90LXByaW50ZWQ="}}}\n' >"$FAKE_HOME/.docker/config.json"
    PATH="$bin:$PATH" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run" run doctor_run
    assert_contains 'no store' '[warn] pass installed but no store' "$output"
    assert_contains 'plaintext named' "plaintext registry credentials in $FAKE_HOME/.docker/config.json: docker.io" "$output"
    assert_eq 'no value' '0' "$(grep -c 'bm90LXByaW50ZWQ=' <<<"$output" || true)"
    mkdir -p "$FAKE_HOME/.password-store" && printf 'ABC\n' >"$FAKE_HOME/.password-store/.gpg-id"
    PATH="$bin:$PATH" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run" run doctor_run
    assert_contains 'store ok' '[ok] pass store initialised' "$output"
}
