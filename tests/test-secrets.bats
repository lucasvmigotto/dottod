#!/usr/bin/env bats
#
# test-secrets.bats — hermetic tests for bin/secrets.sh (spec 017).
#
# gpg, gpgconf and docker-credential-pass are stubs; HOME, the password
# store and the runtime dir are throwaway; _DOT_NO_PACKAGES=1, so nothing
# is installed. The real keyring, store and Podman config are untouched.
# Secret values planted in fixtures must never appear in any output.

load helpers

readonly SECRET='c2VjcmV0LXZhbHVlLW5ldmVyLXByaW50ZWQ='

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
    export PASSWORD_STORE_DIR="$HOME/.password-store"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export GPG_HOME="$HOME/.gnupg"
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$STUBBIN" "$GPG_HOME"
    export _DOT_NO_PACKAGES=1
    export _DOT_OS_RELEASE_FILE="${BATS_TEST_DIRNAME}/fixtures/os-release/debian"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/apt-get"
    # gpg: a secret key exists only when GPG_STUB_KEY is set.
    cat >"$STUBBIN/gpg" <<'EOF'
#!/usr/bin/env bash
[[ -n "${GPG_STUB_KEY:-}" ]] || exit 0
printf 'sec:u:255:22:ABCDEF:1:::u:::scESC:::+:::ed25519:::0:\nfpr:::::::::%s:\n' "${GPG_STUB_KEY}"
EOF
    # gpgconf: agent socket from AGENT_SOCKET, homedir = ~/.gnupg.
    cat >"$STUBBIN/gpgconf" <<'EOF'
#!/usr/bin/env bash
case "$2" in
    agent-socket) printf '%s\n' "${AGENT_SOCKET:-/run/user/1000/gnupg/S.gpg-agent}" ;;
    homedir) printf '%s\n' "${HOME}/.gnupg" ;;
