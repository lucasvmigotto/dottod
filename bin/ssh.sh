#!/usr/bin/env bash
#
# ssh.sh — installs the dottod GitHub SSH configuration without ever
# destroying existing user configuration.
#
# Behavior:
#   * ~/.ssh/config missing  -> installed from config/.ssh.config (mode 600).
#   * ~/.ssh/config present  -> the required GitHub options are merged in:
#       - an existing `Host github.com` block (exact, case-insensitive token,
#         no wildcards) gets only the missing options appended; user values
#         are never modified;
#       - otherwise the canonical block is appended once.
#   * Legacy dottod symlink (config -> repo template) is replaced by a real
#     merged file; a user symlink elsewhere is preserved and the merge is
#     applied to the file it points at.
#   * A backup (<config>.dottod.bak) is written only when an existing file
#     is modified. Repeated runs are byte-identical (idempotent).
#
# OpenSSH uses the first obtained value per option, so appending missing
# options can only fill gaps — it cannot override anything the user set.

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

function _ssh_dir() {
    local current_user=${1:?'User must be informed'}

    local ssh_dir=${_DOT_SSH_DIR:-"/home/${current_user}/.ssh"}
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    echo "${ssh_dir}"
}

# Prints the required GitHub options from the template's Host github.com
# block as "Key<TAB>value" lines, in template order. The template
# (config/.ssh.config) is the single source of truth.
function _github_wanted_options() {
    local template=${1:?'SSH template must be informed'}

    awk '
        function is_boundary(line) {
            low = tolower(line)
            return (low ~ /^[ \t]*(host|match)([ \t]|$)/)
        }
        /^[ \t]*[Hh][Oo][Ss][Tt][ \t]/ {
            inblock = 0
            rest = $0
            sub(/^[ \t]*[Hh][Oo][Ss][Tt][ \t]+/, "", rest)
            n = split(rest, toks, /[ \t]+/)
            for (i = 1; i <= n; i++) {
                tok = tolower(toks[i])
                if (tok !~ /[*?![]/ && tok == "github.com") { inblock = 1; break }
            }
            next
        }
        is_boundary($0) { inblock = 0; next }
        inblock && /^[ \t]*#/ { next }
        inblock && NF >= 2 {
            key = $1
            val = $0
            sub(/^[ \t]*[^ \t=]+[ \t=]+/, "", val)
            printf "%s\t%s\n", key, val
        }
    ' "${template}"
}

function _merge_github_config() {
    local target=${1:?'Target SSH config must be informed'}
    local template=${2:?'SSH template must be informed'}

    if [[ ! -f "${template}" ]]; then
        log_error "SSH template missing: ${template}"
        return 1
    fi

    # Migrate legacy installs: dottod used to symlink the template directly.
    if [[ -L "${target}" ]]; then
        local dest
        dest="$(readlink -m "${target}")"
        if [[ "${dest}" == "${template}" ]]; then
            log_info "Replacing legacy symlink ${target} with a managed file"
            rm -f "${target}"
        else
            log_info "Following user symlink ${target} -> ${dest}"
            target="${dest}"
        fi
    fi

    # Case A — no config yet: install the template verbatim.
    if [[ ! -e "${target}" ]]; then
        mkdir -p "$(dirname "${target}")"
        cp -p "${template}" "${target}"
        chmod 600 "${target}"
        log_ok "Installed default SSH config at ${target}"
        return 0
    fi

    # Required options (template order).
    local -a want_keys=() want_vals=()
    local k v
    while IFS=$'\t' read -r k v; do
        if [[ -n "${k}" ]]; then
            want_keys+=("${k}")
            want_vals+=("${v}")
        fi
    done < <(_github_wanted_options "${template}")
    if [[ ${#want_keys[@]} -lt 1 ]]; then
        log_error "No GitHub options found in ${template}"
        return 1
    fi

    # Case B — merge into the existing file.
    local -a lines=()
    mapfile -t lines <"${target}"
    local n=${#lines[@]}

    # Locate the first Host block naming exact (case-insensitive) github.com.
    local start=-1 end=${n} i line low rest tok tok_low
    for (( i = 0; i < n; i++ )); do
        line="${lines[i]}"
        low="${line,,}"
        if [[ "${low}" =~ ^[[:space:]]*(host|match)([[:space:]]|$) ]]; then
            if (( start >= 0 )); then
                end=${i}
                break
            fi
            if [[ "${line}" =~ ^[[:space:]]*[Hh][Oo][Ss][Tt][[:space:]]+(.*)$ ]]; then
                rest="${BASH_REMATCH[1]}"
                for tok in ${rest}; do
                    tok_low="${tok,,}"
                    case "${tok_low}" in
                        *\** | *\?* | *\!* | *\[*) continue ;;
                        github.com) start=${i} ;;
                    esac
                    (( start >= 0 )) && break
                done
            fi
        fi
    done

    # Which required options are missing from that block?
    local -a missing=()
    local ki found j
    if (( start >= 0 )); then
        for ki in "${!want_keys[@]}"; do
            k="${want_keys[ki]}"
            found=0
            for (( j = start; j < end; j++ )); do
                low="${lines[j],,}"
                # Option names are matched whole (boundary after the key),
                # so `User` never matches `UserKnownHostsFile`, and commented
                # lines (`# User git`) never count as present.
                if [[ "${low}" =~ ^[[:space:]]*${k,,}([[:space:]]|=|$) ]]; then
                    found=1
                    break
                fi
            done
            (( found == 0 )) && missing+=("${ki}")
        done
        if [[ ${#missing[@]} -eq 0 ]]; then
            log_info "GitHub SSH config already present in ${target}"
            return 0
        fi
    fi

    local backup="${target}.dottod.bak"
    log_warn "Backing up existing ${target} to ${backup}"
    cp -p "${target}" "${backup}"

    local tmp
    tmp="$(mktemp "$(dirname "${target}")/.ssh-config.XXXXXX")"
    if (( start < 0 )); then
        # No github.com block: append the canonical one (once).
        (( n > 0 )) && printf '%s\n' "${lines[@]}" >"${tmp}"
        # Ensure exactly one blank line separates the appended block.
        if (( n > 0 )) && [[ -n "${lines[n-1]}" ]]; then
            printf '\n' >>"${tmp}"
        fi
        printf 'Host github.com\n' >>"${tmp}"
        for ki in "${!want_keys[@]}"; do
            printf '    %s %s\n' "${want_keys[ki]}" "${want_vals[ki]}" >>"${tmp}"
        done
    else
        for (( i = 0; i < end; i++ )); do
            printf '%s\n' "${lines[i]}" >>"${tmp}"
        done
        for ki in "${missing[@]}"; do
            printf '    %s %s\n' "${want_keys[ki]}" "${want_vals[ki]}" >>"${tmp}"
        done
        for (( i = end; i < n; i++ )); do
            printf '%s\n' "${lines[i]}" >>"${tmp}"
        done
    fi
    mv -f "${tmp}" "${target}"
    chmod 600 "${target}"

    log_ok "GitHub SSH config ensured in ${target}"
    return 0
}

function _main() {
    local current_user ssh_dir
    current_user="$(id -un)"
    ssh_dir="$(_ssh_dir "${current_user}")"

    local target="${ssh_dir}/config"
    _merge_github_config "${target}" "${DOT_CONFIG_DIR}/.ssh.config"

    if [[ ! -e "${ssh_dir}/github" && ! -L "${ssh_dir}/github" ]]; then
        log_info "No ${ssh_dir}/github key found; create/provision it — the SSH config is ready regardless"
    fi

    # Smoke-test the resulting file (warn only; never fail the bootstrap).
    if ssh -G -F "${target}" github.com >/dev/null 2>&1; then
        log_info 'OpenSSH accepts the resulting configuration (ssh -G -F)'
    else
        log_warn 'OpenSSH could not parse the resulting configuration'
    fi

    log_ok 'ssh config installed'
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
