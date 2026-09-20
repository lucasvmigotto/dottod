#!/usr/bin/env bats
#
# test-neovim.bats — tests for bin/neovim.sh.
#
# Hermetic: stub nvim/apt-cache/curl binaries on a prepended PATH, real
# temp dirs via _DOT_NVIM_CONFIG_HOME, _DOT_NO_PACKAGES=1 so no apt call
# is possible. _install_packages is redefined to record-only (never
# executes), _priv is never reached. Headless integration checks live in
# tests/test-neovim-headless.bats (real nvim; skipped when absent).
#
# NB: deliberately NO `set +e` here (unlike test-container.bats): with
# errexit relaxed, bats-core 1.14 swallows failing assertions (verified
# empirically: a trailing `assert_eq` returning 1 still reports "ok").
# Errexit stays enabled so a failing assert aborts the test and gets
# reported; only `-u` is relaxed (BATS internals use unset vars), and
# non-zero probes go through `run`, which captures status/output safely.

load helpers

setup() {
    STUBBIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"

    # nvim stub: version controlled by NVIM_STUB_VERSION; absent = missing.
    cat >"$STUBBIN/nvim" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
    printf 'NVIM v%s\nBuild type: Release\n' "${NVIM_STUB_VERSION:-0.12.5}"
    exit 0
fi
exit 0
EOF
    # apt-cache stub: candidate controlled by APT_STUB_CANDIDATE.
    cat >"$STUBBIN/apt-cache" <<'EOF'
#!/usr/bin/env bash
printf 'neovim:\n  Installed: (none)\n  Candidate: %s\n' "${APT_STUB_CANDIDATE:-0.10.4-8}"
exit 0
EOF
    chmod +x "$STUBBIN/nvim" "$STUBBIN/apt-cache"

    export NVIM_STUB_VERSION=0.12.5
    export APT_STUB_CANDIDATE='0.10.4-8'
    export STUB_CALLS="$CALLS"
    export _DOT_NO_PACKAGES=1
    export _DOT_NVIM_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    unset _DOT_NVIM_ALLOW_TARBALL _DOT_NVIM_MIN_VERSION _DOT_NVIM_VERSION
    unset _DOT_NVIM_PROFILE _DOT_NVIM_TARBALL_ROOT _DOT_TARGET_USER
    mkdir -p "$_DOT_NVIM_CONFIG_HOME"
    # Hermetic PATH: stubs win, and a REAL nvim elsewhere (e.g. ~/.local/bin
    # on a dev box) can never leak into version probes — nvim_absent must
    # mean "no nvim at all".
    export PATH="$STUBBIN:/usr/bin:/bin"

    # shellcheck disable=SC1091
    # (utils.sh is sourced transitively by neovim.sh; sourcing it here
    # again would trip `readonly DOT_REPO_ROOT` on the double assignment)
    #
    # utils.sh installs `trap _sudo_cleanup EXIT`, which replaces bats'
    # per-test exit trap — with that gone, an errexit abort (i.e. a failed
    # assertion) vanishes from the report instead of failing the test.
    # Save bats' trap and re-arm it after sourcing.
    local _bats_exit_trap
    _bats_exit_trap="$(trap -p EXIT)"
    source "${BATS_TEST_DIRNAME}/../bin/neovim.sh"
    eval "${_bats_exit_trap}"
    # Sourced files enable strict mode; relax only nounset — errexit stays
    # so failing assertions abort the test and are reported.
    set +u

    # Record-only: never install, never touch apt.
    _install_packages() {
        printf 'PKGS:%s\n' "$*" >>"$CALLS"
        return 0
    }
}

nvim_absent()   { mv "$STUBBIN/nvim" "$STUBBIN/nvim.hidden"; }
nvim_present()  { mv "$STUBBIN/nvim.hidden" "$STUBBIN/nvim" 2>/dev/null || true; }

