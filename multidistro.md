# Task: Expand `dottod` to Support Gentoo, Debian, Red Hat/Fedora, Arch Linux and Alpine

You are working as a **senior Linux systems engineer, Bash expert, DevOps engineer, software architect, distro-packaging specialist, and test engineer**.

You are modifying the existing `dottod` repository.

Your objective is to expand `dottod` from its current Debian/apt-oriented implementation into a robust, maintainable, idempotent multi-distribution Linux workstation bootstrap system supporting:

* **Gentoo**
* **Debian**
* **Red Hat family / Fedora**
* **Arch Linux**
* **Alpine Linux**

The implementation must preserve the existing `dottod` philosophy, architecture, shell customization, task system, TUI behavior, container runtime behavior, tests, and safety characteristics wherever practical.

Do NOT blindly translate `apt install` commands into equivalent package-manager commands.

Instead, first understand the repository and design a proper distribution/package abstraction that allows the existing tasks to remain mostly distribution-agnostic.

---

# 1. Current Project Context

The current project contains:

```text
bin/
config/
scripts/
tests/
tui/
docs/
.github/
```

Important existing tasks include:

```text
bin/bootstrap.sh
bin/shell.sh
bin/fonts.sh
bin/vim.sh
bin/container.sh
bin/docker.sh
bin/desktop.sh
bin/vscode.sh
bin/ghostty.sh
bin/gitconfig.sh
bin/ssh.sh
bin/tools.sh
bin/utils.sh
```

The project currently has:

* Bash-based bootstrap tasks
* Zsh + Oh My Zsh + Spaceship
* Nerd Fonts
* Vim + vim-plug
* Podman as the default container runtime
* Docker as an explicit alternative
* GNOME desktop configuration
* VS Code
* Ghostty
* Git configuration
* GitHub SSH configuration
* CLI tooling
* system-information shell utilities
* BATS tests
* integration tests
* a Rust/Ratatui TUI
* GitHub Actions CI/release automation

The current implementation is primarily Debian/Ubuntu oriented because the central package helper ultimately calls:

```bash
apt-get update
apt-get install
```

Several individual tasks also directly assume Debian-specific infrastructure, for example:

```bash
apt
apt-get
dpkg
/etc/apt/
update-alternatives
Microsoft apt repositories
```

The objective is to remove those unnecessary assumptions while preserving Debian behavior.

---

# 2. Primary Objective

Implement first-class Linux distribution support for:

| Distribution | Family  | Package Manager |
| ------------ | ------- | --------------- |
| Debian       | Debian  | apt             |
| Fedora       | Red Hat | dnf             |
| Arch Linux   | Arch    | pacman          |
| Gentoo       | Gentoo  | emerge          |
| Alpine       | Alpine  | apk             |

Also recognize closely related distributions where practical, but **do not promise support for arbitrary derivatives unless the implementation actually supports them**.

At minimum, the architecture should identify:

```text
debian
fedora
arch
gentoo
alpine
```

and a package-manager abstraction should map the detected distribution to its appropriate package management operations.

---

# 3. CRITICAL REQUIREMENT: Analyze Before Modifying

Before changing files:

1. Inspect the entire repository.
2. Understand all scripts under `bin/`.
3. Understand `utils.sh`.
4. Inspect all tests.
5. Inspect TUI task definitions and runtime selection.
6. Inspect CI workflows.
7. Inspect documentation.
8. Identify every Debian/Ubuntu-specific assumption.
9. Identify every package installed by every task.
10. Identify tools that are:

* universally available
* available from distro repositories
* available only through third-party repositories
* better installed from upstream releases
* unavailable or impractical on some distributions
* GUI/session-specific
* unsuitable for Alpine
* unsuitable for non-GNOME environments.

Do not begin implementation until you have established this dependency matrix.

---

# 4. Produce a Detailed Implementation Plan First

Create a comprehensive phased implementation plan before making substantial code changes.

The plan must cover:

### Phase 0 — Repository and Architecture Audit

Document:

* current architecture
* execution flow
* task model
* privilege model
* package installation model
* configuration model
* shell setup
* container setup
* desktop setup
* testing model
* TUI integration
* CI
* release process

Identify all hard-coded Debian assumptions.

Create a table similar to:

