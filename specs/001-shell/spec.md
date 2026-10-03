# 001 — shell (plain bash)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only shell` so that bash is
  ensured as my login shell and `~/.bashrc` links to the dottod customization.
- US2: As a user I get a lightweight exit-aware prompt with git context
  and handy aliases/functions, with no plugins or frameworks to stall my
  terminal.

## Acceptance scenarios
- Given bash not the login shell, when the task runs, then `chsh -s`
  switches it (via `_priv`); given already bash, when the task runs,
  then it skips [OBSERVED: bin/shell.sh `_bash_use_as_shell`,
  tests/test-shell.bats].
- Given `~/.bashrc` exists, when the task runs, then it is backed up
  (`_link_file`) and replaced by the symlink; reruns are no-ops
  [OBSERVED: bin/shell.sh `_custom_bashrc`, tests/test-shell.bats].
- Given the linked bashrc, when an interactive shell sources it, then
  PS1 renders the arrow prompt and no error surfaces
  [OBSERVED: tests/test-shell.bats].
- Given the repo, when searched, then no zsh/oh-my-zsh/spaceship/sysinfo
  remnants exist in the shell task or bashrc
  [OBSERVED: tests/test-shell.bats].

## Status
Implemented. Verified: no (no cross-stack e2e).
