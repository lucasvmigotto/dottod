# dottod

Personal dotfiles and workstation bootstrap for Debian (GNOME). Reproducibly
recreates a plain-bash terminal environment (lightweight prompt, no plugins),
fonts, editor, terminal, CLI tooling, container runtime
(Podman by default), and GitHub SSH configuration after a reset or fresh install.

## Layout

```txt
bin/       executable bootstrap scripts (one per concern)
config/    dotfiles that get symlinked or templated into $HOME
scripts/   shell utilities (aliases + functions)
docs/      feature documentation (ssh, containers, …)
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
| `container` | `bin/container.sh`| Container runtime: Podman by default, Docker when selected          |
| `zed`       | `bin/zed.sh`      | Installs the Zed editor (user-level, verified download)             |
| `ghostty`   | `bin/ghostty.sh`  | Installs Ghostty and sets it as the default terminal                |
| `gitconfig` | `bin/gitconfig.sh`| Prompts for name/email and writes `~/.gitconfig`                    |
| `ssh`       | `bin/ssh.sh`      | Merges GitHub host config into `~/.ssh/config` (never overwrites)   |
| `tools`     | `bin/tools.sh`    | lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa, fzf, gh |
| `cargo`     | `bin/cargo.sh`    | Rust toolchain via rustup (stable, minimal profile) |
| `bun`       | `bin/bun.sh`      | Bun JS runtime (direct-zip install, verified) |

## Installation

### Prerequisites

- Debian (or Debian-based) system with `apt`.
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
tar -xzf "dottod-scripts-${V}.tar.gz" -C ~/dottod      # → ~/dottod/bin/ + ~/dottod/config/ + ~/dottod/scripts/
~/dottod/bin/bootstrap.sh
```

#### Release assets

Each release ships two assets:

- `dottod-scripts-<v>.tar.gz` — bash scripts (`bin/` + `config/` + `scripts/`)
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
./bin/bootstrap.sh --skip ghostty,zed
./bin/bootstrap.sh --only vim,neovim
```

GUI tasks (`zed`, `ghostty`) are skipped by default — the CLI is
terminal-first. Pass `--ui` to include them.

Flags:

- `--only <list>` — run only the given comma-separated tasks
- `--skip <list>` — skip the given comma-separated tasks
- `--ui` — include GUI tasks (`zed ghostty`)
- `--no-ui` — skip GUI tasks (the default; explicit form of omitting `--ui`)
- `--parallel` — run tasks concurrently instead of sequentially
- `--yes` — assume yes for prompts
- `--verbose` / `-v` — stream full output
- `--list` / `-l` — list available tasks

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

Scripts are configurable via `_DOT_*` environment variables:

```bash
_DOT_NERDFONT_VERSION=v3.5.0 ./bin/fonts.sh
```

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
* Container runtime: see `docs/containers.md`; Podman by default, Docker via
  `_DOT_CONTAINER_RUNTIME=docker` (or `--runtime docker`); `bin/docker.sh`
  stays directly runnable for Docker-only setups.

## Design notes

- **Idempotent**: every task checks for an existing install before acting.
- **Failsafe**: `set -Eeuo pipefail`, per-task isolation, backup of existing
  dotfiles (suffixed `.dottod.bak`), curl retries, and a final PASS/FAIL summary.
- **Parallelism**: `--parallel` runs tasks concurrently; apt operations are
  serialized by dpkg's own lock.
- **Terminal-first**: GUI tasks (`zed`, `ghostty`) never run unless `--ui`
  is passed.