| File             | Debian assumption | Why it exists        | Portable replacement     |
| ---------------- | ----------------- | -------------------- | ------------------------ |
| `bin/utils.sh`   | `apt-get`         | package installation | package backend          |
| `bin/vscode.sh`  | apt repository    | VS Code installation | distro/upstream strategy |
| `bin/tools.sh`   | apt packages      | CLI dependencies     | package mapping          |
| `bin/ghostty.sh` | Ubuntu installer  | Ghostty              | distro-aware strategy    |
| etc.             |                   |                      |                          |

Do not limit the audit to obvious `apt` strings.

Search for:

```text
apt
apt-get
apt-cache
dpkg
dpkg-query
add-apt-repository
/etc/apt
update-alternatives
.deb
.deb-specific commands
systemctl
useradd
usermod
chsh
getent
GNOME
Ubuntu
Debian
```

and any other assumptions that may break outside Debian.

---

# 5. Distribution Detection

Introduce a robust Linux distribution detection mechanism.

Prefer `/etc/os-release` as the primary source.

Do not use fragile:

```bash
uname
lsb_release
hostnamectl
```

based detection when `/etc/os-release` is sufficient.

The detection layer should expose normalized information such as:

```text
DOTTOD_OS_ID
DOTTOD_OS_ID_LIKE
DOTTOD_OS_VERSION_ID
DOTTOD_OS_VERSION
DOTTOD_OS_NAME
DOTTOD_OS_FAMILY
DOTTOD_PACKAGE_MANAGER
```

For example:

```text
DOTTOD_OS_FAMILY=debian
DOTTOD_PACKAGE_MANAGER=apt
```

or:

```text
DOTTOD_OS_FAMILY=redhat
DOTTOD_PACKAGE_MANAGER=dnf
```

Do not assume every Red Hat derivative uses exactly the same package tooling without verifying.

Support reasonable fallback behavior.

Unknown distributions must produce a clear diagnostic rather than silently attempting `apt`.

---

# 6. Package Manager Abstraction

This is the central architectural requirement.

Refactor package installation so tasks do not contain package-manager-specific logic.

The conceptual API should look like:

```bash
_pkg_update
_pkg_install ...
_pkg_remove ...
_pkg_clean
_pkg_is_installed ...
_pkg_name ...
```

Use whatever naming fits the existing architecture, but establish a clear abstraction.

The following package managers must be supported:

```text
apt
dnf
pacman
emerge
apk
```

Potentially support:

```text
yum
```

only as a compatibility fallback where justified.

---

# 7. Package Manager Semantics

Do not merely substitute commands.

Respect the semantics of each package manager.

## Debian

Use:

```bash
apt-get update
apt-get install
```

Preserve noninteractive behavior where appropriate.

## Fedora / Red Hat

Use:

```bash
dnf
```

Account for:

* package naming differences
* package groups
* repositories
* packages unavailable by default
* rootless Podman support
* development libraries.

## Arch

Use:

```bash
pacman
```

Account for:

* package names
* repository availability
* `base-devel`
* official repositories versus AUR
* avoiding mandatory AUR dependencies unless absolutely necessary.

**Do not make AUR a hard dependency for core dottod functionality.**

If something exists only in AUR, prefer another installation mechanism.

## Gentoo

Use:

```bash
emerge
```

Account for:

* USE flags
* package availability
* package names/atoms
* profile differences
* binary versus source installation
* optional packages
* packages that may require user intervention.

Do not attempt to automatically manipulate arbitrary user USE flags unless there is a very strong reason.

Gentoo users expect the system's package configuration to remain under their control.

## Alpine

Use:

```bash
apk
```

Account for:

* musl libc
* BusyBox
* package naming differences
* packages unavailable because of Alpine/musl constraints
* packages that assume glibc
* GUI availability
* desktop environments
* upstream binaries compiled against glibc
* shell behavior.

Alpine must be treated as a genuinely different environment, not simply another apt-like system.

---

# 8. Package Mapping Layer

Create a normalized logical package model.

For example:

```text
git
zsh
curl
ca-certificates
vim
fontconfig
unzip
podman
uidmap
btop
httpie
chafa
bat
jq
lsof
```

Then map logical names to distro-specific package names.

Conceptually:

```bash
_pkg_install \
    git \
    zsh \
    curl \
    ca-certificates
```

should resolve internally to:

```text
Debian: git zsh curl ca-certificates
Fedora: git zsh curl ca-certificates
Arch: git zsh curl ca-certificates
Gentoo: dev-vcs/git app-shells/zsh net-misc/curl app-misc/ca-certificates
Alpine: git zsh curl ca-certificates
```

Do NOT blindly assume package names are identical.

