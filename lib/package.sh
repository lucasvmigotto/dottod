#!/usr/bin/env bash
#
# package.sh — native package operations for dottod (spec 015).
#
# Sourced by bin/utils.sh after lib/os.sh; sourcing only defines
# functions. Tasks keep calling _install_packages (bin/utils.sh), which
# lands here. One backend per family, chosen by lib/os.sh detection:
#
#   family  install                                   installed?        candidate
#   debian  apt-get install -qq --yes                 dpkg-query        apt-cache policy
#   gentoo  emerge --noreplace --ask=n --autounmask=n portageq          portageq best_visible
#   arch    pacman -S --needed --noconfirm            pacman -Q         pacman -Si
#   redhat  dnf install -y                            rpm -q            dnf repoquery
#   alpine  apk add                                   apk info -e       apk policy
#
# Fail closed: an unknown distribution, or a family whose manager is not
# on PATH, errors before any package command runs. There is no apt
# fallback.
#
# Refresh policy: debian and alpine refresh their index once per
# bootstrap run (shared by --parallel tasks through a stamp keyed by
# DOT_RUN_ID) or once per process for a task run directly. Gentoo never
# syncs, Arch never runs a lone -Sy (partial upgrades), dnf manages its
# own metadata.
#
# Serialization: refresh + install run under flock(1) on
# ${DOT_LOG_DIR}/pkg.lock, so dottod's own transactions never interleave.
#
# Tasks use logical names (DOT_PKG_LOGICAL); lib/packages/<family>.sh maps
# them to native packages. A name with no entry is a bug (tests require
# full coverage); '-' means the family deliberately lacks it, and the
# install skips it with a warning.

# Every logical package a task may request. Adding a name here requires an
# entry in all five tables (tests/test-packages.bats enforces it).
# shellcheck disable=SC2034 # read by tests and the resolve gate
readonly DOT_PKG_LOGICAL=(
    bash bat bats btop ca_certificates chafa curl cxx_runtime fontconfig fzf gh
    git gnupg httpie jq just lsof neovim openssh_client podman podman_rootless
    python3 shellcheck shfmt tar unzip vim xclip
)

# _pkg_ready: detect once per process and require the manager.
function _pkg_ready() {
    if [[ "${_DOT_PKG_READY:-0}" == 1 ]]; then
        return 0
    fi
    _os_detect || return 1
    _os_require_pkg || return 1
    _DOT_PKG_READY=1
}

# --- backends: installed? ---------------------------------------------

# Query helpers read their command's whole output before matching: a
# reader that stops early (grep -q, head, awk exit) kills the writer with
# SIGPIPE, and under pipefail the pipeline then reports failure.

function _pkg_debian_is_installed() {
    [[ "$(dpkg-query -W -f='${Status}' "${1}" 2>/dev/null)" == *'install ok installed'* ]]
}

function _pkg_gentoo_is_installed() {
    portageq has_version / "${1}" >/dev/null 2>&1
}

function _pkg_arch_is_installed() {
    pacman -Q "${1}" >/dev/null 2>&1
}

function _pkg_redhat_is_installed() {
    rpm -q "${1}" >/dev/null 2>&1
}

function _pkg_alpine_is_installed() {
    apk info -e "${1}" >/dev/null 2>&1
}

# --- backends: refresh (only where the policy above says so) ----------

function _pkg_debian_refresh() {
    _priv env DEBIAN_FRONTEND=noninteractive apt-get update -qq
}

function _pkg_alpine_refresh() {
    _priv apk update -q
}

# --- backends: install ------------------------------------------------

function _pkg_debian_install() {
    _priv env DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes "$@"
}

function _pkg_gentoo_install() {
    # --autounmask=n: a needed USE/keyword change fails with emerge's own
    # message instead of writing to /etc/portage. The user's
    # EMERGE_DEFAULT_OPTS (binhost, jobs) still apply.
    log_warn "emerge may build from source (${*}); this can take a while"
    _priv emerge --noreplace --ask=n --autounmask=n "$@"
}

function _pkg_arch_install() {
    _priv pacman -S --needed --noconfirm "$@"
}

function _pkg_redhat_install() {
    _priv dnf install -y "$@"
}

function _pkg_alpine_install() {
    _priv apk add -q "$@"
}

