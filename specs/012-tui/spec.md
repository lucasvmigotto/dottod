# 012 — interactive runner (TUI)

## Stories
- US1: As a user I run `dottod` so that I can toggle tasks, pick a
  container runtime, and run them with live logs — mirroring every
  `bootstrap.sh` flag.
- US2: As a user I enter git identity in the TUI so that `gitconfig`
  runs non-interactively.
- US3: As a user I press `r` after failures so that only failed tasks rerun.

## Acceptance scenarios
- Given the repo, when the TUI starts, then its task list/ids match
  `DOT_TASKS` exactly (order + ui flags), enforced by
  `registry_matches_bootstrap` [OBSERVED: tui/src/task.rs:124].
- Given `--only/--skip/--no-ui-support/--parallel/--runtime`, when run,
  then filtering matches bootstrap semantics (incl. `needs_apt`
  serialization: one apt task at a time, others capped at CPU count)
  [OBSERVED: tui/src/main.rs:64, tui/src/scheduler.rs:12].
- Given a non-root user without passwordless sudo, when the TUI starts,
  then it preflights privilege once before raw mode
  [OBSERVED: tui/src/main.rs:96].
- Given task output, when running, then stdout+stderr stream line-wise
  with `NO_COLOR=1` [OBSERVED: tui/src/runner.rs:29].
- Given exit, when state saves, then selection/results persist tolerant
  to corrupt state files [OBSERVED: tui/src/state.rs:28].
- Given keybindings (j/k/Space/a/n/u/e/Enter/Tab/PgUp/PgDn/r/q), when
  pressed, then the documented actions fire
  [OBSERVED: README.md:233].

## Status
Bash side: Implemented. TUI side: Implemented (7 Rust unit tests pass).
Verified: no (no cross-stack e2e; TUI needs a TTY).
