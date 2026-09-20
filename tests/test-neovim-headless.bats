#!/usr/bin/env bats
#
# test-neovim-headless.bats — integration checks against a real nvim
# running this repo's config headless. Skips (with a note) unless:
#   * nvim >= 0.11 is on PATH
#   * ~/.config/nvim is a symlink into THIS repo (./bin/neovim.sh did it)
# In CI the workflow installs nvim and links the config first, so these run.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    CONFIG_LINK="${HOME}/.config/nvim"

    if ! command -v nvim >/dev/null 2>&1; then
        skip 'nvim not on PATH (run ./bin/neovim.sh)'
    fi
    if ! nvim --version 2>/dev/null | head -n1 | grep -qE 'NVIM v0\.(1[1-9]|[2-9])'; then
        skip 'nvim < 0.11 on PATH'
    fi
    if [[ ! -L "$CONFIG_LINK" ]] || [[ "$(readlink "$CONFIG_LINK")" != *"dottod/config/nvim" ]]; then
        skip "$HOME/.config/nvim is not linked to this repo"
    fi
    # Sherlock the profile so checks are deterministic.
    export DOTTOD_NVIM_PROFILE=development
}

@test "headless check battery passes (development profile)" {
    run "${REPO_ROOT}/scripts/nvim-headless-check.sh" --profile development
    assert_eq 'headless battery rc 0' '0' "$status"
    assert_contains 'zero failures reported' '0 failure(s)' "$output"
}

@test "headless check battery passes (minimal profile)" {
    run "${REPO_ROOT}/scripts/nvim-headless-check.sh" --profile minimal
    assert_eq 'minimal battery rc 0' '0' "$status"
}

@test "headless check battery passes (full profile)" {
    run "${REPO_ROOT}/scripts/nvim-headless-check.sh" --profile full
    assert_eq 'full battery rc 0' '0' "$status"
}

@test "minimal profile skips heavy plugins at startup" {
    run nvim --headless +'lua local names={}; for n,p in pairs(require("lazy.core.config").plugins) do if p._.loaded then names[#names+1]=n end end; print(table.concat(names,","))' +qa
    assert_eq 'minimal probe rc 0' '0' "$status"
    local loaded="$output"
    # LSP/completion/formatting/linting/telescope must be absent in minimal
    for heavy in blink.cmp nvim-lspconfig conform.nvim nvim-lint telescope.nvim neo-tree.nvim gitsigns.nvim toggleterm.nvim mason.nvim; do
        assert_eq "minimal does not load ${heavy}" '0' "$(printf '%s' "$loaded" | grep -c "${heavy}" || true)"
    done
}

@test "development profile lazy-loads the heavy plugins" {
    run nvim --headless +'lua local names={}; for n,p in pairs(require("lazy.core.config").plugins) do if p._.loaded then names[#names+1]=n end end; print(table.concat(names,","))' +qa
    assert_eq 'development probe rc 0' '0' "$status"
    # colorscheme + statusline load early; the rest wait for events
    for early in tokyonight.nvim lualine.nvim; do
        assert_eq "development loads ${early}" '1' "$(printf '%s' "$output" | grep -c "${early}" || true)"
    done
}

@test "checkhealth dottod reports profile and version" {
    local report="$BATS_TEST_TMPDIR/health.txt"
    nvim --headless +'checkhealth dottod' +"w! ${report}" +qa >/dev/null 2>&1
    assert_eq 'health report written' '1' "$([[ -s "$report" ]] && echo 1 || echo 0)"
    local body
    body="$(cat "$report")"
    assert_contains 'reports neovim version' 'Neovim 0.' "$body"
    assert_contains 'reports profile' 'Profile: development' "$body"
}

@test "lazy-lock.json is valid json pinning the plugin set" {
    local lock="${REPO_ROOT}/config/nvim/lazy-lock.json"
    assert_eq 'lockfile exists' '1' "$([[ -f "$lock" ]] && echo 1 || echo 0)"
    local out
    out="$(python3 - "$lock" <<'EOF'
import json, sys
lock = json.load(open(sys.argv[1]))
assert len(lock) >= 15, f"too few pins: {len(lock)}"
for must in ("lazy.nvim", "telescope.nvim", "neo-tree.nvim", "gitsigns.nvim"):
    assert must in lock, f"core pin missing: {must}"
for name, meta in lock.items():
    assert "commit" in meta, f"{name} missing commit pin"
print("LOCKFILE_OK", len(lock))
EOF
)"
    assert_contains 'lockfile validated' 'LOCKFILE_OK' "$out"
}

@test "startup is fast (headless under 150ms)" {
    local su="$BATS_TEST_TMPDIR/startuptime.txt"
    nvim --headless --startuptime "$su" +qa >/dev/null 2>&1
    local total
    total="$(grep 'NVIM STARTED' "$su" | tail -n1 | awk '{print $1}')"
    assert_eq 'startuptime recorded' '1' "$([[ -n "$total" ]] && echo 1 || echo 0)"
    awk -v t="$total" 'BEGIN { if (t+0 < 150) exit 0; else exit 1 }' \
        || assert_eq "startup ${total}ms under 150ms" 'true' 'false'
}
