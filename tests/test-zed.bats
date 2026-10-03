#!/usr/bin/env bats
#
# test-zed.bats — hermetic tests for bin/zed.sh.
#
# Covers: skip-when-present, download-then-run install via a stub
# installer, and loud failure on download error. The stub installer plants
# a fake zed into $HOME/.local/bin, mirroring the real script's layout.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export _DOT_NO_PACKAGES=1
    unset _DOT_ZED_INSTALLER_URL _DOT_ZED_CHANNEL _DOT_ZED_VERSION
    export PATH="$STUBBIN:/usr/bin:/bin"

    # Fake `zed`: present only when ZED_STUB_VERSION is set.
    cat >"$STUBBIN/zed" <<'EOF'
#!/usr/bin/env bash
if [[ -z "${ZED_STUB_VERSION:-}" ]]; then
    echo "zed stub invoked while absent" >&2
    exit 127
fi
printf 'zed %s\n' "${ZED_STUB_VERSION}"
EOF
    chmod +x "$STUBBIN/zed"

    # Stub installer: plants a fake zed where the real one lands.
    cat >"$BATS_TEST_TMPDIR/stub-install.sh" <<'EOF'
#!/usr/bin/env sh
mkdir -p "$HOME/.local/bin"
printf '#!/usr/bin/env bash\necho "zed 0.0-stub"\n' >"$HOME/.local/bin/zed"
chmod +x "$HOME/.local/bin/zed"
printf 'channel=%s version=%s\n' "${ZED_CHANNEL:-}" "${ZED_VERSION:-}" >"$HOME/stub-env.txt"
EOF
}

zed_absent() { mv "$STUBBIN/zed" "$STUBBIN/zed.hidden"; }

probe() {
    local snippet=${1}
    run bash -c "
        set -Eeuo pipefail
        source '${REPO_ROOT}/bin/zed.sh'
        ${snippet}
    "
}

@test "zed: skips when present without downloading" {
    export ZED_STUB_VERSION=0.200.0
    probe '_zed_ensure >/dev/null'
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message' 'already installed' "$output"
}

@test "zed: installs via download-then-run with channel env" {
    zed_absent
    export _DOT_ZED_INSTALLER_URL="file://$BATS_TEST_TMPDIR/stub-install.sh"
    export _DOT_ZED_CHANNEL=preview
    probe '_zed_ensure >/dev/null'
    assert_eq 'install rc 0' '0' "$status"
    assert_eq 'binary planted executable' '1' "$([[ -x "$FAKE_HOME/.local/bin/zed" ]] && echo 1 || echo 0)"
    assert_contains 'channel passed through' 'channel=preview version=latest' "$(cat "$FAKE_HOME/stub-env.txt")"
}

@test "zed: fails loudly on download error" {
    zed_absent
    export _DOT_ZED_INSTALLER_URL="file:///nonexistent-installer.sh"
    probe '_zed_ensure'
    assert_eq 'download failure rc 1' '1' "$status"
    assert_contains 'names the failure' 'download failed' "$output"
    assert_eq 'nothing installed' '0' "$([[ -e "$FAKE_HOME/.local/bin/zed" ]] && echo 1 || echo 0)"
}

@test "zed: honors version pin" {
    zed_absent
    export _DOT_ZED_INSTALLER_URL="file://$BATS_TEST_TMPDIR/stub-install.sh"
    export _DOT_ZED_VERSION=v0.199.0
    probe '_zed_ensure >/dev/null'
    assert_eq 'pin rc 0' '0' "$status"
    assert_contains 'version passed through' 'version=v0.199.0' "$(cat "$FAKE_HOME/stub-env.txt")"
}
