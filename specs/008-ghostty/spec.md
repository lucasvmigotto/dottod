# 008 — ghostty (terminal)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only ghostty` so that
  Ghostty installs and becomes the default terminal.

## Acceptance scenarios
- Given `ghostty` absent, when the task runs, then the
  `ghostty-ubuntu` installer runs under privilege and Ghostty becomes
  default [OBSERVED: bin/ghostty.sh:22].
- Given `ghostty` present, when the task runs, then install skips and
  default-setting still applies [OBSERVED: bin/ghostty.sh:15].

## Status
Implemented (`ui_group: true`, skipped without `--ui`). Verified: no.
