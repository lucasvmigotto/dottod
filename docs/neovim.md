# Neovim (first-class editor)

dottod ships **two independent editors** with the same installation
philosophy:

| Editor | Stack | Entry |
| ------ | ----- | ----- |
| Vim | VimScript + vim-plug | `bin/vim.sh`, `config/.custom.vimrc` |
| Neovim | Lua + lazy.nvim | `bin/neovim.sh`, `config/nvim/` |

Vim is **not** deprecated and is not touched by the Neovim task. The two
share dottod's conventions (idempotency, backups, task model, tests,
profiles, user overrides) but have independent implementations. Do not
port configs between them blindly.

## Zero-dependency philosophy

The Neovim task is a **base setup**: terminal-first editing, fuzzy
finding, file exploration, git workflow and terminal integration — with
**zero external runtime dependencies**. It ships no LSP servers, no
Treesitter parsers, no formatters, no linters and no debug adapters, and
it never installs language toolchains. First launch needs the network
once (lazy.nvim bootstrap, see below); after that the editor is fully
usable offline.

This makes it a safe ground layer that works identically on a workstation,
a container, or a low-bandwidth SSH box. If you want an IDE-style layer
(LSP, completion, formatting, …), see [Re-adding LSP/Treesitter later](#re-adding-lsptreesitter-later).

## Install

```bash
./bin/neovim.sh                 # version check + config link
./bin/bootstrap.sh --only neovim
./bin/bootstrap.sh --only vim,neovim   # both editors
./bin/bootstrap.sh --skip neovim       # everything but Neovim
./bin/neovim.sh status          # report: version, profile, config, tools
```

Idempotent: re-running converges (installed binary skipped, correct
symlink detected). The installer only validates the binary version and
links the config; plugin installation happens on the first `nvim` launch
(lazy.nvim bootstraps itself, then follows the committed lockfile).

## Version policy (important on Debian)

The configuration targets **Neovim >= 0.11.0** (enforced by the
installer; kept as the floor for future language-tooling re-additions).
Debian trixie's official archive ships **0.10.4** — below the floor. The
installer:

1. Accepts any installed `nvim >= 0.11.0` (any source: apt, tarball, distro).
2. Otherwise checks the apt **candidate**:
   - candidate `>= 0.11.0` → installs via apt;
   - candidate too old (or apt unusable) → **fails with instructions** by
     default. It never silently installs an incompatible version and never
     adds a third-party apt repository.
3. Opt-in healing — install the official upstream tarball (rootless, into
   `~/.local`), sha256-verified against the GitHub release API digest:

   ```bash
   _DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh
   ```

Overrides:

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `_DOT_NVIM_MIN_VERSION` | `0.11.0` | minimum accepted version |
| `_DOT_NVIM_VERSION` | `v0.12.5` | tarball version for healing |
| `_DOT_NVIM_ALLOW_TARBALL` | `0` | `1` enables tarball healing |
| `_DOT_NVIM_TARBALL_ROOT` | `~/.local/nvim` | tarball extract root |
| `_DOT_NVIM_PROFILE` | `development` | `minimal`/`terminal`/`development`/`full` |
| `_DOT_TARGET_USER` | `id -un` | target user |
| `_DOT_NVIM_CONFIG_HOME` | `~/.config` | parent of `nvim/` (tests) |

## Profiles

Selected by `$DOTTOD_NVIM_PROFILE` (env var, read at every startup — no
relink needed), validated by the installer *and* the Lua layer.

| Profile | Plugins at startup |
| ------- | ------------------ |
| `minimal` | options, keymaps, colorscheme, statusline only (SSH/recovery) |
| `terminal` | + gitsigns, toggleterm, lazygit/lazydocker/k9s/btop launchers |
| `development` | same as `terminal` (default) |
| `full` | same as `terminal` |

With the language-tooling layer removed, the profiles currently differ
only in whether git/terminal plugins load; `development` and `full` are
reserved for future feature groups. Telescope, neo-tree and the remaining
plugins are event/key/cmd lazy-loaded in every profile — `minimal`
startup loads only the colorscheme, statusline and plugin manager.

## Existing config safety

If `~/.config/nvim` already exists (any form), it is moved to
`~/.config/nvim.dottod.bak` — never deleted. If a backup already exists, a
timestamped `nvim.dottod.bak.<YYYYmmddHHMMSS>` is used instead. A rerun with
the correct symlink in place does nothing.

## Architecture

```txt
config/nvim/
  init.lua                     # leader + lazy bootstrap + require('dottod')
  lazy-lock.json               # committed pin file (see below)
  lua/dottod/
    init.lua                   # lazy.setup + override chain
    options.lua keymaps.lua autocmds.lua commands.lua
    utils.lua health.lua profiles.lua
    plugins/                   # one spec file per concern
      init.lua ui.lua navigation.lua git.lua terminal.lua
  lua/dottod_local.lua.example # user override template
```

`init.lua` is deliberately tiny; nothing lives in a giant file. Every
plugin spec documents why the plugin exists and which profile gates it.

## Plugin manager: lazy.nvim

- Bootstrap: cloned once (stable branch) into `~/.local/share/nvim/lazy/`.
  Failure (offline first run) prints the git error and continues degraded.
- **Lockfile**: `config/nvim/lazy-lock.json` lives *in the repo* and pins
  every plugin by commit. Because `~/.config/nvim` is a symlink into the
  repo, `:Lazy update` writes the lockfile into your checkout — **commit
  it** to keep installs reproducible. `:Lazy restore` rolls back to it.
- Update checker and change detection are **disabled**: no network on
  startup, ever. Updates are explicit (`:Lazy update`) — a package
  management operation, not a runtime behavior.
- Offline: startup never downloads. Missing plugins are reported by lazy at
  startup only when `install.missing` can't run.

## Keymap reference

`<leader>` = Space. Press `<leader>` and wait for which-key; every custom
map has a description.

Core (all profiles):

| Keys | Action |
| ---- | ------ |
| `<C-p>` / `<leader>ff` | find files (Telescope) |
| `<leader>fg` / `<leader>fw` | live grep / grep current word |
| `<leader>fb` `<leader>bb` | buffers |
| `<leader>fh` | recent files |
| `<leader>f:` / `<leader>f?` | commands / keymaps |
| `<leader>fr` | resume last picker |
| `<F2>` `<F3>` `<F4>` | explorer toggle / focus / reveal (neo-tree) |
| `<leader>e` / `<leader>pe` | toggle explorer |
| `<C-h/j/k/l>` | window navigation |
| `]b` `[b` `]t` `[t` `]q` `[q` | next/prev buffer, tab, quickfix |
| `<leader>w/q/x/Q` | save / quit / save+quit / quit! |
| `<leader>s` `<leader>v` `<leader>o` | split / vsplit / only |
| `<leader><Tab>n` / `<leader><Tab>d` | new tab / close tab |
| `<leader><CR>` or `<leader>n` | clear search highlight |
| `<leader>ev` / `<leader>sv` | edit / reload config |
| `<leader>ta` / `<leader>tq` | run project tests (terminal) / quickfix |
| `<Esc><Esc>` | exit terminal mode |

Terminal profile: `<C-\>` toggle, `<leader>tt/th/tv` float/horizontal/vertical,
`<leader>gg` lazygit, `<leader>dk` lazydocker, `<leader>kk` k9s, `<leader>bt`
btop (each degrades with an actionable warning when the tool is missing).

Git (gitsigns, buffer-local in git repos): `]h`/`[h` next/prev hunk,
`<leader>ghp` preview, `ghs`/`ghr` stage/reset hunk, `ghS`/`ghR` stage/reset
buffer, `ghb` blame line, `ghd` diffthis.

The `<leader>fd`/`fs`/`fS` pickers (diagnostics, document/workspace
symbols) exist but depend on attached sources — without LSP or diagnostics
producers they open empty pickers. They become useful again if language
tooling is re-added (see below).

Deviations from stock Vim (all deliberate, mirroring the old `.vimrc`):
mouse disabled (multiplexers own it), relativenumber on, persistent undo,
no swap/backup files, splits open right/below, clipboard = `unnamedplus`
when available, `timeoutlen=500`.

## Git

gitsigns for the gutter/hunk workflow (see keymap table). lazygit stays the
repository UI (`<leader>gg`, floating via toggleterm) — dottod composes
with its CLI tools, it does not reimplement them.

## User customization

Copy the template once:

```bash
cp config/nvim/lua/dottod_local.lua.example \
   config/nvim/lua/dottod_local.lua
```

`lua/dottod_local.lua` is loaded **after** all dottod defaults, is never
shipped in releases (git-ignored), and is never touched by `./bin/neovim.sh`
— your overrides survive dottod updates. A missing file is fine; a broken
one reports its error once and continues.

## Health

```vim
:checkhealth dottod      " or :DottodHealth
```

Reports: Neovim version vs policy, profile, lazy + lockfile state,
rg/fd/git presence (with degrade notes for Telescope), dottod CLI tools
(lazygit/lazydocker/k9s/btop), TERM/tmux context, user-override status.
Every failure line carries a fix.

## Offline / degraded behavior

- No network on startup (checker disabled, plugins locked).
- Missing rg ⇒ Telescope live grep degrades (install: `sudo apt-get install
  ripgrep`); missing fd ⇒ find_files falls back to `find`.
- `telescope-fzf-native` compiles once via `make`; without a compiler it is
  skipped and Telescope uses its Lua matcher.
- `minimal` profile is the recovery mode (`DOTTOD_NVIM_PROFILE=minimal nvim`).

## Performance baseline

Headless startup (default profile, warm): **~27 ms**. Measure it yourself:

```bash
nvim --headless --startuptime /tmp/su.txt +qa && grep 'NVIM STARTED' /tmp/su.txt
:Lazy profile     " inside nvim: per-plugin timing
```

## Testing

```bash
bats tests/test-neovim.bats         # installer: hermetic (stubs, no network)
bats tests/test-neovim-headless.bats# config: real nvim, skips when absent
scripts/nvim-headless-check.sh      # battery: startup/modules/keymaps/health
./bin/neovim.sh status              # live report
```

The hermetic suite also pins the sourced-by-zsh contract: every `scripts/*.sh`
is sourced by `~/.zshrc` at shell startup, so any bash *program* placed
there must carry the zsh guard (see `nvim-headless-check.sh`'s header) —
the regression test asserts the shell survives sourcing it.

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| `Neovim 0.10.4 via apt is below the minimum 0.11.0` | intended gate: use backports, a newer source, or `_DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh` |
| `nvim: command not found` after tarball install | `~/.local/bin` not on `PATH` (re-login or export it) |
| plugins missing on a new machine | open nvim once online (`:Lazy sync`) — lazy bootstraps on first launch |
| live grep empty | ripgrep missing: `sudo apt-get install ripgrep` |
| which-key popup feels late | it is keyed to `timeoutlen=500`; tune in `dottod_local.lua` |

## Plugin policy (why each one exists)

| Plugin | Why (native/alternative rejected) |
| ------ | --------------------------------- |
| lazy.nvim | lockfile + lazy-loading + profiling; no native equivalent |
| plenary.nvim | shared dependency of telescope/neo-tree |
| tokyonight | terminal-safe dark colorscheme, no animation cost |
| lualine | statusline; `laststatus` alone is too sparse |
| mini.icons | icon set for lualine/telescope/neo-tree (mocks web-devicons) |
| which-key v3 | discoverability of the leader hierarchy |
| indent-blankline | scope-aware indent guides (vim-indent-guides successor) |
| nvim-colorizer | color previews (coloresque successor) |
| telescope + fzf-native + ui-select | fuzzy finding; native pickers lack rg integration; fzf-native is optional (needs `make`) |
| neo-tree v3.x (+ nui) | single explorer (NERDTree successor; ignore list ported from `.nerdtree.vimrc`) |
| gitsigns | gutter signs/hunks; lazygit owns the repo UI |
| toggleterm | float/h/v terminals wrapping native `:terminal` |

Deliberately absent (kept out to honor the zero-dependency rule):
nvim-treesitter (+textobjects), nvim-lspconfig, mason(+lspconfig),
blink.cmp, friendly-snippets, conform.nvim, nvim-lint, neotest,
nvim-dap(+ui). Syntax highlighting uses Vim regex; there is no semantic
completion/formatting/linting until you opt in.

## Re-adding LSP/Treesitter later

Brief recipe — drop a spec into `config/nvim/lua/dottod/plugins/` (or your
`dottod_local.lua`), then `:Lazy sync`:

```lua
-- example: treesitter back, minimal
{ 'nvim-treesitter/nvim-treesitter', branch = 'master', lazy = false,
  build = ':TSUpdate', opts = { ensure_installed = { 'bash', 'lua', 'c', 'cpp' } } }
```

For LSP on Neovim 0.11+, use the native `vim.lsp.config()` /
`vim.lsp.enable()` APIs (the legacy `require('lspconfig').setup()` is
deprecated upstream); enable only servers whose binaries exist so a
missing tool never breaks a buffer. Treesitter note: stay on `master`
(the `main` branch is an incompatible rewrite). Each addition widens the
external-dependency surface — that is the trade-off this base setup
deliberately leaves to you.
