# dottod

Personal dotfiles and workstation bootstrap for Debian/Ubuntu, Gentoo,
Arch, Fedora and Alpine (see [docs/distributions.md](docs/distributions.md)
for what is verified where). Reproducibly
recreates a plain-bash terminal environment (lightweight prompt, no plugins),
fonts, editor, terminal, CLI tooling, container runtime
(Podman by default), and GitHub SSH configuration after a reset or fresh install.

## Layout

```txt
bin/       executable bootstrap scripts (one per concern)
config/    dotfiles that get symlinked or templated into $HOME
scripts/   shell utilities (aliases + functions)
docs/      feature documentation (ssh, containers, …) + docs site (`docs/site/`, deploys to the hub)
tests/     BATS test suites (run with ./tests/run.sh)
.github/   CI + release workflow
```

## Tasks

| Task        | Script            | What it does                                                        |
| ----------- | ----------------- | ------------------------------------------------------------------- |
| `shell`     | `bin/shell.sh`    | Ensures bash as login shell, links `~/.bashrc` (plain bash, no plugins) |
| `fonts`     | `bin/fonts.sh`    | Installs Nerd Fonts (FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono) |
| `vim`       | `bin/vim.sh`      | Installs vim + vim-plug, links `~/.vimrc`, installs plugins         |
| `neovim`    | `bin/neovim.sh`   | Installs Neovim (>= 0.11) + lazy.nvim config (zero external deps), links `~/.config/nvim` (see [docs/neovim.md](docs/neovim.md); vim stays untouched) |
| `container` | `bin/container.sh`| Container runtime: rootless Podman                                  |
| `zed`       | `bin/zed.sh`      | Installs the Zed editor (user-level, verified download; opt-in via `--ui`) |
| `gitconfig` | `bin/gitconfig.sh`| Prompts for name/email and writes `~/.gitconfig`                    |
| `ssh`       | `bin/ssh.sh`      | Merges GitHub host config into `~/.ssh/config` (never overwrites)   |
| `tools`     | `bin/tools.sh`    | btop, bat, xclip, jq, fzf, pv, shellcheck, bats, shfmt, just; opt-in extras via `--extras` |
| `cargo`     | `bin/cargo.sh`    | Rust toolchain via rustup (stable, minimal profile) |
| `bun`       | `bin/bun.sh`      | Bun JS runtime (direct-zip install, verified) |
| `secrets`   | `bin/secrets.sh`  | Opt-in (`--only secrets`): `pass` as the secret store, container registry logins through it, `pass-run`/`loadenv` for other secrets (see [docs/secrets.md](docs/secrets.md), [docs/secret-commands.md](docs/secret-commands.md)) |

## Installation

### Prerequisites

- Debian/Ubuntu, Gentoo, Arch, Fedora or Alpine; dottod detects it and uses
  its package manager (anything else is refused before any install). On
  Alpine, install `bash` first. See [docs/distributions.md](docs/distributions.md).
- `sudo` or `doas`; if not passwordless, the scripts prompt once for the
  password (needs a TTY) — otherwise run as root.
- BATS (`bats` package) only to run the shell test suites — not needed
  to install or use dottod itself.

### Option 1 — Git clone

Clone the repository and `cd` into it:

```bash
git clone https://github.com/lucasvmigotto/dottod.git
cd dottod
```

Then run the bootstrap orchestrator, which installs and configures everything:

```bash
./bin/bootstrap.sh
```

### Option 2 — Release scripts tarball (no git needed)

Pick a version (e.g. `0.1.0`) and download the scripts and checksums:

```bash
V="0.1.0"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-scripts-${V}.tar.gz"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-${V}-sha256sums.txt"
```

Verify integrity:

```bash
sha256sum -c "dottod-${V}-sha256sums.txt"
```

Extract and run:

```bash
mkdir -p ~/dottod
tar -xzf "dottod-scripts-${V}.tar.gz" -C ~/dottod      # → ~/dottod/bin/ + lib/ + config/ + scripts/
~/dottod/bin/bootstrap.sh
```

#### Release assets

Each release ships two assets:

- `dottod-scripts-<v>.tar.gz` — bash scripts (`bin/` + `lib/` + `config/` + `scripts/`)
- `dottod-<v>-sha256sums.txt` — SHA256 checksums (also embedded in the release notes)

## Usage

### Bash bootstrap

Run all tasks:

```bash
./bin/bootstrap.sh
```

Select or exclude tasks:

```bash
./bin/bootstrap.sh --only shell,tools
./bin/bootstrap.sh --skip fonts,cargo
./bin/bootstrap.sh --only vim,neovim
```

GUI tasks (`zed`) are skipped by default — the CLI is terminal-first.
Pass `--ui` to include them.

Opt-in tasks (`secrets`) never run by default; name them with `--only`.

The `tools` task installs only the native-package baseline. Extra tools
are opt-in (all off by default): `gh`, `httpie`, `chafa`, `fastfetch`, or
`all`:

