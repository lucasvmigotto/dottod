#!/usr/bin/env bash

alias z='zed --existing .'

# loadenv [file]: export KEY=value lines from a .env file (default .env).
# The file is data, never code: no eval, no expansion, no command
# substitution. Blank lines, # comments and an `export ` prefix are fine;
# matching quotes around a value are removed. A value `pass:store/path` is
# read from pass (its first line), so the file itself holds no secret.
# All-or-nothing: every line is parsed and every pass: value resolved
# before anything is exported. Prints variable names, never values.
function loadenv() {
    local env_file=${1:-'.env'}
    local line key value lineno=0 from_pass='' path
    local -a keys=() values=()

    if [[ ! -f "${env_file}" ]]; then
        echo "loadenv: ${env_file} not found" >&2
        return 1
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"
        [[ "${line}" =~ ^[[:space:]]*(#|$) ]] && continue
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line#export }"
        if [[ ! "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            echo "loadenv: ${env_file}:${lineno}: not KEY=value, nothing loaded" >&2
            return 1
        fi
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        if [[ "${value}" =~ ^\"(.*)\"$ || "${value}" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi
        if [[ "${value}" == pass:* ]]; then
            path="${value#pass:}"
            if ! value="$(pass show "${path}")"; then
                echo "loadenv: ${key}: cannot read '${path}' from pass, nothing loaded" >&2
                return 1
            fi
            value="${value%%$'\n'*}"
            from_pass+=" ${key}"
        fi
        keys+=("${key}")
        values+=("${value}")
    done <"${env_file}"

    local i
    for i in "${!keys[@]}"; do
        export "${keys[$i]}=${values[$i]}"
    done
    echo "loadenv: ${#keys[@]} from ${env_file}: ${keys[*]}${from_pass:+ (from pass:${from_pass})}" >&2
    return 0
}
