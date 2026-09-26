---
Status: Draft
---

Reconstructed by project:introspec on 2026-09-26 from `39e4839`; retrofit
plan written 2026-09-26. **Requires user approval before step one.**

# dottod — retrofit plan (level: patch, scope: all modules)

Business behavior is frozen: the same inputs produce the same workstation
after each step, proven by the suites below. Anything needing more than
patch is marked MINOR and needs escalation (skill rule).

## Baseline (recorded 2026-09-26, working tree = `39e4839` + 3 dirty files)

Dirty (user's prompt rework — never touched by this retrofit):
`config/.custom.zshrc`, `docs/system-info.md`, `scripts/system-info.sh`.

| Check | Result | Evidence |
|-------|--------|----------|
| `cargo build` (tui/) | OK | run output, rc 0 |
| `cargo test` | 7/7 pass | run output |
| `./tests/run.sh` | 7/7 suites green (final) | run output |
| headless nvim battery (all profiles) | 0 failures | `scripts/nvim-headless-check.sh` |
| SBOM | `docs/product/sbom.cdx.json` (112 crates + 15 nvim pins) | hand-built, method noted |
| Load smoke | N/A — no load targets exist | — |
| Devcontainer image digest | N/A — no docker daemon here | — |

One flake observed (then green twice): `test-neovim.bats#10` failed once
under `run.sh` ("tarball did not yield nvim"), passes standalone —
suspected bash hash-table race in PATH stubs, recorded, not investigated
(see `docs/product/introspec.md`).

**Characterization net (no new tests):** the existing suites already pin
the critical paths — container resolution matrix, ssh merge matrix,
sysinfo collect/format/cache, nvim version gates + backup/idempotency,
headless config load, TUI registry parity. Coverage is hermetic +
integration-grade; nothing material is untested at patch scope.

## CVE table (`cargo audit`, RustSec DB 2026-09-26; no scanner for
nvim pins/shell — manual review)

| ID | Package (locked) | Severity | Reachable? | Disposition |
|----|-----------------|----------|------------|-------------|
| RUSTSEC-2024-0436 | paste 1.0.15 (via ratatui `stylize.rs` `paste!`, compile-time only) | warning (unmaintained) | No (build-time macro; latest == locked, no fix exists) | **Not affected** |
| RUSTSEC-2026-0253 | lru 0.12.5 (via ratatui layout cache) | warning (unsound `pop()`) | No (ratatui calls only `get_or_insert`+`resize`; `layout.rs:655`) | **Not affected** |
| RUSTSEC-2026-0002 | lru 0.12.5 (same) | warning (unsound `IterMut`) | No (never called on the cache) | **Not affected** |

Zero hard vulnerabilities. Fixes (`>= 0.16.3` / `>= 0.18.2`) leave the
0.12 line ratatui 0.29 requires — out of patch scope regardless.

## EOL table (endoflife.date, 2026-09-26)

| Component | Status | Support until | Action |
|-----------|--------|---------------|--------|
| Debian 13 trixie (target) | supported | 2030-06-30 (LTS) | none |
| Rust toolchain (host 1.98, latest) | rolling, current | n/a | none |
| Devcontainer image `rust-1.89-debian` | **drift**: image predates host toolchain | n/a | none at patch (tag bump is minor; recorded) |
| Neovim floor 0.11 / default v0.12.5 (== latest) | current | rolling | none |
| BATS 1.14 / zsh / bash 5.2 | test+runtime, fine | n/a | none |

## Outdated (patch-allowed only)

| Package | Locked | Newest in-range | Takes |
|---------|--------|-----------------|-------|
| clap | 4.6.6 | 4.6.7 | `cargo update` |
| transitive set | (lockfile) | patch drift | `cargo update` |
| nvim pins (7/8 behind HEAD) | lockfile | `:Lazy update` | headless sync + battery |

Out of patch scope (recorded, not attempted): ratatui 0.30.2,
crossterm 0.29.0, lru ≥0.16.3, nerd-fonts default v3.4.0→v3.5.1,
omz floating master, devcontainer rust-1.89→1.98 tag.

## Ordered steps

### Step 1 (patch): cargo lockfile refresh
- Change: `cargo update` in `tui/` (expect clap 4.6.7 + transitive patches).
- Risk: low (semver-compatible by definition).
- Verify: `cargo build`, `cargo test`, `./tests/run.sh`.
- Rollback: `git checkout tui/Cargo.lock`.
- Branch: `chore/retrofit-cargo-lock` off the retrofit working branch.

### Step 2 (patch): lazy-lock pin refresh
- Change: headless `:Lazy sync` (expect plugin code drift on ~7 pins).
- Risk: medium (plugin code changes behavior surface) — verified by the
  headless battery + both neovim BATS suites before/after.
- Verify: battery 0 failures, `bats tests/test-neovim*.bats`, startup time
  within baseline range.
- Rollback: `:Lazy restore` / `git checkout config/nvim/lazy-lock.json`.
- Branch: `chore/retrofit-nvim-pins` off the updated parent.

### Steps 3–5 (MINOR — escalation required, behavior-preserving)
Same software installed, new fetch path (download → verify → run):
3. oh-my-zsh installer (`bin/shell.sh:38`): replace pipe-to-shell with
   pinned download + TLS + tag pin.
4. ghostty-ubuntu installer (`bin/ghostty.sh:22`): same treatment.
5. `tools.sh` GitHub installs: sha256 verification via release-API
   digest (pattern already proven in `bin/neovim.sh:133`).
- Verify each: relevant BATS suite + targeted Docker bootstrap run
  (shell/tools), exactly as done for the sudo fix.
- Rollback per step: revert the one script.
- Branches: `chore/retrofit-omz-installer`, `chore/retrofit-ghostty-installer`,
  `chore/retrofit-tools-checksums`.

### Explicitly not attempted
vim-plug/fonts hardening (no checksum source exists — accepted risk);
base-image digest (no docker here); nerd-fonts default bump (behavior
change, no CVE); paste/lru (not-affected); EOL items (all fine).

## Results (recorded on merge)

| Step | Before → after | Verify |
|------|---------------|--------|
| 1. cargo lockfile | 12 patch bumps (clap 4.6.6→4.6.7, mio, syn, smallvec, …) | build OK, cargo 7/7, suites 7/7 |
| 2. lazy-lock pins | 15 pins verified current, zero diff | battery 0 failures, startup 25 ms |
| 3. omz installer | pipe-to-shell → download-then-run | fresh container install PASS, interactive zsh OK |
| 4. ghostty installer | pipe-to-priv-shell → download-then-run + explicit failures | stub positive+negative runs, shellcheck clean |
| 5. tools checksums | unverified → API-digest verify w/ warn fallback | real lazydocker install verified, shellcheck clean |

CVEs: 0 new (same 3 not-affected warnings). Suites: 7/7 green at every
merge. No characterization test was edited to hide a change.

## Rollback / merge discipline
Per `git:workflow`: working branch off `dev`, one flat-suffix branch per
step, merge back immediately when green (`--ff-only` <4 commits), delete
the context branch. No commit/merge/push without a fresh ask. The three
dirty user files are never staged.
