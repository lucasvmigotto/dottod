# 017 — secrets (`pass`), opt-in, with container registries on top

Decided 2026-10-15. Separate from Claude profiles and from spec 016.

## Why
Registry tokens lived base64-encoded (not encrypted) in
`~/.docker/config.json`, readable by anything with access to the file.
`pass` keeps secrets GPG-encrypted in one store that any tool can read
through `pass show`; container registries are its first consumer.

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only secrets` (the task is
  skipped by default, like zed) so that `pass` is installed and checked:
  a GPG secret key exists and the store is initialised for it.
- US2: As a user without a key or store, the task stops with the exact
  commands to run myself (`gpg --full-generate-key`, `pass init <id>`);
  dottod never generates keys, never sees a passphrase or a secret.
- US3: As a user, every container registry login goes through `pass`:
  `podman login <registry>` stores the token in the store, pulls read it
  back (gpg-agent caches the passphrase); nothing lands in a plain file.
- US4: As a user, plaintext registry credentials left in
  `~/.docker/config.json` or the containers `auth.json` files are removed
  once `pass` is the store (names logged, never values; no backup).
- US5: As a user, `./bin/secrets.sh status` and `dottod-doctor` report the
  store (key present, initialised, credential helper wired) and warn about
  any plaintext registry credential still on disk.

## Rules
- Opt-in task: not in the default run; `--only secrets` (or `--ui`-style
  exclusion list) selects it.
- Never generate GPG keys, never run `pass init` or `pass insert`, never
  read, print or log a secret value. Interactive steps are the user's.
- Registry wiring is a drop-in (`~/.config/containers/registries.conf.d/
  50-dottod-pass.conf`, `credential-helpers = ["pass"]`) — the user's own
  `registries.conf` is never edited; removing the drop-in reverts it.
- Plaintext cleanup touches only registry entries (`auths`) in the three
  known files, keeps every other key, keeps mode 0600, keeps no backup.
- Store sync (`pass git`) is out of scope: a separate project.

## Acceptance scenarios
- Given no GPG secret key, when the task runs, then it exits non-zero
  with the two commands to run, installs nothing else, writes nothing.
- Given a key but no store, then it prints `pass init <that key id>`.
- Given key + store, then the drop-in exists and `podman login` writes
  through `docker-credential-pass` (verified on a real run, T170).
- Given a plaintext `auths` entry, when the task completes, then it is
  gone and the file's other keys are untouched.
- Re-running is a no-op.

## Open, verified in T170 before building
- A `credential-helpers` drop-in in `registries.conf.d` is honoured, and
  `podman login` stores through the first helper.
- `docker-credential-pass` packaging per distro (resolve gate): Debian
  `golang-docker-credential-helpers`, others to confirm.

## Status
Planned.
