# dottod task runner (https://just.systems) — `just` runs the gate,
# `just --list` shows every recipe. Needs `just` itself: `just tools`
# bootstraps it along with shellcheck, bats and shfmt.

# Shell files, explicit (globs skip dotfiles): the one list every
# syntax/lint/format recipe uses, mirroring .github/workflows/shell.yml.
bashn_files := "bin/*.sh scripts/*.sh config/.custom.bashrc scripts/.alias.sh scripts/.bat.utils.sh scripts/.sys.utils.sh scripts/.xclip.utils.sh scripts/.container.utils.sh scripts/.codes.sh scripts/.dev.utils.sh scripts/.wsl.sh scripts/.update.sh scripts/.claude.sh scripts/.doctor.sh scripts/nvim-headless-check.sh tests/run.sh"
lint_files := "bin/*.sh scripts/*.sh styles/*.sh scripts/.alias.sh scripts/.bat.utils.sh scripts/.sys.utils.sh scripts/.xclip.utils.sh scripts/.container.utils.sh scripts/.codes.sh scripts/.dev.utils.sh scripts/.wsl.sh scripts/.update.sh scripts/.claude.sh scripts/.doctor.sh scripts/nvim-headless-check.sh config/.custom.bashrc tests/run.sh tests/test-*.bats tests/helpers.bash"
fmt_files := "bin/*.sh scripts/.alias.sh scripts/.bat.utils.sh scripts/.sys.utils.sh scripts/.xclip.utils.sh scripts/.container.utils.sh scripts/.codes.sh scripts/.dev.utils.sh scripts/.wsl.sh scripts/.update.sh scripts/.claude.sh scripts/.doctor.sh scripts/nvim-headless-check.sh styles/promptlib.sh styles/prompt-robbyrussell.sh styles/prompt-kali.sh styles/prompt-powerline.sh config/.custom.bashrc tests/run.sh scripts/test-release.sh"

# Syntax + lint + format drift (the CI gate).
check:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    for f in {{bashn_files}}; do bash -n "${f}"; done
    shellcheck -S warning {{lint_files}}
    shfmt -i 4 -ci -d {{fmt_files}}

# Rewrite formatting in place (shfmt, 4 spaces, indented case branches).
fmt:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    shfmt -i 4 -ci -w {{fmt_files}}

# Hermetic bats suites.
test:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    ./tests/run.sh

# Release-logic tests (needs python3).
release:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    bash scripts/test-release.sh

# Docs site: install, typecheck, unit tests, lint.
site:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    cd docs/site
    bun install --frozen-lockfile
    bun run typecheck
    bun run test
    bun run lint

# Boot a pristine login shell and assert the interactive surface loads.
smoke:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    HOME="${tmp}" bash -i -c "source '$PWD/config/.custom.bashrc' >/dev/null 2>&1; __dottod_prompt >/dev/null; for f in codes dottod-update claude dottod-doctor; do command -v \"\${f}\" >/dev/null || { echo \"smoke: \${f} missing\" >&2; exit 1; }; done; echo SMOKE_OK"

# Health report (needs a sourced shell; see scripts/.doctor.sh).
doctor:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    bash -i -c "source '$PWD/config/.custom.bashrc' >/dev/null 2>&1; dottod-doctor"

# Install the dev toolchain (just, shellcheck, bats, shfmt) or print how.
tools:
    #!/usr/bin/env bash
    set -Eeuo pipefail
    missing=""
    for t in just shellcheck bats shfmt; do
        command -v "${t}" >/dev/null 2>&1 || missing="${missing} ${t}"
    done
    if [[ -z "${missing}" ]]; then
        echo "toolchain ready: just shellcheck bats shfmt"
        exit 0
    fi
    if command -v apt-get >/dev/null 2>&1; then
        # shellcheck disable=SC2086 # intentional word splitting on the tool list
        sudo apt-get update -qq && sudo apt-get install -y -qq ${missing}
    else
        echo "install missing tools:${missing} (apt-get not found)" >&2
        exit 1
    fi