@test "version comparison handles semver, tags and debian suffixes" {
    run _nvim_ver_ge 0.12.5 0.11.0
    assert_eq 'newer minor ok' '0' "$status"
    run _nvim_ver_ge 0.11.0 0.11.0
    assert_eq 'equal ok' '0' "$status"
    run _nvim_ver_ge 0.10.4 0.11.0
    assert_eq 'older minor fails' '1' "$status"
    run _nvim_ver_ge 1.0.0 0.11.0
    assert_eq 'major bump ok' '0' "$status"
    run _nvim_ver_ge 0.11 0.11.0
    assert_eq 'short vs padded equal' '0' "$status"
    run _nvim_ver_ge v0.13.0-dev 0.12.5
    assert_eq 'dev tag counts as newer' '0' "$status"
}

@test "normalization strips v, distro suffix and epoch" {
    assert_eq 'v-prefixed' '0.12.5' "$(_nvim_norm_ver v0.12.5)"
    assert_eq 'debian revision' '0.10.4' "$(_nvim_norm_ver 0.10.4-8)"
    assert_eq 'epoch' '0.12.5' "$(_nvim_norm_ver 1:0.12.5-1~trixie)"
    assert_eq 'dev suffix' '0.13.0' "$(_nvim_norm_ver 0.13.0-dev-1410)"
}

@test "version probe parses nvim --version and fails on garbage" {
    assert_eq 'parses stub version' '0.12.5' "$(_nvim_version)"
    NVIM_STUB_VERSION=0.10.4
    assert_eq 'parses old version' '0.10.4' "$(_nvim_version)"
    printf '#!/usr/bin/env bash\nprintf "garbage"\n' >"$STUBBIN/nvim"
    run _nvim_version
    assert_eq 'garbage rc 1' '1' "$status"
}

@test "apt candidate is read and normalized" {
    assert_eq 'candidate normalized' '0.10.4' "$(_nvim_apt_candidate)"
    APT_STUB_CANDIDATE='(none)'
    assert_eq 'no candidate empty' '' "$(_nvim_apt_candidate)"
    APT_STUB_CANDIDATE='1:0.12.5-1~trixie'
    assert_eq 'epoch stripped' '0.12.5' "$(_nvim_apt_candidate)"
}

@test "tarball asset resolution parses url and digest from the api" {
    cat >"$STUBBIN/curl" <<'EOF'
#!/usr/bin/env bash
# hermetic stub: emit release metadata; CURL_STUB_NO_DIGEST drops the digest
if [[ -n "${CURL_STUB_NO_DIGEST:-}" ]]; then
    printf '{"assets":[{"name":"nvim-linux-x86_64.tar.gz","browser_download_url":"https://example/nvim-linux-x86_64.tar.gz"}]}'
else
    printf '{"assets":[{"name":"nvim-linux-x86_64.tar.gz","browser_download_url":"https://example/nvim-linux-x86_64.tar.gz","digest":"sha256:abc123"}]}'
fi
exit 0
EOF
    chmod +x "$STUBBIN/curl"
    local url sha
    read -r url sha <<<"$(_nvim_tarball_asset v0.12.5 x86_64)"
    assert_eq 'asset url' 'https://example/nvim-linux-x86_64.tar.gz' "$url"
    assert_eq 'asset digest' 'abc123' "$sha"
    export CURL_STUB_NO_DIGEST=1
    run _nvim_tarball_asset v0.12.5 x86_64
    assert_eq 'missing digest rc 1' '1' "$status"
    assert_contains 'names the missing asset' "No asset 'nvim-linux-x86_64.tar.gz' (with digest)" "$output"
}

@test "ensure skips a compatible installed binary" {
    : >"$CALLS"
    _nvim_ensure_binary >/dev/null
    assert_eq 'compatible rc 0' '0' "$?"
    assert_eq 'no package calls' '0' "$(grep -c '^PKGS:' "$CALLS" || true)"
}

@test "ensure rejects an installed but too-old binary" {
    NVIM_STUB_VERSION=0.10.4
    run _nvim_ensure_binary
    assert_eq 'old binary rc 1' '1' "$status"
    assert_contains 'actionable version message' 'requires Neovim 0.11' "$output"
    assert_eq 'no package calls on reject' '0' "$(grep -c '^PKGS:' "$CALLS" || true)"
}