Build a maintainable mapping mechanism.

---

# 9. Package Availability Matrix

Before implementation, create a detailed matrix for all current dottod dependencies.

At minimum include:

```text
zsh
git
curl
ca-certificates
vim
fontconfig
unzip
podman
uidmap
docker
btop
httpie
chafa
xclip
bat
jq
lsof
gnome-system-monitor
code
ghostty
```

For every package/tool determine:

* Debian availability
* Fedora availability
* Arch availability
* Gentoo availability
* Alpine availability
* package name
* installation mechanism
* whether it is optional
* whether it requires extra repositories
* whether it requires compilation
* whether it depends on glibc
* whether it requires a graphical session
* whether it should be skipped
* whether it should use an upstream binary
* whether it should fail if unavailable.

---

# 10. Doable-by-Distro Philosophy

The implementation must explicitly distinguish between:

### Core functionality

Must remain available wherever reasonably possible:

* shell customization
* Zsh
* Oh My Zsh
* Spaceship
* shell aliases/functions
* system information
* Git configuration
* SSH configuration
* Vim
* CLI fundamentals
* fonts where possible
* container support where possible

### Optional functionality

May be unavailable or skipped:

* GNOME-specific desktop configuration
* VS Code
* Ghostty
* particular GUI utilities
* specific CLI applications
* packages with no reasonable Alpine/Gentoo/Fedora/Arch support.

Do not allow one unavailable optional package to destroy the entire bootstrap.

---

# 11. Shell Customization Must Remain Core

The shell customization must remain fundamentally identical across supported distributions.

Preserve:

* Zsh
* Oh My Zsh
* Spaceship
* zsh-autosuggestions
* zsh-syntax-highlighting
* custom `.zshrc`
* aliases
* functions
* system-info prompt integration
* existing shell environment.

Do not create separate shell configurations per distro unless technically necessary.

The goal is:

```text
Debian     ─┐
Fedora     ├──> same dottod shell experience
Arch       ┤
Gentoo     ┤
Alpine     ┘
```

Distribution-specific behavior should be isolated to package/system integration.

---

# 12. User Home Handling

Audit the existing assumption:

```text
/home/${current_user}
```

This is not universally safe.

Refactor where appropriate to use:

```bash
getent passwd
$HOME
eval echo "~user"
```

or another robust mechanism.

Do not break root/user execution semantics.

Pay particular attention to:

* Zsh installation
* `.zshrc`
* `.vimrc`
* `.gitconfig`
* `.ssh/config`
* fonts
* Oh My Zsh
* Spaceship.

---

# 13. Privilege Abstraction

Preserve the existing:

```text
sudo
doas
root
```

support.

However, audit whether assumptions around:

```text
usermod
chsh
systemctl
update-alternatives
```

are portable.

Introduce small system abstractions where needed.

Do not turn `utils.sh` into an unmaintainable monolith.

Keep responsibilities clear.

---

# 14. Default Shell

The current project changes the user's shell to Zsh.

Make this portable.

Determine the correct mechanism on each target.

At minimum verify:

* `chsh`
* valid shells listed in `/etc/shells`
* Zsh path
* Alpine behavior
* Gentoo behavior
* nonstandard installations.

Do not assume:

```text
/usr/bin/zsh
```

or:

```text
/home/user
```

without verification.

If the operation cannot safely be performed, provide an actionable warning/error.

---

# 15. Container Runtime

Preserve the current policy:

```text
Podman = default
Docker = explicit alternative
```

Do not regress this.

Podman should work on:

* Debian
* Fedora
* Arch
* Gentoo
* Alpine

where realistically supported.

Investigate distribution-specific requirements for:

* `uidmap`
* subuid/subgid
* rootless containers
* user namespaces
* networking
* helper packages.

Do not automatically install Docker when Podman is selected.

Do not automatically switch away from an explicitly selected runtime.

Preserve:

```text
_DOT_CONTAINER_RUNTIME=podman
_DOT_CONTAINER_RUNTIME=docker
_DOT_CONTAINER_RUNTIME=auto
```

and the TUI's runtime selection.

---

# 16. Docker Support

The existing Docker installer is likely Debian-specific.

Refactor it into a distribution-aware implementation.

Determine the appropriate installation strategy per distribution.

Avoid blindly adding Docker's official repository everywhere.

Prefer native packages where appropriate when that provides a reliable setup.

However, do not sacrifice correctness merely to avoid external repositories.

Document the chosen strategy.

