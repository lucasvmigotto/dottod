#!/usr/bin/env bash
#
# nvim-headless-check.sh — validate the dottod Neovim configuration headless.
#
# Checks: startup succeeds, dottod modules load, plugins load, keymaps and
# options are set, health runs. No display, no interactive input. Exit non-zero on any failure.
#
# Usage: scripts/nvim-headless-check.sh [--profile NAME]
#   DOTTOD_NVIM_PROFILE can also be set directly in the environment.
#
# Sourced-by-zsh guard (same contract as scripts/system-info.sh): the zshrc
# glob sources every scripts/*.sh, and this is a bash PROGRAM that executes
# checks and exits — sourcing it under zsh would run the battery inside the
# interactive shell and `exit` would close it. Guard before `set` so shell
# options are never polluted either.

if [[ -n "${ZSH_VERSION:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

set -Eeuo pipefail
_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_PROFILE='development'

if [[ "${1:-}" == '--profile' ]]; then
    _PROFILE="${2:?'--profile requires a name'}"
fi

export DOTTOD_NVIM_PROFILE="${_PROFILE}"

failures=0

function _fail() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

function _pass() {
    printf 'ok:   %s\n' "$*"
}

if ! command -v nvim >/dev/null 2>&1; then
    printf 'FAIL: nvim not on PATH; run ./bin/neovim.sh first\n' >&2
    exit 1
fi

# 1. Startup: no errors, config loads.
startup_out="$(nvim --headless +qa 2>&1 || true)"
if printf '%s' "${startup_out}" | grep -qE '(^|\n)E[0-9]+:|Error'; then
    _fail "startup reported errors: ${startup_out}"
else
    _pass 'headless startup clean'
fi

# 2. Core modules load; collect any load error per module.
module_err="$(nvim --headless +'lua for _, m in ipairs({"dottod", "dottod.options", "dottod.keymaps", "dottod.autocmds", "dottod.commands", "dottod.utils", "dottod.profiles", "dottod.health", "dottod.plugins.ui", "dottod.plugins.navigation", "dottod.plugins.git", "dottod.plugins.terminal"}) do local ok, err = pcall(require, m) if not ok then print("MODULE_FAIL " .. m .. ": " .. tostring(err)) end end' +qa 2>&1 || true)"
if printf '%s' "${module_err}" | grep -q 'MODULE_FAIL'; then
    _fail "module load failures: ${module_err}"
else
    _pass 'all dottod lua modules load'
fi

# 2. Keymaps exist (leader workflow).
keymap_out="$(nvim --headless +'lua local want = {"<Leader>w", "<Leader>q", "<C-h>", "<C-p>", "<Leader>ta", "]b", "[b"} for _, k in ipairs(want) do local km = vim.fn.maparg(k, "n") if km == "" then print("KEYMAP_FAIL " .. k) end end' +qa 2>&1 || true)"
if printf '%s' "${keymap_out}" | grep -q 'KEYMAP_FAIL'; then
    _fail "missing keymaps: ${keymap_out}"
else
    _pass 'core keymaps present'
fi

# 3. Options are applied.
opt_out="$(nvim --headless +'lua if not vim.opt.number:get() then print("OPT_FAIL number") end if next(vim.opt.mouse:get() or {}) ~= nil then print("OPT_FAIL mouse") end if not vim.opt.undofile:get() then print("OPT_FAIL undofile") end' +qa 2>&1 || true)"
if printf '%s' "${opt_out}" | grep -q 'OPT_FAIL'; then
    _fail "option failures: ${opt_out}"
else
    _pass 'options applied (number, no-mouse, undofile)'
fi

# 4. lazy.nvim initialized with the lockfile.
lazy_out="$(nvim --headless +'lua local ok, lazy = pcall(require, "lazy") if not ok then print("LAZY_FAIL load") elseif not lazy.plugins() then print("LAZY_FAIL plugins") end' +qa 2>&1 || true)"
if printf '%s' "${lazy_out}" | grep -q 'LAZY_FAIL'; then
    _fail "lazy.nvim: ${lazy_out}"
else
    _pass 'lazy.nvim initialized'
fi

# 5. Health check runs (informational; failures counted from report).
health_out="$(nvim --headless +'checkhealth dottod' +qa 2>&1 || true)"
if printf '%s' "${health_out}" | grep -qi 'ERROR'; then
    _fail "checkhealth dottod reported errors: $(printf '%s' "${health_out}" | grep -i 'ERROR' | head -n 3)"
else
    _pass 'checkhealth dottod clean'
fi

printf 'headless checks: %d failure(s) (profile: %s)\n' "${failures}" "${_PROFILE}"
exit $(( failures > 0 ))