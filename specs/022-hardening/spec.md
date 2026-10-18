# 022 — hardening: prompt speed, userland coverage, Claude Code guard

Decided 2026-10-18, from the project review after 2.8.0. Each item comes
from something measured or hit in practice; the evidence is in plan.md.

## User scenarios

### User Story 1 - Fast segmented prompts (Priority: P1)

As a user of a segmented theme (pastel, tokyonight, gruvbox, catppuccin,
powerline), the prompt renders about as fast as a plain one.

**Acceptance**: in a git repository, the median render is under 25 ms for
every segmented style (today pastel ~70 ms, powerline ~85 ms), and
robbyrussell (~12 ms) is not slower; at most one `git` call per render.

### User Story 2 - Userland coverage in CI (Priority: P1)

As a maintainer, the bats suite runs on BusyBox (Alpine) and mawk (Debian)
in CI, so userland differences — awk byte counting, regex locales,
`du -b`, `stat` — fail a build instead of reaching a user.

**Acceptance**: a `userland` CI job runs the whole suite in both images,
pinned by digest, and passes on `develop`.

### User Story 3 - Hermetic tests (Priority: P1)

As a maintainer, no suite can read my real environment, and no test
depends on wall-clock timing.

**Acceptance**: with poisoned `CLAUDE_*`, `CODES_*`, `DOT_*`, `XDG_*`
and prompt variables exported, the suite passes and a canary test proves
none reached a test; timing assertions tolerate a clock tick.

### User Story 4 - Claude Code guard (Priority: P2)

As a user, `dottod-doctor` tells me whether the Claude Code internals
dottod relies on still hold, and `claude-mv` refuses to rewrite a store
it no longer recognizes.

**Acceptance**: the current layout reports ok; fixture stores with hashed
folder names, a renamed `cwd` field or pretty-printed lines each warn,
and `claude-mv` refuses them unless `--force`.

### User Story 5 - Tooling without hand lists (Priority: P2)

As a maintainer, new scripts are linted and formatted without editing
file lists, and `tests/run.sh` works where bats is only reachable
through bunx.

**Acceptance**: a test proves every `scripts/.*.sh` and `styles/*.sh` is
in the lint and format sets; `tests/run.sh` passes on a host without
bats on PATH.

### User Story 6 - claude-mv backup retention (Priority: P3)

As a user, claude-mv keeps only its newest backups.

**Acceptance**: after a successful run, only the newest `CLAUDE_MV_KEEP`
(default 5) backup directories remain.

### User Story 7 - Split the Claude script (Priority: P3)

As a maintainer, `scripts/.claude.sh` (888 lines) is split by concern
with no behavior change.

**Acceptance**: profiles/wrapper, panel/picker and usage live in separate
files; function names unchanged; the full suite passes without test
changes beyond file paths.

### User Story 8 - pdd on a real block device (Priority: P2)

As a maintainer, `pdd` is exercised end to end on a real (loop) block
device in CI.

**Acceptance**: plain and `.xz` images are written to a loop device and
match byte for byte; a mounted loop device is refused.

### User Story 9 - Release guard (Priority: P2)

As a maintainer, promoting to `main` refuses when `develop` does not
contain `origin/main`, the tree is dirty, or develop's CI is not green.

**Acceptance**: `just promote` refuses each of those cases and otherwise
promotes, waits for the release and fast-forwards `develop`.

## Out of scope
- G2 (real Gentoo laptop bootstrap) needs hardware; it stays an open
  milestone, tracked here only as a reminder.

## Acceptance
Each phase in tasks.md lists its own checks; the spec is Implemented when
every phase is merged with the gate green (bats, ShellCheck, shfmt, site)
and the new CI jobs pass on `develop`.
