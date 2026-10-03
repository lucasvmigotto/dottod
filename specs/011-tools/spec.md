# 011 — cli tools (lazygit/lazydocker/k9s/btop/…/fzf/gh)

## Stories
- US1: As a user I run the tools task so that the terminal toolbox
  installs: lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip,
  chafa, fzf (all apt) plus `gh` (official GitHub CLI apt repo).

## Acceptance scenarios
- Given a tool already on PATH (or `~/.local/bin`), when the task runs,
  then it skips [OBSERVED: bin/tools.sh:16].
- Given a tool missing, when the task runs, then the GitHub release
  asset matching the arch pattern downloads and installs to
  `~/.local/bin` [OBSERVED: bin/tools.sh:22,54].
- Given an archive without the binary, when installing, then loud error,
  temp cleanup [OBSERVED: bin/tools.sh:57].

## Status
Implemented. Verified: no.
