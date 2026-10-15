# 005 — container runtime (rootless Podman)

## Stories
- US1: As a user I run the container task so that rootless Podman works
  (uidmap + subuid/subgid ranges).
- US2: As a user I run `container.sh status` (or `ctr …`) so that the
  installed/rootless state is reported cheaply.

## Acceptance scenarios
- Given usable podman, when ensuring, then no-op with zero priv calls
  [OBSERVED: tests/test-container.bats:ensure is a no-op].
- Given missing subuid ranges, when ensuring, then exactly one `usermod`
  attempt happens [OBSERVED: tests/test-container.bats:ensure attempts usermod].
- Given missing podman, when ensuring, then loud failure, no priv calls
  [OBSERVED: tests/test-container.bats:ensure fails loudly].

## Status
Implemented. Verified: no (integration/
needs engine+network, gated behind `DOTTOD_TEST_INTEGRATION=1`;
did not run here).

Docker support (install task, `--runtime` and `_DOT_CONTAINER_RUNTIME`)
removed 2026-10-15.
