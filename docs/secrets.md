# Secrets (`pass`)

The opt-in `secrets` task makes [`pass`](https://www.passwordstore.org/)
your system-wide secret store — every secret GPG-encrypted under one key —
and routes container registry logins through it, so no registry token ever
sits in a plain file again.

It never runs by default: select it with `--only secrets`.

## First time

The key and the store are yours to create (your passphrase, your choice
of key); dottod checks them and stops with the exact command when one is
missing.

```bash
gpg --full-generate-key                 # your key, your passphrase
pass init <your key id>                 # the store, for that key
./bin/bootstrap.sh --only secrets       # install, check, wire registries
podman login docker.io                  # the token goes into pass
./bin/secrets.sh status                 # what is set up, nothing changed
```

## What the task does

1. Installs `pass` and `gpg`, and `docker-credential-pass` where the
   distribution packages it (Debian/Ubuntu, Gentoo with `USE=pass`).
2. Requires a GPG secret key and a store initialised for it.
3. Adds `~/.config/containers/registries.conf.d/50-dottod-pass.conf`
   (`credential-helpers = ["pass"]`): every `podman login` stores its token
   in pass, and pulls read it back. Delete the file to undo it.
4. Writes a GnuPG socket redirect (`~/.gnupg/S.gpg-agent` → your agent's
   socket under `/run/user/<uid>`): rootless Podman runs the credential
   helper inside its user namespace, where gpg can't otherwise find your
   agent. It is written only when the agent socket lives under `/run/user`
   and never replaces a live socket or someone else's file.
5. Removes plaintext registry credentials (`auths` entries) from
   `~/.docker/config.json` and the containers `auth.json` files, logging
   registry names only. Other settings in those files are kept.

## What it never does

- Generate a key, run `pass init` or `pass insert`.
- Read, print or log a secret value — `status`, the logs and
  `dottod-doctor` name registries only.
- Edit your `registries.conf`, or `/etc/portage` on Gentoo (it prints the
  `package.use` line to add instead).
- Sync the store: that is a separate project (`pass git` works on its own).

## Per distribution

| | `pass` | `docker-credential-pass` |
|---|---|---|
| Debian / Ubuntu | packaged | packaged (`golang-docker-credential-helpers`) |
| Gentoo | packaged | packaged, needs `USE=pass` on `app-containers/docker-credential-helpers` |
| Arch | packaged | AUR only — install it yourself |
| Fedora | packaged | not packaged — install it yourself |
| Alpine | packaged | not packaged — install it yourself |

Without the helper, pass is still set up; the task explains where to get
the official binary
(<https://github.com/docker/docker-credential-helpers/releases>, verify it
against `checksums.txt`) and wires registries on the next run.

## Passphrase prompts

Pulls decrypt through your own gpg-agent: a graphical pinentry or a cached
passphrase works out of the box. In a terminal-only session, export
`GPG_TTY=$(tty)` so the agent can prompt there.
