# Spec index

Reconstructed by project:introspec on 2026-09-26 from `39e4839`.
Spec Kit is not bootstrapped in this repo (no `.specify/`); the layout
below follows the pipeline's Spec Kit structure so `project:spec` can
adopt it unchanged. No `tasks.md` files — nothing is planned yet.

| # | Feature | Priority | Depends on | Bash status | TUI status |
|---|---------|----------|------------|-------------|------------|
| 001 | shell (zsh + prompt + sysinfo) | P0 | — | Implemented | Implemented |
| 002 | fonts (Nerd Fonts) | P1 | — | Implemented | Implemented |
| 003 | vim (vim-plug) | P1 | — | Implemented | Implemented |
| 004 | neovim (version-gated lazy.nvim config) | P0 | — | Implemented | Implemented |
| 005 | container runtime (Podman/Docker) | P0 | — | Implemented | Implemented |
| 006 | desktop (GNOME) | P2 | — | Implemented | Implemented |
| 007 | vscode (MS repo) | P2 | — | Implemented | Implemented |
| 008 | ghostty (terminal) | P2 | — | Implemented | Implemented |
| 009 | git identity (gitconfig) | P1 | — | Implemented | Implemented |
| 010 | ssh config (GitHub merge) | P1 | — | Implemented | Implemented |
| 011 | cli tools (lazygit/…/bat) | P1 | — | Implemented | Implemented |
| 012 | interactive runner (TUI) | P1 | all above | Implemented | Implemented |

Status meanings (pipeline rule 6): **Implemented** = code path exists and
runs (hermetic suites pass; "no e2e" where true). **Verified** = passing
cross-stack e2e — none claimed: `tests/integration/` needs an engine +
network and did not run here; the Neovim headless battery runs real nvim
against the real config but is classed as integration, not cross-stack
e2e. See `docs/product/introspec.md` for the evidence ledger.
