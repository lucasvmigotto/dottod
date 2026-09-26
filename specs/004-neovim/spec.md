# 004 — neovim (version-gated lazy.nvim config)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only neovim` so that a
  compatible Neovim installs, `~/.config/nvim` links to the repo, and
  plugins sync from the committed lockfile — without touching Vim.
- US2: As a user on old Debian I get a clear error (not a broken editor)
  when apt only offers Neovim < 0.11, with the opt-in tarball path.
- US3: As a user I pick `minimal|terminal|development|full` via env and
  the editor degrades gracefully (Telescope falls back without rg/fd).
- US4: As a user I run `:checkhealth dottod` and get actionable diagnostics.

## Acceptance scenarios
- Given nvim ≥ 0.11 present, when the task runs, then binary install is
  skipped [OBSERVED: bin/neovim.sh:194, tests/test-neovim.bats:143].
- Given nvim 0.10.4 installed, when the task runs, then it fails with the
  upgrade message and installs nothing
  [OBSERVED: tests/test-neovim.bats:150].
- Given apt candidate too old and no healing flag, when the task runs,
  then it names the candidate and suggests `_DOT_NVIM_ALLOW_TARBALL=1`
  without attempting a doomed apt install
  [OBSERVED: tests/test-neovim.bats:158].
- Given healing allowed, when the task runs, then the official tarball is
  sha256-verified (GitHub API digest) and linked rootless
  [OBSERVED: bin/neovim.sh:133, tests/test-neovim.bats:179].
- Given existing `~/.config/nvim`, when the task runs, then it is backed
  up (timestamped on second conflict), never deleted
  [OBSERVED: bin/neovim.sh:258, tests/test-neovim.bats:223].
- Given the linked config, when nvim starts headless, then all modules
  load, keymaps/options apply, health is clean, startup < 150 ms
  [OBSERVED: tests/test-neovim-headless.bats, scripts/nvim-headless-check.sh].

## Status
Bash: Implemented. TUI: Implemented. E2E note: the headless battery runs
real nvim + real config + real plugins (integration-grade); no
cross-stack e2e exists. Treated as Implemented per specs/README.md.
