# dottod task runner (https://just.systems) — `just` runs the gate,
# `just --list` shows every recipe. `just tools` installs shellcheck, bats
# and shfmt; for `just` itself, on any supported distro, run once:
#   bash -c 'source bin/utils.sh && _install_packages just shellcheck bats shfmt'

# Shell files, derived from git by tests/files.sh (dotfiles included): the
# one list every syntax/lint/format recipe uses.
bashn_files := `tests/files.sh syntax | tr '\n' ' '`
lint_files := `tests/files.sh lint | tr '\n' ' '`
fmt_files := `tests/files.sh fmt | tr '\n' ' '`

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
    # dottod's own package layer: the distro's manager, the right names.
    # shellcheck disable=SC2086 # intentional word splitting on the tool list
    bash -c 'source bin/utils.sh && _install_packages "$@"' _ ${missing}
