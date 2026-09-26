---
Status: Draft
---

Reconstructed by project:introspec on 2026-09-26 from `39e4839`.

# dottod — domain model (as implemented)

dottod has no database; its "domain" is **workstation state**. Bounded
context: a single Debian workstation (`$HOME` + system config).

## Entities (workstation state)

| Entity | Identity | Lifecycle |
|--------|----------|-----------|
| Task run | task id + timestamp (`/tmp/dottod/<task>.log`) | pending → running → passed/failed/skipped [OBSERVED: tui/src/state.rs:7] |
| Home symlink | target path (`~/.zshrc`, `~/.vimrc`, `~/.config/nvim`) | missing → linked; existing → backed up → linked [OBSERVED: bin/utils.sh:277] |
| Backup | `<target>.dottod.bak[.timestamp]` | created once; second conflict gets timestamp suffix [OBSERVED: bin/neovim.sh:271, tests/test-neovim.bats:233] |
| Prompt cache | `sysinfo.cache` + `sysinfo.state` in `${XDG_CACHE_HOME}/dottod/` | written atomically (mktemp+mv); corrupt → ignored [OBSERVED: scripts/system-info.sh:99, docs/system-info.md:51] |
| Plugin lock | `config/nvim/lazy-lock.json` (committed) | `:Lazy update` rewrites; `:Lazy restore` rolls back [OBSERVED: docs/neovim.md:111] |
| TUI state | `~/.cache/dottod/state.json` (selected, results, last_run) | loaded tolerant (corrupt → default), saved on exit [OBSERVED: tui/src/state.rs:22] |
| Container runtime | selected engine + usability | configured → selected → usable/no [OBSERVED: bin/container.sh:111] |
| SSH host block | `Host github.com` stanza in `~/.ssh/config` | missing → appended; partial → completed; complete → untouched [OBSERVED: tests/test-ssh-merge.bats:36] |

## Invariants (guards that must hold)
1. **Never destroy user config**: any existing target is backed up before
   linking [OBSERVED: bin/utils.sh:286, bin/neovim.sh:271].
2. **Registries match**: `DOT_TASKS` order/ids == TUI `registry()` ids
   (enforced by `registry_matches_bootstrap` test)
   [OBSERVED: tui/src/task.rs:124].
3. **Apt serialization**: at most one `needs_apt` task runs at a time
   (dpkg lock), in both bash (`--parallel` relies on dpkg) and TUI
   (apt semaphore) [OBSERVED: tui/src/scheduler.rs:57, README.md:268].
4. **Version floor**: Neovim < 0.11.0 is refused, never silently installed
   [OBSERVED: bin/neovim.sh:194, tests/test-neovim.bats:150].
5. **Prompt never breaks shell startup**: section functions always return
   0; collector exits 0 on missing data
   [OBSERVED: scripts/.sysinfo.prompt.sh:47, scripts/system-info.sh:18].
6. **Scripts sourced by zsh must be inert**: bash programs in `scripts/`
   carry the `ZSH_VERSION` guard [OBSERVED: scripts/system-info.sh:37,
   scripts/nvim-headless-check.sh:11].

## State machines
- Task run: `Pending → Running → {Passed, Failed, Skipped}`
  [OBSERVED: tui/src/state.rs:7].
- SSH merge: `missing → installed | unrelated → appended | partial →
  completed | complete → untouched` [OBSERVED: tests/test-ssh-merge.bats].
- Symlink: `missing → linked | correct-link → noop | other → backup+link`.

## Authorization
Single-user model: privilege only via local sudo/doas, cached per run
(`_sudo_preflight`), never stored [OBSERVED: bin/utils.sh:122,122;
trap cleanup bin/utils.sh:70]. No auth matrix beyond that (no multi-user
stories exist) [ASSUMPTION: confirm single-user scope].
