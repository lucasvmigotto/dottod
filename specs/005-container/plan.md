# 005-container — as-is technical context

- Entry: `bin/container.sh` (`_podman_ensure`; `status` subcommand is
  probe-only).
- Detection: `scripts/.container.utils.sh` (`_ctr_installed`,
  `_ctr_usable`, `_ctr_version`, `ctr`).
- subuid/subgid are plain files (`/etc/subuid`), read directly — `getent`
  cannot see them.
- Tests: `tests/test-container.bats` (hermetic),
  `tests/integration/podman-hello.sh` (gated, not run).
- CI: `.github/workflows/container.yml` (Podman integration job).
