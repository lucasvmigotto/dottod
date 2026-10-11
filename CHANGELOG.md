# Changelog

Releases are plain SemVer git tags (`1.0.0`). This file is maintained by
`scripts/release.py`: a `## Unreleased` section below is renamed to the new
version on release (hand-written notes win); otherwise the section is
generated from Conventional Commits since the last tag.

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
