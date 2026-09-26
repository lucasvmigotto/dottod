#!/usr/bin/env bats
#
# test-toolchain.bats — hermetic tests for bin/cargo.sh and bin/bun.sh.
#
# Every test runs its probes in a FRESH bash subprocess that sources exactly
# one task script. This avoids colliding `_main`/`_usage` definitions and
# keeps the sourced EXIT traps out of the BATS process itself. Control the
# stubs from the parent via exported variables:
#   CARGO_STUB_VERSION   version string for the fake `cargo` (unset = absent)
#   BUN_STUB_VERSION     version string for the fake `bun` (unset = absent)
#   CURL_STUB_MODE       api-digest | api-no-digest | api-garbage | dl-fail
#   CURL_STUB_DIGEST     sha256 hex the fake API reports (default abc123)
#   FAKE_CARGO_HOME      cargo home the fake rustup-init plants into
# HOME is redirected to a temp dir so `_ensure_local_bin` never touches the
# real home; PATH is stub-first so no real toolchain can leak in.

load helpers

setup() {
    STUBBIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"

    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export STUBBIN CALLS
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export FAKE_CARGO_HOME="$BATS_TEST_TMPDIR/cargo-home"
    export _DOT_NO_PACKAGES=1
    unset CARGO_STUB_VERSION BUN_STUB_VERSION
    unset CURL_STUB_MODE CURL_STUB_DIGEST _DOT_RUSTUP_TOOLCHAIN _DOT_BUN_VERSION
    export _DOT_CARGO_HOME="$FAKE_CARGO_HOME"
    # _ensure_local_bin targets $HOME/.local/bin and the post-install
    # checks use `command -v`: keep the (initially empty) fake local bin
    # on PATH so installs are observable, exactly like a real shell with
    # the repo .zshrc sourced.
    export PATH="$FAKE_HOME/.local/bin:$STUBBIN:/usr/bin:/bin"

    # Fake `cargo`: version controlled by CARGO_STUB_VERSION; absent = missing.
    cat >"$STUBBIN/cargo" <<'EOF'
#!/usr/bin/env bash
if [[ -z "${CARGO_STUB_VERSION:-}" ]]; then
    echo "cargo stub invoked while absent" >&2
    exit 127
fi
if [[ "${1:-}" == "--version" ]]; then
    printf 'cargo %s\n' "${CARGO_STUB_VERSION}"
    exit 0
fi
exit 0
EOF
    # Fake `bun`: version controlled by BUN_STUB_VERSION; absent = missing.
    cat >"$STUBBIN/bun" <<'EOF'
#!/usr/bin/env bash
if [[ -z "${BUN_STUB_VERSION:-}" ]]; then
    echo "bun stub invoked while absent" >&2
    exit 127
fi
if [[ "${1:-}" == "--version" ]]; then
    printf '%s\n' "${BUN_STUB_VERSION}"
    exit 0
fi
exit 0
EOF
    # Fake `curl`: serves the GitHub API or a download, per CURL_STUB_MODE.
    # Modes: api-digest (default) | api-no-digest | api-garbage | dl-fail.
    cat >"$STUBBIN/curl" <<'EOF'
#!/usr/bin/env bash
is_api=0
dest=""
prev=""
for a in "$@"; do
    [[ "$a" == *"api.github.com"* ]] && is_api=1
    [[ "$prev" == "-o" ]] && dest="$a"
    prev="$a"
done
if [[ "${CURL_STUB_MODE:-api-digest}" == "dl-fail" ]]; then
    exit 22
fi
if (( is_api )); then
    case "${CURL_STUB_MODE:-api-digest}" in
        api-garbage) printf 'not json{{{' ;;
        api-no-digest)
            printf '{"assets":[{"name":"bun-linux-x64.zip","browser_download_url":"https://example/bun.zip"}]}'
            ;;
        *) printf '{"assets":[{"name":"bun-linux-x64.zip","browser_download_url":"https://example/bun.zip","digest":"sha256:%s"}]}' "${CURL_STUB_DIGEST:-abc123}" ;;
    esac
    exit 0
fi
if [[ -n "$dest" ]]; then
    if [[ "${CURL_STUB_INSTALLER:-0}" == "1" ]]; then
        # Fake rustup-init: plants a fake cargo, records its argv.
        cat >"$dest" <<INNER
