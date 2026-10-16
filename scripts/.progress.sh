#!/usr/bin/env bash
#
# .progress.sh — progress bars for long copies, archives, checksums,
# image writes and pipelines, on pv (spec 019; bin/tools.sh installs it).
#
#   pcp SRC DST            copy a file or a directory
#   ptar DIR [OUT]         archive a directory (.tar.zst/.tar.gz/.tar.xz/.tar)
#   puntar ARCHIVE [DIR]   extract an archive
#   psum FILE [ALGO]       checksum a file, sha256sum-style output
#   pdd IMAGE DEVICE       write a disk image to a block device (confirms)
#   pchain FILE -- CMD...  feed a file into any command
#   pvl                    pv -l: count lines through a pipe
#
# Every command checks pv first, never overwrites an existing target, and
# removes the partial target when a stage fails. Sizes are computed up
# front, so the bar shows a percentage and an ETA.

alias pvl='pv -l'

# __dottod_pv_ready <cmd>: 0 when pv is on PATH; fails loudly otherwise.
__dottod_pv_ready() {
    command -v pv >/dev/null 2>&1 && return 0
    echo "${1}: 'pv' not found on PATH (bin/tools.sh installs it)" >&2
    return 1
}

# __dottod_pv_size <path>: bytes in a file, or in a directory's tree.
# du -b is GNU; BusyBox (Alpine) falls back to KiB, close enough for a bar.
__dottod_pv_size() {
    local out
    if [[ -d "${1}" ]]; then
        if out="$(du -sb -- "${1}" 2>/dev/null)"; then
            printf '%s\n' "${out%%[[:space:]]*}"
            return 0
        fi
        out="$(du -sk -- "${1}")" || return 1
        printf '%s\n' "$((${out%%[[:space:]]*} * 1024))"
    else
        stat -c %s -- "${1}" 2>/dev/null || wc -c <"${1}" | tr -d ' '
    fi
}

# __dottod_pv_rc: the first failing status of the pipeline that just ran
# (interactive shells rarely set pipefail). Call it as `__dottod_pv_rc
# "${PIPESTATUS[@]}"` right after the pipeline.
__dottod_pv_rc() {
    local rc
    for rc in "$@"; do
        ((rc == 0)) || return "${rc}"
    done
    return 0
}

# __dottod_pv_codec <archive>: the compressor for an archive name, or rc 1.
__dottod_pv_codec() {
    case "${1}" in
        *.tar.zst | *.tzst) printf 'zstd' ;;
        *.tar.gz | *.tgz) printf 'gzip' ;;
        *.tar.xz | *.txz) printf 'xz' ;;
        *.tar) printf 'cat' ;;
        *) return 1 ;;
    esac
}

# __dottod_pv_image_codec <image>: the decompressor for a disk image.
__dottod_pv_image_codec() {
    case "${1}" in
        *.zst) printf 'zstd' ;;
        *.gz) printf 'gzip' ;;
        *.xz) printf 'xz' ;;
        *) printf 'cat' ;;
    esac
}

# __dottod_pv_need <cmd> <tool>: 0 when tool (other than cat) is on PATH.
__dottod_pv_need() {
    [[ "${2}" == cat ]] && return 0
    command -v "${2}" >/dev/null 2>&1 && return 0
    echo "${1}: '${2}' not found on PATH" >&2
    return 1
}

# __dottod_pv_compress <codec> / __dottod_pv_decompress <codec>: stdin to
# stdout through the codec (cat passes through).
__dottod_pv_compress() {
    case "${1}" in
        zstd) zstd -q -T0 -c ;;
        gzip) gzip -c ;;
        xz) xz -T0 -c ;;
        *) cat ;;
    esac
}

__dottod_pv_decompress() {
    case "${1}" in
        zstd) zstd -q -dc ;;
        gzip) gzip -dc ;;
        xz) xz -dc ;;
        *) cat ;;
    esac
}

