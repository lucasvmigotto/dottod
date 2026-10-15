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