# --- backends: candidate version (raw distro version string) ----------

function _pkg_debian_candidate() {
    apt-cache policy "${1}" 2>/dev/null | awk '/Candidate:/ && !done {print $2; done = 1}'
}

function _pkg_gentoo_candidate() {
    # best_visible prints category/name-version[-rN]; empty when masked/absent.
    local best
    best="$(portageq best_visible / "${1}" 2>/dev/null)" || return 0
    [[ -n "${best}" ]] || return 0
    printf '%s' "${best#"${1}"-}"
}

function _pkg_arch_candidate() {
    pacman -Si "${1}" 2>/dev/null | awk -F': *' '/^Version/ && !done {print $2; done = 1}'
}

function _pkg_redhat_candidate() {
    local out
    out="$(dnf repoquery -q --latest-limit 1 --queryformat '%{version}\n' "${1}" 2>/dev/null)" || return 0
    printf '%s' "${out%%$'\n'*}"
}

function _pkg_alpine_candidate() {
    # First indented version line after "<name> policy:".
    apk policy "${1}" 2>/dev/null | awk '/^  [^ ].*:$/ && !done {sub(/^  /, ""); sub(/:$/, ""); print; done = 1}'
}

# _pkg_norm_ver <raw>: drops an epoch (N:) and the distro revision
# (-1, -r0, -1.fc42, -r1 for Gentoo/Alpine) so callers compare upstream
# versions only.
function _pkg_norm_ver() {
    local v=${1}
    v="${v#*:}"
    v="${v%%-*}"
    v="${v%%+*}"
    v="${v%%~*}"
    printf '%s' "${v}"
}

# --- public API -------------------------------------------------------

# _pkg_resolve <logical...>: fills _DOT_PKG_RESOLVED (native names, in
# order) and _DOT_PKG_UNSUPPORTED (logical names the family lacks). Fails
# on a name with no mapping entry.
function _pkg_resolve() {
    local name native
    local -a words=()
    _DOT_PKG_RESOLVED=()
    _DOT_PKG_UNSUPPORTED=()
    for name in "$@"; do
        if ! native="$("_pkgmap_${DOTTOD_OS_FAMILY}" "${name}")"; then
            log_error "No ${DOTTOD_OS_FAMILY} mapping for package '${name}' (add it to lib/packages/${DOTTOD_OS_FAMILY}.sh)"
            return 1
        fi
        if [[ "${native}" == '-' ]]; then
            _DOT_PKG_UNSUPPORTED+=("${name}")
            continue
        fi
        read -ra words <<<"${native}"
        _DOT_PKG_RESOLVED+=("${words[@]}")
    done
}

