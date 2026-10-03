# 007-zed — as-is technical context

- Entry: `bin/zed.sh` (`_zed_ensure`: presence probe → apt
  `curl ca-certificates tar` → `_download` installer → `sh` with
  `ZED_CHANNEL`/`ZED_VERSION` passthrough → post-check
  `~/.local/bin/zed` executable).
- Deliberately download-then-run, never `curl|sh` (retrofit posture).
- Replaces the removed vscode task (Microsoft apt repo gone with it).
- UI task: skipped by default, included with `--ui`
  [OBSERVED: bin/bootstrap.sh:8].
- Env: `_DOT_ZED_INSTALLER_URL` (default `https://zed.dev/install.sh`),
  `_DOT_ZED_CHANNEL` (default `stable`), `_DOT_ZED_VERSION` (default
  `latest`), `_DOT_NO_PACKAGES`.
- Tests: `tests/test-zed.bats` (4 tests: skip, stub install + channel,
  download failure, version pin).
