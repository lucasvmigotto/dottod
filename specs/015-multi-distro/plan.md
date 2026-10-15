# 015-multi-distro — technical plan

## Where Debian is baked in today (develop @ d1d6b3c)

Smaller than the original audit suggests: every task already goes through
one helper, and that helper already has a hook for a pluggable backend.

| Place | Coupling | Disposition |
|---|---|---|
| `bin/utils.sh:201` `_install_packages` | `dpkg-query` fast path, `apt-get update` per call, stderr hidden, `rm -rf /var/lib/apt/lists/*` per call | becomes a wrapper over `lib/package.sh`; already probes `_pkg_install` (`bin/utils.sh:228`) |
| `bin/utils.sh:270` `_is_dpkg_installed` | dpkg | replaced by `_pkg_is_installed` per backend |
| `bin/neovim.sh:81` `_nvim_apt_candidate` | `apt-cache policy` | `_pkg_candidate_version neovim` (version / none / unknown) |
| `bin/neovim.sh:135`, `bin/shell.sh:36`, `bin/ssh.sh:29`, `bin/vim.sh:9` | `/home/<user>` | one `_dot_user_home` helper (passwd via `getent`) |
| `bin/shell.sh:27` | `chsh` unconditionally | check `chsh` exists and bash is in `/etc/shells`; precise manual hint otherwise |
| `bin/container.sh:51` | `usermod --add-subuids` | keep on glibc distros (shadow ships it everywhere incl. Gentoo); Alpine needs `shadow` installed first |
| `bin/tools.sh:131-149` | gh via GitHub apt repo | Debian only; native `gh` package elsewhere (still opt-in) |
| `bin/tools.sh:189`, `scripts/.bat.utils.sh:3` | `batcat` (Debian's name) | alias whichever of `bat`/`batcat` exists, both directions |
| `config/nvim/.../health.lua:49`, `navigation.lua:72` | `fd-find`/`fdfind` hints | distro-neutral hint; `fdfind` probe stays |
| `bin/utils.sh:339` `_go_arch`/`_rust_arch` | arch only | add libc to asset selection where it matters |
| `justfile:73`, `tests/run.sh:26` | apt hints for dev tools | neutral hints; dev bootstrap stays a convenience |
| `.github/workflows/*` | `apt-get` on ubuntu runners | fine (CI host, not product); new distro matrix runs in containers |
| tests: `test-packages.bats`, `test-neovim.bats` | dpkg/apt-cache stubs | become per-backend stub suites |

## Architecture

```
bin/<task>.sh ──► bin/utils.sh (unchanged public API: _install_packages, _priv, log_*)
                      │ sources
                      ▼
                  lib/os.sh        detection: DOTTOD_OS_FAMILY, DOTTOD_PKG, DOTTOD_ARCH, DOTTOD_LIBC
                  lib/package.sh   _pkg_install/_pkg_is_installed/_pkg_candidate_version + lock
                  lib/packages/{debian,gentoo,arch,redhat,alpine}.sh
                                   one case-table per family: logical name → package(s) | - (unsupported)
```

- Tasks keep calling `_install_packages`; callers move to **logical
  names** (`openssh_client`, `podman_rootless`, `fd`), resolved per
  family. A logical name with no entry is a **bug** (test fails); `-`
  means deliberately unsupported (optional callers skip with reason,
  required callers fail).
- Arguments become arrays (`_install_packages git vim curl`); the
  single-string form stays accepted during migration.
- **Fail closed:** unknown family or missing manager errors before any
  package command. The apt branch only runs when detection says debian.
- Test seams: `_DOT_OS_RELEASE_FILE`, `_DOT_NO_PACKAGES=1` (kept).
  No user-facing distro override.
- `os-release` is parsed line by line (KEY=value, quotes stripped),
  never `source`d.

## Backend policy

| Family | Install | Installed? | Candidate | Refresh policy |
|---|---|---|---|---|
| debian | `apt-get install -y --no-install-recommends` (`DEBIAN_FRONTEND` scoped to the call) | `dpkg-query` | `apt-cache policy` | one `apt-get update` per bootstrap run (lock-guarded stamp), not per call; no list wipe |
| gentoo | `emerge --noreplace --ask=n --autounmask=n` | `portageq has_version / <atom>` | `portageq best_visible / <atom>` | **never** syncs; tells the user to `emaint sync` if an atom is missing |
| arch | `pacman -S --needed --noconfirm` | `pacman -Q` | `pacman -Si` | **never** `-Sy` alone (partial upgrades); on a stale db, fail with "run pacman -Syu" |
| redhat | `dnf install -y` | `rpm -q` | `dnf repoquery --latest-limit 1` | dnf's own metadata expiry |
| alpine | `apk add` | `apk info -e` | `apk policy` | `apk update` once per run |

Gentoo specifics (the primary target):
- `--autounmask=n` makes a needed USE/keyword change fail with emerge's
  own message instead of writing to `/etc/portage`. dottod prints the
  atom and stops; the user decides.
- Source builds are slow: the tools task warns before a large emerge,
  and the mapping prefers `-bin` variants where Gentoo ships them for
  heavy toolchains (e.g. ShellCheck is Haskell). The user's binhost
  settings (`--getbinpkg` in `EMERGE_DEFAULT_OPTS`) apply untouched.
- OpenRC + rootless Podman: package install is not readiness. The
  container status reports kernel user namespaces, subids and the
  cgroup mode (`rc_cgroup_mode` in `/etc/rc.conf`) as findings; dottod
  never edits them.

## Locking

`flock` on a dottod lock file (`/tmp/dottod/pkg.lock`, created 0600 by
the running user, refusing symlinks) wraps refresh + install. util-linux
provides `flock` on glibc distros, BusyBox on Alpine. The refresh stamp
lives next to it so `--parallel` children share one refresh.

## Package mapping

Names are **hypotheses until the resolve gate passes** (T030). Gentoo
atoms especially must be confirmed with `portageq best_visible` in the
stage3 + portage-tree container, not from memory.

## Testing levels

1. **L0 hermetic** (every PR): bats with fixtures and stubbed managers —
   detection, argv per backend, error propagation, lock, home resolution.
2. **L1 mapping gate** (PR, path-filtered): one container per distro
   resolves every mapped name — fast, no installs.
3. **L2 core smoke** (manual/scheduled): `bootstrap.sh --only
   shell,vim,gitconfig,ssh` twice in each container, idempotency checked.
   Gentoo: stage3 + portage snapshot, time-boxed.
4. **L3 real host**: Debian (current machine) and Gentoo (laptop/VM)
   full bootstrap, run by the maintainer.

Containers run under the local Podman (`docker.io/gentoo/stage3`,
`archlinux`, `fedora`, `alpine`, `debian`), pinned by digest in CI.

## Risks
- Wrong package names → caught by L1 before any user sees them.
- Arch partial upgrades → never refresh alone; fail with the remedy.
- Gentoo build time / USE conflicts → `--autounmask=n`, warnings, `-bin`.
- musl → libc in asset selection; skip, never fake success.
- Debian regression → Debian stays the reference; L0 suites keep their
  current assertions as the apt-backend suite.

## Evidence log

**Phase 2 (2026-10-15)**, real managers in containers, backend from
`lib/package.sh` (install twice, then candidate lookup):

| Image | Detected | Install | Second run | neovim candidate |
|---|---|---|---|---|
| debian:trixie | debian/apt-get/glibc | ok | skipped | 0.10.4 (below floor: tarball healing still needed) |
| fedora:42 | redhat/dnf/glibc | ok | skipped | 0.11.5 |
| archlinux:latest | arch/pacman/glibc | `target not found` on a fresh image (empty sync db; dottod never runs `-Sy`), ok after `pacman -Syu` | skipped | 0.12.6 |
| alpine:3.22 (+bash) | alpine/apk/musl | ok | skipped | 0.11.1 |
| gentoo/stage3 + portage | gentoo/emerge/glibc | ok (`app-misc/jq` + dep built from source) | skipped | 0.11.7 |

Learned:
- Gentoo's real os-release single-quotes every value (`ID='gentoo'`);
  the fixture now matches it.
- `portageq has_version / jq` (no category) returns 1 without telling
  absent from invalid: the Gentoo table must use full `category/name`
  atoms (phase 3).
- Alpine needs `bash` before dottod can run at all: a documented
  prerequisite, not something dottod can install for itself.
- Container recipes for L1/L2: Arch needs `pacman -Syu` first; Gentoo
  needs the portage image run once (`podman run --name dottod-portage
  gentoo/portage`) and `--volumes-from` it, since an image mount lands the
  whole image root at the destination.

**Phase 3 (2026-10-15)**, `DOTTOD_TEST_INTEGRATION=1
tests/integration/pkg-resolve.sh`: every logical package in
`DOT_PKG_LOGICAL` (27) resolves in the real repository of debian:trixie,
ubuntu:24.04, fedora:42, archlinux, alpine:3.22 and gentoo stage3 +
portage (stable amd64 keywords; nothing masked or `~amd64`).

The first run caught four names written from memory; each fix was
confirmed against the repository itself:

| Logical | Distro | Wrong guess | Real package |
|---|---|---|---|
| shfmt | gentoo | dev-util/shfmt | dev-util/sh (mvdan.cc/sh, ships shfmt) |
| bats | arch | bash-bats | bats |
| openssh_client | alpine | openssh-client | openssh-client-default |
| podman_rootless | alpine | shadow-uidmap | shadow (usermod) + shadow-subids (newuidmap, /etc/subuid) |

Gentoo picks: `dev-util/shellcheck-bin` (0.11.0, avoids a GHC build),
`app-editors/neovim` 0.11.7 (meets the 0.11 floor from the package).

**Phase 4 / milestone G1 (2026-10-15)**, `DOTTOD_TEST_INTEGRATION=1
tests/integration/core-smoke.sh`: real `bootstrap.sh --only
shell,vim,gitconfig,ssh,fonts` twice per container, as root.

| Distro | Packages installed (run 1) | Login shell | Run 2 |
|---|---|---|---|
| debian:trixie | git curl ca-certificates, fontconfig unzip, vim | bash | no installs, no downloads, no file changed |
| arch (synced) | git, fontconfig unzip, vim, openssh | bash (/usr/bin/bash) | same |
| fedora:42 | git, fontconfig unzip, vim-enhanced | bash | same |
| alpine:3.22 (+bash) | git curl ca-certificates, fontconfig, vim, openssh-client-default | stays /bin/sh: no chsh, warning gives `usermod -s` | same |
| gentoo stage3 | dev-vcs/git, media-libs/fontconfig, app-editors/vim (built from source) | bash | same |

Found on the way (pre-existing, all distros): every run re-downloaded
all Nerd Fonts. `fc-list | grep -q` under pipefail failed whenever grep
exited early (SIGPIPE), and `NerdFontsSymbolsOnly` registers as "Symbols
Nerd Font". Info-ZIP unzip keeps archive mtimes, which hid it; BusyBox
unzip on Alpine exposed it. Fixed in bin/fonts.sh with a regression test;
the smoke now also checks "run 2 downloaded nothing".

Known noise, not a failure: `vim PlugInstall reported errors` comes from
vim-plug's status buffer mappings (E31) in headless `-es` mode; all 19
plugins install.

**Phase 5 (2026-10-15)**, real `bootstrap.sh --only neovim,cargo,bun` in
containers:

| Distro | Neovim | Rust host | Bun |
|---|---|---|---|
| debian:trixie | candidate 0.10.4 < 0.11 → package skipped, verified tarball 0.12.5 (`_DOT_NVIM_ALLOW_TARBALL=1`) | x86_64-unknown-linux-gnu | 1.4.3, verified |
| alpine:3.22 | package 0.11.1 | x86_64-unknown-linux-musl | 1.4.3 musl build, verified, runs |
| arch, fedora | packages 0.12.6 / 0.11.5 | gnu | 1.4.3 |
| gentoo | package 0.11.7, built from source (rerun capped: `--memory 3g --cpus 2`, `MAKEOPTS=-j2`, `--jobs=1`; the first, uncapped run exhausted the 7.5 GiB host) | gnu | 1.4.3 |

The first run found five problems, all fixed with tests:
- `nvim --version | head -n1` under pipefail failed on Alpine (SIGPIPE),
  the fonts bug again; every early-exit pipe reader in `bin/` and `lib/`
  is gone, and a static test forbids new ones.
- A fresh Debian has no apt lists, so the candidate read "none" and
  0.10.4 got installed: the index is now refreshed before the lookup.
- The tarball path ran curl without installing it, and parses the GitHub
  API with python3 (Neovim publishes no checksum file): both are now
  prerequisites (`curl ca_certificates tar python3`).
- Bun's checksum came from the API through python3, absent on minimal
  images, so it always installed unverified: now from the release's
  `SHASUMS256.txt` (curl only; mirrors verify too).
- Bun's musl build needs `libgcc`/`libstdc++` (`cxx_runtime`), absent on
  base Alpine; the new runnable check caught it.

**Follow-up (2026-10-15): devcontainer CLI without Node.js.** On Gentoo
the bun task went on to compile `net-libs/nodejs`, only because the
devcontainer CLI launcher is `#!/usr/bin/env node`. Bun runs the CLI
itself: `read-configuration` output is byte-identical under Node and
`bun --bun`, and `devcontainer up` + `exec` work under Bun with Podman.
The task now writes a `~/.local/bin/devcontainer` wrapper (`bun --bun`),
and `nodejs` left the package tables. The same runs found Bun's checksum
lookup ran before its prerequisites, so a fresh system without curl
installed Bun unverified; prerequisites now come first. Verified on
debian:trixie and alpine:3.22: Bun sha256-verified, devcontainer 0.89.0
on Bun, no Node.js installed.

**Phase 6 (2026-10-15)**, container task in containers (2 GiB / 2 CPU):

| Distro | Install | Rootless helpers | Status |
|---|---|---|---|
| alpine:3.22 | `podman shadow shadow-subids` in one transaction | usermod + newuidmap present; root got `100000:65536` | all four host checks ok |
| fedora:42 | `podman` (helpers already in the base) | usermod + newuidmap present | Podman usable (rootful as root) |

Nested Podman inside a rootless container is not a meaningful rootless
test; the real check is milestone G2 on the Gentoo laptop (OpenRC:
watch the cgroup v2 finding and its `rc_cgroup_mode` hint).

Status and `dottod-doctor` (only where podman is installed) report user
namespaces, subid ranges, newuidmap and cgroup v2, read-only. When every
host check passes but Podman still fails, the task prints `podman info`'s
own error; as root, status says rootful and skips rootless checks.

Found on the way: `tests/test-container.bats` ran with errexit off, so
every assertion but a test's last could fail silently. Turning it back on
exposed "ensure fails when podman is missing" passing through a host
`/usr/bin/podman`. Three more suites now re-arm bats' trap. The status
suite's "writes nothing" check depended on the host's real cargo and
podman; it now stubs them.

**Phase 7 (2026-10-15)**, `bootstrap.sh --only tools --extras gh` in
containers (2 GiB / 2 CPU):

| Distro | gh | bat names |
|---|---|---|
| debian:trixie | official apt repository → 2.102.0 | `bat` linked to `batcat` |
| arch | `github-cli` package → 2.102.0 | `batcat` linked to `bat` |
| fedora:42 | `gh` package → 2.87.3 | `batcat` linked to `bat` |
| alpine:3.22 | `github-cli` package → 2.72.0 | `batcat` linked to `bat` |

lazygit, lazydocker, k9s and resterm were dropped at the maintainer's
request, and with them every upstream-release download in `tools.sh`
(the python3-dependent digest lookup and an early-exit `head` pipe that
the per-line guard could not see). Zed now skips musl with a reason and
must run after install; emerge warns before source builds.

**Phase 8 (2026-10-15).** `.github/workflows/distro.yml`: the resolve
gate per distro on PRs/pushes touching the package layer, and the core
smoke weekly + on demand (Gentoo time-boxed at 120 min). Images are pinned
by digest in `tests/integration/distros.sh`; containers default to
`--memory 3g --cpus 2` locally (`DOT_IT_PODMAN_ARGS=''` on CI runners).
The shell/neovim/docs-ci/container workflows triggered on pushes to the
stale `dev` branch; they now watch `develop`. `just tools` installs the
dev toolchain through dottod's own package layer (verified on Alpine and
Fedora). Not yet run on GitHub: the first push of `develop` will be the
first CI run of the new workflow.
