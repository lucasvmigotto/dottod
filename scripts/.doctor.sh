#!/usr/bin/env bash
#
# .doctor.sh — dottod health report for interactive shells.
#
# `dottod-doctor` prints one [ok]/[warn]/[fail] line per check: shell,
# tools, PATH, prompt, projects (codes), updates, Claude profiles, rootless
# Podman prerequisites (when podman is installed) and the checkout itself. Read-only: no installs, no network. Exits 1 only on hard
# failures (warnings still exit 0).
#
# Config (environment variables):
#   DOT_DOCTOR_TOOLS   space-separated tool list (default: git curl fzf pv rg
#                      jq python3 shellcheck bats shfmt just)

_DOTTOD_DOCTOR_TOOLS_DEFAULT="git curl fzf pv rg jq python3 shellcheck bats shfmt just"

__dottod_doc_tally_ok=0
__dottod_doc_tally_warn=0
__dottod_doc_tally_fail=0

__dottod_doc_ok() {
    _DOTTOD_DOC_OK=$((_DOTTOD_DOC_OK + 1))
    printf '[ok] %s\n' "$*"
}

__dottod_doc_warn() {
    _DOTTOD_DOC_WARN=$((_DOTTOD_DOC_WARN + 1))
    printf '[warn] %s\n' "$*"
}

__dottod_doc_fail() {
    _DOTTOD_DOC_FAIL=$((_DOTTOD_DOC_FAIL + 1))
    printf '[fail] %s\n' "$*"
}

__dottod_doc_init_tally() {
    _DOTTOD_DOC_OK=0
    _DOTTOD_DOC_WARN=0
    _DOTTOD_DOC_FAIL=0
}

# _dottod_doctor_root: the dottod checkout (follows this file), or empty.
_dottod_doctor_root() {
    [[ -n "${BASH_SOURCE[0]:-}" ]] || return 1
    command -v readlink >/dev/null 2>&1 || return 1
    dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
}

