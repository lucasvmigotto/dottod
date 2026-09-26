# 006-desktop — as-is technical context

- Entry: `bin/desktop.sh` (apt `gnome-system-monitor`-family +
  `gsettings` dark theme + `_DOT_DESKTOP_FONT`, default
  `FiraCode Nerd Font 11`) [OBSERVED: bin/desktop.sh:19].
- UI task: skipped by `--no-ui-support` and the TUI `u` toggle
  [OBSERVED: bin/bootstrap.sh:137, tui/src/task.rs:41].
- Env: `_DOT_DESKTOP_FONT`, `_DOT_SYSTEM_MONITOR`
  [OBSERVED: bin/desktop.sh:19].
- No dedicated test suite (shellcheck/bash -n only).
