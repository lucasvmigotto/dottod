# 017-secrets — tasks

One branch per phase off `develop`; same gate as spec 015 (bats green,
ShellCheck/shfmt clean, each commit passing on its own).

## Phase 1 — prove the mechanism (`spike/secrets-helper`, nothing merged)
- [x] T170 Isolated run on the dev host: throwaway `GNUPGHOME` and
  `PASSWORD_STORE_DIR`, an `XDG_CONFIG_HOME` holding only the drop-in, a
  local `registry:2` with an htpasswd dummy user, and the official
  `docker-credential-pass` binary in the scratchpad. Prove: the drop-in is
  honoured, `podman login` stores through pass (the store gains an entry,
  no `auth.json` entry is written), a pull from that registry reads it
  back, `podman logout` removes it. Record the evidence in plan.md.

## Phase 2 — packages (`feat/secrets-packages`)
- [ ] T171 Logical names `pass` and `pass_credential_helper` in all five
  tables; resolve gate green on every distro (unsupported → `-` with the
  reason, never a guess).

## Phase 3 — the task (`feat/secrets-task`)
- [ ] T172 `bin/secrets.sh`: install, then check GPG secret key → store
  initialised for it → write the drop-in → remove plaintext `auths`
  entries (names logged); `status` action; never touches a secret value.
- [ ] T173 Opt-in in bootstrap: excluded from the default run, selected
  by `--only secrets`; listed in `--list`/`--help` and the contract.
- [ ] T174 Tests: no key / no store / ready / plaintext cleanup keeps the
  other keys and mode 0600 / rerun no-op / never prints a value.

## Phase 4 — doctor and docs (`docs/secrets`)
- [ ] T175 `dottod-doctor`: store state, helper wired, plaintext registry
  credentials warned (names only).
- [ ] T176 `docs/secrets.md`, README, site page in both locales, contract.

**Milestone S1 — this machine:** you create the key and run `pass init`,
`./bin/bootstrap.sh --only secrets`, then `podman login docker.io` and
`podman login dhi.io` (tokens typed by you); a `dhi.io` pull works.
