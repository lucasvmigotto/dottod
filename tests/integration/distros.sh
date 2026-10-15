#!/usr/bin/env bash
#
# distros.sh — the reference distro images for the integration gates
# (spec 015), sourced by pkg-resolve.sh and core-smoke.sh.

# shellcheck disable=SC2034 # read by the scripts that source this file
readonly DOT_IT_DISTROS=(debian ubuntu gentoo arch fedora alpine)

function _it_image() {
    case "${1}" in
        debian) printf 'docker.io/library/debian:trixie' ;;
        ubuntu) printf 'docker.io/library/ubuntu:24.04' ;;
        gentoo) printf 'docker.io/gentoo/stage3:latest' ;;
        arch) printf 'docker.io/library/archlinux:latest' ;;
        fedora) printf 'docker.io/library/fedora:42' ;;
        alpine) printf 'docker.io/library/alpine:3.22' ;;
        *) return 1 ;;
    esac
}

# _it_prep <distro> <mode>: shell prelude for a throwaway container.
# mode index: refresh the package index so names can be queried.
# mode system: what a real installed system already has — Arch fully
# synced (dottod never runs a lone -Sy), bash on Alpine (dottod's own
# prerequisite). dottod refreshes debian/alpine indexes itself.
function _it_prep() {
    case "${1}:${2}" in
        debian:index | ubuntu:index) printf 'apt-get update -qq >/dev/null' ;;
        arch:*) printf 'pacman -Syu --noconfirm >/dev/null' ;;
        alpine:index) printf 'apk add -q bash >/dev/null && apk update -q >/dev/null' ;;
        alpine:system) printf 'apk add -q bash >/dev/null' ;;
        *) printf 'true' ;;
    esac
}

# _it_extra_args <distro>: extra podman run arguments. Gentoo needs a
# Portage tree: a stopped dottod-portage container holds it (created on
# first use; running it once copies the tree into its volume).
function _it_extra_args() {
    [[ "${1}" == gentoo ]] || return 0
    podman container exists dottod-portage ||
        podman run --name dottod-portage docker.io/gentoo/portage:latest >/dev/null
    printf -- '--volumes-from\ndottod-portage\n'
}
