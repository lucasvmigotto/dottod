# 016 — work git identity (`gwork`) and `codes` contexts

Decided 2026-10-15; built after spec 015. Separate from Claude profiles:
nothing here reads or sets them.

## Context
The same dottod runs on a personal laptop (also used for home office)
and on a company machine. Personal and work repos share `~/codes` and
must not move: Claude Code conversations are keyed by path. At the
company there is no global git identity; each repo sets its own.

## Stories
- US1: As a user at home, personal stays my global identity and work
  repos carry the work identity in their local config.
- US2: As a user I run `gwork clone <url> [dir] [git clone options…]` so
  that the clone gets the work `user.name`/`user.email` locally.
- US3: As a user I run `gwork set [dir]` / `gwork unset [dir]` to mark an
  existing checkout as work (or back to the default) without moving it;
  `gwork` alone shows which identity the current repo resolves.
- US4: As a user I see each repo's context in `codes` (work when the
  email git resolves is the work email, otherwise personal), and can
  filter (`--work` / `--personal`) and group by it.
- US5: As a user on the company machine I run
  `GIT_GLOBAL_IDENTITY=0 ./bin/bootstrap.sh` so `~/.gitconfig` gets the
  rest of the config but no global `user.*`.

## Rules
- Work values: `GIT_WORK_NAME` / `GIT_WORK_EMAIL`, falling back to
  `~/.gitconfig-work`, which becomes plain data (included by nothing).
- Remove `[includeIf "gitdir:~/codes/**"]` from the gitconfig task: it
  gives every repo under `~/codes` the work identity once one exists.
- Personal is the default everywhere; no tag file — git is the single
  source of truth, read with one `git config` per repo in `codes`.
- No names or emails committed to this repository.
- Host-agnostic: `gwork clone` passes the URL to `git clone` untouched
  and works with any form git accepts — scp-style SSH, `ssh://`,
  `https://` — on any host (Azure DevOps, Bitbucket, GitLab, GitHub,
  self-hosted). No per-host code paths, no URL rewriting.
- The checkout directory, when not given, follows git's own default
  (the "humanish" last path component, minus `.git` and trailing `/`),
  so `gwork clone` lands where `git clone` would.

## Acceptance scenarios (URL forms the tests must cover)
| Host | SSH | HTTPS | Default dir |
|---|---|---|---|
| Azure DevOps | `git@ssh.dev.azure.com:v3/org/proj/repo` | `https://dev.azure.com/org/proj/_git/repo` | `repo` |
| Bitbucket | `git@bitbucket.org:team/repo.git` | `https://bitbucket.org/team/repo.git` | `repo` |
| GitLab (subgroups) | `git@gitlab.com:group/sub/repo.git` | `https://gitlab.com/group/sub/repo.git` | `repo` |
| GitHub | `git@github.com:org/repo.git` | `https://github.com/org/repo` | `repo` |
| any | `ssh://git@host:2222/path/repo.git` | `https://host/path/repo.git/` | `repo` |

Given a failed clone (bad URL, no access), nothing is configured and
the git error stays visible.

## Open
- SSH keys for hosts other than GitHub are out of scope here: the `ssh`
  task only manages the GitHub host entry and key. Supported key types
  vary by host (check Azure DevOps' current requirements before adding
  one).

## Status
Implemented on `feat/gwork` (2026-10-16).

- `bin/gitconfig.sh`: no includeIf (an old one is dropped on the next
  run, with a backup); `~/.gitconfig-work` written only from
  `GIT_WORK_NAME` + `GIT_WORK_EMAIL`, never removed;
  `GIT_GLOBAL_IDENTITY=0` writes no `user.*` and never prompts.
- `scripts/.gwork.sh`: `gwork [status]|clone|set|unset`. `clone` adds
  `-c user.name=… -c user.email=…` to `git clone`, which git writes to the
  new repository's local config only when the clone succeeds.
- `scripts/.codes.sh`: one `git config user.email` per repo in the
  parallel worker; context column once a work email exists; `--work`,
  `--personal`, `--by-context`.

Evidence: `tests/test-gwork.bats` clones every URL of the acceptance
table for real, offline (each mapped to a local bare repo with
`url.<base>.insteadOf`, so git sees the URL as typed), checks the
directory, the local identity and the cd; failed clone, missing identity,
env precedence, set/unset/status. `tests/test-gitconfig.bats` and
`tests/test-codes.bats` cover the task and the context column. Full
suite: 328/328.