# pcp SRC DST: copy with a bar. A file keeps its mode; a directory goes
# through tar (modes, links, times kept). As with cp: an existing DST
# directory receives SRC under its own name; otherwise DST is the copy.
pcp() {
    if [[ "${1:-}" == -h || "${1:-}" == --help || $# -ne 2 ]]; then
        echo 'usage: pcp SRC DST   copy a file or directory with a progress bar'
        [[ "${1:-}" == -h || "${1:-}" == --help ]]
        return
    fi
    __dottod_pv_ready pcp || return 1
    local src=${1%/} dst=${2} size name
    [[ -n "${src}" ]] || src=/
    [[ -e "${src}" ]] || {
        echo "pcp: '${src}' does not exist" >&2
        return 1
    }
    name="$(basename -- "${src}")"
    [[ -d "${dst}" ]] && dst="${dst%/}/${name}"
    [[ -e "${dst}" ]] && {
        echo "pcp: '${dst}' already exists" >&2
        return 1
    }
    size="$(__dottod_pv_size "${src}")" || return 1

    if [[ -d "${src}" ]]; then
        mkdir -p -- "${dst}" || return 1
        tar -C "${src}" -cf - . | pv -s "${size}" -N "${name}" | tar -C "${dst}" -xf -
        __dottod_pv_rc "${PIPESTATUS[@]}" || {
            echo "pcp: copy failed; removing '${dst}'" >&2
            rm -rf -- "${dst}"
            return 1
        }
    else
        pv -s "${size}" -N "${name}" -- "${src}" >"${dst}" || {
            echo "pcp: copy failed; removing '${dst}'" >&2
            rm -f -- "${dst}"
            return 1
        }
        chmod "$(stat -c %a -- "${src}")" -- "${dst}" 2>/dev/null || true
    fi
}

# ptar DIR [OUT]: archive DIR with a bar on its uncompressed size. OUT's
# extension picks the codec; the default is DIR.tar.zst (DIR.tar.gz
# without zstd).
ptar() {
    if [[ "${1:-}" == -h || "${1:-}" == --help || $# -lt 1 || $# -gt 2 ]]; then
        echo 'usage: ptar DIR [OUT.tar.zst|.tar.gz|.tar.xz|.tar]   archive with a progress bar'
        [[ "${1:-}" == -h || "${1:-}" == --help ]]
        return
    fi
    __dottod_pv_ready ptar || return 1
    local dir=${1%/} out=${2:-} codec size name parent
    [[ -d "${dir}" ]] || {
        echo "ptar: '${1}' is not a directory" >&2
        return 1
    }
    name="$(basename -- "${dir}")"
    parent="$(dirname -- "${dir}")"
    if [[ -z "${out}" ]]; then
        out="${name}.tar.gz"
        command -v zstd >/dev/null 2>&1 && out="${name}.tar.zst"
    fi
    codec="$(__dottod_pv_codec "${out}")" || {
        echo "ptar: '${out}': want .tar.zst, .tar.gz, .tar.xz or .tar" >&2
        return 1
    }
    __dottod_pv_need ptar "${codec}" || return 1
    [[ -e "${out}" ]] && {
        echo "ptar: '${out}' already exists" >&2
        return 1
    }
    size="$(__dottod_pv_size "${dir}")" || return 1

    tar -C "${parent}" -cf - -- "${name}" | pv -s "${size}" -N "${name}" |
        __dottod_pv_compress "${codec}" >"${out}"
    __dottod_pv_rc "${PIPESTATUS[@]}" || {
        echo "ptar: archive failed; removing '${out}'" >&2
        rm -f -- "${out}"
        return 1
    }
    echo "ptar: ${out}"
}

# puntar ARCHIVE [DIR]: extract with a bar on the archive's size (default
# DIR: the current directory, created when missing).
puntar() {
    if [[ "${1:-}" == -h || "${1:-}" == --help || $# -lt 1 || $# -gt 2 ]]; then
        echo 'usage: puntar ARCHIVE [DIR]   extract .tar.zst/.tar.gz/.tar.xz/.tar with a progress bar'
        [[ "${1:-}" == -h || "${1:-}" == --help ]]
        return
    fi
    __dottod_pv_ready puntar || return 1
    local archive=${1} dir=${2:-.} codec
    [[ -f "${archive}" ]] || {
        echo "puntar: '${archive}' does not exist" >&2
        return 1
    }
    codec="$(__dottod_pv_codec "${archive}")" || {
        echo "puntar: '${archive}': want .tar.zst, .tar.gz, .tar.xz or .tar" >&2
        return 1
    }
    __dottod_pv_need puntar "${codec}" || return 1
    mkdir -p -- "${dir}" || return 1

    pv -N "$(basename -- "${archive}")" -- "${archive}" |
        __dottod_pv_decompress "${codec}" | tar -C "${dir}" -xf -
    __dottod_pv_rc "${PIPESTATUS[@]}" || {
        echo "puntar: extract failed (files already written stay in '${dir}')" >&2
        return 1
    }
}

# psum FILE [ALGO]: checksum with a bar; prints `HASH  FILE` like
# sha256sum, so `sha256sum -c` reads it. ALGO: sha256 (default), sha1,
# sha224, sha384, sha512, md5, b2.
psum() {
    if [[ "${1:-}" == -h || "${1:-}" == --help || $# -lt 1 || $# -gt 2 ]]; then
        echo 'usage: psum FILE [sha256|sha1|sha224|sha384|sha512|md5|b2]   checksum with a progress bar'
        [[ "${1:-}" == -h || "${1:-}" == --help ]]
        return
    fi
    __dottod_pv_ready psum || return 1
    local file=${1} algo=${2:-sha256} out
    case "${algo}" in
        sha1 | sha224 | sha256 | sha384 | sha512 | md5 | b2) ;;
        *)
            echo "psum: unknown algorithm '${algo}' (want sha256, sha1, sha224, sha384, sha512, md5 or b2)" >&2
            return 1
            ;;
    esac
    __dottod_pv_need psum "${algo}sum" || return 1
    [[ -f "${file}" ]] || {
        echo "psum: '${file}' does not exist" >&2
        return 1
    }
    out="$(pv -N "$(basename -- "${file}")" -- "${file}" | "${algo}sum")"
    __dottod_pv_rc "${PIPESTATUS[@]}" || return 1
    printf '%s  %s\n' "${out%% *}" "${file}"
}

# __dottod_pdd_is_block <path>: 0 for a block device (a seam for tests).
__dottod_pdd_is_block() {
    [[ -b "${1}" ]]
}

# __dottod_pdd_priv: sudo unless already root.
__dottod_pdd_priv() {
    if ((EUID == 0)); then
        "$@"
    else
        sudo "$@"
    fi
}

# pdd IMAGE DEVICE: write a disk image (.img/.iso, or .xz/.gz/.zst
# compressed) to a whole device. Refuses a non-block path, a device with
# anything mounted or used as swap, and an image larger than the device;
# shows the device and asks for its name typed back before writing.
# conv=fsync flushes the device itself (no global sync: it would wait on
# every other disk's writes too).
pdd() {
    if [[ "${1:-}" == -h || "${1:-}" == --help || $# -ne 2 ]]; then
        echo 'usage: pdd IMAGE DEVICE   write a disk image to a block device (e.g. pdd debian.iso /dev/sdb)'
        [[ "${1:-}" == -h || "${1:-}" == --help ]]
        return
    fi
    __dottod_pv_ready pdd || return 1
    local image=${1} dev=${2} codec size devsize mounts answer
    [[ -f "${image}" ]] || {
        echo "pdd: '${image}' does not exist" >&2
        return 1
    }
    __dottod_pdd_is_block "${dev}" || {
        echo "pdd: '${dev}' is not a block device" >&2
        return 1
    }
    command -v lsblk >/dev/null 2>&1 || {
        echo "pdd: 'lsblk' not found on PATH (needed to check the device)" >&2
        return 1
    }
    mounts="$(lsblk -nro MOUNTPOINT -- "${dev}" | grep -v '^$')"
    [[ -z "${mounts}" ]] || {
        printf 'pdd: %s is in use (mounted or swap): %s\n' "${dev}" "$(printf '%s' "${mounts}" | tr '\n' ' ')" >&2
        return 1
    }
    codec="$(__dottod_pv_image_codec "${image}")"
    __dottod_pv_need pdd "${codec}" || return 1
    size="$(__dottod_pv_size "${image}")" || return 1
    devsize="$(lsblk -bndo SIZE -- "${dev}")"
    if [[ "${codec}" == cat && "${devsize}" =~ ^[0-9]+$ ]] && ((size > devsize)); then
        echo "pdd: '${image}' (${size} bytes) is larger than ${dev} (${devsize} bytes)" >&2
        return 1
    fi

    lsblk -o NAME,SIZE,TYPE,MODEL,TRAN -- "${dev}"
    printf 'pdd: EVERYTHING on %s will be overwritten by %s.\n' "${dev}" "${image}"
    printf 'pdd: type the device name (%s) to continue: ' "${dev##*/}"
    read -r answer || return 1
    [[ "${answer}" == "${dev##*/}" || "${answer}" == "${dev}" ]] || {
        echo 'pdd: aborted'
        return 1
    }

    pv -s "${size}" -N "$(basename -- "${image}")" -- "${image}" |
        __dottod_pv_decompress "${codec}" |
        __dottod_pdd_priv dd of="${dev}" bs=4M conv=fsync status=none
    __dottod_pv_rc "${PIPESTATUS[@]}" || {
        echo "pdd: write to ${dev} failed" >&2
        return 1
    }
    echo "pdd: ${image} written to ${dev}"
}

# pchain FILE -- CMD...: read FILE through pv into CMD's stdin; returns
# CMD's status (or pv's, when only pv failed).
pchain() {
    if [[ "${1:-}" == -h || "${1:-}" == --help || $# -lt 3 || "${2}" != -- ]]; then
        echo 'usage: pchain FILE -- COMMAND [ARGS...]   feed FILE into COMMAND with a progress bar'
        echo '       e.g. pchain dump.sql -- psql mydb'
        [[ "${1:-}" == -h || "${1:-}" == --help ]]
        return
    fi
    __dottod_pv_ready pchain || return 1
    local file=${1} rc_pv rc_cmd
    shift 2
    [[ -f "${file}" ]] || {
        echo "pchain: '${file}' does not exist" >&2
        return 1
    }
    pv -N "$(basename -- "${file}")" -- "${file}" | "$@"
    rc_pv=${PIPESTATUS[0]} rc_cmd=${PIPESTATUS[1]}
    ((rc_cmd != 0)) && return "${rc_cmd}"
    return "${rc_pv}"
}

# Completions: algorithms for psum, block devices for pdd, a command
# after pchain's `--`; files everywhere else.
_psum() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if ((COMP_CWORD == 2)); then
        mapfile -t COMPREPLY < <(compgen -W 'sha256 sha1 sha224 sha384 sha512 md5 b2' -- "${cur}")
    else
        mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
    fi
}

_pdd() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if ((COMP_CWORD == 2)) && command -v lsblk >/dev/null 2>&1; then
        mapfile -t COMPREPLY < <(compgen -W "$(lsblk -dnpo NAME 2>/dev/null)" -- "${cur}")
    else
        mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
    fi
}

_pchain() {
    local i cur=${COMP_WORDS[COMP_CWORD]}
    for ((i = 1; i < COMP_CWORD; i++)); do
        [[ "${COMP_WORDS[i]}" == -- ]] || continue
        if ((COMP_CWORD == i + 1)); then
            mapfile -t COMPREPLY < <(compgen -c -- "${cur}")
        elif declare -F _command_offset >/dev/null; then
            _command_offset $((i + 1))
        else
            mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
        fi
        return 0
    done
    mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
}

complete -o filenames -F _psum psum 2>/dev/null
complete -o filenames -F _pdd pdd 2>/dev/null
complete -o filenames -F _pchain pchain 2>/dev/null
