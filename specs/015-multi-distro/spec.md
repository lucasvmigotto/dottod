# 015 — multi-distro support (Debian, Gentoo, Arch, Fedora, Alpine)

Supersedes the loose `dottod-multi-distro-revised.md` (audited against
1.8.0, before Docker, Ghostty and OpenCode were removed). Its research
is kept where still true; everything about `docker.sh`, `ghostty.sh`,
`--runtime` and "Docker explicit" no longer applies.

## Why

The maintainer is moving their laptop to **Gentoo (OpenRC, desktop)**.
dottod is Debian-only today. All five families are in scope, but
**focus and quality come first**: each distro lands as its own slice,
behind the same small seam, with evidence before any support claim.

## Stories
- US1: As a user on Debian I see no behavior change: same tasks, flags,
  logs, backups, idempotency.
- US2: As a user on Gentoo (OpenRC) I run `./bin/bootstrap.sh` so that
  the core terminal setup (shell, fonts, vim, neovim, gitconfig, ssh,
  tools) installs through `emerge`, respecting my USE flags, profile,
  keywords and make.conf — dottod never edits them.
- US3: As a user on Arch, Fedora or Alpine I get the same core setup
  through `pacman`, `dnf` or `apk`.
- US4: As a user on an unknown or inconsistent system (unrecognized
  `ID`, or `ID=fedora` without `dnf`) I get a clear error **before any
  package command runs** — never a silent apt fallback.
- US5: As a user whose distro lacks a tool or a compatible binary
  (e.g. Zed on musl) I get a per-tool skip with the reason, and the
  rest of the task still completes.

## Acceptance scenarios
- Given each `os-release` fixture (debian, ubuntu, gentoo, arch,
  fedora, alpine, unknown, malformed), when detection runs, then
  family / package manager / libc are exact, and unknown or malformed
  never reaches a backend.
- Given a logical package list, when installing on each backend, then
  the exact argv is asserted (stubbed), already-installed packages skip
  without privilege, and a failing transaction fails the task with the
  manager's error visible.
- Given two tasks under `--parallel`, when both install packages, then
  dottod's transactions never interleave (lock test).
- Given a real container image per distro, when the mapping gate runs,
  then every mapped package name resolves in that distro's repository
  (no install needed).
- Given a fresh Gentoo stage3 (OpenRC) container, when
  `bootstrap.sh --only shell,vim,gitconfig,ssh` runs twice, then both
  runs pass and the second makes no changes.
- Given a target user whose home is not `/home/<user>`, when shell,
  vim, neovim or ssh run, then they write to the passwd home.
- Given Alpine (musl), when an upstream glibc-only binary is selected,
  then it is skipped with a reason, never installed and reported OK.

## Out of scope
Docker (removed in 2.0), Ghostty, GNOME/desktop settings, any AUR
helper, editing Gentoo USE/keywords/make.conf/overlays, converting tasks
to another language or framework, Ubuntu-derivative guarantees beyond
what `ID`/`ID_LIKE=debian` fixtures prove.

## Support levels (target; turned into evidence in Phase 9)
| Feature | Debian | Gentoo | Arch | Fedora | Alpine |
|---|---|---|---|---|---|
| shell, vim, gitconfig, ssh, fonts | core | core | core | core | core |
| neovim >= 0.11 | core | core (package) | core | core | conditional (apk version) |
| tools baseline | core | core (source builds) | core | core | core subset |
| tools extras | opt-in | opt-in, native first | opt-in | opt-in | opt-in, musl assets only |
| cargo (rustup) / bun | conditional | conditional | conditional | conditional | conditional (musl targets) |
| container (rootless podman) | conditional | conditional (cgroups/userns) | conditional | conditional | not promised |
| zed (`--ui`) | optional | optional | optional | optional | unsupported (glibc) |

## Status
Planned. Verified: no.
