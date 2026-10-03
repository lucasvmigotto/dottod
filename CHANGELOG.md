# Changelog

Releases are plain SemVer git tags (`1.0.0`). This file is maintained by
`scripts/release.py`: a `## Unreleased` section below is renamed to the new
version on release (hand-written notes win); otherwise the section is
generated from Conventional Commits since the last tag.

## Unreleased

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
