# 001-shell — as-is technical context

- Entry: `bin/shell.sh` (`_main`: apt → chsh → omz → plugins → spaceship → link).
- Sudo via `_priv`/`_sudo_preflight` (askpass caching, passwordless fast-path) [OBSERVED: bin/utils.sh:122].
- oh-my-zsh install is a piped remote script (`curl … | sh`-style via `sh -c "$(curl…)"`) [OBSERVED: bin/shell.sh:38] — supply-chain risk, see introspec.md.
- `config/.custom.zshrc` sets `$ZSH` explicitly (required: omz template normally does it) [OBSERVED: config/.custom.zshrc:21].
- Prompt sections: `spaceship_sysinfo` + `spaceship_container` + `exec_time` reorder, idempotent registration [OBSERVED: scripts/.sysinfo.prompt.sh:117,136,166].
- Collector `scripts/system-info.sh`: bash, no `set -e`, zsh-source guard, atomic cache writes, TTL 2s [OBSERVED: scripts/system-info.sh:18,37,99].
- Tests: `tests/test-system-info.bats` (11 tests), `tests/test-spaceship-sysinfo.zsh` (20), `tests/test-container.zsh` (22/25 incl. prompt section).
