# 010-ssh — as-is technical context

- Entry: `bin/ssh.sh` (`_merge_github_config <target> <template>`;
  `_github_wanted_options` parses the template)
  [OBSERVED: tests/test-ssh-merge.bats:22].
- Template: `config/.ssh.config` (6 options: HostName, User,
  IdentityFile, IdentitiesOnly, AddKeysToAgent, LogLevel)
  [OBSERVED: tests/test-ssh-merge.bats:28].
- Merge is awk-driven, case-insensitive host match, never overwrites
  user values [OBSERVED: bin/ssh.sh:45].
- Env: `_DOT_SSH_DIR` (default `/home/<user>/.ssh`)
  [OBSERVED: bin/ssh.sh:29, tests/test-ssh-merge.bats:14].
- Tests: `tests/test-ssh-merge.bats` (16 tests incl. `ssh -G` validation).
