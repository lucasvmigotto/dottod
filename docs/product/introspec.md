---
Status: Draft
---

Reconstructed by project:introspec on 2026-09-26 from `39e4839`.

# dottod — introspection evidence report

## Scope and boundaries (agreed 2026-09-26)
- Target: `dottod` repo, whole scope (12 bootstrap tasks + TUI + Neovim
  config + tests + docs + CI).
- Ran with approval: `cargo build`, `cargo test`, `./tests/run.sh`
  (incl. headless nvim battery). Evidence logs (local-only, not
  committed): `/tmp/opencode/introspec-tests.log`,
  `/tmp/opencode/introspec-cargo.log`.
- No database exists or is involved — db steps N/A, no data rows anywhere.
- No HTTP API exists — the contract is `contracts/tasks.yaml`
  (CLI/task seam), not OpenAPI.

## Inventory
- 14 bash task scripts (`bin/`, incl. shared `bin/utils.sh`), 15 Neovim
  Lua files (5 plugin specs), 7 Rust files (`tui/src/`), 4 workflows,
  4 feature docs, 7 test suites (5 BATS + 2 zsh), 2 gated integration
  scripts. Languages: bash 26 files, Lua 14, Rust 7, Markdown 5+.
- Manifests: `tui/Cargo.toml`/`Cargo.lock` (112 crates), 
...[truncated 4471 chars]