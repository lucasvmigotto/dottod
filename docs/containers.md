# Container runtime (Podman default, Docker alternative)

dottod treats the container engine as a **runtime abstraction** with two
backends. **Podman is installed and configured by default**; Docker stays
available for anyone who explicitly selects it. Nothing is ever migrated
or deleted: existing Docker/Podman installs, images, and containers are
left alone.

```text
                         dottod
                           │
                 Container Runtime
                           │
              ┌────────────┴────────────┐
              │                         │
           Podman                    Docker
          DEFAULT                  ALTERNATIVE
              │                         │
              └────────────┬────────────┘
                           │
                  bin/container.sh
                  scripts/.container.utils.sh
                           │
              ┌────────────┼────────────┐
              │            │            │
           Bootstrap      TUI        Shell prompt
```

Linux-only (native, Debian/apt). No Podman Machine, Docker Desktop, WSL,
Compose, Swarm, or Kubernetes abstraction — dottod uses none of those.

## Selection

| Value | Meaning |
| ----- | ------- |
| `podman` | Use Podman (the default when nothing is configured) |
| `docker` | Use Docker (explicit alternative) |
| `auto` | Podman if usable, else Docker if usable, else Podman (install target) |

Configure via the `_DOT_CONTAINER_RUNTIME` environment variable (repo
`_DOT_*` convention), the bootstrap `--runtime` flag, or the TUI
`--runtime` flag / `e` key. Precedence:

```text
bootstrap --runtime / TUI --runtime (explicit flag)
      ↓
_DOT_CONTAINER_RUNTIME (environment, incl. TUI per-run forwarding)
      ↓
default: podman
```

An explicit `podman`/`docker` choice is **never silently switched**; if the
chosen runtime is unusable, setup fails loudly with an actionable message.
`auto` is the only mode that probes, in Podman-first order.

Examples:

```bash
./bin/bootstrap.sh                              # Podman
_DOT_CONTAINER_RUNTIME=docker ./bin/bootstrap.sh
./bin/bootstrap.sh --runtime docker --only container
./bin/bootstrap.sh --only container             # re-run safely (idempotent)
```

## Detection vocabulary

| Term | Meaning | How |
| ---- | ------- | --- |
| configured | env value | `_DOT_CONTAINER_RUNTIME`, default `podman` |
| installed | binary on `PATH` | `command -v podman` / `docker` |
| usable | works as *you*, no sudo | Podman: `podman info`; Docker: `docker info` (daemon reachable) |
| selected | resolution result | `_ctr_resolve` (probes only in `auto` mode) |

Binary-exists is not usable: a stopped Docker daemon or a Podman without
user namespaces is *installed but unusable*, and dottod reports exactly that.

## Podman (default)

`./bin/container.sh` (the `container` bootstrap task) ensures Podman:

1. Installs `podman` + `uidmap` via the repo apt helper (skipped if present;
   honors `_DOT_NO_PACKAGES=1`).
2. Ensures rootless `subuid`/`subgid` ranges (`100000-165535`, created with
   `usermod` only when missing).
3. Validates rootless operation (`podman info` as your user, no sudo).

Ordinary usage needs no privileges afterwards: `podman ps`, `podman run`,
etc. work as your user. If prerequisites are missing and cannot be fixed
safely, setup stops with instructions instead of guessing.

## Docker (alternative)

Select it explicitly (see above) and the `container` task delegates
installation to the untouched `bin/docker.sh` (official apt repo +
`docker` group membership; a re-login may be needed before the daemon
answers — reported as a warning, matching existing behavior). Podman is
never installed on this path. `bin/docker.sh` also stays directly runnable
for Docker-only setups: `./bin/docker.sh`.

## Status

```bash
./bin/container.sh status
```

```text
Container runtime
-----------------
Configured: <unset> (default: podman)
Selected:   podman
Podman:     installed 5.4.2
Docker:     installed 29.7.2
Rootless:   yes
Usable:     no
```

Probes run only here (and during ensure) — never in the prompt.

## Shell

* `ctr` (auto-sourced shell function) dispatches to the resolved runtime:
  `ctr ps`, `ctr images`, `ctr run …`. Explicit values are honored;
  `auto` resolves per invocation.
* The existing `docker*` aliases are unchanged and keep working wherever
  the `docker` binary works.
* The prompt shows a small runtime token after the system metrics
  (`<cube> podman`), rendered from the *configured selection only* — zero
  subprocess cost, never blocks startup. Toggle with
  `SPACESHIP_CONTAINER_SHOW=false` (or the `_DOT_SYSTEM_INFO_ENABLED`
  master switch); color via `SPACESHIP_CONTAINER_COLOR`.

## TUI

`dottod --runtime docker` (or `podman`/`auto`; invalid values rejected),
a `runtime:…` status-bar segment, and `e` to cycle the choice per run. An
interacted-with or flagged choice is forwarded to task scripts as
`_DOT_CONTAINER_RUNTIME`; otherwise the ambient environment (or each
script's Podman default) applies untouched.

## Testing

| Test | Needs engine | Needs network |
| ---- | ------------ | ------------- |
| `tests/test-container.sh` (selection, detection, ensure, errors, idempotency) | no (stubs) | no |
| `tests/test-container.zsh` (lib under zsh, prompt section, order) | no (stubs) | no |
| Rust TUI tests (default, values, cycle, env forwarding) | no | no |
| `tests/integration/podman-hello.sh` | Podman + `DOTTOD_TEST_INTEGRATION=1` | yes (one pull) |
| `tests/integration/docker-hello.sh` | Docker + `DOTTOD_TEST_INTEGRATION=1` | yes (one pull) |

Run the fast suite with `./tests/run.sh` (integration is excluded by
design). Run one integration explicitly, e.g.
`DOTTOD_TEST_INTEGRATION=1 ./tests/integration/docker-hello.sh`.
Integration cleans up only its own container (always) and its image (only
if it pulled it); CI additionally sweeps the `dottod-test=1` label.

## CI

* `shell` workflow: syntax, ShellCheck, fast suites (incl. container unit
  tests), Rust checks.
* `container` workflow (this page's jobs): independent **Podman** and
  **Docker** integration jobs (`contents: read`, ephemeral runner,
  pinned `hello-world`, label-scoped cleanup) — neither runtime's result
  can mask the other's.

## Compatibility and limitations

* No Compose abstraction: dottod ships the compose *plugin* but runs no
  compose files; `docker compose` ↔ `podman compose` parity is therefore
  out of scope.
* No Podman socket/`DOCKER_HOST` management: tools like `lazydocker`
  (installed by the `tools` task) speak the Docker socket; point
  `DOCKER_HOST` at a user-managed `podman system service` socket yourself
  if you combine them — dottod won't open that interface for you.
* No systemd units, no daemon management for Podman (rootless needs none
  for CLI use), no migration of existing Docker users.

## Files

* `scripts/.container.utils.sh` — selection/detection/dispatcher (single
  branching point; bash+zsh safe)
* `bin/container.sh` — task: ensure + `status` (+ `--help`)
* `bin/docker.sh` — explicit-Docker installer (unchanged behavior)
* `tests/test-container.{sh,zsh}`, `tests/integration/*-hello.sh`
* `tui/src/{main,app,ui,task}.rs` — `--runtime`, indicator, cycle, tests
* `scripts/.sysinfo.prompt.sh` — `spaceship_container` section
* `.github/workflows/container.yml`
