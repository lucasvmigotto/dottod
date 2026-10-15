# Container runtime (rootless Podman)

dottod's container runtime is **rootless Podman**. Nothing is ever migrated
or deleted: existing container engines, images, and containers are left
alone. Docker is not installed or managed by dottod.

Linux-only (native, Debian/apt). No Podman Machine, WSL, Compose, Swarm, or
Kubernetes abstraction — dottod uses none of those.

## Detection vocabulary

| Term | Meaning | How |
| ---- | ------- | --- |
| installed | binary on `PATH` | `command -v podman` |
| usable | works as *you*, no sudo | `podman info` |

Binary-exists is not usable: a Podman without user namespaces or subids is
*installed but unusable*, and dottod reports exactly that.

## Setup

`./bin/container.sh` (the `container` bootstrap task) ensures Podman:

1. Installs `podman` + `uidmap` via the repo apt helper (skipped if present;
   honors `_DOT_NO_PACKAGES=1`).
2. Ensures rootless `subuid`/`subgid` ranges (`100000-165535`, created with
   `usermod` only when missing).
3. Validates rootless operation (`podman info` as your user, no sudo).

Ordinary usage needs no privileges afterwards: `podman ps`, `podman run`,
etc. work as your user. If prerequisites are missing and cannot be fixed
safely, setup stops with instructions instead of guessing.

```bash
./bin/bootstrap.sh --only container             # re-run safely (idempotent)
```

## Status

```bash
./bin/container.sh status
```

```text
Container runtime
-----------------
Podman:     installed 5.4.2
Rootless:   yes
```

Probes run only here (and during ensure) — never in the prompt.

## Shell

* `ctr` (shell function, sourced from `scripts/.container.utils.sh` by
  `config/.custom.bashrc`) is shorthand for `podman`: `ctr ps`,
  `ctr images`, `ctr run …`.
* `cps`, `cimg`, `cprune`, `csh`, `clog` (`scripts/.containers.sh`) check
  that Podman is usable first and fail loudly otherwise.

## Testing

| Test | Needs engine | Needs network |
| ---- | ------------ | ------------- |
| `tests/test-container.bats` (detection, ensure, errors, idempotency) | no (stubs) | no |
| `tests/integration/podman-hello.sh` | Podman + `DOTTOD_TEST_INTEGRATION=1` | yes (one pull) |

Run the fast suite with `./tests/run.sh` (integration is excluded by
design). Run the integration explicitly:
`DOTTOD_TEST_INTEGRATION=1 ./tests/integration/podman-hello.sh`.
Integration cleans up only its own container (always) and its image (only
if it pulled it); CI additionally sweeps the `dottod-test=1` label.

## CI

* `shell` workflow: syntax, ShellCheck, fast suites (incl. container unit
  tests).
* `container` workflow: the **Podman** integration job (`contents: read`,
  ephemeral runner, pinned `hello-world`, label-scoped cleanup).

## Compatibility and limitations

* No Compose abstraction.
* No Podman socket/`DOCKER_HOST` management: tools like `lazydocker`
  (an opt-in `tools` extra) speak the Docker API; point `DOCKER_HOST` at a
  user-managed `podman system service` socket yourself if you combine
  them — dottod won't open that interface for you.
* No systemd units, no daemon management (rootless needs none for CLI use).

## Files

* `scripts/.container.utils.sh` — detection helpers + `ctr` (plain bash)
* `bin/container.sh` — task: ensure + `status` (+ `--help`)
* `tests/test-container.bats`, `tests/integration/podman-hello.sh`
* `.github/workflows/container.yml`
