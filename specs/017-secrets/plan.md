# 017-secrets — technical plan

## Evidence log

**T170 (2026-10-15)**, isolated on the Debian dev host: throwaway
`HOME`, `XDG_RUNTIME_DIR`, `GNUPGHOME` and `PASSWORD_STORE_DIR`; pass
1.7.4 and the official `docker-credential-pass` v0.9.10 (checksum
verified) in a scratch dir; a local `registry:2` with an htpasswd dummy
user; Podman 5.4.2.

| Step | Result |
|---|---|
| Drop-in under `XDG_CONFIG_HOME` | **ignored**: Podman reads user drop-ins from `$HOME/.config/containers/registries.conf.d` only |
| Drop-in at `$HOME/.config/containers/registries.conf.d/50-dottod-pass.conf` (`credential-helpers = ["pass"]`) | honoured |
| `podman login` | token stored as `docker-credential-helpers/<base64 registry>/<user>.gpg`; no `auth.json`, no `~/.docker/config.json` written |
| pull with the stored login | **failed** at first: rootless Podman runs the helper in its user namespace (uid 0), where gpg looks for `/run/user/0` and falls back to `$GNUPGHOME/S.gpg-agent` |
| + GnuPG socket redirect file `$GNUPGHOME/S.gpg-agent` (`%Assuan%` / `socket=/run/user/<uid>/gnupg/…/S.gpg-agent`) | pull **works**, decrypting through the user's own agent |
| `podman logout` | entry removed from the store; next pull: authentication required |

Consequences for the task:
- Write the drop-in at the fixed `$HOME/.config/...` path.
- Write the redirect file only when the user's agent socket lives under
  `/run/user/<uid>` (systemd/elogind sessions) and `~/.gnupg/S.gpg-agent`
  is not itself a socket; otherwise warn — never replace a live socket.
- A passphrase-protected key prompts through the user's own agent:
  graphical pinentry or a cached passphrase work; terminal pinentry needs
  `GPG_TTY` — confirm in Milestone S1.

**T171 (2026-10-15)**, resolve gate on the pinned images:

| | pass | docker-credential-pass |
|---|---|---|
| debian / ubuntu | `pass` 1.7.4 | `golang-docker-credential-helpers` 0.6.4 |
| gentoo | `app-admin/pass` 1.7.4-r5 | `app-containers/docker-credential-helpers` 0.9.8 — builds the pass helper only with `USE=pass` (no flag on by default) |
| arch | `pass` 1.7.4 | not in the official repos (AUR only) → unsupported |
| fedora | `pass` 1.7.4 | not packaged → unsupported |
| alpine | `pass` 1.7.4 | not packaged → unsupported |

Debian's helper (0.6.4) is older than the one proven in T170 (0.9.10):
Milestone S1 on this Debian host exercises it directly.

**Milestone S1 (2026-10-15)**, the maintainer's Debian 13 host, real setup:
the maintainer created an ed25519 key and ran `pass init`, then
`./bin/bootstrap.sh --only secrets` (Debian `golang-docker-credential-helpers`
0.6.4), `podman login docker.io` and `podman login dhi.io`.
- `secrets.sh status`: key, store, helper, drop-in and redirect in place;
  no plaintext registry credentials anywhere.
- The store holds `docker-credential-helpers/<registry>/lucasvmigotto`
  for docker.io and dhi.io; no containers `auth.json` exists.
- `podman pull dhi.io/bun:1-debian13-dev` (login required) succeeds,
  decrypting through the user's own agent with its cached passphrase;
  Debian's older 0.6.4 helper behaves like the 0.9.10 proven in T170.
