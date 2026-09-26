# 014-bun — as-is technical context

- Entry: `bin/bun.sh` (`_bun_ensure`: presence probe → arch map →
  `_bun_zip_asset` URL+digest → apt `curl ca-certificates unzip` →
  `_download` → verify → unzip `bun-<target>/bun` → `install -m 0755`
  into `~/.local/bin` → post-check).
- Deliberately NOT bun's `install.sh`: that script appends `# bun`
  exports to a writable `~/.zshrc` (the repo symlink) and takes no
  checksum. Direct-zip avoids both.
- Version forms: `latest` (default), `bun-vX.Y.Z`, `vX.Y.Z`, `X.Y.Z`
  (normalized to `bun-v` tag). Mirror override `_DOT_BUN_GITHUB`
  disables digest lookup (no API on mirrors).
- Arch map: `x86_64`→`linux-x64`, `aarch64`→`linux-aarch64`; others fail
  loudly. glibc Debian assumed (no musl variant).
- Tests: `tests/test-toolchain.bats` (hermetic); real install verified in
  container during implementation.
