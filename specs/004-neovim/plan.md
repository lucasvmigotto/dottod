# 004-neovim — as-is technical context

- Entry: `bin/neovim.sh` (`_nvim_ensure_binary` candidate-first, then
  `_nvim_link_config`; no plugin sync in installer — lazy bootstraps on
  first launch) [OBSERVED: bin/neovim.sh:190,349].
- Config tree `config/nvim/`: `init.lua` (leader + lazy bootstrap),
  `lua/dottod/{options,keymaps,autocmds,commands,utils,health,profiles}.lua`,
  `lua/dottod/plugins/{init,ui,navigation,git,terminal,devcontainer}.lua` — 16 pinned
  plugins, zero LSP/Treesitter/formatting/linting by design
  [OBSERVED: config/nvim/lua/dottod/plugins/, docs/neovim.md:287].
- Profiles gate only `core|git|terminal`
  [OBSERVED: config/nvim/lua/dottod/profiles.lua:17].
- Lockfile `config/nvim/lazy-lock.json` (16 pins) lives in-repo via the
  config symlink [OBSERVED: lazy-lock.json].
- Tests: `tests/test-neovim.bats` (20 hermetic), `tests/test-neovim-headless.bats`
  (8 integration), `scripts/nvim-headless-check.sh` battery; CI job
  `.github/workflows/neovim.yml` [OBSERVED: tests/, .github/workflows/neovim.yml].
- Known flake (observed once, then green): hermetic test 10 under run.sh —
  see `docs/product/introspec.md` findings.
