#!/usr/bin/env bash
#
# pass-run — run one command with secrets from pass in its environment
# (spec 017). The secrets exist only in that command's environment: never
# in your shell, never on its command line, never printed by pass-run.
#
# Usage: pass-run VAR=store/path [VAR=store/path ...] -- command [args...]
#
#   pass-run GH_TOKEN=github/pat -- gh pr list
#   pass-run AZURE_DEVOPS_EXT_PAT=azure-devops/pat -- az boards query --wiql "..."
#
# Each VAR gets the first line of `pass show <path>` (pass's convention:
# the first line is the secret). Installed as ~/.local/bin/pass-run by
# `./bin/bootstrap.sh --only secrets`; a real program, so non-interactive
# shells (scripts, AI agents) can use it too.

set -Eeuo pipefail

function _usage() {
    cat <<'EOF'
Usage: pass-run VAR=store/path [VAR=store/path ...] -- command [args...]

Runs command with each VAR set to the first line of `pass show store/path`.
The values live only in that command's environment and are never printed.
EOF
}

function _die() {
    printf 'pass-run: %s\n' "$1" >&2
    exit "${2:-1}"
}

function _main() {
    local -a assigns=()
    while (($# > 0)); do
        case "$1" in
            --)
                shift
                break
                ;;
            -h | --help)
                _usage
                return 0
                ;;
            *=*)
                assigns+=("$1")
                shift
                ;;
            *)
                _usage >&2
                _die "expected VAR=store/path or --, got '$1'" 2
                ;;
        esac
    done
    ((${#assigns[@]} > 0)) || _die 'no VAR=store/path given' 2
    (($# > 0)) || _die 'no command after --' 2
    command -v pass >/dev/null 2>&1 || _die 'pass is not installed (./bin/bootstrap.sh --only secrets)'

    local a var path value
    for a in "${assigns[@]}"; do
        var="${a%%=*}"
        path="${a#*=}"
        [[ "${var}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || _die "invalid variable name '${var}'" 2
        # A store path, not an option or a filesystem escape.
        if [[ -z "${path}" || "${path}" == -* || "${path}" == /* || "/${path}/" == */../* ]]; then
            _die "invalid store path '${path}' for ${var}" 2
        fi
        # pass's own diagnostics (missing entry, agent can't prompt) carry
        # no secret; they stay visible on stderr.
        value="$(pass show "${path}")" || _die "cannot read '${path}' from pass"
        value="${value%%$'\n'*}"
        [[ -n "${value}" ]] || _die "'${path}' is empty in pass"
        export "${var}=${value}"
    done
    unset a value
    exec "$@"
}

_main "$@"
