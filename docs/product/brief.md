---
Status: Draft
---

Reconstructed by project:introspec on 2026-09-26 from `39e4839`.

# dottod — product brief

## Problem
Setting up a Debian workstation after a reset or fresh install is manual,
slow and unrepeatable: shell, fonts, editors, terminal, container runtime,
Git identity and SSH have to be reconfigured by hand
[ASSUMPTION: the pain is personal-workstation resets; confirm audience].

## Goals
- Reproduce a working Debian (GNOME) workstation from one command
  [INFERRED: single orchestrator `bin/bootstrap.sh` + TUI → confirm].
- Every task idempotent and safe to re-run
  [OBSERVED: tests/test-container.bats:196, tests/test-neovim.bats:255].
- No silent destruction of user config (backup-before-link everywhere)
  [OBSERVED: bin/utils.sh:277].

## Audiences
- The maintainer themself (single-user dotfiles). Confirmed 2026-09-26:
  no multi-user, team or enterprise stories; downstream specs stay
  single-user. The TUI serves the same user as an interactive frontend
  (incl. no-Rust prebuilt installs).

## Capabilities (observed task inventory)
`bin/bootstrap.sh` `DOT_TASKS` [OBSERVED: bin/bootstrap.sh:7]:

| # | Capability | Entry point |
|---|-----------|-------------|
| 1 | shell (zsh + oh-my-zsh + spaceship + sysinfo) | `bin/shell.sh` |
| 2 | fonts (Nerd Fonts) | `bin/fonts.sh` |
| 3 | vim (vim-plug) | `bin/vim.sh` |
| 4 | neovim (version-gated + lazy.nvim config) | `bin/neovim.sh` |
| 5 | container (Podman default, Docker alt) | `bin/container.sh`, `bin/docker.sh` |
| 6 | desktop (GNOME) | `bin/desktop.sh` |
| 7 | vscode (MS apt repo) | `bin/vscode.sh` |
| 8 | ghostty (terminal) | `bin/ghostty.sh` |
| 9 | gitconfig (identity) | `bin/gitconfig.sh` |
| 10 | ssh (GitHub host merge) | `bin/ssh.sh` |
| 11 | tools (lazygit/lazydocker/k9s/btop/httpie/bat/…) | `bin/tools.sh` |
| 12 | interactive runner (TUI) | `tui/src/main.rs:25` (`dottod` binary) |

## Journeys
1. **Fresh install**: clone → `./bin/bootstrap.sh` → all 11 tasks run
   sequentially with PASS/FAIL summary [OBSERVED: bin/bootstrap.sh:67].
2. **Selective install**: `--only shell,tools` / `--skip desktop`
   [OBSERVED: bin/bootstrap.sh:169].
3. **Interactive**: `cargo run --release` in `tui/`, toggle tasks, `Enter`
   runs them [OBSERVED: tui/src/main.rs:178].
4. **Recovery**: re-run any task; backups (`*.dottod.bak`) preserve user
   files [OBSERVED: bin/utils.sh:277, bin/neovim.sh:258].

## Non-functional needs (as implemented)
- Idempotency over speed (every task probes before acting).
- Debian-only (`apt`, `dpkg` lock assumptions)
  [OBSERVED: bin/utils.sh:223, tui/src/scheduler.rs:12].
- TTY or passwordless sudo required for privileged steps
  [OBSERVED: bin/utils.sh:146].
- Offline-tolerant editor config (locked plugins, no startup network)
  [OBSERVED: config/nvim/lua/dottod/init.lua:10].

## Metrics, risks
No product metrics or SLOs exist in the repo [OBSERVED: no metrics code
found]. Top risks: third-party install scripts (`curl|bash` in
`bin/ghostty.sh:33`, oh-my-zsh pipe in `bin/shell.sh:38`), no LICENSE
file (only `license = "MIT"` in `tui/Cargo.toml:6`), one observed flaky
hermetic test (see `docs/product/introspec.md`).

## Glossary
- **Task** — one `bin/<id>.sh` unit plus its TUI registry entry; the two
  registries must match exactly. Not: script, job.
- **Profile** (`DOTTOD_NVIM_PROFILE`) — `minimal | terminal | development |
  full`; selects Neovim feature gates. Not: mode, tier.
- **Configured / Selected / Usable** (container) — explicit choice vs.
  auto-resolution vs. working runtime [OBSERVED: bin/container.sh:111].
- **Healing** — opt-in tarball install when apt is too old
  (`_DOT_NVIM_ALLOW_TARBALL=1`) [OBSERVED: bin/neovim.sh:224].
- **Sysinfo segment** — the Spaceship prompt metrics section
  [OBSERVED: scripts/.sysinfo.prompt.sh:48].