@test "ensure with old apt candidate and no healing fails with instructions" {
    nvim_absent
    run _nvim_ensure_binary
    assert_eq 'old candidate rc 1' '1' "$status"
    assert_contains 'names the candidate' '0.10.4 via apt is below the minimum 0.11.0' "$output"
    assert_contains 'offers the healing flag' '_DOT_NVIM_ALLOW_TARBALL=1' "$output"
    assert_eq 'never attempts doomed apt install' '0' "$(grep -c '^PKGS:' "$CALLS" || true)"
}

@test "ensure with good candidate attempts apt first, fails honestly if it yields nothing" {
    nvim_absent
    APT_STUB_CANDIDATE='0.12.5-1'
    run _nvim_ensure_binary
    # record-only _install_packages cannot put a binary on PATH: ensure
    # must report that precisely (not blame the candidate, which is fine)
    assert_eq 'no binary after apt rc 1' '1' "$status"
    assert_eq 'apt attempted exactly once' '1' "$(grep -c '^PKGS:neovim' "$CALLS" || true)"
    assert_contains 'honest failure message' 'did not yield a usable Neovim' "$output"
    assert_contains 'offers the healing flag' '_DOT_NVIM_ALLOW_TARBALL=1' "$output"
}

@test "ensure heals via tarball when allowed" {
    nvim_absent
    export _DOT_NVIM_ALLOW_TARBALL=1
    _nvim_install_tarball() {
        printf 'TARBALL:%s\n' "$*" >>"$CALLS"
        # simulate a successful rootless install: put nvim back on PATH
        nvim_present
    }
    _nvim_ensure_binary >/dev/null
    assert_eq 'healed rc 0' '0' "$?"
    assert_contains 'tarball invoked with version and user' 'TARBALL:v0.12.5' "$(cat "$CALLS")"
    assert_eq 'no apt attempt when candidate too old' '0' "$(grep -c '^PKGS:neovim' "$CALLS" || true)"
}

@test "ensure refuses tarball version below the minimum" {
    nvim_absent
    export _DOT_NVIM_ALLOW_TARBALL=1 _DOT_NVIM_VERSION=v0.10.4
    run _nvim_ensure_binary
    assert_eq 'old tarball rc 1' '1' "$status"
    assert_contains 'rejects old pinned tarball' 'below minimum' "$output"
}

@test "config link: fresh target becomes a symlink" {
    _nvim_link_config "$(id -un)" >/dev/null
    local target="$_DOT_NVIM_CONFIG_HOME/nvim"
    assert_eq 'symlink created' '1' "$([[ -L "$target" ]] && echo 1 || echo 0)"
    local repo_root
    repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    assert_eq 'points at repo config' "${repo_root}/config/nvim" "$(readlink "$target")"
}