esac
EOF
    chmod +x "$STUBBIN"/*
    export PATH="$STUBBIN:$PATH"
    unset GPG_STUB_KEY AGENT_SOCKET _DOT_SECRETS_HELPER
}

with_helper() {
    printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/docker-credential-pass"
    chmod +x "$STUBBIN/docker-credential-pass"
}

ready() {
    export GPG_STUB_KEY=0123456789ABCDEF0123456789ABCDEF01234567
    mkdir -p "$PASSWORD_STORE_DIR"
    printf '%s\n' "$GPG_STUB_KEY" >"$PASSWORD_STORE_DIR/.gpg-id"
    with_helper
}

run_task() { run "$REPO_ROOT/bin/secrets.sh" "$@"; }
dropin() { printf '%s' "$HOME/.config/containers/registries.conf.d/50-dottod-pass.conf"; }

@test "no GPG key: stops with the command to run, writes nothing" {
    run_task
    assert_eq 'rc 1' '1' "$status"
    assert_contains 'tells how' 'gpg --full-generate-key' "$output"
    assert_eq 'no drop-in' '0' "$([[ -e "$(dropin)" ]] && echo 1 || echo 0)"
    assert_eq 'no redirect' '0' "$([[ -e "$GPG_HOME/S.gpg-agent" ]] && echo 1 || echo 0)"
}

@test "key but no store: prints pass init for that key" {
    export GPG_STUB_KEY=0123456789ABCDEF0123456789ABCDEF01234567
    run_task
    assert_eq 'rc 1' '1' "$status"
    assert_contains 'tells how' "pass init $GPG_STUB_KEY" "$output"
}

@test "helper missing: pass is ready, registries not wired, rc 0" {
    ready
    rm -f "$STUBBIN/docker-credential-pass"
    # Absent whatever the host has installed.
    export _DOT_SECRETS_HELPER=dottod-test-no-helper
    run_task
    assert_eq 'rc 0 (degraded)' '0' "$status"
    assert_contains 'manual install' 'docker-credential-helpers/releases' "$output"
    assert_eq 'no drop-in' '0' "$([[ -e "$(dropin)" ]] && echo 1 || echo 0)"
}

@test "gentoo without USE=pass: prints the package.use line, edits nothing" {
    ready
    rm -f "$STUBBIN/docker-credential-pass"
    # Absent whatever the host has installed.
    export _DOT_SECRETS_HELPER=dottod-test-no-helper
    export _DOT_OS_RELEASE_FILE="${BATS_TEST_DIRNAME}/fixtures/os-release/gentoo"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$STUBBIN/emerge"
    printf '#!/usr/bin/env bash\nexit 1\n' >"$STUBBIN/portageq"
    chmod +x "$STUBBIN/emerge" "$STUBBIN/portageq"
    run_task
    assert_contains 'package.use hint' 'app-containers/docker-credential-helpers pass' "$output"
}

@test "ready: drop-in, redirect, plaintext removed without printing a value" {
    ready
    mkdir -p "$HOME/.docker" "$XDG_RUNTIME_DIR/containers"
    printf '{"auths":{"docker.io":{"auth":"%s"}},"credsStore":"x","psFormat":"y"}\n' "$SECRET" >"$HOME/.docker/config.json"
    printf '{"auths":{"dhi.io":{"auth":"%s"}}}\n' "$SECRET" >"$XDG_RUNTIME_DIR/containers/auth.json"
    chmod 600 "$HOME/.docker/config.json"
    run_task
    assert_eq 'rc 0' '0' "$status"
    assert_eq 'drop-in setting' 'credential-helpers = ["pass"]' "$(grep -v '^#' "$(dropin)")"
    assert_eq 'redirect' $'%Assuan%\nsocket=/run/user/1000/gnupg/S.gpg-agent' "$(cat "$GPG_HOME/S.gpg-agent")"
    assert_contains 'names logged' 'Removed plaintext registry credential: docker.io' "$output"
    assert_eq 'no value printed' '0' "$(grep -c "$SECRET" <<<"$output" || true)"
    assert_eq 'docker auths emptied' '{}' "$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1]))["auths"]))' "$HOME/.docker/config.json")"
    assert_eq 'other keys kept' 'x y' "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["credsStore"],d["psFormat"])' "$HOME/.docker/config.json")"
    assert_eq 'mode 600' '600' "$(stat -c %a "$HOME/.docker/config.json")"
    assert_eq 'runtime auths emptied' '{}' "$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1]))["auths"]))' "$XDG_RUNTIME_DIR/containers/auth.json")"
}

@test "rerun is a no-op" {
    ready
    run_task
    local before
    before="$(stat -c %Y "$(dropin)" "$GPG_HOME/S.gpg-agent")"
    sleep 1
    run_task
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'skips the drop-in' 'already log in through pass' "$output"
    assert_contains 'skips the redirect' 'redirect already in place' "$output"
    assert_eq 'files untouched' "$before" "$(stat -c %Y "$(dropin)" "$GPG_HOME/S.gpg-agent")"
}

@test "redirect: a live agent socket is never replaced" {
    ready
    python3 -c 'import socket,sys;s=socket.socket(socket.AF_UNIX);s.bind(sys.argv[1])' "$GPG_HOME/S.gpg-agent"
    run_task
    assert_contains 'warns' 'is a live agent socket; leaving it alone' "$output"
    assert_eq 'still a socket' '1' "$([[ -S "$GPG_HOME/S.gpg-agent" ]] && echo 1 || echo 0)"
}

@test "redirect: a foreign file is left alone" {
    ready
    printf 'something else\n' >"$GPG_HOME/S.gpg-agent"
    run_task
    assert_contains 'warns' 'is not a socket redirect; leaving it alone' "$output"
    assert_eq 'unchanged' 'something else' "$(cat "$GPG_HOME/S.gpg-agent")"
}

@test "redirect: not written when the agent is outside /run/user" {
    ready
    export AGENT_SOCKET="$GPG_HOME/S.gpg-agent"
    run_task
    assert_contains 'explains' 'not under /run/user' "$output"
    assert_eq 'no redirect file' '0' "$([[ -e "$GPG_HOME/S.gpg-agent" ]] && echo 1 || echo 0)"
}

@test "status reports state and names, never values" {
    ready
    mkdir -p "$HOME/.docker"
    printf '{"auths":{"docker.io":{"auth":"%s"}}}\n' "$SECRET" >"$HOME/.docker/config.json"
    run_task status
    assert_eq 'rc 0' '0' "$status"
    assert_contains 'key' "GPG key:    $GPG_STUB_KEY" "$output"
    assert_contains 'plaintext named' "Plaintext:  docker.io ($HOME/.docker/config.json)" "$output"
    assert_eq 'no value printed' '0' "$(grep -c "$SECRET" <<<"$output" || true)"
    assert_eq 'status wrote nothing' '0' "$([[ -e "$(dropin)" ]] && echo 1 || echo 0)"
}

@test "bootstrap runs secrets only when --only names it" {
    mkdir -p "$BATS_TEST_TMPDIR/sudo"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/sudo/sudo"
    chmod +x "$BATS_TEST_TMPDIR/sudo/sudo"
    local fakeroot="$BATS_TEST_TMPDIR/fakeroot"
    mkdir -p "$fakeroot/bin"
    cp "$REPO_ROOT/bin/bootstrap.sh" "$REPO_ROOT/bin/utils.sh" "$fakeroot/bin/"
    cp -R "$REPO_ROOT/lib" "$fakeroot/lib"
    for t in shell secrets; do
        printf '#!/usr/bin/env bash\necho "RAN:%s" >>"%s/calls.log"\n' "$t" "$BATS_TEST_TMPDIR" >"$fakeroot/bin/$t.sh"
        chmod +x "$fakeroot/bin/$t.sh"
    done
    PATH="$BATS_TEST_TMPDIR/sudo:$PATH" run "$fakeroot/bin/bootstrap.sh" --skip fonts,vim,neovim,container,gitconfig,ssh,tools,cargo,bun --verbose
    assert_contains 'skipped by default' 'Skipping opt-in task (select it with --only secrets): secrets' "$output"
    assert_eq 'not run' '0' "$(grep -c 'RAN:secrets' "$BATS_TEST_TMPDIR/calls.log" 2>/dev/null || true)"
    PATH="$BATS_TEST_TMPDIR/sudo:$PATH" run "$fakeroot/bin/bootstrap.sh" --only secrets --verbose
    assert_eq 'run when named' '1' "$(grep -c 'RAN:secrets' "$BATS_TEST_TMPDIR/calls.log")"
}

@test "pass-run is linked onto PATH; a foreign one is left alone" {
    ready
    run_task
    assert_eq 'linked to the repo script' "$REPO_ROOT/scripts/pass-run.sh" "$(readlink "$HOME/.local/bin/pass-run")"
    rm "$HOME/.local/bin/pass-run"
    printf '#!/bin/sh\n' >"$HOME/.local/bin/pass-run"
    run_task
    assert_contains 'warns' "is not dottod's pass-run; leaving it alone" "$output"
    assert_eq 'unchanged' '#!/bin/sh' "$(cat "$HOME/.local/bin/pass-run")"
}
