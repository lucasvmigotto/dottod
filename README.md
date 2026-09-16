# dottod

Personal dotfiles and workstation bootstrap for Debian (GNOME). Reproducibly
recreates a [Spaceship](https://spaceship-prompt.sh/) Zsh environment (with a
system-info segment), fonts, editor, terminal, CLI tooling, and GitHub SSH
configuration after a reset or fresh install.

## Layout

```txt
bin/       executable bootstrap scripts (one per concern)
config/    dotfiles that get symlinked or templated into $HOME
scripts/   zsh utilities (aliases + functions) sourced by .zshrc
tui/       Ratatui TUI runner (Rust)
docs/      feature documentation (system-info, ssh, …)
tests/     shell test suites (run with ./tests/run.sh)
.github/   CI + release workflow
```

## Tasks

| Task        | Script            | What it does                                                        |
| ----------- | ----------------- | ------------------------------------------------------------------- |
| `shell`     | `bin/shell.sh`    | Installs zsh + oh-my-zsh + Spaceship prompt (+ system-info segment), links `~/.zshrc` |
| `fonts`     | `bin/fonts.sh`    | Installs Nerd Fonts (FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono) |
| `vim`       | `bin/vim.sh`      | Installs vim + vim-plug, links `~/.vimrc`, installs plugins         |
| `docker`    | `bin/docker.sh`   | Installs Docker Engine from the official apt repo                   |
| `desktop`   | `bin/desktop.sh`  | Installs GNOME system monitor, applies dark theme and fonts         |
| `vscode`    | `bin/vscode.sh`   | Installs VSCode from the Microsoft apt repo                         |
| `ghostty`   | `bin/ghostty.sh`  | Installs Ghostty and sets it as the default terminal                |
| `gitconfig` | `bin/gitconfig.sh`| Prompts for name/email and writes `~/.gitconfig`                    |
| `ssh`       | `bin/ssh.sh`      | Merges GitHub host config into `~/.ssh/config` (never overwrites)   |
| `tools`     | `bin/tools.sh`    | lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa  |

## Installation

### Prerequisites

- Debian (or Debian-based) system with `apt`.
- `sudo` or `doas`; if not passwordless, the scripts prompt once for the
  password (needs a TTY) — otherwise run as root.
- Rust toolchain only if you build the TUI from source.

### Option 1 — Git clone

Clone the repository and `cd` into it:

```bash
git clone https://github.com/lucasvmigotto/dottod.git
cd dottod
```

Then use either interface below.

#### Using the scripts only (no Rust needed)

Run the bootstrap orchestrator, which installs and configures everything:

```bash
./bin/bootstrap.sh
```

#### Using the TUI (needs Rust)

Build and run the interactive front-end:

```bash
cd tui
cargo run --release
```

### Option 2 — Prebuilt release (no Rust, no build)

Pick a version (e.g. `0.1.0`) and download the scripts, binary, and checksums:

```bash
V="0.1.0"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-scripts-${V}.tar.gz"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-linux-x86_64"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-${V}-sha256sums.txt"
```

Verify integrity (ignores assets you did not download, e.g. the source tarball):

```bash
sha256sum --ignore-missing -c "dottod-${V}-sha256sums.txt"
```

Extract the scripts and install the binary next to them (so the TUI can find
`bin/`, `config/`, and `scripts/` automatically):

```bash
mkdir -p ~/dottod
tar -xzf "dottod-scripts-${V}.tar.gz" -C ~/dottod      # → ~/dottod/bin/ + ~/dottod/config/ + ~/dottod/scripts/
install -m 0755 dottod-linux-x86_64 ~/dottod/dottod
```

Then use either interface below.

#### Using the scripts only

```bash
~/dottod/bin/bootstrap.sh
```

#### Using the TUI

```bash
~/dottod/dottod          # auto-detects ~/dottod/bin/, ~/dottod/config/, and ~/dottod/scripts/
```

Run it from anywhere with `--repo`, or via the `DOT_REPO_ROOT` variable, or by
adding the directory to your `PATH`:

```bash
~/dottod/dottod --repo ~/dottod
export DOT_REPO_ROOT="$HOME/dottod"
export PATH="$HOME/dottod:$PATH"
```

#### Release assets

Each release ships four assets:

- `dottod-tui-src-<v>.tar.gz` — TUI source (for building from source)
- `dottod-scripts-<v>.tar.gz` — bash scripts (`bin/` + `config/` + `scripts/`)
- `dottod-linux-x86_64` — compiled TUI binary
- `dottod-<v>-sha256sums.txt` — SHA256 checksums (also embedded in the release notes)

### Option 3 — Build the TUI from the source tarball

If you want to build the TUI yourself without git:

```bash
V=0.1.0
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-tui-src-${V}.tar.gz"
tar -xzf "dottod-tui-src-${V}.tar.gz"
cd tui
cargo build --release
# binary at: tui/target/release/dottod
```

## Usage

### Bash bootstrap

Run all tasks:

```bash
./bin/bootstrap.sh
```

Select or exclude tasks:

```bash
./bin/bootstrap.sh --only shell,tools
./bin/bootstrap.sh --skip docker,desktop
```

Flags:

- `--only <list>` — run only the given comma-separated tasks
- `--skip <list>` — skip the given comma-separated tasks
- `--no-ui-support` — skip GUI tasks (`desktop vscode ghostty`)
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
./tests/run.sh
```

Runs the shell test suites (system-info collector, Spaceship section, SSH
merge) against hermetic fixtures — the real `$HOME` and `/proc` are never
touched. Zsh suites print a skip note when zsh is not installed.

### Interactive TUI

The `dottod` binary mirrors `bootstrap.sh`'s flags:

```bash
dottod --no-ui-support --parallel
dottod --only shell,tools --repo ~/dottod
```

Keybindings:

- `j`/`k` or `↑`/`↓` — move
- `Space` — toggle task
- `a`/`n` — select all / none
- `u` — toggle the GUI task group (like `--no-ui-support`)
- `Enter` — run selected
- `Tab` / `h` / `l` — switch pane
- `PgUp`/`PgDn` — scroll log
- `r` — rerun failures (summary)
- `q` — quit

The TUI implementation in `tui/src/` (`app.rs`, `ui.rs`, `runner.rs`,
`scheduler.rs`, `state.rs`, `task.rs`) is the authoritative design reference.

## Configuration

Dotfiles live in `config/` and are symlinked or templated into `$HOME` by the
corresponding tasks. Edit them there and re-run the task to reapply.

* Prompt system metrics: see `docs/system-info.md` (collector tuning via
  `_DOT_SYSTEM_INFO_*`, display via `SPACESHIP_SYSINFO_*`).
* GitHub SSH: see `docs/ssh.md`; `config/.ssh.config` is the template of
  required options merged into `~/.ssh/config` by the `ssh` task.

## Design notes

- **Idempotent**: every task checks for an existing install before acting.
- **Failsafe**: `set -Eeuo pipefail`, per-task isolation, backup of existing
  dotfiles (suffixed `.dottod.bak`), curl retries, and a final PASS/FAIL summary.
- **Parallelism**: `--parallel` runs tasks concurrently; apt operations are
  serialized by dpkg's own lock.
- A Ratatui-based interactive runner lives in `tui/`.