@test "config link: rerun is a no-op without backups" {
    _nvim_link_config "$(id -un)" >/dev/null
    local target="$_DOT_NVIM_CONFIG_HOME/nvim"
    local before
    before="$(readlink "$target")"
    local out
    # log_* helpers write to stderr; capture it for the assertion
    out="$(_nvim_link_config "$(id -un)" 2>&1)"
    assert_contains 'second run skips' 'Already linked' "$out"
    assert_eq 'link unchanged' "$before" "$(readlink "$target")"
    assert_eq 'no backup created' '0' "$([[ -e "$target.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "config link: existing user config is backed up, never destroyed" {
    target="$_DOT_NVIM_CONFIG_HOME/nvim"
    mkdir -p "$target"
    printf 'my precious config\n' >"$target/init.lua"
    _nvim_link_config "$(id -un)" >/dev/null
    assert_eq 'backup exists' '1' "$([[ -e "$target.dottod.bak" ]] && echo 1 || echo 0)"
    assert_contains 'user file preserved in backup' 'my precious config' "$(cat "$target.dottod.bak/init.lua")"
    assert_eq 'target now a symlink' '1' "$([[ -L "$target" ]] && echo 1 || echo 0)"
}

@test "config link: second pre-existing config gets a timestamped backup" {
    local target="$_DOT_NVIM_CONFIG_HOME/nvim"
    mkdir -p "$target" "$target.dottod.bak"
    _nvim_link_config "$(id -un)" >/dev/null
    assert_eq 'original backup still there' '1' "$([[ -e "$target.dottod.bak" ]] && echo 1 || echo 0)"
    assert_eq 'timestamped backup created' '1' \
        "$(ls "$target.dottod.bak."* >/dev/null 2>&1 && echo 1 || echo 0)"
}

@test "config target honors env override and other users" {
    assert_eq 'env override' "$_DOT_NVIM_CONFIG_HOME/nvim" "$(_nvim_config_target "$(id -un)")"
    unset _DOT_NVIM_CONFIG_HOME
    assert_eq 'other user path' "/home/otheruser/.config/nvim" "$(_nvim_config_target otheruser)"
}

@test "main rejects an invalid profile" {
    export _DOT_NVIM_PROFILE=bogus
    run _nvim_main_wrapper
    assert_eq 'invalid profile rc 1' '1' "$status"
    assert_contains 'profile error names valid values' 'minimal|terminal|development|full' "$output"
}

@test "main installs, links and is idempotent end to end" {
    export _DOT_NVIM_PROFILE=development
    run _nvim_main_wrapper
    assert_eq 'first run rc 0' '0' "$status"
    assert_eq 'config linked' '1' "$([[ -L "$_DOT_NVIM_CONFIG_HOME/nvim" ]] && echo 1 || echo 0)"
    # The neovim package itself is version-gated (installed binary is
    # accepted); core deps go through apt every run — that is by design
    # (apt is idempotent), so only the gated call is asserted here.
    assert_eq 'no neovim package call needed' '0' "$(grep -c '^PKGS:neovim' "$CALLS" || true)"
    run _nvim_main_wrapper
    assert_eq 'second run rc 0' '0' "$status"
    assert_eq 'still no neovim package call' '0' "$(grep -c '^PKGS:neovim' "$CALLS" || true)"
    assert_contains 'second link is a no-op' 'Already linked' "$output"
}

@test "status prints a version and policy report" {
    out="$(_nvim_status)"
    assert_contains 'installed version' 'Installed: 0.12.5' "$out"
    assert_contains 'minimum policy' 'Minimum:   0.11.0' "$out"
    assert_contains 'apt candidate' 'Apt cand:  0.10.4' "$out"
    assert_contains 'default profile' 'Profile:   development' "$out"
}

@test "headless check script is inert when sourced by zsh (zshrc glob)" {
    # config/.custom.zshrc sources every scripts/*.sh at startup; a bash
    # program without the zsh guard would run its body inside the
    # interactive shell and `exit` would close it (regression: the shell
    # "loaded and closed just after" the shell task ran).
    command -v zsh >/dev/null 2>&1 || skip 'zsh not installed'
    local script="${BATS_TEST_DIRNAME}/../scripts/nvim-headless-check.sh"
    local out rc
    out="$(zsh -c "source '${script}'; echo SURVIVED; [[ -o errexit ]] && echo ERR_EXIT_LEAKED; true" 2>&1)"; rc=$?
    assert_eq 'sourcing under zsh rc 0' '0' "$rc"
    assert_contains 'shell survives sourcing' 'SURVIVED' "$out"
    assert_eq 'no battery output leaks' '0' "$(printf '%s' "$out" | grep -c 'headless startup clean' || true)"
    assert_eq 'no shell options leaked' '0' "$(printf '%s' "$out" | grep -c 'ERR_EXIT_LEAKED' || true)"
}

# _main without running it: neovim.sh self-executes only when BASH_SOURCE
# equals $0, so sourcing is safe; this wrapper isolates _main for probing.
_nvim_main_wrapper() {
    _main ''
}
