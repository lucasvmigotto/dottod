---
Status: Draft
---

Reconstructed by project:introspec on 2026-09-26 from `39e4839`.

# dottod — as-is architecture

## Topology
Single-host workstation provisioner. Two interfaces drive the same task
scripts [OBSERVED: tui/src/runner.rs:19, bin/bootstrap.sh:51]:

```text
./bin/bootstrap.sh --only/--skip/--parallel ─┐
                                              ├─► bin/<task>.sh ─► $HOME, /etc/apt, ~/.config
dottod (Ratatui TUI, tui/src/main.rs) ────────┘         (via _priv sudo/doas)
```

## Hosting / platform
- Target: Debian 13 (trixie), GNOME; CI runs `ubuntu-26.04`
  [OBSERVED: .github/workflows/shell.yml:22].
- Dev container: `lucasvmigotto/devenv:rust-1.89-debian` with docker-outside-of-docker
  [OBSERVED: .devcontainer/devcontainer.json:2].
- No servers, no databases, no cloud resources. State lives on the
  workstation (`$HOME`, `/etc`, `/tmp/dottod`, `~/.cache/dottod`).

## Stack
| Layer | Technology | Evidence |
|-------|-----------|----------|
| Orchestration | bash (`set -Eeuo pipefail`), shared `bin/utils.sh` | bin/utils.sh:3 |
| Interactive runner | Rust: ratatui 0.29, crossterm 0.28, tokio 1, clap 4, serde 1 | tui/Cargo.toml |
| Shell env | zsh + oh-my-zsh + spaceship + custom sysinfo/container sections | bin/shell.sh, scripts/.sysinfo.prompt.sh |
| Editors | vim+vim-plug; Neovim ≥0.11 + lazy.nvim (15 pinned plugins) | bin/vim.sh, bin/neovim.sh, config/nvim/lazy-lock.json |
| Prompt metrics | bash collector over `/proc`+`/sys`, atomic cache | scripts/system-info.sh:99 |
| Tests | BATS 1.14 (5 suites), zsh suites (2), Rust unit tests (7) | tests/run.sh |
| CI | 4 GitHub workflows (shell, container, neovim, tui) | .github/workflows/ |
| Releases | `tui.yml` release job: `dottod-linux-x86_64` binary + scripts tarball + sha256sums | .github/workflows/tui.yml:43 |

## Data stores
None (no database). Persistent workstation state is enumerated in
`docs/product/domain-model.md` (symlinks, backups, caches, lockfiles,
TUI `state.json`).

## Integrations (outbound only)
oh-my-zsh install script, spaceship-prompt, vim-plug, Nerd Fonts
releases, Microsoft + Docker apt repos, ghostty-ubuntu installer,
GitHub release APIs (neovim, lazygit/lazydocker/k9s/resterm),
lazy.nvim + Mason registries, crates.io. See `docs/product/introspec.md`
for the full table with config keys.

## Capacity
No capacity model, no load targets, no metrics pipeline exist
[OBSERVED: no metrics/telemetry code found]. Only performance datum:
headless Neovim startup ~27 ms [OBSERVED: docs/neovim.md:259 — claimed,
not re-measured here].

## ADRs (reconstructed from history/docs — confirm)
- **Podman default, Docker alternative** (`_DOT_CONTAINER_RUNTIME`,
  `--runtime`): rootless-first on Debian
  [OBSERVED: bin/container.sh:111, tui/src/task.rs:60].
- **Two editors, independent implementations** (VimScript vs Lua, no
  shared abstraction) [OBSERVED: docs/neovim.md:3].
- **Neovim ≥0.11 floor + tarball healing** instead of third-party apt
  repos [OBSERVED: bin/neovim.sh:190].
- **Zero-dependency Neovim base** (LSP/Treesitter/formatting removed;
  re-add recipe in docs) [OBSERVED: config/nvim/lua/dottod/plugins/,
  docs/neovim.md:287].
- **Lockfile-committed plugins** (`lazy-lock.json` in repo)
  [OBSERVED: config/nvim/lazy-lock.json].
