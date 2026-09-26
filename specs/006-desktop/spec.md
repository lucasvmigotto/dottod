# 006 — desktop (GNOME)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only desktop` so that the
  GNOME system monitor installs and dark theme + Nerd Font apply.

## Acceptance scenarios
- Given GNOME present, when the task runs, then system monitor installs
  and theme/fonts apply; given headless/CI, when the task runs, then it
  degrades without failing the bootstrap
  [INFERRED: UI-task grouping + `--no-ui-support` skip; confirm with a
  headless run].

## Status
Bash: Implemented. TUI: Implemented (`ui: true`). Verified: no.
