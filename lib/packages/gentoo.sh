#!/usr/bin/env bash
#
# gentoo.sh — logical package names → Gentoo atoms (spec 015).
# Always full category/name atoms: portageq cannot tell an absent bare
# name from an invalid one. Prints '-' when deliberately unsupported;
# rc 1 for a name with no entry.

function _pkgmap_gentoo() {
    case "${1}" in
        bash) printf 'app-shells/bash' ;;
        bat) printf 'sys-apps/bat' ;;
        bats) printf 'dev-util/bats' ;;
        btop) printf 'sys-process/btop' ;;
        ca_certificates) printf 'app-misc/ca-certificates' ;;
        chafa) printf 'media-gfx/chafa' ;;
        curl) printf 'net-misc/curl' ;;
        fontconfig) printf 'media-libs/fontconfig' ;;
        fzf) printf 'app-shells/fzf' ;;
        gh) printf 'dev-util/github-cli' ;;
        git) printf 'dev-vcs/git' ;;
        gnupg) printf 'app-crypt/gnupg' ;;
        httpie) printf 'net-misc/httpie' ;;
        jq) printf 'app-misc/jq' ;;
        just) printf 'dev-build/just' ;;
        lsof) printf 'sys-process/lsof' ;;
        neovim) printf 'app-editors/neovim' ;;
        nodejs) printf 'net-libs/nodejs' ;;
        openssh_client) printf 'net-misc/openssh' ;;
        podman) printf 'app-containers/podman' ;;
        podman_rootless) printf 'sys-apps/shadow' ;;
        # ShellCheck is Haskell: the -bin package avoids a GHC toolchain build.
        shellcheck) printf 'dev-util/shellcheck-bin' ;;
        # shfmt ships in mvdan's sh project.
        shfmt) printf 'dev-util/sh' ;;
        tar) printf 'app-arch/tar' ;;
        unzip) printf 'app-arch/unzip' ;;
        vim) printf 'app-editors/vim' ;;
        xclip) printf 'x11-misc/xclip' ;;
        *) return 1 ;;
    esac
}
