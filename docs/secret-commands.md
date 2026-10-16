# Secrets in commands (`pass-run`, `loadenv`)

Once the [`secrets` task](secrets.md) has set up `pass`, any secret can
live in the store — personal access tokens, API keys — and reach a command
only when that command runs. Two tools do it:

- **`pass-run`** — one command, with secrets in its environment only.
- **`loadenv`** — a `.env` file whose secret lines point into the store.

Both read the **first line** of a store entry (pass's convention: the first
line is the secret, the rest is free-form notes), and neither ever prints a
value.

## Naming entries

Pick a path per secret, `<service>/<what>`:

```bash
pass insert github/pat              # prompts twice; nothing echoes
pass insert azure-devops/pat
pass insert -m openai/api-key       # -m: multi-line; the first line is the key
pass ls                             # names only
```

Registry logins made through `podman login` live under
`docker-credential-helpers/` — leave those to Podman.

## `pass-run`

```bash
pass-run GH_TOKEN=github/pat -- gh pr list
pass-run AZURE_DEVOPS_EXT_PAT=azure-devops/pat GH_TOKEN=github/pat -- ./release.sh
```

`pass-run VAR=store/path [VAR=store/path …] -- command [args…]`:

- each `VAR` is set to the entry's first line, **only in the environment of
  `command`** — not in your shell, not on the command line (where other
  users' `ps` could read it), not in your history;
- `pass-run` replaces itself with the command (`exec`), so its exit code is
  the command's;
- a missing or empty entry stops it before the command runs;
- variable names must be shell names; paths can't start with `-` or `/` or
  contain `..`.

It's a real program at `~/.local/bin/pass-run` (linked by the `secrets`
task), so scripts and non-interactive shells — AI agents included — can use
it, not only your interactive shell.

## `loadenv` with `pass:` values

`loadenv [file]` (default `.env`) exports `KEY=value` lines into your
current shell. A value written as `pass:store/path` is read from the store:

```bash
# .env — safe to keep next to the code: it names secrets, never holds them
API_URL=https://api.example.com
GH_TOKEN=pass:github/pat
AZURE_DEVOPS_EXT_PAT=pass:azure-devops/pat
```

```console
$ loadenv
loadenv: 3 from .env: API_URL GH_TOKEN AZURE_DEVOPS_EXT_PAT (from pass: GH_TOKEN AZURE_DEVOPS_EXT_PAT)
```

- The file is **data, never code**: no `$(…)`, no backticks, no `$VAR`
  expansion — a value is taken literally. Blank lines, `# comments`, an
  `export ` prefix and matching quotes around a value are fine.
- **All or nothing**: if a line is malformed or a `pass:` entry can't be
  read, nothing is exported and the line is named.
- It reports names, never values.

Prefer `pass-run` when only one command needs the secret: `loadenv` puts it
in your shell, where every later command can see it.

## Unlocking

Decrypting needs your GPG passphrase; gpg-agent caches it — 10 minutes
after last use, at most 2 hours, by default
(`default-cache-ttl 600`, `max-cache-ttl 7200` in `~/.gnupg/gpg-agent.conf`).
A graphical pinentry prompts on demand; in a terminal-only session,
`export GPG_TTY=$(tty)` first. To unlock ahead of time without printing
anything:

```bash
pass-run X=azure-devops/pat -- true
```

## Example: the Azure DevOps CLI

A PAT in pass, used by `az` through `pass-run` — work items, pull requests
and pipelines without the token ever sitting in a file or your shell.

### 1. A narrow PAT

In Azure DevOps → User settings → Personal access tokens
(`https://dev.azure.com/<org>/_usersSettings/tokens`), create one for your
organization with the **narrowest scopes** that do the job — read-only
(Work Items: Read, Code: Read, Build: Read) for looking things up — and the
**shortest expiry** that works for you.

```bash
pass insert azure-devops/pat         # paste it once; nowhere else
```

### 2. The `az` CLI, set up without the token

```bash
az extension add --name azure-devops
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>
```

Don't use `az devops login`: it saves the PAT in the extension's own
credential store, outside pass. The extension reads `AZURE_DEVOPS_EXT_PAT`
from the environment instead — exactly what `pass-run` provides. If you
also use `az login`, the extension tries that identity first; `az logout`
makes it use the PAT.

### 3. The commands

```bash
pass-run AZURE_DEVOPS_EXT_PAT=azure-devops/pat -- az boards work-item show --id 1234
pass-run AZURE_DEVOPS_EXT_PAT=azure-devops/pat -- az repos pr list --status active
pass-run AZURE_DEVOPS_EXT_PAT=azure-devops/pat -- az pipelines runs list --top 5
```

## From scripts and AI agents

`pass-run` works the same in a script or an agent's shell: the command
gets the secret, the caller sees only the command's output. One property
matters when something other than you chooses the command: `pass-run`
gives the secret to **whatever follows `--`** — `pass-run X=… -- env` would
print it. So when an agent may run `pass-run`, pin which commands it may
put after `--`, keep `pass show` closed to it, and rely on the token's
narrow scopes and short expiry as the real limit.

The guardrails for Claude Code (permission rules, instructions) live with
the other agent tooling in the `ai-gent` repository, not in dottod.
