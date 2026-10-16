#!/usr/bin/env bash
#
# redhat.sh — logical package names → Fedora packages (spec 015).
# Prints '-' when deliberately unsupported; rc 1 for a name with no entry.

function _pkgmap_redhat() {
    case "${1}" in
        gnupg) printf 'gnupg2' ;;
        openssh_client) printf 'openssh-clients' ;;
        podman_rootless) printf 'shadow-utils' ;;
        cxx_runtime) printf 'libstdc++' ;;
        shellcheck) printf 'ShellCheck' ;;
        # Not packaged by Fedora.
        pass_credential_helper) printf -- '-' ;;
        vim) printf 'vim-enhanced' ;;
        bash | bat | bats | btop | ca_certificates | chafa | curl | fastfetch | fontconfig | \
            fzf | gh | git | httpie | jq | just | lsof | neovim | pass | podman | \
            pv | python3 | shfmt | tar | unzip | xclip)
            printf '%s' "${1//_/-}"
            ;;
        *) return 1 ;;
    esac
}
