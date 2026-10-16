# Changelog

Releases are plain SemVer git tags (`1.0.0`). This file is maintained by
`scripts/release.py`: a `## Unreleased` section below is renamed to the new
version on release (hand-written notes win); otherwise the section is
generated from Conventional Commits since the last tag.

## 2.5.0 — 2026-10-16

### Added

- **shell:** prompt-style --preview
- **shell:** extract through pv
- **codes:** mark repos with a Claude conversation; codes -c
- **claude:** offer a new conversation when --continue/--resume has none

## 2.4.0 — 2026-10-16

### Added

- **shell:** pv progress shortcuts

## 2.3.0 — 2026-10-16

### Added

- **shell:** prompt-style saves the style in ~/.prompt-style; --dry-run
- **shell:** prompt-style lists and switches the prompt style

### Fixed

- **doctor:** know every prompt style, and the saved one

## 2.2.0 — 2026-10-16

### Added

- **prompt:** pastel, tokyonight, gruvbox and catppuccin themes
- **prompt:** theme glyphs; ASCII glyphs on bash before 4.2

## 2.1.1 — 2026-10-16

### Fixed

- **prompt:** branch and directory names can't run commands

## 2.1.0 — 2026-10-16

### Added

- **fetch:** draw the card with fastfetch; fastfetch as a tools extra
- **codes:** work/personal context column and filters
- **shell:** gwork clone/set/unset for the work identity
- **gitconfig:** work identity as data, GIT_GLOBAL_IDENTITY=0 opt-out
- **scripts:** dottod-fetch card of what dottod sees on a system
- **secrets:** link pass-run onto PATH
- **scripts:** pass-run gives one command secrets from pass
- **dev:** loadenv reads .env as data and resolves pass: values
- **doctor:** report the pass store and plaintext registry credentials
- **secrets:** opt-in pass task with container registry logins through it
- **bootstrap:** opt-in tasks run only when --only names them
- **lib:** map pass and the docker credential helper per distro
- **site:** icon support matrix with tooltips on the Distributions page

### Fixed

- **packages:** fastfetch only where Debian and Ubuntu package it
- **prompt:** lighter powerline status block
- **prompt:** powerline closing arrow visible on the left
- **prompt:** powerline right side as filled blocks
- **shell:** switching DOT_PROMPT_STYLE on reload replaces the prompt instead of stacking

## 2.0.0 — 2026-10-15

### Added

- **A `status` action on every task.** `<task>.sh status` prints a
  read-only report (installed versions, linked config, identity, keys,
  fonts, tools) for shell, fonts, vim, zed, gitconfig, ssh and tools,
  joining neovim, container, cargo and bun. `bootstrap.sh --status` prints
  every report and honours `--only`, `--skip` and `--ui`. Nothing is
  installed, written or asked.
- **Docs.** The Commands page documents the status reports with a vhs
  demo, the `--help` demo is re-recorded with `--status`, and the Roadmap
  lists what 2.0.0 delivers. The "Deliberately not planned" list is gone.

### Fixed

- **Docs guide pages.** Sidebar, search and "Next" links pointed guides
  at `#/guide-<name>` instead of their `#/guides/<name>` route, so every
  Guides page showed "That page doesn't exist". All links now come from one
  page-to-route mapping, with a test that opens every sidebar link.
- **Docs footer versions.** The footer reads `dottod@vX.Y.Z · docs@vX.Y.Z`,
  each linked to the repository tree at its release tag (or the commit
  past it), and the site deploys after the release workflow, so it never
  shows the previous version. The docs version (`docs/site/package.json`)
  is raised by `scripts/release.py`, now able to bump the manifests listed
  in `release.json`.

## 1.8.0 — 2026-10-13

### Added

- **scripts:** container listing aliases on the runtime dispatcher

## 1.7.1 — 2026-10-11

### Fixed

- **tests:** pin prompt timer so worker speed can't flake it

## 1.7.0 — 2026-10-11

