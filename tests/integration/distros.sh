#!/usr/bin/env bash
#
# distros.sh — the reference distro images for the integration gates
# (spec 015), sourced by pkg-resolve.sh and core-smoke.sh.
#
# Images are pinned by digest (the tag stays for readability), so a run
# is reproducible and a new upstream image is a reviewed change. To bump
# one: podman pull <image:tag>, then copy the digest from
#   podman image inspect --format '{{range .RepoDigests}}{{.}} {{end}}' <image:tag>
# Arch is rolling: its prep step upgrades the pinned image anyway.
#
# Containers run with modest limits by default (a source build on Gentoo
# exhausted a 7.5 GiB host once); DOT_IT_PODMAN_ARGS replaces them, e.g.
# DOT_IT_PODMAN_ARGS='' on a large CI runner.

# shellcheck disable=SC2034 # read by the scripts that source this file
readonly DOT_IT_DISTROS=(debian ubuntu gentoo arch fedora alpine)

function _it_image() {
    case "${1}" in
        debian) printf 'docker.io/library/debian:trixie@sha256:913f6706df59a68922d1dd08f78c2476560a8d367897200a6005b00e5f67c2d5' ;;
        ubuntu) printf 'docker.io/library/ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55' ;;
        gentoo) printf 'docker.io/gentoo/stage3:latest@sha256:d60b786ab715b2bd5ec0efdbe90a55b261b68ba3f56c0a7f6b3de6ff768f034e' ;;
        arch) printf 'docker.io/library/archlinux:latest@sha256:363129b67b2bc6c5a634f8fb4961a7e2eba213a2ec075d159127b1260290a722' ;;
        fedora) printf 'docker.io/library/fedora:42@sha256:7c63468daf71fdc5bda3699cd483b169bb995b5137265d5ffe8f04e2ce87fbb8' ;;
        alpine) printf 'docker.io/library/alpine:3.22@sha256:3e9b4b680bfc9fb5269227cffbd6d42be39fbf7c0b908123913864aa4447e764' ;;
        *) return 1 ;;
    esac
}

readonly DOT_IT_PORTAGE_IMAGE='docker.io/gentoo/portage:latest@sha256:272b424ac58597ebdea1101741bb6da8b69e03cf5be4a76329fc5b164497a260'

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

# _it_run_args <distro>: podman run arguments, one per line — resource
# limits (DOT_IT_PODMAN_ARGS, word-split) and, for Gentoo, the Portage
# tree plus build parallelism matching those limits. The tree lives in a
# stopped dottod-portage container (running it once copies the tree into
# its volume); `podman rm dottod-portage` makes the next run take a fresh
# snapshot from DOT_IT_PORTAGE_IMAGE.
function _it_run_args() {
    local -a limits=()
    read -ra limits <<<"${DOT_IT_PODMAN_ARGS---memory 3g --cpus 2}"
    ((${#limits[@]} == 0)) || printf '%s\n' "${limits[@]}"
    [[ "${1}" == gentoo ]] || return 0
    podman container exists dottod-portage ||
        podman run --name dottod-portage "${DOT_IT_PORTAGE_IMAGE}" >/dev/null
    printf -- '--volumes-from\ndottod-portage\n'
    printf -- '-e\nMAKEOPTS=%s\n' "${MAKEOPTS:--j2}"
    printf -- '-e\nEMERGE_DEFAULT_OPTS=--jobs=1 --load-average=2\n'
}