Docker daemon management must account for:

* systemd distributions
* non-systemd environments
* Alpine OpenRC
* rootless versus rootful operation.

Do not assume:

```bash
systemctl enable --now docker
```

works everywhere.

---

# 17. Podman Service Semantics

Likewise, do not assume Podman requires a daemon.

Preserve Podman's rootless architecture.

Where socket activation is useful, detect and configure it appropriately.

Do not introduce unnecessary system services.

---

# 18. CLI Tools

Refactor `bin/tools.sh`.

The current tools include:

```text
btop
httpie
chafa
xclip
bat
jq
curl
tar
ca-certificates
lsof
lazygit
lazydocker
k9s
resterm
```

Determine the best installation mechanism for each.

Important rule:

### Prefer native distribution packages when they are reliable.

Otherwise use:

1. upstream binary release
2. source installation
3. optional skip
4. explicit failure only when the tool is considered core.

Do not introduce language package managers such as:

```text
pip
npm
cargo install
go install
```

as an arbitrary replacement for every missing distro package.

If using upstream binaries, account for:

* architecture
* libc
* version
* tar/zip format
* checksums where practical
* installation location
* upgrades
* idempotency.

---

# 19. Alpine / musl

Treat Alpine specially.

Audit every downloaded upstream binary.

A binary compiled against glibc may not run on Alpine.

Therefore:

* detect musl versus glibc
* do not install incompatible binaries
* prefer Alpine packages
* prefer statically linked upstream releases where available
* skip unsupported tools with an informative message
* never report a successful installation when the binary cannot execute.

This is particularly important for:

```text
lazygit
lazydocker
k9s
resterm
Ghostty
VS Code
```

and any other precompiled binary.

---

# 20. VS Code

The existing VS Code installer directly configures the Microsoft apt repository.

This must become distro-aware.

Investigate viable approaches for:

* Debian
* Fedora
* Arch
* Gentoo
* Alpine.

Do not force VS Code support where Microsoft does not provide a compatible package.

Potentially support:

* native repositories
* official Microsoft packages
* distro packages
* upstream alternatives

but document exactly what is supported.

If Alpine cannot reasonably support official VS Code, treat it as an optional unsupported task and skip cleanly.

The `bootstrap` process must not fail merely because an optional GUI/editor package is unavailable.

---

# 21. Ghostty

The current implementation uses an Ubuntu-specific installer:

```text
mkasberg/ghostty-ubuntu
```

This must not be blindly used across distributions.

Investigate native package availability and installation strategies for:

* Debian
* Fedora
* Arch
* Gentoo
* Alpine.

Where unavailable:

```text
skip with a clear reason
```

rather than pretending installation succeeded.

Ghostty should remain optional.

---

# 22. Desktop Support

The current desktop task assumes GNOME.

Preserve GNOME support but make the task robust.

Detect:

```text
XDG_CURRENT_DESKTOP
XDG_SESSION_DESKTOP
DESKTOP_SESSION
```

and determine whether a GNOME session is actually active.

Do not blindly execute:

```bash
gsettings
```

against a headless machine.

Do not make desktop configuration a prerequisite for server/minimal environments.

For Alpine especially, assume that a desktop environment may not exist.

The desktop task should:

* install what is reasonably available
* apply GNOME settings only when GNOME is actually present
* otherwise warn/skip.

---

# 23. `update-alternatives`

The current Ghostty implementation assumes Debian's:

```bash
update-alternatives
```

mechanism.

Do not assume this exists.

Create a small abstraction if terminal selection actually requires one.

Never break installation merely because `update-alternatives` is unavailable.

---

# 24. Fonts

Nerd Fonts should remain cross-distribution.

Preserve:

```text
FiraCode
FiraMono
RobotoMono
NerdFontsSymbolsOnly
ZedMono
```

Ensure the implementation works for:

* user-local installation
* global installation
* fontconfig
* Alpine
* Gentoo
* Arch
* Fedora
* Debian.

Do not require a GUI.

---

# 25. Vim

Keep Vim installation cross-platform.

The implementation should use the package abstraction.

Avoid hard-coded:

```text
/home/${current_user}
```

where unnecessary.

Preserve vim-plug behavior and idempotency.

---

# 26. Git Configuration

Git configuration should remain distribution independent.

Preserve:

* existing identity discovery
* interactive fallback
* environment variables
* backup behavior
* `.gitconfig` template.

Do not alter the user's existing configuration destructively.

---

