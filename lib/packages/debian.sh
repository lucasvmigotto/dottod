#!/usr/bin/env bash
#
# debian.sh — logical package names → Debian/Ubuntu packages (spec 015).
# Prints native name(s), '-' when deliberately unsupported; rc 1 for a
# name with no entry (a bug: tests require every logical name here).

function _pkgmap_debian() {
    case "${1}" in
        ca_certificates) printf 'ca-certificates' ;;
        openssh_client) printf 'openssh-client' ;;
        podman_rootless) printf 'uidmap' ;;
        cxx_runtime) printf 'libstdc++6' ;;
        pass_credential_helper) printf 'golang-docker-credential-helpers' ;;
        fastfetch) _pkgmap_debian_fastfetch ;;
        bash | bat | bats | btop | chafa | curl | fontconfig | fzf | gh | git | \
            gnupg | httpie | jq | just | lsof | neovim | pass | podman | \
            python3 | shellcheck | shfmt | tar | unzip | vim | xclip)
            printf '%s' "${1}"
            ;;
        *) return 1 ;;
    esac
}

# fastfetch is in the archive from Debian 13 and Ubuntu 25.04 on. Ubuntu
# derivatives (ID_LIKE ubuntu) number their releases their own way, so
# they count as unsupported rather than guessed at.
function _pkgmap_debian_fastfetch() {
    local major="${DOTTOD_OS_VERSION_ID:-0}"
    major="${major%%.*}"
    [[ "${major}" =~ ^[0-9]+$ ]] || major=0
    case "${DOTTOD_OS_ID:-}" in
        debian) ((major == 0 || major >= 13)) && printf 'fastfetch' || printf '-' ;;
        ubuntu) ((major >= 25)) && printf 'fastfetch' || printf '-' ;;
        *)
            if [[ " ${DOTTOD_OS_ID_LIKE:-} " == *" ubuntu "* ]]; then
                printf '-'
            else
                printf 'fastfetch'
            fi
            ;;
    esac
}
