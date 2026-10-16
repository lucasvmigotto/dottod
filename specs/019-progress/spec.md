# 019 — progress bars (`pv` + shortcuts)

Decided 2026-10-16: `pv` joins the core tools (every distro packages
it), and `scripts/.progress.sh` adds shortcuts that put a bar with a
percentage and an ETA on long copies, archives, checksums, image writes
and pipelines.

## Stories
- US1: As a user the tools task installs `pv` with the other core tools
  (Debian/Ubuntu, Arch, Fedora, Alpine `pv`; Gentoo `sys-apps/pv`).
- US2: `pcp SRC DST` copies a file (mode kept) or a directory tree
  (through tar: modes, links and times kept) with a bar; like `cp`, an
  existing DST directory receives SRC under its own name.
- US3: `ptar DIR [OUT]` archives with a bar on the uncompressed size;
  OUT's extension picks the codec (`.tar.zst`/`.tzst`, `.tar.gz`/`.tgz`,
  `.tar.xz`/`.txz`, `.tar`); the default is `DIR.tar.zst`, or
  `DIR.tar.gz` without zstd. `puntar ARCHIVE [DIR]` extracts with a bar
  on the archive's size.
- US4: `psum FILE [ALGO]` checksums with a bar and prints `HASH  FILE`,
  which `sha256sum -c` accepts (sha256 default; sha1, sha224, sha384,
  sha512, md5, b2).
- US5: `pdd IMAGE DEVICE` writes a disk image (plain, or `.xz`/`.gz`/
  `.zst`, decompressed on the way) to a block device.
- US6: `pchain FILE -- CMD...` feeds a file through pv into any command
  (`pchain dump.sql -- psql mydb`) and returns the command's status;
  `pvl` is `pv -l` for line counts through a pipe.

## Rules
- Every command checks for pv first and fails loudly (never a bare
  "command not found"); `-h` prints usage.
- Never overwrite an existing target (`pcp`, `ptar`); remove the partial
  target when any pipeline stage fails. Interactive shells rarely set
  pipefail, so each stage's status is checked (`PIPESTATUS`).
- `pdd` refuses a path that is not a block device, a device with
  anything mounted or used as swap, and an uncompressed image larger
  than the device; it shows the device (`lsblk`) and writes only after
  the device name is typed back — no `--yes`. It writes with
  `dd conv=fsync` through sudo (unless root) and never runs a global
  `sync`, which would wait on every other disk.
- Works on GNU and BusyBox userlands (sizes: `du -sb`, else `du -sk`).

## Status
Implemented on `feat/progress` (2026-10-16).

- `scripts/.progress.sh`; `pv` in `DOT_PKG_LOGICAL`, the five family
  maps and the tools task's core list.
- `tests/test-progress.bats` (23, on a stub pv; pdd on stub
  lsblk/sudo/dd and a block-device seam — no real disk); tools and
  status suites updated.
- Smoke-tested with the real pv 1.9.31 on Debian 13 and Alpine 3.22
  containers (pcp file and tree, ptar/puntar gz and xz, psum -c, pchain).
  pdd was not run against a real device.
