# dottod

Personal dotfiles and workstation bootstrap for Debian (GNOME). Reproducibly
recreates a [Spaceship](https://spaceship-prompt.sh/) Zsh environment, fonts,
editor, terminal and CLI tooling after a reset or fresh install.

## Layout

```txt
bin/       executable bootstrap scripts (one per concern)
config/    dotfiles that get symlinked or templated into $HOME
scripts/   zsh utilities (aliases + functions) sourced by .zshrc
tui/       Ratatui TUI runner (Rust)
docs/      design notes (Ratatui TUI plan)
.github/   CI + release workflow
```

## Tasks

| Task        | Script            | What it does                                                        |
| ----------- | ----------------- | ------------------------------------------------------------------- |
| `shell`     | `bin/shell.sh`    | Installs zsh + oh-my-zsh + Spaceship prompt, links `~/.zshrc`       |
| `fonts`     | `bin/fonts.sh`    | Installs Nerd Fonts (FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono) |
| `vim`       | `bin/vim.sh`      | Installs vim + vim-plug, links `~/.vimrc`, installs plugins         |
| `docker`    | `bin/docker.sh`   | Installs Docker Engine from the official apt repo                   |
| `desktop`   | `bin/desktop.sh`  | Installs GNOME system monitor, applies dark theme and fonts         |
| `vscode`    | `bin/vscode.sh`   | Installs VSCode from the Microsoft apt repo                         |
| `ghostty`   | `bin/ghostty.sh`  | Installs Ghostty and sets it as the default terminal                |
| `gitconfig` | `bin/gitconfig.sh`| Prompts for name/email and writes `~/.gitconfig`                    |
| `tools`     | `bin/tools.sh`    | lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa  |

## Installation

### Prerequisites

- Debian (or Debian-based) system with `apt`.
- `sudo` or `doas`; if not passwordless, the scripts prompt once for the
  password (needs a TTY) — otherwise run as root.
- Rust toolchain only if you build the TUI from source.

### Option 1 — Git clone

Clone the repository and `cd` into it:

```sh
git clone https://github.com/lucasvmigotto/dottod.git
cd dottod
```

Then use either interface below.

#### Using the scripts only (no Rust needed)

Run the bootstrap orchestrator, which installs and configures everything:

```sh
./bin/bootstrap.sh
```

#### Using the TUI (needs Rust)

Build and run the interactive front-end:

```sh
cd tui
cargo run --release
```

### Option 2 — Prebuilt release (no Rust, no build)

Pick a version (e.g. `0.1.0`) and download the scripts, binary, and checksums:

```sh
V=0.1.0
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-scripts-${V}.tar.gz"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-linux-x86_64"
curl -fsSLO "https://github.com/lucasvmigotto/dottod/releases/download/${V}/dottod-${V}-sha256sums.txt"
```

Verify integrity (ignores assets you did not download, e.g. the source tarball):

```sh
sha256sum --ignore-missing -c "dottod-${V}-sha256sums.txt"
```

Extract the scripts and install the binary next to them (so the TUI can find
`bin/` and `config/` automatically):

```sh
mkdir -p ~/dottod
tar -xzf "dottod-scripts-${V}.tar.gz" -C ~/dottod      # → ~/dottod/bin/ + ~/dottod/config/
install -m 0755 dottod-linux-x86_64 ~/dottod/dottod
```

Then use either interface below.

#### Using the scripts only

```sh
~/dottod/bin/bootstrap.sh
```

#### Using the TUI

```sh
~/dottod/dottod          # auto-detects ~/dottod/bin/ and ~/dottod/config/
```

Run it from anywhere with `--repo`, or via the `DOT_REPO_ROOT` variable, or by
adding the directory to your `PATH`:

```sh
~/dottod/dottod --repo ~/dottod
export DOT_REPO_ROOT="$HOME/dottod"
export PATH="$HOME/dottod:$PATH"
```

#### Release assets

Each release ships four assets:

- `dottod-tui-src-<v>.tar.gz` — TUI source (for building from source)
- `dottod-scripts-<v>.tar.gz` — bash scripts (`bin/` + `config/`)
- `dottod-linux-x86_64` — compiled TUI binary
- `dottod-<v>-sha256sums.txt` — SHA256 checksums (also embedded in the release notes)

### Option 3 — Build the TUI from the source tarball

If you want to build the TUI yourself without git:

```sh
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

```sh
./bin/bootstrap.sh
```

Select or exclude tasks:

```sh
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

```sh
./bin/fonts.sh FiraCode ZedMono
./bin/gitconfig.sh
```

Identity for `gitconfig` can be supplied non-interactively:

```sh
GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./bin/gitconfig.sh
```

Scripts are configurable via `_DOT_*` environment variables:

```sh
_DOT_NERDFONT_VERSION=v3.5.0 ./bin/fonts.sh
```

### Interactive TUI

The `dottod` binary mirrors `bootstrap.sh`'s flags:

```sh
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

See `docs/ratatui-plan.md` for the full design.

## Configuration

Dotfiles live in `config/` and are symlinked or templated into `$HOME` by the
corresponding tasks. Edit them there and re-run the task to reapply.

## Design notes

- **Idempotent**: every task checks for an existing install before acting.
- **Failsafe**: `set -Eeuo pipefail`, per-task isolation, backup of existing
  dotfiles (suffixed `.dottod.bak`), curl retries, and a final PASS/FAIL summary.
- **Parallelism**: `--parallel` runs tasks concurrently; apt operations are
  serialized by dpkg's own lock.
- A Ratatui-based interactive runner lives in `tui/` — see `docs/ratatui-plan.md`.
