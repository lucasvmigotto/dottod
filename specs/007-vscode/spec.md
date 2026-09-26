# 007 — vscode (Microsoft apt repo)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only vscode` so that VSCode
  installs from the signed Microsoft apt repository.

## Acceptance scenarios
- Given `code` absent, when the task runs, then the MS GPG key + signed
  source list install, then `code` apt-installs
  [OBSERVED: bin/vscode.sh:20].
- Given `code` present, when the task runs, then it skips
  [OBSERVED: bin/vscode.sh:8].

## Status
Bash: Implemented. TUI: Implemented (`ui: true`). Verified: no.
