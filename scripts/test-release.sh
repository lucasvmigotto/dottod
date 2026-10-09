#!/usr/bin/env bash
# Tests scripts/release.py in throwaway repositories: which commits release
# and at which level, CHANGELOG promotion or generation, ignored commits,
# --dry-run and --notes. Follows the ai-gent test-release.sh pattern
# (adapted: dottod has no versioned sub-packages, so no manifest cases).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="$REPO_DIR/scripts/release.py"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.test
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.test

failures=0
check() { # check <description> <command...>
    local what="$1"
    shift
    if "$@"; then
        printf '      ok    %s\n' "$what"
    else
        printf '      FAIL  %s\n' "$what"
        failures=$((failures + 1))
    fi
}

# A base repository tagged 1.2.3 with a released CHANGELOG section.
base="$SANDBOX/base"
mkdir -p "$base"
printf '# Changelog\n\n## 1.2.3 — 2026-01-01\n\nFirst.\n' >"$base/CHANGELOG.md"
echo "base" >"$base/file.txt"
git -C "$base" init -q -b main
git -C "$base" add -A
git -C "$base" commit -q -m "chore: initial"
git -C "$base" tag -a 1.2.3 -m 1.2.3

repo="" out="" rc=0
fresh() {
    repo="$SANDBOX/r$RANDOM$RANDOM"
    git clone -q "$base" "$repo"
}
edit() { # edit <file> <commit subject> [<body>]
    echo "change $RANDOM" >>"$repo/$1"
    git -C "$repo" add -A
    if (($# > 2)); then git -C "$repo" commit -q -m "$2" -m "$3"; else git -C "$repo" commit -q -m "$2"; fi
}
run() { # run <args...>: sets out and rc
    set +e
    out="$(cd "$repo" && python3 "$RELEASE" --date 2026-02-02 "$@" 2>/dev/null)"
    rc=$?
    set -e
}
# shellcheck disable=SC2329 # called through check()
clean() { [[ -z "$(git -C "$repo" status --porcelain)" ]]; }

# 1. feat -> minor, generated section, version on stdout.
fresh
edit file.txt "feat(shell): add bash prompt"
run
check 'feat releases minor' test "$out" = "1.3.0"
check 'generated section committed' grep -q '^## 1.3.0 — 2026-02-02' "$repo/CHANGELOG.md"
check 'section groups Added' grep -q '^### Added' "$repo/CHANGELOG.md"

# 2. fix -> patch.
fresh
edit file.txt "fix(ssh): never overwrite keys"
run
check 'fix releases patch' test "$out" = "1.2.4"

# 3. breaking (! and footer) -> major.
fresh
edit file.txt "feat(cli)!: drop legacy flag"
run
check 'bang releases major' test "$out" = "2.0.0"
fresh
edit file.txt "fix(cli): change default" "BREAKING CHANGE: defaults flipped"
run
check 'footer releases major' test "$out" = "2.0.0"

# 4. docs-only -> exit 3, nothing written.
fresh
edit file.txt "docs(readme): touch up install"
run
check 'docs-only exits 3' test "$rc" = "3"
check 'docs-only writes nothing' clean

# 5. merge commits and chore(release) ignored.
fresh
edit file.txt "feat(tools): add fzf"
git -C "$repo" commit -q --allow-empty -m "Merge branch 'other' into main"
run
check 'merge subject ignored, feat still minor' test "$out" = "1.3.0"

# 6. Unreleased section is promoted verbatim (hand-written wins).
fresh
edit file.txt "fix(fonts): probe first"
printf '## Unreleased\n\nHand-written notes.\n\n' >>"$repo/CHANGELOG.md"
git -C "$repo" add -A && git -C "$repo" commit -q -m "docs: draft notes"
run
check 'unreleased promoted' test "$out" = "1.2.4"
check 'hand-written body kept' grep -q 'Hand-written notes' "$repo/CHANGELOG.md"
check 'no generated groups' test "$(grep -c '^### ' "$repo/CHANGELOG.md" || true)" = "0"

# 7. --dry-run writes nothing.
fresh
edit file.txt "feat(bun): add devcontainer step"
run --dry-run
check 'dry-run exits 0' test "$rc" = "0"
check 'dry-run prints plan' bash -c 'printf "%s" "$0" | grep -q "release 1.3.0"' "$out"
check 'dry-run writes nothing' clean

# 8. --notes prints the newest section body.
fresh
edit file.txt "feat(zed): add task"
run >/dev/null
check 'release ran' test "$out" = "1.3.0"
notes="$(cd "$repo" && python3 "$RELEASE" --notes)"
check 'notes contain the entry' bash -c 'printf "%s" "$0" | grep -q "add task"' "$notes"

# 9. no tag -> --initial when releasable.
fresh
git -C "$repo" tag -d 1.2.3 >/dev/null
edit file.txt "feat(shell): fresh start"
run --initial 1.0.0
check 'initial version used' test "$out" = "1.0.0"

# 10. no tag and nothing releasable -> exit 3.
fresh
git -C "$repo" tag -d 1.2.3 >/dev/null
edit file.txt "docs: only docs"
run
check 'untagged docs-only exits 3' test "$rc" = "3"

printf 'release tests: %d failure(s)\n' "$failures"
exit $((failures > 0))
