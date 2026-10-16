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
pass insert -m openai/api-key       # -m: multi-line; the first line is the key
pass ls                             # names only
```

Registry logins made through `podman login` live under
`docker-credential-helpers/` — leave those to Podman.

## `pass-run`

```bash
pass-run GH_TOKEN=github/pat -- gh pr list
pass-run GH_TOKEN=github/pat NPM_TOKEN=npm/token -- ./release.sh
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
NPM_TOKEN=pass:npm/token
```

```console
$ loadenv
loadenv: 3 from .env: API_URL GH_TOKEN NPM_TOKEN (from pass: GH_TOKEN NPM_TOKEN)
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
pass-run X=github/pat -- true
```

## Example: the GitHub CLI

A token in pass, used by `gh` through `pass-run` — pull requests, issues
and workflow runs without the token ever sitting in a file or your shell.

### 1. A narrow token

On GitHub → Settings → Developer settings → Personal access tokens →
**Fine-grained tokens**, create one limited to the repositories it needs,
with the **narrowest permissions** that do the job — read-only (Contents,
Pull requests, Issues, Actions: Read) for looking things up — and the
**shortest expiry** that works for you.

```bash
pass insert github/pat               # paste it once; nowhere else
```

### 2. Use it through `pass-run`

`gh` reads `GH_TOKEN` from the environment, and it takes precedence over
any credentials stored by `gh auth login` — so there's no need to log `gh`
in at all (`gh auth login` would keep the token in its own config or
keyring, outside pass).

```bash
pass-run GH_TOKEN=github/pat -- gh pr list
pass-run GH_TOKEN=github/pat -- gh issue view 12
pass-run GH_TOKEN=github/pat -- gh run list --limit 5
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
