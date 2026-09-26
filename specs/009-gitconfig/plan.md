# 009-gitconfig — as-is technical context

- Entry: `bin/gitconfig.sh` (env → existing global config → TTY prompt;
  refuses to proceed with empty values) [OBSERVED: bin/gitconfig.sh:11].
- Env: `GIT_NAME`, `GIT_EMAIL` (also read by the TUI identity overlay)
  [OBSERVED: bin/gitconfig.sh, tui/src/main.rs:150].
- TUI passes identity through task env; `needs_apt: false` (no packages)
  [OBSERVED: tui/src/task.rs:51].
- Writes `~/.gitconfig` (template/merge semantics per `_link_file`-style
  backup) [OBSERVED: bin/gitconfig.sh:28].
- No dedicated BATS suite.
