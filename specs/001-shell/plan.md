# 001-shell — as-is technical context

- Entry: `bin/shell.sh` (`_main`: apt → chsh-to-bash → link bashrc).
- Sudo via `_priv`/`_sudo_preflight` (askpass caching, passwordless fast-path) [OBSERVED: bin/utils.sh:122].
- `config/.custom.bashrc`: exit-aware `➜` prompt via `PROMPT_COMMAND`
  (`__dottod_prompt`), git branch/dirty segment (`__dottod_git_info`,
  per-repo opt-out via `git config dottod.hide-dirty 1`), history tuning,
  ls/grep colors, git + navigation aliases, utility functions
  (`mkcd`, `extract`, `ff`, `gr`, `psg`, `port`, `serve`, `gcl`, …).
  Interactive-shell guard up front; `cd` failures `return` (never `exit`).
- Removed 2026-10: zsh + oh-my-zsh + spaceship + sysinfo collector
  (terminal stalls; heavy prompt stack). Deleted:
  `config/.custom.zshrc`, `scripts/.sysinfo.prompt.sh`,
  `scripts/system-info.sh`, `docs/system-info.md`,
  `tests/test-spaceship-sysinfo.zsh`, `tests/test-container.zsh`,
  `tests/test-system-info.bats`.
- Tests: `tests/test-shell.bats` (6 tests: remnants, syntax, interactive
  PS1, login-shell skip, link args, link backup/no-op).
