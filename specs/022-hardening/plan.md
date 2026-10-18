# 022-hardening — technical plan

## Evidence (2026-10-18, Debian 13 dev host, bash 5.2)

| Finding | Measurement / incident |
|---|---|
| Prompt cost per render, in this repo (6 renders after a warm-up) | robbyrussell 11–14 ms; pastel 54–78 ms; powerline 81–90 ms |
| Shell startup (`source config/.custom.bashrc`) | 77–89 ms — acceptable, not in scope |
| mawk counts bytes | `codes` status column misaligned (fixed in 2.5.0 by hand) |
| Byte-range regex `[\200-\277]` | invalid in BusyBox awk and in gawk under UTF-8 |
| Env leak into tests | `CLAUDE_CONFIG_DIR` from the running session made test-codes read the real store; `tests/helpers.bash` clears nothing |
| Timing flake | test-prompt-themes expected `took 7s`, got 8s on a second tick (fixed in 2.4.0) |
| `tests/run.sh` without bats on PATH | "30 run, 30 failed" on the dev host (bats only via bunx) |
| justfile file lists | three hand lists (`bashn_files`, `lint_files`, `fmt_files`); every new script needs three edits |
| claude-mv backups | full copies of transcript folders, never pruned |
| `scripts/.claude.sh` | 888 lines: profiles, wrapper, picker panel, usage, consolidate |
| `pdd` | only stubbed (lsblk/sudo/dd); never wrote a real device |
| Release race | another session released 2.6.0 while this one worked on `develop` |

## Approach per phase

**P1 hermetic tests and tooling.** `tests/helpers.bash` gets a
`dottod_test_env` function called on load: unset `CLAUDE_*`, `CODES_*`,
`DOT_*` (keeping test-set ones is each suite's job), `XDG_*_HOME`,
`PROMPT_COMMAND`, `PS0`; set `LC_ALL=C.UTF-8` when available. A canary
test exports poison values and proves a suite's setup does not see them.
`tests/run.sh` resolves bats as `bats`, else `bunx bats@1.11.1`, else a
clear error. The justfile computes its lists from globs plus an explicit
exclusion list (kept where a file is not bash, e.g. `scripts/release.py`).
An audit replaces timing-sensitive assertions with ranges or injected
clocks.

**P2 prompt speed.** A benchmark (`tests/bench/prompt.sh`: median of N
renders per style, in a fixture repo) gives before/after numbers; it is
not a gate, its output is recorded here. Then, in `styles/promptlib.sh`
and `styles/segments.sh`:
- one `git status --porcelain=v2 --branch` per prompt, parsed in bash,
  replacing separate branch/dirty/ahead-behind calls;
- per-PWD memo of project root, stack and OS id (recomputed on `cd`);
- no `$(...)` in the hot path: helpers write to variables (`printf -v`).
A test stubs `git` and asserts at most one invocation per render.
Target: segmented median < 25 ms; robbyrussell unchanged or faster.

**P3 userland matrix.** `tests/integration/userland.sh <image>` runs the
bats suite in a container: Alpine 3.22 (bash + BusyBox userland, bats
from apk) and Debian 13 slim (mawk default), both pinned by digest like
`distros.sh`. A `userland` job in `shell.yml` runs both. Failures that
surface are fixed in the same phase.

**P4 Claude Code guard.** `__dottod_claude_compat [store] [config]`
checks the assumptions, each `ok`/`warn` with the Claude Code version:
projects folder names follow the key rule for at least one transcript
`cwd`; transcript lines carry `"cwd":"…"` in compact JSON;
`.claude.json` has a `projects` object; `cachedUsageUtilization` has
`five_hour`/`seven_day`. `dottod-doctor` prints them; `claude-mv` runs the
folder and line checks first and refuses on a failure unless `--force`.
Fixture stores cover the current layout and plausible changes (hashed
keys, a renamed field, pretty-printed lines).

**P5 claude-mv retention; split `.claude.sh`.** After a successful run,
`claude-mv` keeps the newest `CLAUDE_MV_KEEP` (5) backup dirs. The split
moves code without changing it: `.claude.sh` (profiles, overlay, wrapper),
`.claude-panel.sh` (bar/until/ago/info, picker), `.claude-usage.sh`
(stale/refresh/spawn, `claude-profile usage` body). Function names stay;
the export-list test and the stub-fzf test prove the picker still works.

**P6 pdd on a loop device.** `tests/integration/pdd-loop.sh`
(`DOTTOD_TEST_INTEGRATION=1`, needs sudo): a 16 MiB file attached with
`losetup`, `pdd` of a plain and an `.xz` image (answer piped), `cmp`
against the device; a mounted loop device is refused. Runs in CI on the
Ubuntu runner.

**P7 release guard.** `scripts/promote.sh` (and `just promote`): refuses
unless `develop` contains `origin/main`, the working tree is clean and
every workflow run for `develop`'s HEAD succeeded; then pushes
`develop:main`, waits for the release run, fast-forwards `develop` to
the release commit and pushes it. README gains a "Releasing" section.

## Phase 2 result (prompt speed)

`tests/bench/prompt.sh` — median of 31 renders in-process, fixture repo with
a `package.json`, one untracked file, no containers:

| style | before | after |
|---|---|---|
| robbyrussell | 5.2 ms | 2.8 ms |
| kali | 19.8 ms | 2.5 ms |
| powerline | 73.0 ms | 3.9 ms |
| pastel / tokyonight / gruvbox / catppuccin | 47–49 ms | 3.1–3.5 ms |

How: the repo root and gitdir come from a walk up to `.git` (no process);
one `git status --porcelain=v2 --branch` per render (none with
`dottod.hide-dirty`, read from the repo config file); every helper in the
hot path leaves its result in `REPLY` instead of a `$(...)` subshell; the
free-disk readout is remembered for 30 s. Known difference: a dirty
submodule no longer marks the segmented prompts (`--ignore-submodules=dirty`,
as the default style always did). `tests/test-prompt-perf.bats` pins the
≤ 1 git call per render.

## Phase 3 result (userland matrix)

`tests/integration/userland.sh [alpine|debian]` runs all bats suites as an
unprivileged user with a UTF-8 locale on the pinned Alpine 3.22 (BusyBox
awk/sed/date/mktemp/realpath) and Debian trixie (mawk) images; the
`userland` job in `shell.yml` runs both. First run: 20 failures on Alpine,
15 on Debian (mostly the harness: root, no locale, no python3). What was
left were real BusyBox bugs, each fixed with a regression test:

- `claude-mv`: `realpath -m` → a pure-bash fallback (it refused every path).
- `bin/ssh.sh`: `readlink -m` → `_ssh_resolve_link` (SSH config merge died).
- `claude` usage panel: `date -d <ISO>` → `__dottod_claude_epoch` parses
  ISO-8601 in bash (reset stamps printed raw).
- `dottod-fetch.sh`: `mktemp …XXXXXX.jsonc` → a temp directory (the card
  never drew).
- Tests that assumed GNU `date -d '+35 minutes'`, `touch -d`, `/usr/bin/bash`
  or a glibc host now use epoch arithmetic and `command -v bash`.