# 27. SSH

SSH configuration should remain distribution independent.

Audit:

* OpenSSH client package
* `ssh`
* `ssh -G`
* home directory resolution
* permissions
* config paths.

Preserve the current safe merge behavior.

Do not replace the whole SSH config.

---

# 28. System Information

Audit all scripts under:

```text
scripts/
```

for distribution assumptions.

Pay particular attention to:

* `/proc`
* `/sys`
* `free`
* `df`
* `lsb_release`
* `hostnamectl`
* package manager commands
* CPU information
* memory information
* filesystem information
* shell detection.

The system-info feature should work on all supported Linux distributions where the underlying kernel interfaces exist.

Alpine's BusyBox utilities must be considered.

---

# 29. Bootstrap Task Model

Keep:

```bash
./bin/bootstrap.sh
```

as the primary orchestration mechanism.

Preserve:

```text
--only
--skip
--runtime
--parallel
--no-ui-support
--yes
--verbose
--list
```

Add distribution-related diagnostics where useful.

For example:

```text
dottod environment
------------------
OS:          Fedora Linux 42
Family:      redhat
Package:     dnf
Architecture: x86_64
Init:        systemd
Desktop:     GNOME
Container:   podman
```

Do not clutter normal output unnecessarily.

---

# 30. Parallel Execution Safety

The current bootstrap supports:

```text
--parallel
```

Multi-distribution support must not introduce package-manager races.

Different tasks may call `_pkg_update` simultaneously.

Do not rely on:

```text
apt/dnf/pacman/emerge/apk
```

locking alone.

Design package-manager synchronization where appropriate.

The package abstraction should guarantee that concurrent package operations do not corrupt the package database.

This is especially important for:

```text
--parallel
```

---

# 31. Error Classification

Introduce clear distinctions between:

### Required failure

Example:

```text
zsh cannot be installed
```

if shell setup is selected.

### Optional unavailable feature

Example:

```text
VS Code is unavailable on Alpine.
Skipping optional task.
```

### Unsupported environment

Example:

```text
GNOME configuration requested, but no GNOME session is available.
```

### Recoverable warning

Example:

```text
lazygit is unavailable from the native repository and no compatible upstream binary was found.
```

Do not hide real failures.

Do not turn every unsupported feature into a hard failure.

---

# 32. Configuration/Capability Model

Consider introducing a capability layer rather than scattering distro checks throughout every script.

For example:

```text
OS detection
     |
     v
capabilities
     |
     +--> package manager
     +--> init system
     +--> libc
     +--> desktop
     +--> container support
     +--> package mappings
     |
     v
tasks
```

Possible capabilities:

```text
has_systemd
has_openrc
has_gnome
is_musl
is_glibc
supports_podman
supports_docker
supports_vscode
supports_ghostty
```

Only introduce abstractions that are actually useful.

Avoid overengineering.

---

# 33. Distribution-Specific Code Placement

Do not create enormous scripts containing:

```bash
if Debian
elif Fedora
elif Arch
elif Gentoo
elif Alpine
```

for every task.

Prefer:

```text
bin/
lib/
packages/
platform/
```

or another clean architecture.

A reasonable direction could be:

```text
bin/
lib/
  os.sh
  package.sh
  init.sh
  desktop.sh
  container.sh
  ...
```

with distro-specific package mappings isolated.

The final structure should remain understandable to a Bash developer.

---

# 34. Testing Strategy

This expansion must significantly improve automated testing.

Add unit tests for distribution detection.

Use fixture files for:

```text
/etc/os-release
```

rather than requiring the CI machine to actually be each distribution.

Test:

```text
Debian
Ubuntu-like Debian
Fedora
RHEL-like
Arch
Manjaro-like if supported
Gentoo
Alpine
unknown distribution
```

Test package-manager selection.

Test package mappings.

Test unsupported packages.

Test capability detection.

---

# 35. Package Manager Tests

Use command stubs/mocks where appropriate.

Verify that logical package requests produce the expected commands.

Examples:

```text
Debian:
apt-get update
apt-get install ...

Fedora:
dnf install ...

Arch:
pacman -Sy ...
pacman -S ...

Gentoo:
emerge ...

Alpine:
apk add ...
```

Do not run actual package installation in unit tests.

---

# 36. Integration Testing

Introduce distro-specific CI where practical.

Use containers for package-layer testing where possible.

Potential CI matrix:

```text
debian
fedora
archlinux
gentoo
alpine
```

