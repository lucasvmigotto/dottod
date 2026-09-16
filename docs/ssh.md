# GitHub SSH configuration

The `ssh` task ensures a working `github.com` SSH client configuration
without ever destroying existing user configuration.

Desired logical configuration (`config/.ssh.config`, single source of
truth):

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github
    IdentitiesOnly yes
    AddKeysToAgent yes
    LogLevel VERBOSE
```

## Key provisioning

The configuration references `~/.ssh/github`. dottod never generates,
modifies, or prints private keys: that key is expected to be created or
provisioned by the user (or another secure process). If it is absent, the
bootstrap logs an informational hint and continues — a missing key is not
a failure. `AddKeysToAgent yes` only tells the client to offer the key to
a running agent; it does not start one.

## Behavior

**Case A — `~/.ssh/config` does not exist.** `~/.ssh/` is created
(mode `0700`) and the template installed verbatim (mode `0600`).

**Case B — `~/.ssh/config` already exists.** It is merged, never
overwritten:

1. The file is scanned for a `Host` line whose patterns include an exact,
   case-insensitive `github.com` token without wildcard characters
   (a double-quoted `"github.com"` counts — OpenSSH treats it identically;
   `Host *` and `Host *.example.com` do not count).
2. If found, only the required options missing from that (first) block are
   appended inside it, before the next `Host`/`Match` boundary.
3. If not found, the canonical block is appended exactly once.
4. If every required option is already present, the file is left
   byte-identical — no backup, no rewrite.

## Merge policy details

* **Non-destructive.** Existing values always win: a user `User deploy` or
  `IdentityFile ~/.ssh/id_rsa` is preserved; only absent keys are added.
  This is safe under OpenSSH semantics, where the first obtained value
  per option wins — appended keys can only fill gaps, never override.
* **Whole-key matching.** Keys match case-insensitively with a word
  boundary, so `User` never matches `UserKnownHostsFile`, and commented
  lines (`# User git`) never count as present.
* **Legacy migration.** Old dottod installs symlinked the template to
  `~/.ssh/config`; that symlink is replaced by a real merged file. A user
  symlink pointing anywhere else is preserved, and the merge is applied to
  the file it points at.
* **Idempotent.** Repeated runs produce no further changes and never
  duplicate the block.
* **Backup.** `<config>.dottod.bak` (copy, original preserved) is written
  only when an existing file is actually modified — consistent with the
  rest of dottod.
* **Permissions.** `~/.ssh` → `0700`, config → `0600`.

## Validation (no network needed)

Inspect the effective configuration OpenSSH computes:

```bash
ssh -G github.com | grep -iE '^(user|hostname|identityfile|identitiesonly|addkeystoagent|loglevel)'
```

Expected (among other lines): `user git`, `hostname github.com`,
`identityfile ~/.ssh/github`, `identitiesonly yes`, `loglevel VERBOSE`.
Note `ssh -G` canonicalizes `yes` to `true` (`addkeystoagent true`) —
that is display only; the file keeps `yes`.

To check a specific file instead of the live one:

```bash
ssh -G -F /path/to/config github.com
```

This never contacts github.com; it only parses local configuration.

## Files

* `bin/ssh.sh` — merge engine (`_merge_github_config`), permissions,
  key hint, and a warn-only `ssh -G -F` smoke test.
* `config/.ssh.config` — template and single source of truth for the
  required options (parsed by the merger, so the two cannot diverge).
* `tests/test-ssh-merge.sh` — matrix: no config, unrelated config,
  complete/partial/conflicting blocks, wildcards, case-insensitivity,
  `Match` boundaries, legacy/user symlinks, idempotency, permissions,
  backups, and `ssh -G -F` acceptance.
