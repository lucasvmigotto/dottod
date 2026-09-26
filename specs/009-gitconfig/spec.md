# 009 — git identity (gitconfig)

## Stories
- US1: As a user I run the gitconfig task so that `user.name` /
  `user.email` are set (from env, existing config, or one prompt).
- US2: As a CI/automation user I set `GIT_NAME`/`GIT_EMAIL` so that the
  task never prompts.

## Acceptance scenarios
- Given `GIT_NAME`/`GIT_EMAIL` set, when the task runs, then it writes
  non-interactively [OBSERVED: README.md:184, bin/gitconfig.sh:11].
- Given existing global identity, when the task runs, then it reuses it
  [OBSERVED: bin/gitconfig.sh:11].
- Given neither, when run on a TTY, then it prompts once; otherwise it
  fails loudly instead of hanging [OBSERVED: bin/gitconfig.sh:18].

## Status
Bash: Implemented. TUI: Implemented (identity overlay feeds env)
[OBSERVED: tui/src/main.rs:150, tui/src/ui.rs:110]. Verified: no.
