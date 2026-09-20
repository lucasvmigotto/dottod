#!/usr/bin/env bash
#
# neovim.sh — dottod Neovim task (first-class additional editor; Vim stays).
#
# Validates Neovim version (>= 0.11.0) and links config/nvim to ~/.config/nvim
# without ever destroying an existing user configuration.
#
# Version policy: minimum supported Neovim is 0.11.0.
# If Neovim is missing or too old, fails with actionable instructions.
# Opt-in healing via official GitHub tarball:
#   _DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh
#
# Env overrides:
#   _DOT_NVIM_MIN_VERSION   minimum accepted version (default 0.11.0)
#   _DOT_NVIM_VERSION       tarball version when healing (default v0.12.5)
#   _DOT_NVIM_ALLOW_TARBALL 0|1 (default 0: fail with instructions)
#   _DOT_NVIM_PROFILE       minimal|terminal|development|full (default development)
#   _DOT_NVIM_TARBALL_ROOT  tarball extract root (default ~/.local/nvim)
#   _DOT_TARGET_USER        target user (default id -un)
#   _DOT_NVIM_CONFIG_HOME   parent of nvim config dir (default ~/.config, tests override HOME)
#   _DOT_NO_PACKAGES        1 skips apt (tests)
#
# Usage: neovim.sh [""] | status | --help|-h
#   ("")     validate version + link config
#   status   print version/selection report without changing anything

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

_DOT_NVIM_MIN_VERSION_DEFAULT='0.11.0'
_DOT_NVIM_VERSION_DEFAULT='v0.12.5'
_DOT_NVIM_PROFILE_DEFAULT='development'

function _nvim_norm_ver() {
    local v=${1:?'Version must be informed'}
    v="${v#v}"
    v="${v%%[-+]*}"
    v="${v#*:}" # optional apt epoch, e.g. 1:0.12.5-1~trixie
    printf '%s' "${v}"
}

# _nvim_ver_ge have max_ge: 0 if have >= min, 1 otherwise.
function _nvim_ver_ge() {
    local have min
    have="$(_nvim_norm_ver "${1:?'Have version must be informed'}")"
    min="$(_nvim_norm_ver "${2:?'Min version must be informed'}")"
    local -a h=() m=()
    IFS='.' read -ra h <<<"${have}" || true
    IFS='.' read -ra m <<<"${min}" || true
    local i hn mn
    for i in 0 1 2; do
        hn="${h[$i]:-0}"
        mn="${m[$i]:-0}"
        hn="${hn%%[^0-9]*}"
        mn="${mn%%[^0-9]*}"
        [[ -z "${hn}" ]] && hn=0
        [[ -z "${mn}" ]] && mn=0
        if [[ "${hn}" -gt "${mn}" ]]; then
            return 0
        fi
        if [[ "${hn}" -lt "${mn}" ]]; then
            return 1
        fi
    done
    return 0
}

# Print installed version (e.g. 0.12.5) or fail when absent/unparseable.
function _nvim_version() {
    local out
    out="$(nvim --version 2>/dev/null | head -n1)" || return 1
    if [[ "${out}" =~ NVIM\ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Print apt candidate version or empty when none.
function _nvim_apt_candidate() {
    local cand
    cand="$(apt-cache policy neovim 2>/dev/null | awk '/Candidate:/ {print $2}' | head -n1)" || true
    if [[ -z "${cand}" || "${cand}" == '(none)' ]]; then
        printf ''
        return 0
    fi
    printf '%s' "$(_nvim_norm_ver "${cand}")"
    return 0
}

function _nvim_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf 'x86_64' ;;
        arm64|aarch64) printf 'arm64' ;;
        *) return 1 ;;
    esac
}

# Resolve the tarball download URL and its sha256 digest for a release tag
# from the GitHub API (over TLS, same origin as the download). Prints
# "<url> <sha256hex>" or fails. Accepts v-tags and the 'stable' alias.
function _nvim_tarball_asset() {
    local version=${1:?'Version must be informed'}
    local arch=${2:?'Arch must be informed'}
    local asset_name="nvim-linux-${arch}.tar.gz"
    local api_json url digest
    api_json="$(curl -fsSL "https://api.github.com/repos/neovim/neovim/releases/tags/${version}")" || return 1
    url="$(printf '%s' "${api_json}" | python3 -c '
import json,sys
for a in json.load(sys.stdin)["assets"]:
    if a["name"] == sys.argv[1]:
        print(a["browser_download_url"]); break
' "${asset_name}")"
    digest="$(printf '%s' "${api_json}" | python3 -c '
import json,sys
for a in json.load(sys.stdin)["assets"]:
    if a["name"] == sys.argv[1]:
        print((a.get("digest") or "").removeprefix("sha256:")); break
' "${asset_name}")"
    if [[ -z "${url}" || -z "${digest}" ]]; then
        log_error "No asset '${asset_name}' (with digest) for Neovim ${version}"
        return 1
    fi
    printf '%s %s\n' "${url}" "${digest}"
}

