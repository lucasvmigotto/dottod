# 004-neovim — data model (config tree as state)

- `~/.config/nvim` → symlink to `<repo>/config/nvim` (or
  `~/.config/nvim.dottod.bak[.timestamp]` backup of prior user config).
- `~/.local/share/nvim/lazy/` — plugin checkouts (lazy-managed, unpinned
  on disk; pins live in `lazy-lock.json`).
- `~/.local/share/nvim/mason/` — absent by design (no Mason in this config).
- `lua/dottod_local.lua` — optional user overlay, git-ignored, loaded
  after defaults, never touched by the installer
  [OBSERVED: config/nvim/lua/dottod/init.lua:24, .gitignore].
- Invariants: installed nvim must satisfy `_DOT_NVIM_MIN_VERSION`
  (default 0.11.0); lockfile commits keep installs reproducible.