Be realistic about Gentoo CI cost.

If a full Gentoo bootstrap is too expensive, use focused package/detection tests and document the limitation.

The CI should at minimum verify:

* distribution detection
* package manager detection
* core shell dependencies
* basic package resolution
* syntax
* BATS
* relevant task execution.

---

# 37. Alpine CI

Alpine deserves a dedicated CI path.

Verify:

```text
apk
musl
zsh
curl
git
vim
fontconfig
podman
```

where feasible.

Do not run glibc-specific upstream binaries merely to make a test pass.

---

# 38. Shell Testing

Continue using:

```text
BATS
```

and existing shell tests.

Add tests for:

```text
OS detection
package abstraction
package mapping
capability detection
home directory handling
default shell
container runtime
```

Tests must remain hermetic.

Do not modify the developer's real:

```text
$HOME
/etc
/proc
/sys
```

unless explicitly running integration tests.

---

# 39. TUI

The Rust/Ratatui TUI must remain compatible with the new backend.

The TUI should not contain distro-specific package installation logic.

It should invoke the same task layer.

Preserve:

```text
--runtime
--repo
--only
--no-ui-support
--parallel
```

and the current runtime selector.

If the TUI currently assumes a fixed list of tasks, verify whether optional/unsupported tasks should be represented as:

```text
available
unavailable
skipped
```

rather than blindly runnable.

Do not rewrite the TUI unnecessarily.

---

# 40. Documentation

Update documentation extensively.

README must document:

```text
Supported distributions
Package managers
Core functionality
Optional functionality
Distribution-specific limitations
Installation
Testing
Container runtime
GUI support
Alpine limitations
Gentoo considerations
```

Add a dedicated document such as:

```text
docs/distributions.md
```

containing:

### Debian

Supported features and package strategy.

### Fedora

Supported features and package strategy.

### Arch

Supported features and package strategy.

### Gentoo

Supported features, USE flag considerations, and limitations.

### Alpine

Supported features, musl limitations, and unsupported binaries.

---

# 41. Documentation Matrix

Create a feature matrix such as:

| Feature   | Debian | Fedora | Arch | Gentoo |   Alpine |
| --------- | -----: | -----: | ---: | -----: | -------: |
| Zsh       |      ✓ |      ✓ |    ✓ |      ✓ |        ✓ |
| Oh My Zsh |      ✓ |      ✓ |    ✓ |      ✓ |        ✓ |
| Spaceship |      ✓ |      ✓ |    ✓ |      ✓ |        ✓ |
| Fonts     |      ✓ |      ✓ |    ✓ |      ✓ |        ✓ |
| Vim       |      ✓ |      ✓ |    ✓ |      ✓ |        ✓ |
| Podman    |      ✓ |      ✓ |    ✓ |      ✓ |        ? |
| Docker    |      ✓ |      ✓ |    ✓ |      ✓ |        ? |
| GNOME     |      ✓ |      ✓ |    ✓ |      ✓ | optional |
| VS Code   |      ✓ |      ? |    ? |      ? |        ? |
| Ghostty   |      ✓ |      ? |    ✓ |      ? |        ? |
| CLI tools |      ✓ |      ✓ |    ✓ |      ✓ |        ? |

Replace `?` with the actual implementation status.

Never claim support merely because a package theoretically exists.

---

# 42. Idempotency

Every task must remain idempotent.

Running:

```bash
./bin/bootstrap.sh
```

twice should not:

* reinstall everything unnecessarily
* duplicate repository entries
* duplicate shell plugins
* duplicate SSH config
* destroy user files
* overwrite configuration without backup
* duplicate subuid/subgid entries
* duplicate package repositories
* break services.

This is especially important when adding distro-specific repository configuration.

---

# 43. Safety

Never:

* overwrite user configuration without backup
* modify unrelated package-manager configuration
* blindly modify Gentoo USE flags
* blindly add AUR helpers
* execute arbitrary remote installers without justification
* install incompatible binaries
* silently switch container runtimes
* assume systemd
* assume glibc
* assume GNOME
* assume `/home/<user>`
* assume `apt`.

For remote installation scripts, critically evaluate whether they are still necessary.

Where possible, prefer:

```text
native package
+
verified upstream release
```

over:

```text
curl | bash
```

---

# 44. Remote Binary Installation

For tools installed from GitHub releases, improve the architecture where practical.

The current implementation dynamically queries:

```text
api.github.com
```

and installs the first matching asset.

Audit this for:

