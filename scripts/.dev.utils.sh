#!/usr/bin/env bash
# NOTE: PATH for ~/.opencode/bin is owned by config/.custom.bashrc
# (dedup-safe); do not prepend here or `reload` duplicates entries.

function loadenv() {

    local env_file=${1:-'.env'}

    if [[ ! -f "${env_file}" ]]; then
        echo "File ${env_file} not found" >&2
        return 1
    fi

    set -a
    eval "$(cat "${env_file}")"
    set +a

    return 0

}

ocresume() {
    local dir
    dir=$(cd "${1:-$PWD}" && pwd) || return 1

    local d
    for d in opencode jq fzf; do
        if ! command -v "$d" >/dev/null 2>&1; then
            echo "ocresume: '$d' is required but not on PATH" >&2
            return 1
        fi
    done

    local sessions
    sessions=$(opencode session list --format json) || {
        echo "ocresume: 'opencode session list' failed" >&2
        return 1
    }

    local rows
    rows=$(jq -r --arg dir "$dir" '
            map(select(.directory == $dir))
            | sort_by(-.updated)[]
            | [
                .id,
                (.updated / 1000 | gmtime | strftime("%Y-%m-%d %H:%M")),
                (.title // "(untitled)")
              ]
            | @tsv
        ' <<<"$sessions" 2>&1)

    if [[ -z "$rows" ]]; then
        echo "ocresume: no opencode sessions found for ${dir}" >&2
        return 1
    fi

    local picked
    picked=$(printf '%s\n' "$rows" |
        fzf --delimiter='\t' \
            --with-nth=2,3 \
            --prompt='opencode session> ' \
            --header='enter: resume   esc: cancel' |
        cut -f1)

    [[ -z "$picked" ]] && return 130

    (cd "$dir" && exec opencode --session "$picked")
}
