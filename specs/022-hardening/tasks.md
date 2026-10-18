# 022-hardening — tasks

One branch per phase off `develop`; gate per commit: bats green,
ShellCheck (`-S warning`) and shfmt clean, site checks when docs change.

## Phase 1 — hermetic tests and tooling (`fix/test-harness`)
- [x] T180 [US3] `tests/helpers.bash`: clear `CLAUDE_*`, `CODES_*`, `DOT_*`,
  `XDG_*_HOME`, `PROMPT_COMMAND`, `PS0` for every suite; a canary test
  proves poisoned outer values never reach a test.
- [x] T181 [US5] `tests/run.sh`: bats, else `bunx bats@1.11.1`, else a clear
  error; summary unchanged.
- [x] T182 [US5] justfile: lint/format/syntax lists from globs plus explicit
  exclusions; a test proves every `scripts/.*.sh` and `styles/*.sh` is
  covered.
- [x] T183 [US3] Audit timing-sensitive assertions (SECONDS, date, sleep) and
  Audit: the remaining `sleep`s only cross an mtime boundary; the duration
  assertion is already tolerant (`took [78]s`). Nothing else is clock-bound.
  make them tolerant or clock-injected.

## Phase 2 — prompt speed (`perf/prompt`)
- [x] T184 [US1] `tests/bench/prompt.sh`: median render time per style in a
  fixture repo; baseline recorded in plan.md.
- [x] T185 [US1] One `git status --porcelain=v2 --branch` per prompt, parsed in
  bash, shared by every style.
- [x] T186 [US1] Per-PWD memo of project root, stack and OS id; no `$(...)` in
  the render path.
- [x] T187 [US1] Test: a stub git proves ≤ 1 git invocation per render; bench
  after: segmented median < 25 ms, robbyrussell not slower.

## Phase 3 — userland matrix (`ci/userland`)
- [x] T188 [US2] `tests/integration/userland.sh <image>`: the bats suite inside
  Alpine 3.22 (BusyBox) and Debian 13 slim (mawk), images pinned by digest.
- [x] T189 [US2] `userland` job in `shell.yml` running both.
- [x] T190 [US2] Fix every failure it surfaces (each with a regression test).

## Phase 4 — Claude Code guard (`feat/claude-compat`)
- [x] T191 [US4] `__dottod_claude_compat`: key rule, compact `cwd` lines,
  `.claude.json` projects, usage cache shape — ok/warn with the version.
- [x] T192 [US4] `dottod-doctor` section "claude internals".
- [x] T193 [US4] `claude-mv` runs the store checks first; refuses on a failure
  unless `--force`.
- [x] T194 [US4] Fixture stores: current layout passes; hashed keys, renamed
  `cwd`, pretty-printed lines each warn.

## Phase 5 — claude-mv retention; split `.claude.sh` (`refactor/claude`)
- [ ] T195 [US6] `claude-mv` keeps the newest `CLAUDE_MV_KEEP` (5) backups.
- [ ] T196 [US7] Split into `.claude.sh`, `.claude-panel.sh`, `.claude-usage.sh`
  with unchanged function names and behavior.
- [ ] T197 [US7] Full suite green with no test edits beyond file paths.

## Phase 6 — pdd on a real block device (`ci/pdd-loop`)
- [ ] T198 [US8] `tests/integration/pdd-loop.sh`: loop device, plain and `.xz`
  images written and compared, mounted device refused.
- [ ] T199 [US8] CI job on the Ubuntu runner (sudo, losetup).

## Phase 7 — release guard (`feat/promote`)
- [ ] T200 [US9] `scripts/promote.sh` / `just promote`: refuses unless develop
  contains origin/main, the tree is clean and develop's runs are green;
  promotes, waits for the release, fast-forwards develop.
- [ ] T201 [US9] README "Releasing" section.

## Open milestone (not scheduled)
- [ ] T202 G2: full bootstrap on a real Gentoo laptop (rootless Podman
  under OpenRC) — needs the hardware.