* architecture
* libc
* archive type
* release naming
* checksums
* GitHub API rate limits
* Alpine compatibility.

Do not make assumptions that every GitHub release has:

```text
Linux_x86_64
Linux_arm64
```

or compatible naming.

Build a reusable architecture/platform resolution strategy.

---

# 45. Architecture Support

Preserve existing architecture detection but improve it where needed.

At minimum account for:

```text
x86_64
aarch64
arm64
```

Do not claim support for architectures that the upstream binaries do not support.

Package-manager installations may support architectures that GitHub binaries do not.

This distinction must be represented.

---

# 46. Init System Detection

Introduce detection for at least:

```text
systemd
OpenRC
```

Do not assume:

```bash
systemctl
```

exists.

This matters particularly for:

```text
Alpine
Gentoo
```

and container environments.

Any service-management code must use the appropriate abstraction.

---

# 47. Environment Detection

Support:

```text
physical workstation
VM
container
headless server
GUI workstation
SSH session
```

The bootstrap should not fail merely because it is being executed on a server.

For example:

```text
desktop
vscode
ghostty
```

should be safely optional.

---

# 48. Preserve Existing UX

Keep the existing logging model:

```text
log_step
log_info
log_ok
log_warn
log_error
```

Keep color/no-color behavior.

Keep:

```text
/tmp/dottod
```

logging behavior unless there is a strong reason to change it.

Do not make normal output excessively verbose.

---

# 49. Backward Compatibility

Existing Debian users must not need to change their commands.

These should continue to work:

```bash
./bin/bootstrap.sh
./bin/bootstrap.sh --only shell,tools
./bin/bootstrap.sh --skip desktop
./bin/bootstrap.sh --runtime podman
./bin/bootstrap.sh --runtime docker
./bin/bootstrap.sh --parallel
./bin/shell.sh
./bin/container.sh
```

The default container runtime must remain:

```text
Podman
```

---

# 50. Environment Overrides

Preserve existing `_DOT_*` environment configuration.

Add only useful overrides, for example:

```text
_DOT_OS_FAMILY
_DOT_PACKAGE_MANAGER
_DOT_PACKAGE_BACKEND
```

only if genuinely useful for testing or advanced users.

Do not make normal users configure their distro manually.

Automatic detection must remain the default.

---

# 51. Unknown Distribution Behavior

If an unsupported distribution is detected:

```text
OS: unknown
```

must not cause:

```text
apt-get
```

to execute.

Instead produce:

```text
Unsupported Linux distribution.

Detected:
  ID: ...
  ID_LIKE: ...

Supported distributions:
  Debian
  Fedora
  Arch Linux
  Gentoo
  Alpine
```

and fail safely.

---

# 52. Recommended Architecture

Use this as guidance, not as a rigid requirement:

```text
bin/
    bootstrap.sh
    shell.sh
    fonts.sh
    vim.sh
    container.sh
    docker.sh
    desktop.sh
    vscode.sh
    ghostty.sh
    gitconfig.sh
    ssh.sh
    tools.sh
    utils.sh

lib/
    os.sh
    package.sh
    init.sh
    capabilities.sh
    architecture.sh

config/
scripts/
tests/
    fixtures/
        os-release/
            debian
            fedora
            arch
            gentoo
            alpine
            unknown
```

Package-specific mappings may alternatively live in:

```text
lib/packages/
```

Choose the cleanest design after analyzing the repository.

---

# 53. Implementation Phases

The final plan must be organized into explicit phases.

At minimum:

## Phase 0

Repository audit.

## Phase 1

OS and environment detection.

## Phase 2

Package-manager abstraction.

## Phase 3

Package mapping.

## Phase 4

Core task migration.

## Phase 5

Shell portability.

## Phase 6

Container runtime portability.

## Phase 7

GUI/desktop/editor/terminal portability.

## Phase 8

CLI/upstream binary portability.

## Phase 9

Testing and CI matrix.

## Phase 10

Documentation.

## Phase 11

TUI compatibility.

## Phase 12

Final hardening and compatibility review.

For every phase specify:

* objective
* files to modify
* files to create
* implementation details
* risks
* dependencies
* tests
* acceptance criteria
* rollback considerations.

---

# 54. Implementation Order

Do not implement everything in one giant change.

Follow this sequence:

1. audit
2. architecture
3. tests
4. detection
5. package backend
6. migrate core tasks
7. migrate optional tasks
8. container support
9. CI
10. documentation
11. TUI verification
12. final integration.

