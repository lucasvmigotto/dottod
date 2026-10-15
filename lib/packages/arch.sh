#!/usr/bin/env bash
#
# arch.sh — logical package names → Arch Linux packages (spec 015).
# Official repositories only (never the AUR). Prints '-' when
# deliberately unsupported; rc 1 for a name with no entry.

function _pkgmap_arch() {
    case "${1}" in
        gh) printf 'github-cli' ;;
        openssh_client) printf 'openssh' ;;
        podman_rootless) printf 'shadow' ;;
        bash | bat | bats | btop | ca_certificates | chafa | curl | fontconfig | fzf | \
            git | gnupg | httpie | jq | just | lsof | neovim | nodejs | podman | \
            shellcheck | shfmt | tar | unzip | vim | xclip)
            printf '%s' "${1//_/-}"
            ;;
        *) return 1 ;;
    esac
}
