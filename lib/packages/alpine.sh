#!/usr/bin/env bash
#
# alpine.sh — logical package names → Alpine packages (spec 015).
# Prints '-' when deliberately unsupported; rc 1 for a name with no entry.

function _pkgmap_alpine() {
    case "${1}" in
        gh) printf 'github-cli' ;;
        openssh_client) printf 'openssh-client-default' ;;
        # usermod is in shadow; newuidmap and /etc/subuid in shadow-subids.
        podman_rootless) printf 'shadow shadow-subids' ;;
        bash | bat | bats | btop | ca_certificates | chafa | curl | fontconfig | \
            fzf | git | gnupg | httpie | jq | just | lsof | neovim | nodejs | \
            podman | shellcheck | shfmt | tar | unzip | vim | xclip)
            printf '%s' "${1//_/-}"
            ;;
        *) return 1 ;;
    esac
}
