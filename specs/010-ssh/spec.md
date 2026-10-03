# 010 — ssh config (GitHub host merge)

## Stories
- US1: As a user I run the ssh task so that the GitHub host block lands
  in `~/.ssh/config` without touching my other hosts.
- US2: As a user with a partial GitHub block I get only the missing keys
  added; conflicting values are never overwritten.

## Acceptance scenarios
- Given no `~/.ssh/config`, when the task runs, then the template
  installs verbatim, mode 600, no backup
  [OBSERVED: tests/test-ssh-merge.bats:36].
- Given unrelated hosts, when the task runs, then they are preserved and
  the GitHub block appends exactly once (second run byte-identical)
  [OBSERVED: tests/test-ssh-merge.bats:44].
- Given a complete block, when the task runs, then nothing changes, no
  backup [OBSERVED: tests/test-ssh-merge.bats:60].
- Given a partial block, when the task runs, then only missing keys are
  added [OBSERVED: tests/test-ssh-merge.bats:69].
- Given conflicting values, when the task runs, then user values win
  [OBSERVED: tests/test-ssh-merge.bats:78].
- Given the merged result, when parsed by OpenSSH, then `ssh -G` accepts
  it [OBSERVED: tests/test-ssh-merge.bats:15].

## Status
Implemented. Verified: no (hermetic BATS only).
