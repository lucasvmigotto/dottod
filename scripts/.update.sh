#!/usr/bin/env bash
#
# .update.sh — dottod self-update check (oh-my-zsh style, notify-only).
#
# Sourced with the other scripts/.*.sh libraries; pure definitions plus one
# explicit _dottod_update_check call from config/.custom.bashrc. Never blocks
# shell startup: the network refresh runs detached, the notice (if any) comes
# from a timestamped cache file.
#
# Config (environment variables):
#   DOT_UPDATE_DAYS      days between remote checks (default 7)
#   DOT_NO_UPDATE_CHECK  set (any value) to disable the check entirely
#   DOT_UPDATE_REPO      owner/repo slug (default: from origin, else
#                        lucasvmigotto/dottod)

# _dottod_ver_gt <a> <b>: true when SemVer a > b (tolerates a leading v and
# missing parts; non-numeric suffixes are ignored).
_dottod_ver_gt() {
    local a=${1#v} b=${2#v}
    local -a va=() vb=()
    IFS='.' read -ra va <<<"${a}" || true
    IFS='.' read -ra vb <<<"${b}" || true
    local i an bn
    for i in 0 1 2; do
        an="${va[$i]:-0}"
        bn="${vb[$i]:-0}"
        an="${an%%[^0-9]*}"
        bn="${bn%%[^0-9]*}"
        [[ -z "${an}" ]] && an=0
        [[ -z "${bn}" ]] && bn=0
        if ((10#${an} > 10#${bn})); then
            return 0
        fi
        if ((10#${an} < 10#${bn})); then
            return 1
        fi
    done
    return 1
}

# _dottod_update_root: prints the dottod checkout root, or fails.
# DOT_UPDATE_ROOT overrides detection (tests, exotic layouts).
_dottod_update_root() {
    if [[ -n "${DOT_UPDATE_ROOT:-}" ]]; then
        printf '%s' "${DOT_UPDATE_ROOT}"
        return 0
    fi
    [[ -n "${BASH_SOURCE[0]:-}" ]] || return 1
    command -v readlink >/dev/null 2>&1 || return 1
    dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
}

# _dottod_local_tag [root]: newest local SemVer tag, or fails.
_dottod_local_tag() {
    local root="${1:-$(_dottod_update_root)}"
    [[ -n "${root}" ]] || return 1
    git -C "${root}" tag --list '[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n 1 | grep -q . \
        && git -C "${root}" tag --list '[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n 1
}

# _dottod_repo_slug [root]: owner/repo for the remote release lookup.
_dottod_repo_slug() {
    if [[ -n "${DOT_UPDATE_REPO:-}" ]]; then
        printf '%s' "${DOT_UPDATE_REPO}"
        return 0
    fi
    local root="${1:-}" url slug
    url=""
    [[ -n "${root}" ]] && url="$(git -C "${root}" remote get-url origin 2>/dev/null)"
    if [[ "${url}" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
        slug="${BASH_REMATCH[1]}"
        printf '%s' "${slug%.git}"
        return 0
    fi
    printf 'lucasvmigotto/dottod'
}

# _dottod_update_state_file: path of the timestamped cache file.
_dottod_update_state_file() {
    printf '%s' "${XDG_STATE_HOME:-${HOME}/.local/state}/dottod/update-check"
}

# _dottod_update_refresh: fetch the newest release tag into the cache.
# Silent and infallible by design (it runs detached in the background).
_dottod_update_refresh() {
    local root slug json tag now state tmp
    root="$(_dottod_update_root)" || return 0
    command -v curl >/dev/null 2>&1 || return 0
    slug="$(_dottod_repo_slug "${root}")"
    json="$(curl -fsSL --max-time 8 "https://api.github.com/repos/${slug}/releases/latest" 2>/dev/null)" || return 0
    tag="$(printf '%s' "${json}" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | cut -d'"' -f4)" || return 0
    [[ "${tag}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 0
    now="$(date +%s 2>/dev/null)" || return 0
    state="$(_dottod_update_state_file)"
    mkdir -p -- "${state%/*}" 2>/dev/null || return 0
    tmp="$(mktemp "${state%/*}/update-check.XXXXXX" 2>/dev/null)" || return 0
    printf '%s %s\n' "${now}" "${tag}" >"${tmp}" || {
        rm -f -- "${tmp}"
        return 0
    }
    mv -- "${tmp}" "${state}" 2>/dev/null || rm -f -- "${tmp}"
    return 0
}

# _dottod_update_check: notify once per DOT_UPDATE_DAYS when a newer release
# tag is known. Reads the cache; refreshes it detached when stale. Always
# silent except for the notice itself; never fails the shell.
_dottod_update_check() {
    [[ $- == *i* ]] || return 0
    [[ -z "${DOT_NO_UPDATE_CHECK:-}" ]] || return 0
    local root local_tag state checked remote now maxage
    root="$(_dottod_update_root)" || return 0
    state="$(_dottod_update_state_file)"
    now="$(date +%s 2>/dev/null)" || return 0
    maxage=$(( ${DOT_UPDATE_DAYS:-7} * 86400 ))
    if [[ -s "${state}" ]]; then
        read -r checked remote <"${state}" || return 0
        if [[ ! "${checked}" =~ ^[0-9]+$ ]] || ((now - checked >= maxage)); then
            ( _dottod_update_refresh </dev/null >/dev/null 2>&1 & )
        fi
    else
        ( _dottod_update_refresh </dev/null >/dev/null 2>&1 & )
        return 0
    fi
    [[ -n "${remote:-}" ]] || return 0
    local_tag="$(_dottod_local_tag "${root}")" || return 0
    [[ -n "${local_tag}" ]] || return 0
    if _dottod_ver_gt "${remote}" "${local_tag}"; then
        printf '[dottod] update available: %s → %s — run `dottod-update`\n' "${local_tag}" "${remote}"
    fi
    return 0
}

# dottod-update: fast-forward the checkout to the newest release (git
# installs), or print tarball instructions otherwise.
dottod-update() {
    local root tag
    root="$(_dottod_update_root)" || {
        echo 'dottod-update: dottod checkout not found' >&2
        return 1
    }
    if git -C "${root}" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "${root}" pull --ff-only || {
            echo 'dottod-update: fast-forward failed (diverged? update it by hand)' >&2
            return 1
        }
        tag="$(_dottod_local_tag "${root}")"
        printf 'dottod updated%s\n' "${tag:+ to ${tag}}"
        return 0
    fi
    printf '%s\n' 'dottod-update: not a git checkout (tarball install?).' \
        'Re-download the newest dottod-scripts-<version>.tar.gz release and' \
        'extract it over your install, then reload your shell.'
    return 1
}
