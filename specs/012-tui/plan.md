# 012-tui — as-is technical context

- Crate `dottod` 1.0.0 (MIT): ratatui 0.29 + crossterm 0.28 + tokio 1 +
  clap 4 + serde/serde_json + dirs + anyhow
  [OBSERVED: tui/Cargo.toml, tui/Cargo.lock].
- Modules: `main` (clap CLI, privilege preflight, raw-mode loop),
  `app` (selection/running/summary modes, key handling), `ui`
  (list/log/status panes), `runner` (spawns `bin/<id>.sh`, streams),
  `scheduler` (sequential or semaphore-gated parallel),
  `state` (cache-dir `state.json`), `task` (registry + repo-root +
  runtime resolution) [OBSERVED: tui/src/].
- Tests: 7 Rust unit tests (`registry_matches_bootstrap`,
  runtime resolve matrix) [OBSERVED: tui/src/task.rs:103].
- Release: `tui.yml` release job ships `dottod-linux-x86_64` +
  scripts tarball + sha256sums via `gh release`
  [OBSERVED: .github/workflows/tui.yml:43].
- Keybindings and runtime cycling (`e`: podman→docker→auto) per README.
