# 013-cargo — as-is technical context

- Entry: `bin/cargo.sh` (`_cargo_ensure`: presence probe → apt
  `curl ca-certificates` → `_download` rustup-init → `sh` with
  `-y --no-modify-path --profile minimal --default-toolchain stable` →
  post-check `${CARGO_HOME:-~/.cargo}/bin/cargo` executable).
- `--no-modify-path` is load-bearing: rustup must not append to
  `~/.zshrc` (the repo symlink); PATH comes from `config/.custom.zshrc`
  (`~/.cargo/bin` block).
- Env: `_DOT_RUSTUP_INIT_URL` (default `https://sh.rustup.rs`),
  `_DOT_RUSTUP_TOOLCHAIN` (default `stable`), `_DOT_RUSTUP_PROFILE`
  (default `minimal`), `_DOT_CARGO_HOME`, `_DOT_NO_PACKAGES`.
- Download-then-run posture per retrofit (never pipe-to-shell).
- Tests: `tests/test-toolchain.bats` (hermetic); real install verified in
  container during implementation.
