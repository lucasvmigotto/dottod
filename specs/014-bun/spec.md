# 014 — bun (JS runtime, direct-zip install)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only bun` so that the Bun
  binary installs to `~/.local/bin`, sha256-verified, without modifying
  any shell rc file.
- US2: As a user with `bun` already present I get a skip, so re-runs converge.

## Acceptance scenarios
- Given `bun` absent, when the task runs, then `bun-linux-<arch>.zip`
  downloads (latest, or `_DOT_BUN_VERSION` tag), verifies against the
  release-API digest when published, extracts, and installs the single
  binary to `~/.local/bin` [OBSERVED: bin/bun.sh: `_bun_ensure`].
- Given a checksum mismatch, when the task runs, then it fails loudly
  and installs nothing.
- Given no published digest (mirror override), when the task runs, then
  it warns and proceeds (same as before).
- Given `_DOT_BUN_VERSION=bun-v1.2.0`, when the task runs, then that tag
  installs instead of latest.

## Status
Bash: Implemented. TUI: Implemented. Verified: no (no cross-stack e2e).
