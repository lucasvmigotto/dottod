# 020 — Claude sessions: continue or start, and `codes` marks

Decided 2026-10-16, for 2.5.0.

## Stories
- US1: As a user, `claude -c` (`--continue`) in a directory with no saved
  conversation asks `Start a new one? [y/N]` instead of stopping at Claude
  Code's "No conversation found to continue". `y` launches without the
  flag, every other argument kept; `N` or enter launches nothing (rc 1).
- US2: The same for a bare `claude -r` (`--resume`). `-r <id or term>` is
  Claude Code's to resolve and goes through untouched.
- US3: `codes` marks repositories with a saved Claude Code conversation
  (nf-cod-sparkle, U+EC10, in Claude orange); `codes -c <name>` jumps there
  and runs `claude -c` (so US1 applies when there is none).

## Rules
- The wrapper never captures Claude Code's output (it owns the terminal):
  it looks before launching. A conversation is a `<session>.jsonl` under
  `<config dir>/projects/<cwd with every non-alphanumeric as '->`, the
  physical cwd. Paths past 200 characters are keyed with a hash dottod
  cannot rebuild: they count as having one (Claude Code decides).
- Ask only on a terminal in an interactive shell; otherwise (scripts,
  pipes, `-p`) the arguments go through untouched. `-c`/`-r` after `--`
  are arguments, not options.
- `codes` reads `${CLAUDE_CONFIG_DIR:-~/.claude}/projects` (the profiles'
  shared store). `CODES_CLAUDE=0` hides the mark, `CODES_CLAUDE_GLYPH`
  replaces it; `-c` refuses `-l`/`-p`.
- Status column widths count characters on every awk (mawk counts bytes:
  continuation bytes are skipped there), so marked rows stay aligned.

## Status
Implemented on `feat/claude-continue` (2026-10-16).

- `scripts/.claude.sh` (`__dottod_claude_session_flag`,
  `__dottod_claude_has_conversation`, `__dottod_claude_can_ask` — the test
  seam —, `__dottod_claude_offer_new`); `scripts/.codes.sh` (worker field
  15, `wlen`, `-c/--claude`).
- Tests: `test-claude.bats` +9, `test-codes.bats` +4; the lookup checked
  against the real store (conversations found for ~/codes/dottod and
  ~/codes/ai-gent, none for ~/Downloads); width helper checked on mawk,
  BusyBox awk and gawk (UTF-8 and C locales).
- The projects/ folder naming is Claude Code's internal layout, not a
  documented interface: if it changes, the question may be asked where a
  conversation exists (y then starts a new one).