```bash
./bin/bootstrap.sh --only tools --extras gh,httpie
DOT_TOOLS_EXTRA=all ./bin/tools.sh
```

Flags:

- `--only <list>` — run only the given comma-separated tasks
- `--skip <list>` — skip the given comma-separated tasks
- `--ui` — include GUI tasks (`zed`)
- `--extras <list>` — opt-in tools for the `tools` task (sets `DOT_TOOLS_EXTRA`)
- `--no-ui` — skip GUI tasks (the default; explicit form of omitting `--ui`)
- `--parallel` — run tasks concurrently instead of sequentially
- `--yes` — assume yes for prompts
- `--verbose` / `-v` — stream full output
- `--status` — print every selected task's read-only status report
  (honours `--only`, `--skip` and `--ui`); one task alone is
  `./bin/<task>.sh status`
- `--list` / `-l` — list available tasks

### Task runner

Day-to-day checks run through `just` (installed by the `tools` task):

```bash
just          # the gate: syntax + lint + format drift
just test     # hermetic bats suites
just fmt      # rewrite shell formatting in place
just site     # docs site typecheck + tests + lint
just smoke    # boot a pristine login shell and assert the surface
just doctor   # health report: tools, prompt, projects, updates, profiles
just --list   # every recipe
```

### Individual scripts

Each task can be run on its own; some accept arguments:

```bash
./bin/fonts.sh FiraCode ZedMono
./bin/gitconfig.sh
```

Identity for `gitconfig` can be supplied non-interactively:

```bash
GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./bin/gitconfig.sh
```

The global identity is the default everywhere. A machine where every
repository sets its own (a company laptop, say) can skip it:

```bash
GIT_GLOBAL_IDENTITY=0 ./bin/gitconfig.sh   # the rest of ~/.gitconfig, no user.*
```

#### Work repositories (`gwork`)

Store a work identity once (in `~/.gitconfig-work`, which nothing
includes) and give it to the repositories you choose — in their local
config, wherever they live:

```bash
GIT_WORK_NAME="You At Work" GIT_WORK_EMAIL="you@work.example.com" \
  ./bin/gitconfig.sh

gwork clone git@ssh.dev.azure.com:v3/org/project/repo   # clone as work, cd in
gwork clone https://gitlab.com/group/sub/repo.git api --depth 1
gwork set [dir]      # mark an existing checkout as work
gwork unset [dir]    # back to the global identity
gwork                # which identity this repo resolves, and from where
```

`gwork clone` hands the URL to `git clone` untouched, so any form git
accepts works — SSH (`git@host:path`, `ssh://`) or HTTPS, on Azure DevOps,
Bitbucket, GitLab, GitHub or your own host — and the clone lands where
`git clone` would put it. A failed clone configures nothing.
`GIT_WORK_NAME`/`GIT_WORK_EMAIL` in the environment take precedence over
the file.

`codes` shows each repository's context — **work** when the email git
resolves there is the work email, **personal** otherwise — and filters by
it: `codes --work`, `codes --personal`, `codes --by-context` (work first).

Repositories with a saved Claude Code conversation carry a sparkle
(nf-cod-sparkle, in Claude orange); `codes -c <name>` jumps there and runs
`claude -c`. `CODES_CLAUDE=0` hides the mark, `CODES_CLAUDE_GLYPH='*'`
replaces it (no Nerd Font).

#### Progress bars (`pv`)

`pv` is a core tool, and the shell loads shortcuts that put a bar with a
percentage and an ETA on long jobs:

```bash
pcp big.iso /media/usb/            # copy a file or a directory tree
ptar project                       # project.tar.zst (.tar.gz without zstd)
puntar backup.tar.gz restore/      # extract .tar.zst/.tar.gz/.tar.xz/.tar
psum debian.iso                    # sha256sum-style line (md5, sha512, b2…)
pdd debian.iso /dev/sdb            # write an image (.xz/.gz/.zst decompressed)
pchain dump.sql -- psql mydb       # feed a file into any command
find / -name '*.log' | pvl | wc -l # pvl = pv -l: count lines through a pipe
```

They never overwrite an existing target and remove a partial one when a
step fails. `extract` streams tar archives and single `.gz`/`.bz2`/`.xz`/
`.zst` files through `pv` too. `pdd` refuses a device with anything mounted (or used as
swap) and writes only after you type the device name back.

Scripts are configurable via `_DOT_*` environment variables:

```bash
_DOT_NERDFONT_VERSION=v3.5.0 ./bin/fonts.sh
```

### Claude profiles

The interactive shell offers named Claude Code profiles (`work`,
`personal`, …) over one shared store (`~/.claude` holds memory, skills,
projects; each `~/.claude-<name>` overlay keeps its own login, settings
and identity dirs). The fzf picker previews each profile's account, plan,
preferences, usage bars and reset times:

```bash
claude              # pick a profile (fzf) — defaults to personal headless
claude -P work      # one profile for this invocation (--profile works too)
claude-profile add extra   # new overlay (links shared store, own login)
claude-profile ls          # profiles with login state
claude-profile usage       # refresh and show every profile's 5h/7d usage
claude-profile init        # build every profile, repair split ones, seed the profiles memory
claude-profile consolidate # fold profiles' private history/projects into ~/.claude
```