### Added

- **gitconfig:** conditional work identity via includeIf
- **claude:** add profile rename subcommand

### Fixed

- **claude:** abort launch when the picker is cancelled
- **claude:** silence live-session scan on unreadable processes
- **claude:** refuse rename/rm while a session is live
- **claude:** export preview helpers so the picker resolves them

## 1.6.0 — 2026-10-11

### Added

- **claude:** usage bars and resets in profile picker

## 1.5.0 — 2026-10-09

### Added

- **scripts:** add clipboard paste and clear aliases
- **claude:** profile info in picker and quiet launch path

## 1.4.0 — 2026-10-09

### Added

- **scripts:** multi-profile Claude setup with marker discovery
- **devx:** add justfile task runner
- **scripts:** add dottod-doctor health check
- **scripts:** work/personal Claude profiles over shared store

### Fixed

- **scripts:** isolate profile identity dirs
- **scripts:** guard intentional word splitting in claude lib
- **scripts:** silence shellcheck on unused match var and bare cd
- **scripts:** warn on stray shared login

## 1.3.0 — 2026-10-06

### Added

- **scripts:** self-update check with notify-only prompt
- **codes:** grouped display and qualified matching
- **codes:** keep linked nested checkouts in discovery
- **styles:** add powerline prompt variant
- **styles:** add kali prompt variant

### Fixed

- **codes:** no parent prefix on nested children
- **styles:** hermetic prompt tests and shellcheck findings
- **devcontainer:** drop stale env-file arg
- **scripts:** scope ssh-agent bootstrap to WSL

### Changed

- **styles:** extract prompt library and robbyrussell variant

## 1.2.0 — 2026-10-05

### Added

- **scripts:** add codes function

## 1.1.1 — 2026-10-04

### Fixed

- **tests:** shadow system nvim in hermetic installer suite

## 1.1.0 — 2026-10-04

### Added

- **docs:** vhs terminal demos with transcripts
- **docs:** documentation site with hub deploy

### Fixed

- **shell:** restore PATH and utilities loading in bashrc

## 1.0.1 — 2026-10-04

### Fixed

- **ci:** use version variable in release assets

## 1.0.0 — 2026-10-03

### Added

- **Plain-bash terminal task.** `bin/shell.sh` ensures bash as the login
  shell and links `config/.custom.bashrc` (exit-aware prompt, git segment,
  `ctr` dispatcher, utility functions) — no zsh, oh-my-zsh, spaceship or
  prompt plugins.
- **Cargo and Bun tasks.** `bin/cargo.sh` (rustup, stable/minimal) and
  `bin/bun.sh` (verified direct-zip install plus the devcontainer CLI via
  `bun install --global`).
- **Zed editor task.** `bin/zed.sh` (user-level, verified download).
- **GitHub CLI and SSH keygen.** `tools.sh` installs `gh` from its official
  apt repository; `ssh.sh` generates an `ed25519` key at `~/.ssh/github`
  when none exists.
- **Neovim devcontainer plugin.** `devcontainer-cli.nvim`, gated on the
  `terminal` profile; `:checkhealth dottod` reports the `devcontainer` CLI.
- **Installer hardening.** Download-then-run everywhere (oh-my-zsh, Ghostty,
  Zed, rustup); sha256 verification for GitHub release assets; tarball
  healing for Neovim also covers an installed-but-too-old binary.

### Changed

- **Terminal-first by default.** GUI tasks (`zed`, `ghostty`) are skipped
  unless `--ui` is passed (`--no-ui-support` retired for `--ui`/`--no-ui`).
- **Fonts are user-level and sudo-free** when prerequisites exist; the
  GNOME-wide font override is gone with the `desktop` task.

### Removed

- zsh + oh-my-zsh + spaceship + sysinfo collector; the `desktop` and
  `vscode` tasks; the Ratatui TUI (`bin/bootstrap.sh` is the only
  interface; releases ship the scripts tarball).
