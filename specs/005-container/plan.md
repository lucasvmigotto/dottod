# 005-container — as-is technical context

- Entry: `bin/container.sh` (`_container_ensure` dispatches on
  `_ctr_resolve`; `status` subcommand is probe-only)
  [OBSERVED: bin/container.sh:111].
- Selection logic: `scripts/.container.utils.sh` (`_ctr_configured`,
  `_ctr_resolve`, `_ctr_usable_*`); explicit choice never auto-switches
  [OBSERVED: tests/test-container.bats:109].
- `bin/docker.sh` owns the Docker path (repo + install + group);
  `bin/container.sh` never migrates or destroys the other runtime
  [OBSERVED: bin/container.sh:96].
- subuid/subgid are plain files (`/etc/subuid`), read directly — `getent`
  cannot see them [OBSERVED: bin/container.sh:42].
- `ctr` dispatcher routes to the resolved engine
  [OBSERVED: tests/test-container.bats:127].
- Tests: `tests/test-container.bats` (12 hermetic), `tests/test-container.zsh`,
  `tests/integration/{docker,podman}-hello.sh` (gated, not run).
- CI: `.github/workflows/container.yml` (Podman/Docker integration jobs).
