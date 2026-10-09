#!/usr/bin/env bash
#
# .claude.sh — work/personal Claude Code profiles sharing one store.
#
# Layout:
#   ~/.claude            shared store (memory, skills, plugins, projects, …)
#   ~/.claude-work       work overlay: settings.json + .credentials.json real,
#                        everything shared symlinked to ~/.claude/…
#   ~/.claude-personal   same for personal
#
# Usage: `claude` picks a profile (fzf when interactive), `claudew` and
# `claudep` jump straight to work/personal. Every overlay entry that can be
# shared is a symlink — only per-profile files are real.
#
# Config (environment variables):
#   CLAUDE_PROFILE       work|personal (bypasses the picker)
#   CLAUDE_WORK_DIR      work overlay dir (default ~/.claude-work)
#   CLAUDE_PERSONAL_DIR  personal overlay dir (default ~/.claude-personal)
#   CLAUDE_DEFAULT_PROFILE  fallback when no picker (default personal)
#   CLAUDE_NO_PICKER     set (any value) to never show the picker

# Entries shared from ~/.claude into each overlay (symlinked when present).
__DOTTOD_CLAUDE_SHARED="projects plans plugins skills history.jsonl file-history downloads cache backups shell-snapshots paste-cache sessions session-env state"

# __dottod_claude_profile_dir <work|personal>: prints the overlay dir.
__dottod_claude_profile_dir() {
    case "${1:?profile required}" in
        work) printf '%s' "${CLAUDE_WORK_DIR:-${HOME}/.claude-work}" ;;
        personal) printf '%s' "${CLAUDE_PERSONAL_DIR:-${HOME}/.claude-personal}" ;;
        *) return 1 ;;
    esac
}

# __dottod_claude_binary: prints the real claude binary path, ignoring this
# file's claude() wrapper. Fails when no binary is on PATH.
__dottod_claude_binary() {
    local d IFS=:
    for d in ${PATH:-/usr/bin:/bin}; do
        if [[ -f "${d}/claude" && -x "${d}/claude" ]]; then
            printf '%s' "${d}/claude"
            return 0
        fi
    done
    return 1
}

# __dottod_claude_ensure_profile <work|personal>: builds the overlay
# (idempotent, never overwrites real files) and prints its dir. Migrates the
# shared personal token into the personal overlay once.
__dottod_claude_ensure_profile() {
    local name="${1:?profile required}" dir entry src
    dir="$(__dottod_claude_profile_dir "${name}")" || return 1
    [[ -n "${HOME:-}" ]] || {
        echo 'claude: HOME is empty' >&2
        return 1
    }
    mkdir -p -- "${dir}" || {
        echo "claude: cannot create ${dir}" >&2
        return 1
    }
    chmod 700 -- "${dir}" 2>/dev/null || true
    for entry in ${__DOTTOD_CLAUDE_SHARED}; do
        src="${HOME}/.claude/${entry}"
        [[ -e "${src}" ]] || continue
        if [[ -L "${dir}/${entry}" ]]; then
            continue
        elif [[ -e "${dir}/${entry}" ]]; then
            printf 'claude: keeping existing %s (not replacing with a link)\n' "${dir}/${entry}" >&2
            continue
        fi
        ln -s -- "${src}" "${dir}/${entry}" || printf 'claude: cannot link %s\n' "${entry}" >&2
    done
    if [[ ! -e "${dir}/settings.json" && -f "${HOME}/.claude/settings.json" ]]; then
        cp -- "${HOME}/.claude/settings.json" "${dir}/settings.json" 2>/dev/null || true
    fi
    if [[ "${name}" == "personal" && -f "${HOME}/.claude/.credentials.json" ]]; then
        if [[ ! -e "${dir}/.credentials.json" ]]; then
            mv -- "${HOME}/.claude/.credentials.json" "${dir}/.credentials.json" 2>/dev/null \
                && chmod 600 -- "${dir}/.credentials.json" 2>/dev/null \
                && printf 'claude: adopted the shared login into the personal profile\n' >&2 || true
        elif ! cmp -s -- "${HOME}/.claude/.credentials.json" "${dir}/.credentials.json" 2>/dev/null; then
            printf 'claude: ignoring a login in the shared store (log in through claudew/claudep instead)\n' >&2
        fi
    fi
    printf '%s' "${dir}"
}

# __dottod_claude_fzf: profile picker, prints work|personal (fails on esc).
__dottod_claude_fzf() {
    local wdir pdir
    wdir="$(__dottod_claude_profile_dir work)"
    pdir="$(__dottod_claude_profile_dir personal)"
    printf 'work\npersonal\n' \
        | CLAUDE_WD="${wdir}" CLAUDE_PD="${pdir}" fzf --prompt='profile> ' \
            --height=40% --layout=reverse --border \
            --header='enter: launch   esc: cancel' \
            --preview='if [ "{}" = work ]; then d="$CLAUDE_WD"; else d="$CLAUDE_PD"; fi; if [ -s "$d/.credentials.json" ]; then echo authenticated; else echo "needs /login"; fi; ls "$d" 2>/dev/null'
}

# __dottod_claude_pick_profile: prints the profile to use (fails on esc or
# a bad CLAUDE_PROFILE value).
__dottod_claude_pick_profile() {
    local choice="${CLAUDE_PROFILE:-}" picked
    case "${choice}" in
        work | personal)
            printf '%s' "${choice}"
            return 0
            ;;
        "")
            ;;
        *)
            printf 'claude: unknown CLAUDE_PROFILE=%s (want work|personal)\n' "${choice}" >&2
            return 2
            ;;
    esac
    if [[ $- == *i* ]] && [[ -t 0 ]] && [[ -z "${CLAUDE_NO_PICKER:-}" ]] && command -v fzf >/dev/null 2>&1; then
        picked="$(__dottod_claude_fzf)" || return $?
        [[ -n "${picked}" ]] || return 130
        printf '%s' "${picked}"
        return 0
    fi
    printf '%s' "${CLAUDE_DEFAULT_PROFILE:-personal}"
}

# claude-profiles-init: builds both overlays (migrates the personal token).
claude-profiles-init() {
    __dottod_claude_ensure_profile work >/dev/null || return 1
    __dottod_claude_ensure_profile personal >/dev/null || return 1
    printf 'claude profiles ready: work + personal (shared store %s/.claude)\n' "${HOME}"
}

# claude: launch Claude Code under the picked profile.
claude() {
    local profile dir
    if ! __dottod_claude_binary >/dev/null; then
        echo 'claude: binary not found on PATH' >&2
        return 127
    fi
    profile="$(__dottod_claude_pick_profile)" || return $?
    dir="$(__dottod_claude_ensure_profile "${profile}")" || return $?
    CLAUDE_CONFIG_DIR="${dir}" command claude "$@"
}

# claudew / claudep: jump straight to a profile.
claudew() {
    CLAUDE_PROFILE=work claude "$@"
}

claudep() {
    CLAUDE_PROFILE=personal claude "$@"
}