dottod-doctor() {
    __dottod_doc_init_tally
    local t d root branch dirty tag checked remote days found

    # Shell basics.
    if [[ -z "${HOME:-}" ]]; then
        __dottod_doc_fail "HOME is empty"
    elif ((BASH_VERSINFO[0] >= 4)); then
        __dottod_doc_ok "bash ${BASH_VERSION} (HOME set)"
    else
        __dottod_doc_warn "bash ${BASH_VERSION} is older than 4"
    fi

    # Distribution: what dottod's package layer detects (lib/os.sh, run in
    # a subshell so none of its functions leak into this shell).
    local distro_root distro
    distro_root="$(_dottod_doctor_root)" || distro_root=''
    if [[ -n "${distro_root}" && -f "${distro_root}/lib/os.sh" ]]; then
        if distro="$(
            # shellcheck source=../lib/os.sh
            source "${distro_root}/lib/os.sh" &&
                _os_detect 2>&1 &&
                printf '%s %s (%s family, %s, %s)' "${DOTTOD_OS_ID}" "${DOTTOD_OS_VERSION_ID:-rolling}" \
                    "${DOTTOD_OS_FAMILY}" "${DOTTOD_PKG}" "${DOTTOD_LIBC}" &&
                { _os_require_pkg >/dev/null 2>&1 || printf ' — %s not on PATH' "${DOTTOD_PKG}"; }
        )"; then
            if [[ "${distro}" == *'not on PATH'* ]]; then
                __dottod_doc_warn "distro: ${distro}"
            else
                __dottod_doc_ok "distro: ${distro}"
            fi
        else
            __dottod_doc_warn "distro: ${distro#dottod: }"
        fi
    fi

    # Toolchain.
    # shellcheck disable=SC2086 # intentional word splitting on the tool list
    for t in ${DOT_DOCTOR_TOOLS:-${_DOTTOD_DOCTOR_TOOLS_DEFAULT}}; do
        if command -v "${t}" >/dev/null 2>&1; then
            __dottod_doc_ok "${t} on PATH"
        else
            __dottod_doc_warn "${t} missing (bin/tools.sh installs it)"
        fi
    done

    # Tool dirs: present once each, never duplicated.
    for d in "${HOME}/.cargo/bin" "${HOME}/.bun/bin" "${HOME}/.local/bin"; do
        if [[ -d "${d}" ]]; then
            if [[ ":${PATH}:" == *":${d}:"* ]]; then
                __dottod_doc_ok "PATH has ${d}"
            else
                __dottod_doc_warn "PATH lacks ${d}"
            fi
        fi
    done

    # Prompt: the style that applies (DOT_PROMPT_STYLE, else the one saved
    # in ~/.prompt-style, else robbyrussell) exists, and a hook is set.
    local style="${DOT_PROMPT_STYLE:-}" from='DOT_PROMPT_STYLE' sfile root
    sfile="${DOT_PROMPT_STYLE_FILE:-${HOME}/.prompt-style}"
    if [[ -z "${style}" && -r "${sfile}" ]]; then
        IFS= read -r style <"${sfile}" || true
        style="${style//[[:space:]]/}"
        from="${sfile/#"${HOME}"/\~}"
    fi
    [[ -n "${style}" ]] || style=robbyrussell
    root="$(_dottod_doctor_root)" || root=''
    if [[ -n "${root}" ]] && ! [[ "${style}" =~ ^[a-z0-9][a-z0-9_-]*$ && -f "${root}/styles/prompt-${style}.sh" ]]; then
        __dottod_doc_warn "unknown prompt style ${style} (from ${from})"
    elif [[ "${PROMPT_COMMAND:-}" == *"__dottod_prompt"* ]]; then
        __dottod_doc_ok "prompt ${style} installed"
    else
        __dottod_doc_warn "no dottod prompt in PROMPT_COMMAND"
    fi

    # Projects: every scan root exists; count finds (find only, no git work).
    if declare -F __codes_roots >/dev/null 2>&1; then
        while IFS= read -r d; do
            __dottod_doc_ok "codes root ${d}"
        done < <(__codes_roots)
        if declare -F __codes_find >/dev/null 2>&1; then
            __dottod_doc_ok "$(__codes_find 2>/dev/null | wc -l) projects found"
        fi
    else
        __dottod_doc_warn "codes library not loaded"
    fi

    # Updates: state age plus any pending release (cache only, no network).
    if declare -F _dottod_update_state_file >/dev/null 2>&1; then
        d="$(_dottod_update_state_file)"
        if [[ -s "${d}" ]]; then
            read -r checked _ <"${d}" || checked=""
            if [[ "${checked}" =~ ^[0-9]+$ ]]; then
                days=$((($(date +%s) - checked) / 86400))
                __dottod_doc_ok "update check ${days}d ago"
            else
                __dottod_doc_warn "update state unreadable"
            fi
            if declare -F _dottod_local_tag >/dev/null 2>&1 && declare -F _dottod_ver_gt >/dev/null 2>&1; then
                root="$(_dottod_update_root 2>/dev/null)"
                tag="$([ -n "${root}" ] && _dottod_local_tag "${root}" 2>/dev/null)"
                remote="$(cut -d' ' -f2- "${d}" 2>/dev/null)"
                if [[ -n "${tag}" && -n "${remote}" ]] && _dottod_ver_gt "${remote}" "${tag}"; then
                    __dottod_doc_warn "update available: ${tag} → ${remote} (dottod-update)"
                fi
            fi
        else
            __dottod_doc_warn "never checked for updates"
        fi
    else
        __dottod_doc_warn "update library not loaded"
    fi

    # Claude profiles: every discovered overlay with unbroken links, an
    # isolated identity and a login present.
    if declare -F __dottod_claude_profiles >/dev/null 2>&1; then
        found=0
        while IFS= read -r t; do
            found=1
            d="$(__dottod_claude_profile_dir "${t}")" || continue
            if [[ -d "${d}" ]]; then
                __dottod_doc_ok "claude ${t} overlay present"
                if [[ -s "${d}/.credentials.json" ]]; then
                    __dottod_doc_ok "claude ${t} logged in"
                else
                    __dottod_doc_warn "claude ${t} needs /login"
                fi
                if __dottod_doc_broken_links "${d}"; then
                    __dottod_doc_ok "claude ${t} links intact"
                else
                    __dottod_doc_warn "claude ${t} has broken links"
                fi
                if __dottod_doc_identity_isolated "${d}"; then
                    __dottod_doc_ok "claude ${t} identity isolated"
                else
                    __dottod_doc_warn "claude ${t} shares identity dirs (rebuild the overlay)"
                fi
            else
                __dottod_doc_warn "claude ${t} overlay missing (run it once)"
            fi
        done < <(__dottod_claude_profiles)
        ((found == 1)) || __dottod_doc_warn "no claude profiles (run claude once)"
    else
        __dottod_doc_warn "claude library not loaded"
    fi

    # Secrets (bin/secrets.sh): only where pass is installed. Registry names
    # only — never a credential value.
    if command -v pass >/dev/null 2>&1; then
        if [[ -s "${PASSWORD_STORE_DIR:-${HOME}/.password-store}/.gpg-id" ]]; then
            __dottod_doc_ok "pass store initialised"
        else
            __dottod_doc_warn "pass installed but no store (./bin/bootstrap.sh --only secrets explains)"
        fi
        if [[ -f "${HOME}/.config/containers/registries.conf.d/50-dottod-pass.conf" ]]; then
            __dottod_doc_ok "container registry logins go through pass"
        fi
        local f names
        for f in "${HOME}/.docker/config.json" "${HOME}/.config/containers/auth.json" \
            "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json"; do
            [[ -s "${f}" ]] || continue
            names="$(python3 -c 'import json,sys
