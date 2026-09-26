# 013 — cargo (Rust toolchain via rustup)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only cargo` so that the Rust
  toolchain installs via rustup without touching my shell rc files.
- US2: As a user with `cargo` already present I get a skip, so re-runs converge.

## Acceptance scenarios
- Given `cargo` absent, when the task runs, then rustup-init downloads
  (with retries) and installs the `stable` toolchain with the `minimal`
  profile and `--no-modify-path`
  [OBSERVED: bin/cargo.sh: `_cargo_ensure`].
- Given `cargo` present, when the task runs, then it skips without network
  or password prompts [OBSERVED: bin/cargo.sh `_is_installed` guard].
- Given a failed download or installer, when the task runs, then it fails
  loudly with the URL/reason (no silent partial install).
- Given `_DOT_RUSTUP_TOOLCHAIN=1.98.0`, when the task runs, then that
  toolchain installs instead of stable.

## Status
Bash: Implemented. TUI: Implemented. Verified: no (no cross-stack e2e).
