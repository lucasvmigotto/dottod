#!/usr/bin/env bash
#
# tools.sh — dottod CLI tools: the core set from native packages, plus
# opt-in extras (DOT_TOOLS_EXTRA, bootstrap's --extras).
#
# Usage: tools.sh [""] | status | --help|-h
#   ("")     install the core tools and the selected extras
#   status   print which tools are present, without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# gh: the distro package, except on Debian/Ubuntu, where the official
# GitHub CLI apt repository is used (https://cli.github.com) because the
# distro's own gh lags far behind.
function _github_cli_install() {
    if _is_installed gh; then
        log_info 'gh already installed, skipping...'
        return 0
    fi

    _os_detect || return 1
    if [[ "${DOTTOD_OS_FAMILY}" == debian ]]; then
        _github_cli_apt_repo || return 1
    fi

    log_step 'Installing GitHub CLI (gh)'
    _install_packages gh

    if ! _is_installed gh; then
        log_error 'GitHub CLI install did not yield a gh binary on PATH.'
        return 1
    fi
    log_ok 'GitHub CLI installed'
    return 0
}

# _github_cli_apt_repo: the signed GitHub CLI apt source (Debian family
# only). Download-then-install: a failed download never produces a keyring.
function _github_cli_apt_repo() {
    local arch keyring tmp_key
    arch="$(dpkg --print-architecture)"
    keyring='/usr/share/keyrings/githubcli-archive-keyring.gpg'

    log_step 'Installing GitHub CLI prerequisites'
    _install_packages curl ca_certificates gnupg

    tmp_key="$(mktemp)"
    log_step 'Adding GitHub CLI apt repository'
    _download 'https://cli.github.com/packages/githubcli-archive-keyring.gpg' "${tmp_key}"
    _priv install -m 0644 "${tmp_key}" "${keyring}"
    rm -f "${tmp_key}"

    echo "deb [arch=${arch} signed-by=${keyring}] https://cli.github.com/packages stable main" |
        _priv tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    # The new source must be in the index before gh can resolve.
    _priv env DEBIAN_FRONTEND=noninteractive apt-get update -qq
}

# Opt-in tools (default: none). DOT_TOOLS_EXTRA is a comma-separated list
# of these names, or `all`; bootstrap's --extras sets it.
readonly DOT_TOOLS_EXTRAS=(gh httpie chafa fastfetch)

# _extra_wanted <name>: 0 when DOT_TOOLS_EXTRA selects that tool.
function _extra_wanted() {
    local list=",${DOT_TOOLS_EXTRA:-},"
    [[ "${list}" == *",all,"* || "${list}" == *",${1},"* ]]
}

function _extras_validate() {
    local item known
    local IFS=','
    for item in ${DOT_TOOLS_EXTRA:-}; do
        [[ -z "${item}" || "${item}" == all ]] && continue
        for known in "${DOT_TOOLS_EXTRAS[@]}"; do
            [[ "${item}" == "${known}" ]] && continue 2
        done
        log_error "Unknown extra tool '${item}' (want: ${DOT_TOOLS_EXTRAS[*]}, or all)"
        return 1
    done
    return 0
}

# _tools_alias <name> <other>: when only one of two spellings of a tool
# is on PATH, link the missing one to it in ~/.local/bin.
function _tools_alias() {
    local a=${1} b=${2} have
    if _is_installed "${a}" && ! _is_installed "${b}"; then
        have="$(command -v "${a}")"
        ln -sfn "${have}" "$(_ensure_local_bin)/${b}"
        log_info "Linked ${b} -> ${have}"
    elif _is_installed "${b}" && ! _is_installed "${a}"; then
        have="$(command -v "${b}")"
        ln -sfn "${have}" "$(_ensure_local_bin)/${a}"
        log_info "Linked ${a} -> ${have}"
    fi
}

# The core tools by command name (bat may be batcat on Debian).
readonly DOT_TOOLS_CORE=(btop xclip bat jq curl tar lsof fzf shellcheck bats shfmt just)

function _tools_status() {
    local tool missing=() present=0
    for tool in "${DOT_TOOLS_CORE[@]}"; do
        if command -v "${tool}" >/dev/null 2>&1 ||
            { [[ "${tool}" == bat ]] && command -v batcat >/dev/null 2>&1; }; then
            present=$((present + 1))
        else
            missing+=("${tool}")
        fi
    done
    local extra_present=0 extra_missing=() selected=()
    for tool in "${DOT_TOOLS_EXTRAS[@]}"; do
        local cmd=${tool}
        [[ "${tool}" == httpie ]] && cmd=http
        if command -v "${cmd}" >/dev/null 2>&1; then
            extra_present=$((extra_present + 1))
        else
            extra_missing+=("${tool}")
        fi
        if _extra_wanted "${tool}"; then selected+=("${tool}"); fi
    done
    cat <<EOF
Tools
-----
Core:      ${present}/${#DOT_TOOLS_CORE[@]} present${missing[*]:+ (missing: ${missing[*]})}
Extras:    ${extra_present}/${#DOT_TOOLS_EXTRAS[@]} present${extra_missing[*]:+ (missing: ${extra_missing[*]})}
Selected:  ${selected[*]:-none} (DOT_TOOLS_EXTRA)
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: tools.sh [status]

  (no args)  install the core tools and the extras DOT_TOOLS_EXTRA selects
  status     print which tools are present, without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '') ;;
        status)
            _tools_status
            return 0
            ;;
        --help | -h)
            _usage
            return 0
            ;;
        *)
            log_error "Unknown action: ${1} (want empty or 'status')"
            _usage
            return 1
            ;;
    esac

    _extras_validate

    log_step 'Installing CLI tools (native packages)'
    _install_packages btop xclip bat jq curl tar ca_certificates lsof fzf shellcheck bats shfmt just

    # Debian renames bat and fd (batcat, fdfind); other distros don't.
    # Link the missing spelling so both names work everywhere.
    _tools_alias bat batcat
    _tools_alias fd fdfind

    local pkg_extras=()
    _extra_wanted httpie && pkg_extras+=(httpie)
    _extra_wanted chafa && pkg_extras+=(chafa)
    _extra_wanted fastfetch && pkg_extras+=(fastfetch)
    if ((${#pkg_extras[@]} > 0)); then
        log_step "Installing opt-in tools (native packages): ${pkg_extras[*]}"
        _install_packages "${pkg_extras[@]}"
    fi

    if _extra_wanted gh; then
        _github_cli_install
    fi

    log_ok 'Tools installed'
    return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi
