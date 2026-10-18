# 021 — `claude-mv`: move a directory with its Claude sessions

Decided 2026-10-18, for 2.8.0.

## Context
Claude Code files a conversation by the directory it started in. Moving
a project (`mv ~/codes/app ~/work/app`) leaves its sessions behind:
`claude -c` and `--resume` find nothing, trust and allowed tools are
asked again, and the prompt history no longer matches.

## Stories
- US1: `claude-mv OLD NEW` moves the directory and repoints every record
  of the sessions started in it or in any directory inside it.
- US2: `claude-mv --fixup OLD NEW` does the repointing after a move by
  hand (OLD gone, NEW a directory).
- US3: `--dry-run` prints the plan — directory, session folders (and
  merges), history lines, config entries per file, codes visits — and
  changes nothing.

## What is repointed
| Where | Field |
|---|---|
| `<store>/projects/<key>/` (transcripts, session dirs, `memory/`) | the folder name: the path, non-alphanumerics as `-` |
| each transcript line (`*.jsonl`, subagents included) | `"cwd"` |
| `<store>/history.jsonl` | `"project"` |
| each profile's `.claude.json`, `~/.claude/.claude.json`, `~/.claude.json` | `projects` keys, `githubRepoPaths` values |
| dottod `codes` visits | the path column |

Paths equal to OLD or under `OLD/` map to NEW. Session-keyed stores
(`file-history/`, `shell-snapshots/`, `plans/`) hold no path and stay.

## Rules
- A key is lossy (`/a/b` and `/a/b-c` share the prefix `-a-b`): a folder
  moves only when one of its transcripts' `cwd` values maps back to its
  key; a folder without transcripts moves on an exact key match only.
- Only the path fields change, by a literal match on the compact JSON
  Claude Code writes (`"cwd":"<path>"`, followed by `"` or `/`);
  conversation text keeps the paths it mentions. `.claude.json` is
  rewritten with jq; an entry already under the new path is kept.
- An existing destination folder is merged (the consolidate merge:
  identical duplicates dropped, differing ones kept as
  `<file>.from-claude-mv`).
- Refuses while a Claude Code process (the `claude` binary or a
  `claude/versions/` build) works inside OLD — or NEW, with `--fixup`;
  refuses NEW existing (without `--fixup`), NEW inside OLD, a missing
  parent, `/`, and paths with quotes, backslashes or newlines.
- Before changing anything it copies the session folders, history and
  configs to `${XDG_STATE_HOME:-~/.local/state}/dottod/claude-mv/<time>/`
  (mode 700). Files are written through a temporary file renamed into
  place. A failed `mv` stops before any record changes.

## Status
Implemented on `feat/claude-mv` (2026-10-18): `scripts/.claude-mv.sh`,
`tests/test-claude-mv.bats` (9: dry run, full move incl. subdirectory
sessions, subagent transcripts, memory, the lookalike left alone, every
config, codes visits, backups, `--fixup`, merge, refusals, live
detection on a fake /proc, memory-only folder). Dry runs against the
real store: refused for the directory this session works in; plans for
idle projects. Not yet run for real on a live store.
