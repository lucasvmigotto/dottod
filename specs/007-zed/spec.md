# 007 — zed (user-level editor)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only zed --ui` so that the
  Zed editor installs user-level without touching any other editor.
- US2: As a terminal-first user I never get Zed unless I pass `--ui`.

## Acceptance scenarios
- Given `zed` absent, when the task runs, then the official installer
  downloads (with retries) and runs from a file (never pipe-to-shell),
  honouring `_DOT_ZED_CHANNEL`/`_DOT_ZED_VERSION`, and `~/.local/bin/zed`
  becomes executable [OBSERVED: bin/zed.sh, tests/test-zed.bats].
- Given `zed` present, when the task runs, then it skips without network
  [OBSERVED: bin/zed.sh presence probe, tests/test-zed.bats].
- Given a failed download or installer, when the task runs, then it fails
  loudly and installs nothing [OBSERVED: tests/test-zed.bats].
- Given a default bootstrap run, when tasks are selected, then `zed` is
  excluded unless `--ui` is passed [OBSERVED: bin/bootstrap.sh
  `DOT_UI_TASKS`, `--ui`/`--no-ui` flags].

## Status
Implemented. Verified: no (no cross-stack e2e).
