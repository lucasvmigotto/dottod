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
        bash | bat | bats | btop | chafa | curl | fastfetch | fontconfig | fzf | gh | git | \
            gnupg | httpie | jq | just | lsof | neovim | pass | podman | \
            python3 | shellcheck | shfmt | tar | unzip | vim | xclip)
            printf '%s' "${1}"
            ;;
        *) return 1 ;;
    esac
}
