# Secrets (`pass`)

The opt-in `secrets` task makes [`pass`](https://www.passwordstore.org/)
your system-wide secret store — every secret GPG-encrypted under one key —
and routes container registry logins through it, so no registry token ever
sits in a plain file.

It never runs by default: select it with `--only secrets`. dottod never
creates your key, never runs `pass init`/`pass insert`, and never reads,
prints or logs a secret: those steps are yours, below.

- [First setup](#first-setup)
- [Everyday use](#everyday-use)
- [Moving to a new laptop](#moving-to-a-new-laptop)
- [Key expiry and rotation](#key-expiry-and-rotation)
- [Revoking](#revoking)
- [What the task does](#what-the-task-does)
- [Per distribution](#per-distribution)

## First setup

### 1. Create your GPG key

```bash
gpg --full-generate-key
```

Answer the prompts:

| Prompt | Answer |
|---|---|
| Kind of key | `ECC (sign and encrypt)` — the default in GnuPG 2.4 (ed25519 + cv25519) |
| Expiry | your choice; `2y` is a good default (see [expiry](#key-expiry-and-rotation)) — `0` never expires |
| Name, email, comment | yours (the email identifies the key later) |
| Passphrase | a strong one you can type: it protects everything in the store |

GnuPG also writes a **revocation certificate** for the new key, in
`~/.gnupg/openpgp-revocs.d/<FINGERPRINT>.rev`. Keep a copy somewhere
offline (see [Revoking](#revoking)).

### 2. Find the fingerprint

```bash
gpg --fingerprint you@example.com
```

```text
pub   ed25519 2026-10-15 [SC]
      3EE7 54D4 94F5 58BB 9B09  F66C FC29 FD31 CC4B 9208   <- the fingerprint
uid           [ultimate] Your Name <you@example.com>
sub   cv25519 2026-10-15 [E]
```

The 40-character line under `pub` is the fingerprint; drop the spaces when
you pass it to a command. It is public — safe to share or paste.

### 3. Create the store

```bash
pass init 3EE754D494F558BB9B09F66CFC29FD31CC4B9208
```

This creates `~/.password-store` with a `.gpg-id` naming your key. The
email works too, but the fingerprint can only ever match this one key.

### 4. Run the task and log in

```bash
./bin/bootstrap.sh --only secrets      # install, check, wire registries
podman login docker.io                 # paste the token when asked
./bin/secrets.sh status                # everything in place, nothing changed
```

Use an access token (a Docker Hub "Personal access token", for example),
never your account password: a token can be revoked on its own.

## Everyday use

- `podman login <registry>` stores the token in pass; pulls and pushes read
  it back through your gpg-agent, which caches the passphrase for a while.
- A graphical pinentry prompts when the cache is empty. In a terminal-only
  session, export the TTY first so the agent can prompt there:

  ```bash
  export GPG_TTY=$(tty)
  ```

- `podman logout <registry>` deletes that token from the store.
- Other secrets (PATs, API keys): store them with `pass insert <name>` and
  hand them to commands with `pass-run` or `loadenv` — see
  [Secrets in commands](secret-commands.md). Registry logins live under
  `docker-credential-helpers/`.
- `./bin/secrets.sh status` and `dottod-doctor` report the setup and warn
  about any registry credential left in a plain file (names only).

## Moving to a new laptop

You need two things: the **secret key** (to decrypt) and the **store** (the
encrypted files). Both together unlock everything — move them on a USB
drive or over SSH, never through email, chat or a cloud drive.

On the **old** laptop:

```bash
FPR=3EE754D494F558BB9B09F66CFC29FD31CC4B9208
gpg --export-secret-keys --armor "$FPR" > secret-key.asc   # asks your passphrase
gpg --export-ownertrust > ownertrust.txt
tar -czf password-store.tgz -C ~ .password-store
# copy the three files to the new laptop, e.g.:
#   scp secret-key.asc ownertrust.txt password-store.tgz new-laptop:
shred -u secret-key.asc                                    # don't leave it lying here
```

On the **new** laptop:

```bash
gpg --import secret-key.asc               # asks your passphrase
gpg --import-ownertrust ownertrust.txt    # marks the key as yours (ultimate)
tar -xzf password-store.tgz -C ~
shred -u secret-key.asc ownertrust.txt password-store.tgz
./bin/bootstrap.sh --only secrets         # rewires podman for this machine
pass ls                                   # your secrets, decryptable again
```

Also copy `~/.gnupg/openpgp-revocs.d/` if it isn't already in your offline
backup. Registry logins need nothing else: their tokens are in the store.

## Key expiry and rotation

An expiry date is a safety net: a key you lose stops being valid on its
own. Expiry is not a deadline — you extend it before it lapses, and old
secrets keep working:

```bash
gpg --quick-set-expire "$FPR" 2y          # the primary key
gpg --quick-set-expire "$FPR" 2y '*'      # its subkeys (the encryption one)
```

To move the store to a **new** key (rotation), with both keys still
present:

```bash
pass init <NEW_FINGERPRINT>               # re-encrypts every secret for the new key
```

## Revoking

### A registry token (leaked, or simply no longer needed)

1. Revoke it **at the registry**: that is what makes it useless — for
   Docker Hub and dhi.io, Account settings → Personal access tokens.
2. Remove it locally: `podman logout <registry>`.
3. Create a new token there and `podman login <registry>` again.

Deleting a token only from your laptop does not revoke it.

### Your GPG key (lost laptop, leaked key or passphrase)

1. **Revoke every token in the store first**, at each registry, as above:
   anyone with the key and its passphrase can read them all.
2. Revoke the key with its revocation certificate. GnuPG prefixes the
   certificate with a `:` so it can't be imported by accident; remove that
   one character from the `-----BEGIN PGP PUBLIC KEY BLOCK-----` line:

   ```bash
   cp ~/.gnupg/openpgp-revocs.d/$FPR.rev /tmp/revoke.asc
   sed -i 's/^:-----BEGIN/-----BEGIN/' /tmp/revoke.asc
   gpg --import /tmp/revoke.asc          # the key is now marked revoked
   ```

   If you ever published the key to a keyserver, publish the revocation
   too: `gpg --send-keys "$FPR"`. No certificate? Make one while you still
   have the key: `gpg --gen-revoke "$FPR" > revoke.asc`.
3. Start over: a new key ([First setup](#first-setup)), `pass init` with
   it, new tokens, `podman login` again. If the old key is still available,
   `pass init <NEW_FINGERPRINT>` re-encrypts the existing store instead.

Keep the revocation certificate **offline and separate** from the key: with
it, anyone can revoke your key (but cannot read your secrets).

## What the task does

1. Installs `pass` and `gpg`, and `docker-credential-pass` where the
   distribution packages it.
2. Requires a GPG secret key and a store initialised for it — otherwise it
   stops with the exact command to run and changes nothing.
3. Adds `~/.config/containers/registries.conf.d/50-dottod-pass.conf`
   (`credential-helpers = ["pass"]`): every `podman login` stores its token
   in pass. Delete the file to undo it.
4. Links `~/.local/bin/pass-run` ([Secrets in commands](secret-commands.md)).
5. Writes a GnuPG socket redirect (`~/.gnupg/S.gpg-agent` → your agent's
   socket under `/run/user/<uid>`): rootless Podman runs the credential
   helper inside its user namespace, where gpg can't otherwise find your
   agent. Written only when the agent socket lives under `/run/user`, and
   never over a live socket or a file that isn't dottod's.
6. Removes plaintext registry credentials (`auths` entries) from
   `~/.docker/config.json` and the containers `auth.json` files, logging
   registry names only. Other settings in those files are kept.

It never edits your `registries.conf` or, on Gentoo, `/etc/portage` (it
prints the `package.use` line to add instead), and never syncs the store —
that is a separate project (`pass git` works on its own).

## Per distribution

| | `pass` | `docker-credential-pass` |
|---|---|---|
| Debian / Ubuntu | packaged | packaged (`golang-docker-credential-helpers`) — verified on Debian 13 |
| Gentoo | packaged | packaged, needs `USE=pass` on `app-containers/docker-credential-helpers` |
| Arch | packaged | AUR only — install it yourself |
| Fedora | packaged | not packaged — install it yourself |
| Alpine | packaged | not packaged — install it yourself |

Without the helper, pass is still set up; the task points at the official
binaries (<https://github.com/docker/docker-credential-helpers/releases>,
verify against `checksums.txt`) and wires registries on the next run.
