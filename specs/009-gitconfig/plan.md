# 009-gitconfig — as-is technical context

- Entry: `bin/gitconfig.sh` (env → existing global config → TTY prompt;
  refuses to proceed with empty values) [OBSERVED: bin/gitconfig.sh:11].
- Env: `GIT_NAME`, `GIT_EMAIL` [OBSERVED: bin/gitconfig.sh].
- No package installs (`needs_apt: false`).
- Writes `~/.gitconfig` (template/merge semantics per `_link_file`-style
  backup) [OBSERVED: bin/gitconfig.sh:28].
- No dedicated BATS suite.
