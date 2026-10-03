# Spec index

Reconstructed by project:introspec on 2026-09-26 from `39e4839`.
Spec Kit is not bootstrapped in this repo (no `.specify/`); the layout
below follows the pipeline's Spec Kit structure so `project:spec` can
adopt it unchanged. No `tasks.md` files — nothing is planned yet.

Terminal-first revision 2026-10-03: plain-bash shell (zsh/omz/spaceship
removed), desktop and vscode tasks removed, zed added, TUI removed
(`bin/bootstrap.sh` is the only interface).

| # | Feature | Priority | Depends on | Status |
|---|---------|----------|------------|--------|
| 001 | shell (plain bash + prompt) | P0 | — | Implemented |
| 002 | fonts (Nerd Fonts, user-level) | P1 | — | Implemented |
| 003 | vim (vim-plug) | P1 | — | Implemented |
| 004 | neovim (version-gated lazy.nvim config) | P0 | — | Implemented |
| 005 | container runtime (Podman/Docker) | P0 | — | Implemented |
| 007 | zed (user-level editor) | P2 | — | Implemented |
| 008 | ghostty (terminal) | P2 | — | Implemented |
| 009 | git identity (gitconfig) | P1 | — | Implemented |
| 010 | ssh config (GitHub merge + keygen) | P1 | — | Implemented |
| 011 | cli tools (lazygit/…/fzf/gh) | P1 | — | Implemented |
| 013 | cargo (rustup toolchain) | P1 | — | Implemented |
| 014 | bun (JS runtime + devcontainer CLI) | P1 | — | Implemented |

Removed: 006 desktop (GNOME settings), 007 vscode (replaced by zed),
012 interactive runner (TUI; `bootstrap.sh` is the only interface).

Status meanings (pipeline rule 6): **Implemented** = code path exists and
runs (hermetic suites pass; "no e2e" where true). **Verified** = passing
cross-stack e2e — none claimed: `tests/integration/` needs an engine +
network and did not run here; the Neovim headless battery runs real nvim
against the real config but is classed as integration, not cross-stack
e2e. See `docs/product/introspec.md` for the evidence ledger.
