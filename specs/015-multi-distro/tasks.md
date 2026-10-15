# 015-multi-distro — tasks

One branch per phase, off `develop`, merged back when its gate passes.
**Gate for every phase:** all bats suites green, ShellCheck clean, Debian
behavior unchanged. A phase never starts a distro the previous phase
didn't prove. Gentoo goes first among the new distros, since it's the
maintainer's target.

## Phase 1 — OS detection (`feat/os-detect`)
- [x] T001 `tests/fixtures/os-release/{debian,ubuntu,gentoo,arch,fedora,alpine,unknown,malformed}`
- [x] T002 `lib/os.sh`: line parser (no `source`), `DOTTOD_OS_FAMILY`, `DOTTOD_PKG`, `DOTTOD_ARCH`, `DOTTOD_LIBC`; `ID` first, `ID_LIKE` only for listed families; manager presence check
- [x] T003 `tests/test-os.bats`: every fixture, unknown/malformed fail, `ID=fedora` without `dnf` fails
- [x] T004 `bin/utils.sh` sources `lib/`; nothing reads it yet (zero behavior change)

## Phase 2 — package backend (`feat/pkg-backend`)
- [x] T010 `lib/package.sh`: `_pkg_install` / `_pkg_is_installed` / `_pkg_candidate_version`; array args; manager stderr visible on failure
- [x] T011 apt backend at parity with today's `_install_packages` (fast path, no-recommends), minus the per-call list wipe; refresh once per run
- [x] T012 `_install_packages` becomes the wrapper; old string form still accepted
- [x] T013 `flock` lock + shared refresh stamp under `/tmp/dottod` (0600, no symlinks)
- [x] T014 gentoo backend (`emerge --noreplace --ask=n --autounmask=n`, `portageq`), no sync
- [x] T015 arch backend (`pacman -S --needed --noconfirm`, no lone `-Sy`)
- [x] T016 redhat backend (`dnf`, `rpm -q`)
- [x] T017 alpine backend (`apk add`, `apk info -e`)
- [x] T018 `tests/test-packages.bats` → per-backend argv/fast-path/failure/lock tests; unknown family invokes nothing

## Phase 3 — logical packages + mapping gate (`feat/pkg-mapping`)
- [x] T020 `lib/packages/<family>.sh` case-tables for every name tasks request today (see plan); `-` = unsupported
- [x] T021 callers switch to logical names: shell, fonts, vim, neovim, ssh, container, tools, cargo, bun, zed
- [x] T022 test: every logical name used in `bin/` has an entry in all five tables
- [x] T030 `tests/integration/pkg-resolve.sh`: inside a distro container, every mapped name resolves (apt-cache show / portageq best_visible / pacman -Si / dnf info / apk search -e) — the evidence for the mapping
- [x] T031 run T030 locally under Podman for all five; fix the tables until green

## Phase 4 — target user and core tasks (`feat/user-home`)
- [x] T040 `_dot_user_home <user>` via `getent passwd` (fallback: `$HOME` for the current user); no `eval ~user`
- [x] T041 shell, vim, neovim, ssh use it (drop the four `/home/<user>` constructions)
- [x] T042 `shell.sh`: verify `chsh` + `/etc/shells` before switching; clear manual hint otherwise
- [x] T043 tests: `/var/home/u`, missing user, non-root target

**Milestone G1 — Gentoo core, in a container.** ✅ containers, 2026-10-15 (`tests/integration/core-smoke.sh`; real Gentoo host still to do). stage3 + portage snapshot:
`bootstrap.sh --only shell,vim,gitconfig,ssh,fonts` twice, both pass,
second is a no-op. Then the same on a real Gentoo (VM or the laptop).
Same smoke on Arch, Fedora, Alpine, Debian before moving on.

## Phase 5 — neovim and toolchains (`feat/toolchain-distro`)
- [x] T050 neovim: candidate from `_pkg_candidate_version` (version / none / unknown — unknown never counts as too old); tarball healing stays opt-in and glibc-only
- [x] T051 libc in upstream asset choice; bun uses its musl asset on Alpine; rustup's musl target on Alpine
- [x] T052 `test-neovim.bats` / `test-toolchain.bats`: per-backend candidate states, musl paths

## Phase 6 — container (`feat/container-distro`)
- [ ] T060 `podman_rootless` logical set per family (uidmap / shadow); Alpine installs `shadow` before `usermod`
- [ ] T061 `container.sh status` + `dottod-doctor`: user namespaces, subids, cgroup v2 (OpenRC `rc_cgroup_mode` hint) as findings — never edited
- [ ] T062 tests for each finding; integration `podman-hello.sh` unchanged

## Phase 7 — tools and zed (`feat/tools-distro`)
- [ ] T070 `bat`/`batcat` and `fd`/`fdfind` aliases both directions; `.bat.utils.sh` and nvim health use whichever exists
- [ ] T071 `gh` extra: apt repo on Debian only, native package elsewhere
- [ ] T072 extras native-first where the distro ships them (lazygit, k9s…), upstream release otherwise, musl-checked
- [ ] T073 zed: refuse on musl with a reason; runnable check after install
- [ ] T074 Gentoo: warn before heavy builds; `-bin` atoms where available

## Phase 8 — CI (`ci/distro-matrix`)
- [ ] T080 `distro.yml`: L1 mapping gate per distro, path-filtered on `lib/**`, `bin/**`
- [ ] T081 scheduled L2 core smoke (Gentoo time-boxed), images pinned by digest
- [ ] T082 neutral dev-tool hints in `justfile` and `tests/run.sh`

## Phase 9 — docs and support claims (`docs/distributions`)
- [ ] T090 `docs/distributions.md`: support matrix from evidence only (L1/L2/L3 results), Gentoo/Arch policies, known limits
- [ ] T091 README prerequisites, `docs/containers.md`, `docs/neovim.md`, contracts (`needs_apt` → `uses_packages`), docs site (both locales)
- [ ] T092 `dottod-doctor` shows the detected distro/family/libc
- [ ] T093 final search for apt/dpkg/`/home/`/glibc assumptions; each survivor has a reason

Promotion of `develop` to `main` (and the 2.x release) is a separate
decision after Phase 9, or earlier if Gentoo core is wanted on `main`
sooner.