#!/usr/bin/env bash
printf '%s\n' "\$*" >"${CALLS}.rustup-args"
mkdir -p "${FAKE_CARGO_HOME}/bin"
printf '#!/usr/bin/env bash\necho "cargo 1.99.0 (stub)"\n' >"${FAKE_CARGO_HOME}/bin/cargo"
chmod +x "${FAKE_CARGO_HOME}/bin/cargo"
INNER
    else
        printf 'BUNZIP-DUMMY' >"$dest"
    fi
    exit 0
fi
exit 0
EOF
    # Fake `unzip`: plants the extracted bun binary, records invocation.
    cat >"$STUBBIN/unzip" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CALLS}.unzip-args"
mkdir -p "${CALLS}.unzip-out/bun-linux-x64"
printf '#!/usr/bin/env bash\necho "9.9.9"\n' >"${CALLS}.unzip-out/bun-linux-x64/bun"
chmod +x "${CALLS}.unzip-out/bun-linux-x64/bun"
# The real flow extracts into $tmpdir; mirror it by copying our plant there.
for a in "$@"; do
    if [[ -d "$a" ]]; then
        mkdir -p "$a/bun-linux-x64"
        cp "${CALLS}.unzip-out/bun-linux-x64/bun" "$a/bun-linux-x64/bun"
    fi
done
exit 0
EOF
    chmod +x "$STUBBIN"/{cargo,bun,curl,unzip}

    # Record-only package installs; never touch apt.
    cat >"$STUBBIN/pkg-shim-note" <<'EOF'
placeholder
EOF
}

# Absence must be real (`mv`), because `_is_installed` uses `command -v`:
# a present-but-failing stub file would still count as installed.
cargo_absent() { mv "$STUBBIN/cargo" "$STUBBIN/cargo.hidden"; }
bun_absent()   { mv "$STUBBIN/bun" "$STUBBIN/bun.hidden"; }