try: print(",".join(sorted((json.load(open(sys.argv[1])).get("auths") or {}))))
except Exception: pass' "${f}" 2>/dev/null)"
            [[ -n "${names}" ]] && __dottod_doc_warn "plaintext registry credentials in ${f}: ${names}"
        done
    fi

    # Containers: rootless Podman prerequisites, only where Podman is
    # installed (scripts/.container.utils.sh; read-only checks).
    if command -v podman >/dev/null 2>&1 && declare -F _ctr_rootless_findings >/dev/null; then
        local state msg
        while IFS=$'\t' read -r state msg; do
            if [[ "${state}" == ok ]]; then
                __dottod_doc_ok "podman: ${msg}"
            else
                __dottod_doc_warn "podman: ${msg}"
            fi
        done < <(_ctr_rootless_findings)
    fi

    # Checkout: branch, dirtiness, newest tag (when inside the repo).
    root="$(_dottod_doctor_root 2>/dev/null)"
    if [[ -n "${root}" ]] && git -C "${root}" rev-parse --git-dir >/dev/null 2>&1; then
        branch="$(git -C "${root}" symbolic-ref --short -q HEAD 2>/dev/null || git -C "${root}" describe --tags --exact-match HEAD 2>/dev/null || git -C "${root}" rev-parse --short HEAD 2>/dev/null)"
        dirty="$(git -C "${root}" status --porcelain --ignore-submodules=dirty 2>/dev/null | wc -l)"
        tag="$(git -C "${root}" tag --list '[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n 1)"
        __dottod_doc_ok "checkout ${branch}${tag:+ @ ${tag}} (${dirty} dirty files)"
    else
        __dottod_doc_warn "dottod checkout not found"
    fi

    printf 'doctor: %s ok, %s warnings, %s failures\n' "${_DOTTOD_DOC_OK}" "${_DOTTOD_DOC_WARN}" "${_DOTTOD_DOC_FAIL}"
    ((_DOTTOD_DOC_FAIL == 0))
}

# __dottod_doc_identity_isolated <dir>: true when no identity-bearing entry
# (backups, state, sessions, session-env) is a symlink into another store —
# a shared identity lets one profile restore another profile's account.
__dottod_doc_identity_isolated() {
    local entry
    for entry in backups state sessions session-env; do
        if [[ -L "${1:?dir required}/${entry}" ]]; then
            return 1
        fi
    done
    return 0
}
# __dottod_doc_broken_links <dir>: true when no symlink inside is dangling.
__dottod_doc_broken_links() {
    local entry
    for entry in "${1:?dir required}"/*; do
        if [[ -L "${entry}" && ! -e "${entry}" ]]; then
            return 1
        fi
    done
    return 0
}
