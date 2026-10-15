# 011 — cli tools (apt baseline + opt-in extras)

## Stories
- US1: As a user I run the tools task so that the terminal baseline
  installs from apt: btop, bat, xclip, jq, curl, tar, ca-certificates,
  lsof, fzf, shellcheck, bats, shfmt, just.
- US2: As a user I opt in to extras with `--extras <list>` (or
  `DOT_TOOLS_EXTRA`, `all` for every one): gh (official GitHub CLI apt
  repo), lazygit, lazydocker, k9s, resterm (GitHub releases), httpie,
  chafa (apt). None install by default.

## Acceptance scenarios
- Given no `DOT_TOOLS_EXTRA`, when the task runs, then only the apt
  baseline installs.
- Given an unknown extra name, when the task runs, then loud error
  before any install.
- Given a tool already on PATH (or `~/.local/bin`), when the task runs,
  then it skips.
- Given a tool missing, when the task runs, then the GitHub release
  asset matching the arch pattern downloads and installs to
  `~/.local/bin`.
- Given an archive without the binary, when installing, then loud error,
  temp cleanup.

## Status
Implemented. Verified: no.