# Run a probe in a fresh bash with PATH/HOME already hermetic.
# Usage: probe <script> <snippet>  (stdout+stderr captured via `run`)
# The task script is sourced directly (it brings bin/utils.sh along, and
# its BASH_SOURCE guard keeps _main from running); _install_packages is
# overridden afterwards to record-only.
probe() {
    local script=${1} snippet=${2}
    run bash -c "
        set -Eeuo pipefail
        source '${REPO_ROOT}/bin/${script}.sh'
        _install_packages() { printf 'PKGS:%s\n' \"\$*\" >>\"\$CALLS\"; return 0; }
        ${snippet}
    "
}

@test "cargo: skips when present without package calls" {
    export CARGO_STUB_VERSION=1.98.0
    probe cargo '_cargo_ensure >/dev/null'
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message names version' '1.98.0 already installed' "$output"
    assert_eq 'no package calls' '0' "$(grep -c '^PKGS:' "$CALLS" || true)"
}

@test "cargo: installs toolchain when absent" {
    cargo_absent
    export CURL_STUB_INSTALLER=1
    probe cargo '_cargo_ensure >/dev/null'
    assert_eq 'install rc 0' '0' "$status"
    assert_eq 'fake cargo planted' '1' "$([[ -x "$FAKE_CARGO_HOME/bin/cargo" ]] && echo 1 || echo 0)"
    assert_eq 'deps requested once' '1' "$(grep -c '^PKGS:curl ca-certificates' "$CALLS" || true)"
    assert_contains 'installer got toolchain flags' '--default-toolchain stable' "$(cat "$CALLS.rustup-args")"
}

@test "cargo: honors toolchain override" {
    cargo_absent
    export CURL_STUB_INSTALLER=1 _DOT_RUSTUP_TOOLCHAIN=1.99.0
    probe cargo '_cargo_ensure >/dev/null'
    assert_eq 'override rc 0' '0' "$status"
    assert_contains 'override passed through' '--default-toolchain 1.99.0' "$(cat "$CALLS.rustup-args")"
}

@test "cargo: fails honestly on download error" {
    cargo_absent
    export CURL_STUB_MODE=dl-fail
    probe cargo '_cargo_ensure'
    assert_eq 'download failure rc 1' '1' "$status"
    assert_contains 'names the failure' 'download failed' "$output"
    assert_eq 'no cargo planted' '0' "$([[ -e "$FAKE_CARGO_HOME/bin/cargo" ]] && echo 1 || echo 0)"
}

@test "cargo: rejects invalid action" {
    probe cargo "_main bogus"
    assert_eq 'invalid action rc 1' '1' "$status"
    assert_contains 'usage hint' 'Unknown action' "$output"
}

@test "cargo: status prints a toolchain report" {
    export CARGO_STUB_VERSION=1.98.0
    probe cargo '_cargo_status'
    assert_eq 'status rc 0' '0' "$status"
    assert_contains 'reports cargo' 'cargo 1.98.0' "$output"
    assert_contains 'reports home' 'Home:' "$output"
}

@test "bun: skips when present without package calls" {
    export BUN_STUB_VERSION=1.2.0
    probe bun '_bun_ensure >/dev/null'
    assert_eq 'skip rc 0' '0' "$status"
    assert_contains 'skip message names version' '1.2.0 already installed' "$output"
    assert_eq 'no package calls' '0' "$(grep -c '^PKGS:' "$CALLS" || true)"
}

@test "bun: arch maps to a linux target" {
    probe bun '[[ "$(_bun_arch)" == linux-* ]]'
    assert_eq 'arch is a linux target' '0' "$status"
}

@test "bun: asset resolution builds latest URL and digest" {
    probe bun 'read -r url sha <<<"$(_bun_zip_asset latest linux-x64)"; printf "%s %s" "$url" "$sha"'
    assert_eq 'latest url' 'https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip abc123' "$output"
}

@test "bun: tag normalization accepts bun-v, v and bare forms" {
    probe bun 'read -r url sha <<<"$(_bun_zip_asset v1.2.0 linux-x64)"; printf "%s" "$url"'
    assert_eq 'v form' 'https://github.com/oven-sh/bun/releases/download/bun-v1.2.0/bun-linux-x64.zip' "$output"
    probe bun 'read -r url sha <<<"$(_bun_zip_asset 1.2.0 linux-x64)"; printf "%s" "$url"'
    assert_eq 'bare form' 'https://github.com/oven-sh/bun/releases/download/bun-v1.2.0/bun-linux-x64.zip' "$output"
}

@test "bun: verified install when digest matches" {
    bun_absent
    export CURL_STUB_DIGEST
    CURL_STUB_DIGEST="$(printf 'BUNZIP-DUMMY' | sha256sum | cut -d' ' -f1)"
    probe bun '_bun_ensure >/dev/null'
    assert_eq 'verified rc 0' '0' "$status"
    assert_eq 'binary installed executable' '1' "$([[ -x "$FAKE_HOME/.local/bin/bun" ]] && echo 1 || echo 0)"
    assert_contains 'unzip extracted the bundle' 'bun-linux-x64/bun' "$(cat "$CALLS.unzip-args")"
}

@test "bun: checksum mismatch fails without installing" {
    bun_absent
    export CURL_STUB_DIGEST=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
    probe bun '_bun_ensure'
    assert_eq 'mismatch rc 1' '1' "$status"
    assert_contains 'names the mismatch' 'checksum mismatch' "$output"
    assert_eq 'nothing installed' '0' "$([[ -e "$FAKE_HOME/.local/bin/bun" ]] && echo 1 || echo 0)"
}

@test "bun: missing digest warns and proceeds" {
    bun_absent
    export CURL_STUB_MODE=api-no-digest
    probe bun '_bun_ensure'
    assert_eq 'warn-path rc 0' '0' "$status"
    assert_contains 'warns once' 'No checksum published' "$output"
    assert_eq 'binary installed' '1' "$([[ -x "$FAKE_HOME/.local/bin/bun" ]] && echo 1 || echo 0)"
}

@test "bun: rejects invalid action" {
    probe bun "_main bogus"
    assert_eq 'invalid action rc 1' '1' "$status"
    assert_contains 'usage hint' 'Unknown action' "$output"
}

@test "bun: status prints a bun report" {
    export BUN_STUB_VERSION=1.2.0
    probe bun '_bun_status'
    assert_eq 'status rc 0' '0' "$status"
    assert_contains 'reports version' '1.2.0' "$output"
    assert_contains 'reports pin default' 'Pinned:' "$output"
}
