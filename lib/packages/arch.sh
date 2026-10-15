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
        python3) printf 'python' ;;
        # docker-credential-pass is AUR-only (never used by dottod).
        pass_credential_helper) printf -- '-' ;;
        cxx_runtime) printf 'gcc-libs' ;;
        bash | bat | bats | btop | ca_certificates | chafa | curl | fontconfig | fzf | \
            git | gnupg | httpie | jq | just | lsof | neovim | pass | podman | \
            shellcheck | shfmt | tar | unzip | vim | xclip)
            printf '%s' "${1//_/-}"
            ;;
        *) return 1 ;;
    esac
}
