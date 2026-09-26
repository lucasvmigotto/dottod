# 005-container — data model (runtime state)

- Selection: `configured` (`_DOT_CONTAINER_RUNTIME`, default podman) →
  `selected` (`_ctr_resolve`: explicit stays; `auto` prefers usable
  podman, falls back to usable docker, else podman) →
  `usable` (engine `info` succeeds + subuid ranges for podman).
- System effects (podman path): `podman`+`uidmap` apt packages,
  `usermod --add-subuids/--add-subgids` once when ranges missing.
- System effects (docker path): `bin/docker.sh` (apt repo + keyring +
  install); re-login may be needed for the docker group.
