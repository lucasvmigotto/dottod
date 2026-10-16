#!/usr/bin/env bash
#
# secrets.sh — dottod secrets task (spec 017), opt-in: `pass` as the
# system-wide secret store, with container registry logins on top.
#
# dottod never generates keys, never runs `pass init`/`pass insert`, never
# reads, prints or logs a secret: the interactive steps are the user's;
# this task installs, checks and wires.
#
# Steps (each skipped when already done):
#   1. install pass + gpg (and docker-credential-pass where packaged)
#   2. require a GPG secret key, then a store initialised for it — or stop
#      with the exact commands to run
#   3. registries: a drop-in makes every `podman login` store its token in
#      pass, plus a GnuPG socket redirect so rootless Podman's helper can
#      reach the user's agent from inside its user namespace
#   4. remove plaintext registry credentials (`auths` entries) left in
#      ~/.docker/config.json and the containers auth.json files
#
# Usage: secrets.sh [""] | status | --help|-h
#
# Env overrides (tests):
#   PASSWORD_STORE_DIR   the store (pass's own variable; default ~/.password-store)
#   _DOT_SECRETS_HELPER  credential helper command (default docker-credential-pass)
#   _DOT_NO_PACKAGES     1 skips package installs

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# Podman reads user drop-ins from this fixed path (not XDG_CONFIG_HOME).
function _secrets_dropin() {
    printf '%s' "${HOME}/.config/containers/registries.conf.d/50-dottod-pass.conf"
}

function _secrets_store() {
    printf '%s' "${PASSWORD_STORE_DIR:-${HOME}/.password-store}"
}

# The fingerprint of the first GPG secret key, or nothing.
function _secrets_key_id() {
    gpg --list-secret-keys --with-colons 2>/dev/null |
        awk -F: '$1 == "fpr" && !id { id = $10 } END { if (id) print id }'
}

# The key id the store was initialised for (.gpg-id), or nothing.
function _secrets_store_id() {
    local f
    f="$(_secrets_store)/.gpg-id"
    [[ -s "${f}" ]] || return 0
    head -n1 "${f}"
}

# Files where registry logins land in plain base64 (containers-auth.json(5)).
function _secrets_plaintext_files() {
    printf '%s\n' "${HOME}/.docker/config.json" \
        "${HOME}/.config/containers/auth.json" \
        "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json"
}

# _secrets_auths <file>: the registry names with stored credentials.
function _secrets_auths() {
    [[ -s "${1}" ]] || return 0
    python3 - "${1}" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for name in sorted((data.get("auths") or {})):
    print(name)
PY
}

# _secrets_drop_auths <file>: remove every `auths` entry, keep every other
# key and mode 0600, keep no backup. Prints the names removed.
function _secrets_drop_auths() {
    python3 - "${1}" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path))
names = sorted((data.get("auths") or {}))
if names:
    data["auths"] = {}
    tmp = path + ".dottod-tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh, indent="\t")
        fh.write("\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
for name in names:
    print(name)
PY
}

