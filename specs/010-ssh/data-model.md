# 010-ssh — data model (merge states + keypair)

- Target `~/.ssh/config` (mode 600) vs template `config/.ssh.config`.
- States: missing → install-verbatim | complete → untouched (no backup)
  | unrelated-only → append-once (backup) | partial → add-missing-keys
  | conflicting-values → keep-user (never overwrite).
- Second run is always byte-identical (single `Host github.com`).
- Keypair `~/.ssh/github[.pub]` (ed25519, 600/644): absent → generated
  (`ssh-keygen -N ''`, comment `user@host`); either half present →
  untouched, never overwritten.