Keep commits/changes logically separable where possible.

---

# 55. Required Final Analysis

Before implementation, explicitly answer:

### A. Which features are realistically portable to all five distributions?

### B. Which features should remain optional?

### C. Which features should be unsupported on Alpine?

### D. Which features require special Gentoo handling?

### E. Which features require Fedora-specific repositories?

### F. Which features require Arch-specific handling?

### G. Which existing scripts contain hidden Debian assumptions?

### H. Which current GitHub binary downloads are incompatible with Alpine?

### I. Which operations require systemd versus OpenRC?

### J. Which packages have different names between distributions?

### K. Which package installations should remain native?

### L. Which tools should use upstream releases?

### M. Which features should be skipped instead of failing?

---

# 56. Do Not Overengineer

This is a Bash project.

Do not transform it into:

* Python
* Ansible
* Nix
* a generic package-management framework
* a huge abstraction hierarchy.

The abstraction should be **small, explicit and understandable**.

The objective is:

```text
portable dottod
```

not:

```text
generic Linux provisioning framework
```

---

# 57. Quality Requirements

All implementation must follow:

```text
set -Eeuo pipefail
```

where appropriate.

Use:

* shellcheck
* BATS
* Rust fmt
* Clippy
* cargo test
* existing CI checks.

Avoid:

* unnecessary global state
* unsafe word splitting
* accidental glob expansion
* unquoted variables
* unnecessary subshells
* fragile parsing
* distro checks scattered throughout business logic.

Use Bash arrays for package lists and command arguments.

---

# 58. Required Acceptance Criteria

The implementation is complete only when:

### Distribution detection

```text
Debian      -> Debian/apt
Fedora      -> Red Hat/dnf
Arch        -> Arch/pacman
Gentoo      -> Gentoo/emerge
Alpine      -> Alpine/apk
```

works reliably.

### Core shell

The same shell customization experience works across all supported distributions where Zsh is available.

### Package abstraction

No core task directly invokes:

```text
apt-get
dnf
pacman
emerge
apk
```

outside the package/system abstraction layer unless there is a documented, intentional exception.

### Container

Podman remains default.

Docker remains optional.

### Optional features

Unavailable optional software is skipped gracefully with an explanation.

### Alpine

No incompatible glibc binary is reported as successfully installed.

### Gentoo

No arbitrary USE flags are silently changed.

### Arch

No AUR helper becomes a core dependency.

### Desktop

Headless systems do not fail because GNOME is absent.

### Idempotency

Running tasks repeatedly remains safe.

### Tests

The full existing test suite passes, plus new multi-distro tests.

### CI

At least Debian, Fedora, Arch and Alpine are exercised in CI, with a practical Gentoo validation strategy documented/implemented.

### Documentation

Supported distributions, feature availability and limitations are documented.

---

# 59. Important Development Rule

Do not make assumptions based only on package names.

For each distro, verify actual availability and semantics.

Use authoritative distribution documentation/package indexes where necessary.

If a feature is technically possible but operationally unreliable, classify it as optional rather than claiming full support.

---

# 60. Execution Instructions

Start by performing a complete repository audit.

Then produce:

```text
1. Architecture assessment
2. Current Debian-specific assumptions
3. Distribution compatibility matrix
4. Proposed architecture
5. Package mapping strategy
6. Capability strategy
7. Detailed phased implementation plan
8. Testing strategy
9. CI strategy
10. Documentation strategy
11. Risks and mitigations
12. Acceptance criteria
```

Do not immediately rewrite the repository.

After the plan is established, implement it phase-by-phase.

For every phase:

1. modify the minimum necessary files
2. add/update tests
3. run relevant tests
4. inspect failures
5. fix regressions
6. verify shellcheck
7. continue to the next phase.

At the end, perform a full repository review.

Search again for:

```text
apt
apt-get
dpkg
Ubuntu
Debian-specific paths
systemctl
update-alternatives
/home/${current_user}
glibc
```

and determine whether every remaining occurrence is intentional and portable.

Finally provide:

```text
Implementation summary
Changed files
New files
Supported distro matrix
Known limitations
Test results
CI results
Remaining risks
Recommended follow-up work
```

The final implementation must feel like a **native evolution of dottod**, not five unrelated installers bolted together.

The most important design principle is:

> **Keep dottod's workstation experience consistent; isolate distribution differences underneath it.**

Core shell customization and the user's configured environment must remain the center of the project.