# Opt-in healing: official release tarball + sha256 verification (digest
# from the GitHub release API). Installs under _DOT_NVIM_TARBALL_ROOT
# (default ~/.local/nvim) and links nvim into ~/.local/bin. Rootless.
# Never adds third-party apt sources.
function _nvim_install_tarball() {
    local version=${1:?'Version must be informed'}
    local user=${2:?'User must be informed'}
    local user_home="/home/${user}"
    [[ "${user}" == "$(id -un)" ]] && user_home="${HOME}"
    local root=${_DOT_NVIM_TARBALL_ROOT:-"${user_home}/.local/nvim"}
    local arch url digest tmpdir
    arch="$(_nvim_arch)" || {
        log_error "Unsupported architecture '$(uname -m)' for Neovim tarball install."
        return 1
    }
    read -r url digest <<<"$(_nvim_tarball_asset "${version}" "${arch}")"

    if [[ -x "${root}/nvim-linux-${arch}/bin/nvim" ]]; then
        log_info "Neovim tarball ${version} already extracted, skipping..."
    else
        tmpdir="$(mktemp -d)"
        log_step "Downloading Neovim ${version} (${arch}) with sha256 verification"
        _download "${url}" "${tmpdir}/nvim.tar.gz"
        local actual
        actual="$(sha256sum "${tmpdir}/nvim.tar.gz" | cut -d' ' -f1)"
        if [[ "${actual}" != "${digest}" ]]; then
            log_error "Neovim tarball checksum mismatch (want ${digest}, got ${actual})."
            rm -rf "${tmpdir}"
            return 1
        fi
        mkdir -p "${root}"
        tar -xzf "${tmpdir}/nvim.tar.gz" -C "${root}"
        rm -rf "${tmpdir}"
        log_ok "Neovim ${version} extracted to ${root} (sha256 verified)"
    fi

    local local_bin dest
    local_bin="$(_ensure_local_bin)"
    dest="${local_bin}/nvim"
    if [[ ! -x "${dest}" ]]; then
        ln -sfn "${root}/nvim-linux-${arch}/bin/nvim" "${dest}"
        log_ok "Linked ${dest} -> ${root}/nvim-linux-${arch}/bin/nvim"
    else
        log_info 'nvim already on PATH, skipping link...'
    fi
    return 0
}

function _nvim_fail_old_apt() {
    local min=${1} cand=${2}
    if [[ -n "${cand}" ]] && ! _nvim_ver_ge "${cand}" "${min}"; then
        log_error "Neovim ${cand} via apt is below the minimum ${min}."
        log_error 'Debian trixie ships Neovim 0.10.4 which lacks vim.lsp.config APIs.'
    else
        log_error "apt did not yield a usable Neovim >= ${min} on PATH (candidate: ${cand:-<none>})."
    fi
    log_error 'Options: enable trixie-backports, use a newer Neovim source, or heal with the official tarball:'
    log_error '  _DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh'
    return 1
}

function _nvim_ensure_binary() {
    local min=${_DOT_NVIM_MIN_VERSION:-"${_DOT_NVIM_MIN_VERSION_DEFAULT}"}
    local ver cand

    if ver="$(_nvim_version 2>/dev/null)"; then
        if _nvim_ver_ge "${ver}" "${min}"; then
            log_info "Neovim ${ver} already installed (>= ${min}), skipping..."
            return 0
        fi
        log_error "Neovim ${ver} detected, but this configuration requires Neovim ${min}+."
        log_error 'Upgrade Neovim or use a compatible profile; refusing to use an incompatible binary.'
        return 1
    fi

    # Candidate-first: never attempt a doomed apt install (sudo prompt for a
    # version we already know is too old) when tarball healing is allowed.
    cand="$(_nvim_apt_candidate)"
    local need_tarball=0
    if [[ -n "${cand}" ]] && ! _nvim_ver_ge "${cand}" "${min}"; then
        log_info "apt Neovim candidate ${cand} is below minimum ${min}"
        need_tarball=1
    fi

    if [[ "${need_tarball}" == 0 ]]; then
        log_step 'Installing Neovim (apt)'
        _install_packages 'neovim'
        if ver="$(_nvim_version 2>/dev/null)" && _nvim_ver_ge "${ver}" "${min}"; then
            log_ok "Neovim ${ver} installed"
            return 0
        fi
        log_warn 'apt did not provide a usable/enough nvim binary'
        need_tarball=1
    fi

    if [[ "${_DOT_NVIM_ALLOW_TARBALL:-0}" != 1 ]]; then
        _nvim_fail_old_apt "${min}" "${cand:-${ver:-}}"
        return 1
    fi

    local tar_ver=${_DOT_NVIM_VERSION:-"${_DOT_NVIM_VERSION_DEFAULT}"}
    [[ "${tar_ver}" == v* ]] || tar_ver="v${tar_ver}"
    if ! _nvim_ver_ge "${tar_ver}" "${min}"; then
        log_error "_DOT_NVIM_VERSION=${tar_ver} is below minimum ${min}."
        return 1
    fi
    _nvim_install_tarball "${tar_ver}" "$(id -un)"
    if ver="$(_nvim_version 2>/dev/null)" && _nvim_ver_ge "${ver}" "${min}"; then
        log_ok "Neovim ${ver} ready (tarball)"
        return 0
    fi
    log_error 'Tarball install did not yield a compatible nvim on PATH.'
    log_error "Check that \$HOME/.local/bin/nvim exists and \$HOME/.local/bin is on PATH."
    return 1
}

