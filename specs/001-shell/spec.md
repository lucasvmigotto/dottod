# 001 — shell (zsh + prompt + sysinfo)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only shell` so that zsh +
  oh-my-zsh + spaceship prompt are installed and `~/.zshrc` is linked.
- US2: As a user I see CPU/RAM/net metrics in my prompt (sysinfo segment)
  without the prompt ever breaking my shell startup.

## Acceptance scenarios
- Given zsh missing, when the task runs, then `zsh`, `git`, `curl`,
  `ca-certificates` are apt-installed and zsh becomes the login shell
  [OBSERVED: bin/shell.sh:110, tests: green run.sh].
- Given `~/.oh-my-zsh` absent, when the task runs, then oh-my-zsh
  installs unattended, `zsh-autosuggestions` + `zsh-syntax-highlighting`
  clone, spaceship theme links
  [OBSERVED: bin/shell.sh:38,67,89].
- Given any `scripts/*.sh` sourced by zsh, when `.zshrc` loads, then no
  battery runs, no options leak, the shell survives
  [OBSERVED: tests/test-neovim.bats:283, scripts/nvim-headless-check.sh:11].
- Given a corrupt sysinfo cache, when the prompt renders, then metrics
  are recollected and the shell keeps working
  [OBSERVED: tests/test-system-info.bats:160].

## Status
Bash: Implemented. TUI: Implemented. Verified: no (no cross-stack e2e).
