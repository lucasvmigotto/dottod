# 005-container — data model (runtime state)

- State: `installed` (`podman` on PATH) → `usable` (rootless
  `podman info` succeeds + subuid ranges).
- System effects: `podman`+`uidmap` apt packages,
  `usermod --add-subuids/--add-subgids` once when ranges missing.