# _pkg_is_installed <logical>: 0 when every native package it maps to is
# installed; 1 otherwise, including when the family lacks it.
function _pkg_is_installed() {
    local pkg
    _pkg_ready || return 1
    _pkg_resolve "${1:?'package required'}" || return 1
    ((${#_DOT_PKG_RESOLVED[@]} > 0)) || return 1
    for pkg in "${_DOT_PKG_RESOLVED[@]}"; do
        "_pkg_${DOTTOD_OS_FAMILY}_is_installed" "${pkg}" || return 1
    done
}

# _pkg_candidate_version <logical>: prints the upstream version the manager
# would install. rc 0 = version printed, rc 1 = no candidate (absent or
# masked), rc 2 = unknown (detection failed). Unknown is never "too old".
function _pkg_candidate_version() {
    local raw
    _pkg_ready 2>/dev/null || return 2
    _pkg_resolve "${1:?'package required'}" 2>/dev/null || return 2
    ((${#_DOT_PKG_RESOLVED[@]} > 0)) || return 1
    raw="$("_pkg_${DOTTOD_OS_FAMILY}_candidate" "${_DOT_PKG_RESOLVED[0]}")" || raw=''
    if [[ -z "${raw}" || "${raw}" == '(none)' ]]; then
        return 1
    fi
    printf '%s' "$(_pkg_norm_ver "${raw}")"
}

# _pkg_refresh_once: refresh the index at most once per run, for the
# families whose policy refreshes. Caller holds the lock. Under bootstrap
# (DOT_RUN_ID set) a stamp file shares the refresh across task processes;
# a task run directly remembers it in this process only.
function _pkg_refresh_once() {
    declare -F "_pkg_${DOTTOD_OS_FAMILY}_refresh" >/dev/null || return 0
    if [[ -z "${DOT_RUN_ID:-}" ]]; then
        [[ "${_DOT_PKG_REFRESHED:-}" == "${DOTTOD_OS_FAMILY}" ]] && return 0
        "_pkg_${DOTTOD_OS_FAMILY}_refresh" || return 1
        _DOT_PKG_REFRESHED="${DOTTOD_OS_FAMILY}"
        return 0
    fi
    local stamp="${DOT_LOG_DIR}/pkg-refresh.${DOTTOD_OS_FAMILY}.${DOT_RUN_ID}"
    [[ -e "${stamp}" ]] && return 0
    "_pkg_${DOTTOD_OS_FAMILY}_refresh" || return 1
    : >"${stamp}"
}

# _pkg_locked <cmd...>: runs cmd under dottod's package lock (flock on
# ${DOT_LOG_DIR}/pkg.lock), on a descriptor of this shell, not a subshell,
# so process-local refresh memory survives; released on every path.
function _pkg_locked() {
    local lock="${DOT_LOG_DIR}/pkg.lock"

    if ! command -v flock >/dev/null 2>&1; then
        log_warn 'flock not found; package transactions are not serialized'
        "$@"
        return
    fi
    if [[ -L "${lock}" ]]; then
        log_error "Refusing symlinked lock file: ${lock}"
        return 1
    fi
    (umask 077 && : >>"${lock}") || return 1

    local fd rc=0
    exec {fd}>>"${lock}" || return 1
    if flock "${fd}"; then
        "$@" || rc=$?
    else
        rc=1
    fi
    exec {fd}>&-
    return "${rc}"
}

# _pkg_refresh_and_install <native...>: refresh (if due) + install.
function _pkg_refresh_and_install() {
    _pkg_refresh_once && "_pkg_${DOTTOD_OS_FAMILY}_install" "$@"
}

# _pkg_transaction <native...>: refresh (if due) + install, under the lock.
function _pkg_transaction() {
    _pkg_locked _pkg_refresh_and_install "$@"
}

# _pkg_refresh_index: refresh the package index now (once per run, under
# the lock) so candidate lookups see current data — a fresh Debian has no
# apt lists, and its candidate would read "none". May need privilege.
# No-op with _DOT_NO_PACKAGES=1 and for families that never refresh.
function _pkg_refresh_index() {
    [[ "${_DOT_NO_PACKAGES:-0}" == 1 ]] && return 0
    _pkg_ready || return 1
    _pkg_locked _pkg_refresh_once
}

# _pkg_install <logical...>: installs what is missing; no privilege, refresh
# or lock when everything is already installed. A failed transaction
# fails with the manager's own output left visible.
function _pkg_install() {
    local -a missing=()
    local pkg

    (($# > 0)) || return 0
    _pkg_ready || return 1
    _pkg_resolve "$@" || return 1
    for pkg in "${_DOT_PKG_UNSUPPORTED[@]}"; do
        log_warn "${pkg} is not packaged for ${DOTTOD_OS_FAMILY}; skipping it"
    done
    ((${#_DOT_PKG_RESOLVED[@]} > 0)) || return 0

    for pkg in "${_DOT_PKG_RESOLVED[@]}"; do
        "_pkg_${DOTTOD_OS_FAMILY}_is_installed" "${pkg}" || missing+=("${pkg}")
    done
    if ((${#missing[@]} == 0)); then
        log_info "Packages already installed, skipping: ${_DOT_PKG_RESOLVED[*]}"
        return 0
    fi

    log_info "Installing with ${DOTTOD_PKG}: ${missing[*]}"
    if ! _pkg_transaction "${missing[@]}"; then
        log_error "${DOTTOD_PKG} failed to install: ${missing[*]}"
        if [[ "${DOTTOD_OS_FAMILY}" == arch ]]; then
            log_error 'If the package database is stale, run: sudo pacman -Syu (dottod never runs a partial -Sy)'
        elif [[ "${DOTTOD_OS_FAMILY}" == gentoo ]]; then
            log_error 'If an atom is missing or masked, sync (emaint sync -a) or adjust /etc/portage yourself; dottod never edits it'
        fi
        return 1
    fi
    return 0
}
