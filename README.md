# dottod

Personal dotfiles and workstation bootstrap for Debian (GNOME). Reproducibly
recreates a [Spaceship](https://spaceship-prompt.sh/) Zsh environment, fonts,
editor, terminal and CLI tooling after a reset or fresh install.

## Layout

```txt
bin/       executable bootstrap scripts (one per concern)
config/    dotfiles that get symlinked or templated into $HOME
docs/      design notes (Ratatui TUI plan)
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

## Usage

Run everything:

```sh
./bin/bootstrap.sh
```

Run a subset:

```sh
./bin/bootstrap.sh --only shell,tools
./bin/bootstrap.sh --skip docker,desktop
```

Useful flags:

- `--parallel` — run tasks concurrently instead of sequentially
- `--verbose` / `-v` — stream full output
- `--yes` — assume yes for prompts
- `--list` — list available tasks

Each script can also be run on its own, e.g. `./bin/fonts.sh FiraCode ZedMono`.

### Requirements

- Debian (or Debian-based) system with `apt`.
- `sudo` or `doas` available; bootstrap assumes passwordless sudo (or run as root).

## Configuration

Scripts are configurable via environment variables using the `_DOT_*` prefix,
e.g.:

```sh
_DOT_NERDFONT_VERSION=v3.5.0 ./bin/fonts.sh
```

Identity for `gitconfig` can be supplied non-interactively:

```sh
GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./bin/gitconfig.sh
```

## Design notes

- **Idempotent**: every task checks for an existing install before acting.
- **Failsafe**: `set -Eeuo pipefail`, per-task isolation, backup of existing
  dotfiles (suffixed `.dottod.bak`), curl retries, and a final PASS/FAIL summary.
- **Parallelism**: `--parallel` runs tasks concurrently; apt operations are
  serialized by dpkg's own lock.
- A Ratatui-based interactive runner is planned — see `docs/ratatui-plan.md`.
