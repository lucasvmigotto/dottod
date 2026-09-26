# 005 — container runtime (Podman default, Docker alternative)

## Stories
- US1: As a user I run the container task (default) so that rootless
  Podman works (uidmap + subuid/subgid ranges).
- US2: As a user I select `--runtime docker` (or `_DOT_CONTAINER_RUNTIME`)
  so that Docker installs instead, without Podman being touched.
- US3: As a user I run `container.sh status` (or `ctr …`) so that the
  configured/selected/installed/usability state is reported cheaply.

## Acceptance scenarios
- Given explicit `docker`, when resolving, then it never switches to
  podman even if podman is broken
  [OBSERVED: tests/test-container.bats:109].
- Given `auto` with usable podman, when resolving, then podman wins;
  given broken podman + usable docker, then docker
  [OBSERVED: tests/test-container.bats:109].
- Given missing subuid ranges, when ensuring, then exactly one `usermod`
  attempt happens [OBSERVED: tests/test-container.bats:166].
- Given missing podman, when ensuring, then loud failure, no priv calls
  [OBSERVED: tests/test-container.bats:158].
- Given invalid `_DOT_CONTAINER_RUNTIME`, when any entry runs, then rc 1
  with empty output [OBSERVED: tests/test-container.bats:75].

## Status
Bash: Implemented. TUI: Implemented. Verified: no (integration/
needs engine+network, gated behind `DOTTOD_TEST_INTEGRATION=1`;
did not run here).