# GnuPG socket redirect: rootless Podman runs the credential helper as uid 0
# in its user namespace, where gpg can't find /run/user/<uid> and falls back
# to <homedir>/S.gpg-agent. A redirect file there points it at the user's
# own agent. Written only when the agent socket lives under /run/user and
# the homedir path is not itself a live socket.
function _secrets_redirect() {
    local socket homedir target want
    socket="$(gpgconf --list-dirs agent-socket 2>/dev/null)" || socket=''
    homedir="$(gpgconf --list-dirs homedir 2>/dev/null)" || homedir="${HOME}/.gnupg"
    target="${homedir}/S.gpg-agent"
    if [[ "${socket}" != /run/user/* ]]; then
        log_warn "gpg-agent's socket is not under /run/user (${socket:-unknown}); no redirect needed or possible"
        return 0
    fi
    if [[ -S "${target}" ]]; then
        log_warn "${target} is a live agent socket; leaving it alone (pulls may need a second agent)"
        return 0
    fi
    want="$(printf '%%Assuan%%\nsocket=%s' "${socket}")"
    if [[ -f "${target}" ]] && [[ "$(cat "${target}")" == "${want}" ]]; then
        log_info 'GnuPG socket redirect already in place, skipping...'
        return 0
    fi
    if [[ -e "${target}" ]] && [[ "$(head -n1 "${target}" 2>/dev/null)" != '%Assuan%' ]]; then
        log_warn "${target} exists and is not a socket redirect; leaving it alone"
        return 0
    fi
    printf '%s\n' "${want}" >"${target}"
    chmod 0600 "${target}"
    log_ok "GnuPG socket redirect -> ${socket}"
}

# pass-run (scripts/pass-run.sh) on PATH as a real program, so scripts and
# non-interactive shells (AI agents included) can use it. A pass-run that
# isn't dottod's link is left alone.
function _secrets_link_pass_run() {
    local dest src
    dest="$(_ensure_local_bin)/pass-run"
    src="${DOT_REPO_ROOT}/scripts/pass-run.sh"
    if [[ -L "${dest}" && "$(readlink "${dest}")" == "${src}" ]]; then
        log_info 'pass-run already linked, skipping...'
    elif [[ -e "${dest}" || -L "${dest}" ]]; then
        log_warn "${dest} exists and is not dottod's pass-run; leaving it alone"
    else
        ln -s "${src}" "${dest}"
        log_ok "pass-run linked (${dest})"
    fi
}

function _secrets_wire_registries() {
    local dropin want
    dropin="$(_secrets_dropin)"
    want='credential-helpers = ["pass"]'
    if [[ -f "${dropin}" ]] && grep -qxF "${want}" "${dropin}"; then
        log_info 'Container registries already log in through pass, skipping...'
    else
        mkdir -p "$(dirname "${dropin}")"
        {
            printf '# dottod (bin/secrets.sh): every container registry login is\n'
            printf '# stored in pass. Delete this file to go back to auth.json.\n'
            printf '%s\n' "${want}"
        } >"${dropin}"
        log_ok "Registry logins now go through pass (${dropin})"
    fi
    _secrets_redirect
}

function _secrets_cleanup() {
    local file name
    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        while IFS= read -r name; do
            [[ -n "${name}" ]] && log_info "Removed plaintext registry credential: ${name} (${file})"
        done < <(_secrets_drop_auths "${file}")
    done < <(_secrets_plaintext_files)
}

function _secrets_ensure() {
    log_step 'Installing pass and gpg'
    _install_packages pass gnupg python3

    local key store_id
    key="$(_secrets_key_id)"
    if [[ -z "${key}" ]]; then
        log_error 'No GPG secret key yet. Create one (interactive, your passphrase), then re-run:'
        log_error '  gpg --full-generate-key'
        return 1
    fi
    store_id="$(_secrets_store_id)"
    if [[ -z "${store_id}" ]]; then
        log_error "No password store yet at $(_secrets_store). Initialise it for your key, then re-run:"
        log_error "  pass init ${key}"
        return 1
    fi
    log_ok "pass ready (store for ${store_id})"
    _secrets_link_pass_run

    _install_packages pass_credential_helper
    if ! _is_installed "${_DOT_SECRETS_HELPER:-docker-credential-pass}"; then
        _os_detect 2>/dev/null || true
        if [[ "${DOTTOD_OS_FAMILY:-}" == gentoo ]]; then
            log_warn 'docker-credential-pass needs USE=pass. Add it, re-emerge, re-run:'
            log_warn '  echo "app-containers/docker-credential-helpers pass" | sudo tee /etc/portage/package.use/docker-credential-helpers'
        else
            log_warn 'docker-credential-pass is not packaged here: install it from'
            log_warn '  https://github.com/docker/docker-credential-helpers/releases (checksums.txt), then re-run'
        fi
        log_warn 'pass is ready; container registry logins are not wired yet.'
        return 0
    fi

    _secrets_wire_registries
    _secrets_cleanup
    log_ok 'Secrets ready: podman login <registry> stores its token in pass'
    return 0
}

function _secrets_status() {
    local key store_id helper dropin redirect file names plaintext=''
    key="$(_secrets_key_id)"
    store_id="$(_secrets_store_id)"
    helper="$(command -v "${_DOT_SECRETS_HELPER:-docker-credential-pass}" || true)"
    dropin="$(_secrets_dropin)"
    redirect='n/a'
    local homedir
    homedir="$(gpgconf --list-dirs homedir 2>/dev/null)" || homedir="${HOME}/.gnupg"
    if [[ -f "${homedir}/S.gpg-agent" ]] && [[ "$(head -n1 "${homedir}/S.gpg-agent" 2>/dev/null)" == '%Assuan%' ]]; then
        redirect='in place'
    elif [[ "$(gpgconf --list-dirs agent-socket 2>/dev/null)" == /run/user/* ]]; then
        redirect='missing'
    fi
    while IFS= read -r file; do
        names="$(_secrets_auths "${file}" | paste -sd, -)"
        [[ -n "${names}" ]] && plaintext+="${plaintext:+; }${names} (${file})"
    done < <(_secrets_plaintext_files)
    cat <<EOF
Secrets
-------
pass:       $(command -v pass >/dev/null 2>&1 && echo present || echo missing)
GPG key:    ${key:-missing (gpg --full-generate-key)}
Store:      $([[ -n "${store_id}" ]] && echo "$(_secrets_store) (for ${store_id})" || echo "missing (pass init <key>)")
pass-run:   $([[ -L "$(_ensure_local_bin)/pass-run" ]] && echo "linked ($(_ensure_local_bin)/pass-run)" || echo 'not linked')
Helper:     ${helper:-missing}
Registries: $([[ -f "${dropin}" ]] && echo "through pass (${dropin})" || echo 'not wired')
Redirect:   ${redirect}
Plaintext:  ${plaintext:-none}
EOF
    return 0
}

function _usage() {
    cat <<'EOF'
Usage: secrets.sh [status]

  (no args)  set up pass and route container registry logins through it
  status     print the secrets report without changing anything
EOF
}

function _main() {
    case "${1:-}" in
        '')
            log_step 'Ensuring secrets (pass)'
            _secrets_ensure
            ;;
        status)
            _secrets_status
            ;;
        --help | -h)
            _usage
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