First run builds the overlay; a fresh profile asks for `/login`. Configure
with `CLAUDE_PROFILE=<name>`, `CLAUDE_NO_PICKER=1`.

Usage numbers come from Claude Code itself: opening the picker refreshes
every logged-in profile whose numbers are older than five minutes, in the
background, through `claude -p /usage` (runs locally — no model turn, no
cost, no session saved). `ctrl-r` in the picker refreshes the highlighted
profile now. Each bar shows when it resets: the time left (`in 4h 12m`),
or the date when more than a day away. Settings are listed last, as
indented JSON with every `env` value and anything token-, key- or
secret-like masked. `CLAUDE_USAGE_REFRESH=0` turns the refresh off,
`CLAUDE_USAGE_TTL` changes the five minutes.

Moving a project directory would orphan its Claude sessions (they are
filed by path). `claude-mv` moves it and brings them along:

```bash
claude-mv --dry-run ~/codes/app ~/work/app   # what would change
claude-mv ~/codes/app ~/work/app             # mv + repoint the sessions
claude-mv --fixup ~/codes/app ~/work/app     # already moved by hand
```

It repoints, for the directory and every directory inside it, the
`projects/` folders (transcripts, memory), each transcript line's `cwd`,
the prompt history, every profile's `.claude.json` (and `~/.claude.json`)
and the `codes` visit list — conversation text stays as written. It
refuses while a Claude Code session works inside the directory, and
copies everything it rewrites to `~/.local/state/dottod/claude-mv/` first.

These stores are Claude Code internals, not a documented interface, so
`claude-mv` first checks they still look the way it expects (folder names
are the path with non-alphanumerics as `-`, compact `"cwd"` lines,
`.claude.json` and history fields) and refuses otherwise unless `--force`.
`dottod-doctor` runs the same checks under "claude internals" and names the
Claude Code version, so an upgrade that moves something shows up there first.

`claude -c` (`--continue`) or a bare `claude -r` (`--resume`) in a
directory with no saved conversation asks `Start a new one? [y/N]` instead
of stopping at Claude Code's "No conversation found": `y` launches without
the flag, the rest of the arguments kept; `-r <id>` is left to Claude Code. Without a terminal (scripts, pipes) the
arguments go through untouched.

### Tests

```bash
./tests/run.sh                  # everything fast (BATS)
bats tests/                     # BATS suites only (TAP output)
bats tests/test-container.bats  # one suite
```

| Suite | What | Needs |
| ----- | ---- | ----- |
| `tests/test-shell.bats` | bash task: linking, login shell, no plugin remnants | nothing (fixtures) |
| `tests/test-ssh-merge.bats` | GitHub SSH merge matrix | nothing (fixtures) + `ssh` for `-G` checks |
| `tests/test-container.bats` | runtime selection, ensure, errors, idempotency | nothing (stubs) |
| `tests/test-neovim.bats` | installer: version policy, backups, idempotency | nothing (stubs) |
| `tests/test-neovim-headless.bats` | config: headless startup, profiles, lockfile | `nvim` >= 0.11 + linked config (else skipped) |
| `tests/helpers.bash` | shared BATS assertions, loaded per suite | — |

Shell suites run against hermetic fixtures — the real `$HOME` and `/proc`
are never touched.

Real container lifecycles live apart in `tests/integration/` and run only
on request (they need an engine + network):

```bash
DOTTOD_TEST_INTEGRATION=1 ./tests/integration/docker-hello.sh
DOTTOD_TEST_INTEGRATION=1 ./tests/integration/podman-hello.sh
```

## Configuration

Dotfiles live in `config/` and are symlinked or templated into `$HOME` by the
corresponding tasks. Edit them there and re-run the task to reapply.

* Neovim: see `docs/neovim.md` — zero-dependency base setup, profiles
  (`DOTTOD_NVIM_PROFILE`), keymaps, `~/.config/nvim` backup policy and the
  `lua/dottod_local.lua` override mechanism. Vim remains a fully supported,
  separate task.
* GitHub SSH: see `docs/ssh.md`; `config/.ssh.config` is the template of
  required options merged into `~/.ssh/config` by the `ssh` task, which also
  generates an `ed25519` key at `~/.ssh/github` when none exists.
* Container runtime: see `docs/containers.md`; rootless Podman only.

## Design notes

- **Idempotent**: every task checks for an existing install before acting.
- **Failsafe**: `set -Eeuo pipefail`, per-task isolation, backup of existing
  dotfiles (suffixed `.dottod.bak`), curl retries, and a final PASS/FAIL summary.
- **Parallelism**: `--parallel` runs tasks concurrently; dottod serializes
  its own package transactions with a lock, and refreshes the package index
  once per run.
- **Terminal-first**: GUI tasks (`zed`) never run unless `--ui`
  is passed.