function _nvim_config_target() {
    local user=${1:?'User must be informed'}
    if [[ -n "${_DOT_NVIM_CONFIG_HOME:-}" ]]; then
        printf '%s/nvim' "${_DOT_NVIM_CONFIG_HOME}"
        return 0
    fi
    if [[ "${user}" == "$(id -un)" ]]; then
        printf '%s/.config/nvim' "${HOME}"
        return 0
    fi
    printf '/home/%s/.config/nvim' "${user}"
}

# Link config/nvim -> ~/.config/nvim. Existing user config is moved to
# ~/.config/nvim.dottod.bak (timestamped suffix when a backup exists).
function _nvim_link_config() {
    local user=${1:?'User must be informed'}
    local source_dir="${DOT_REPO_ROOT}/config/nvim"
    local target
    target="$(_nvim_config_target "${user}")"

    if [[ -L "${target}" && "$(readlink "${target}")" == "${source_dir}" ]]; then
        log_info "Already linked: ${target}"
        return 0
    fi

    if [[ -e "${target}" || -L "${target}" ]]; then
        local backup="${target}.dottod.bak"
        if [[ -e "${backup}" || -L "${backup}" ]]; then
            backup="${backup}.$(date +%Y%m%d%H%M%S)"
        fi
        log_warn "Backing up existing ${target} to ${backup}"
        mv -f "${target}" "${backup}"
    fi

    mkdir -p "$(dirname "${target}")"
    ln -s "${source_dir}" "${target}"
    log_ok "Linked ${target} -> ${source_dir}"
    return 0
}

function _nvim_status() {
    local min=${_DOT_NVIM_MIN_VERSION:-"${_DOT_NVIM_MIN_VERSION_DEFAULT}"}
    local profile=${_DOT_NVIM_PROFILE:-"${_DOT_NVIM_PROFILE_DEFAULT}"}
    local ver='missing' state='missing' cand
    if ver="$(_nvim_version 2>/dev/null)"; then
        if _nvim_ver_ge "${ver}" "${min}"; then
            state="ok (>= ${min})"
        else
            state="too old (need >= ${min})"
        fi
    else
        ver='missing'
    fi
    cand="$(_nvim_apt_candidate)"
    local target
    target="$(_nvim_config_target "$(id -un)")"
    local link='missing'
    if [[ -L "${target}" ]]; then
        link="symlink -> $(readlink "${target}")"
    elif [[ -d "${target}" ]]; then
        link='directory (user-managed)'
    fi
    cat <<EOF
Neovim
------
Installed: ${ver} (${state})
Minimum:   ${min}
Apt cand:  ${cand:-<none>}
Profile:   ${profile}
Config:    ${target} (${link})
Rg:        $(command -v rg >/dev/null 2>&1 && echo present || echo missing)
Fd:        $(command -v fd fdfind >/dev/null 2>&1 && echo present || echo missing)
Git:       $(command -v git >/dev/null 2>&1 && echo present || echo missing)
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: neovim.sh [status]

First-class Neovim editor (Vim remains untouched).

  (no args)  validate version + link config
  status     print version/profile report without changing anything
EOF
}

function _main() {
    local profile=${_DOT_NVIM_PROFILE:-"${_DOT_NVIM_PROFILE_DEFAULT}"}
    case "${profile}" in
        minimal|terminal|development|full) ;;
        *)
            log_error "Invalid _DOT_NVIM_PROFILE='${profile}' (want minimal|terminal|development|full)"
            return 1
            ;;
    esac

    case "${1:-}" in
        '')
            _nvim_ensure_binary
            _nvim_link_config "$(id -un)"
            log_ok "Neovim ready (profile: ${profile})"
            return 0
            ;;
        status)
            _nvim_status
            return 0
            ;;
        --help|-h)
            _usage
            return 0
            ;;
        *)
            log_error "Unknown action: ${1} (want empty or 'status')"
            _usage
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    _main "$@"
fi