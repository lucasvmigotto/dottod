# 011 — cli tools (apt baseline + opt-in extras)

## Stories
- US1: As a user I run the tools task so that the terminal baseline
  installs from apt: btop, bat, xclip, jq, curl, tar, ca-certificates,
  lsof, fzf, shellcheck, bats, shfmt, just.
- US2: As a user I opt in to extras with `--extras <list>` (or
  `DOT_TOOLS_EXTRA`, `all` for every one): gh, httpie, chafa (native
  packages; gh from the official GitHub CLI apt repo on Debian/Ubuntu).
  None install by default.

## Acceptance scenarios
- Given no `DOT_TOOLS_EXTRA`, when the task runs, then only the apt
  baseline installs.
- Given an unknown extra name, when the task runs, then loud error
  before any install.
- Given a tool already on PATH (or `~/.local/bin`), when the task runs,
  then it skips.

- Given Debian (batcat, fdfind), when the task runs, then `bat` and `fd`
  also resolve; elsewhere `batcat`/`fdfind` resolve too.

## Status
Implemented. Verified: no.
