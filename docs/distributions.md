# Distributions

dottod runs on **Debian/Ubuntu, Gentoo, Arch, Fedora and Alpine**. Every
task installs packages through one small layer (`lib/package.sh`) that
detects the distribution from `/etc/os-release` and uses its own package
manager, with each distro's real package names. Anything else is refused
before a single package command runs — there is no "try apt anyway".

```bash
dottod-doctor | grep distro     # what dottod detected on this machine
```

## What has been verified

Only what was actually run is claimed. Containers are throwaway images
(pinned in `tests/integration/distros.sh`), run twice to check that the
second run changes nothing; "host" means a real installed system.

| | Debian 13 | Ubuntu 24.04 | Gentoo (OpenRC) | Arch | Fedora 42 | Alpine 3.22 |
|---|---|---|---|---|---|---|
| Detection + package names resolve | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| shell, vim, gitconfig, ssh, fonts (twice) | ✅ container | names only | ✅ container | ✅ container | ✅ container | ✅ container |
| neovim ≥ 0.11 | ✅ via tarball¹ | names only | ✅ package 0.11.7 | ✅ package 0.12.6 | ✅ package 0.11.5 | ✅ package 0.11.1 |
| cargo (rustup) | ✅ | — | ✅ | ✅ | ✅ | ✅ musl toolchain |
| bun + devcontainer CLI (no Node.js) | ✅ verified | — | ✅ bun² | ✅ bun, verified² | ✅ bun, verified² | ✅ musl build, verified |
| tools + `gh` extra | ✅ gh from GitHub's apt repo | — | names only | ✅ | ✅ | ✅ |
| `fastfetch` extra | names only | ⛔ not packaged before 25.04 | names only | names only | names only | names only |
| container (rootless Podman) | ✅ host (status) | — | ⏳ laptop³ | — | rootful only⁴ | helpers + subids only⁴ |
| zed (`--ui`) | not run | — | not run | not run | not run | ⛔ unsupported (glibc builds only) |

¹ Debian 13 ships Neovim 0.10.4, below the floor: `_DOT_NVIM_ALLOW_TARBALL=1`
installs the verified official tarball instead.
² These runs predate the devcontainer-on-Bun change: Bun installed, the
Node-free devcontainer CLI was verified on Debian and Alpine only.
³ Real rootless Podman needs a real host: the Gentoo laptop is the
reference (watch the cgroup v2 line of `./bin/container.sh status`).
⁴ Nested Podman in a rootless container can't test rootless operation.

"names only" = every package dottod would install exists in that distro's
repositories, but the task itself was not run there.

## Per distribution

### Debian / Ubuntu
- `apt-get`, index refreshed once per bootstrap run.
- `gh` comes from GitHub's official apt repository (the distro's lags).
- `bat` and `fd` install as `batcat` and `fdfind`; dottod links `bat` and
  `fd` too.

### Gentoo
- `emerge --noreplace --ask=n --autounmask=n` with your own profile, USE
  flags and `EMERGE_DEFAULT_OPTS` (binhost, jobs) untouched.
- dottod **never syncs** and **never writes to `/etc/portage`**: a missing
  or masked package fails with emerge's own message — sync
  (`emaint sync -a`) or adjust `/etc/portage` yourself, then re-run.
- Packages may build from source; dottod says so before emerging. Heavy
  toolchains use prebuilt packages where Gentoo has them
  (`dev-util/shellcheck-bin`).
- OpenRC + rootless Podman needs cgroup v2: if
  `./bin/container.sh status` reports cgroup v1/hybrid, set
  `rc_cgroup_mode="unified"` in `/etc/rc.conf` and reboot (dottod only
  reports it).

### Arch
- `pacman -S --needed --noconfirm`; dottod never runs a lone `pacman -Sy`
  (partial upgrades are unsupported on Arch). If a package is not found,
  run `sudo pacman -Syu` first.
- Official repositories only — no AUR.

### Fedora
- `dnf install -y`; dnf manages its own metadata.

### Alpine
- `bash` must be installed first (`apk add bash`) — dottod is a bash
  program.
- musl: Bun and rustup use their musl builds; the official Neovim tarball
  and Zed are glibc-only, so Neovim comes from `apk` and Zed is skipped
  with a reason.
- There is no `chsh` by default: the shell task leaves the login shell
  as is and prints the `usermod -s` command to switch it.

## Checking it yourself

```bash
# package names resolve in each distro's repositories (no installs)
DOTTOD_TEST_INTEGRATION=1 tests/integration/pkg-resolve.sh gentoo arch
# the core bootstrap, twice, in throwaway containers (slow, network)
DOTTOD_TEST_INTEGRATION=1 tests/integration/core-smoke.sh alpine
```

Both run with Podman, capped at 3 GiB and 2 CPUs per container by default
(`DOT_IT_PODMAN_ARGS` changes it). CI runs the first on every change to
the package layer and the second weekly (`.github/workflows/distro.yml`).
The full evidence log lives in `specs/015-multi-distro/plan.md`.
