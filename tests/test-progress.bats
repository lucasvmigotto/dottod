#!/usr/bin/env bats
#
# test-progress.bats — hermetic tests for scripts/.progress.sh (spec 019):
# pcp, ptar/puntar, psum, pdd, pchain and pvl on a stub pv that records
# its arguments and passes the bytes through (PV_FAIL=1: three bytes,
# then exit 1). pdd's device checks run on stub lsblk/sudo/dd and a
# block-device seam; nothing touches a real disk.

load helpers

setup() {
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export PV_CALLS="$BATS_TEST_TMPDIR/pv.log"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$PV_CALLS"
    : >"$CALLS"

    cat >"$STUBBIN/pv" <<'EOF'
#!/usr/bin/env bash
printf 'pv %s\n' "$*" >>"${PV_CALLS:?}"
files=()
while (($#)); do
    case "$1" in
        -s | -N) shift 2 ;;
        --) shift; files+=("$@"); break ;;
        -*) shift ;;
        *) files+=("$1"); shift ;;
    esac
done
if [[ -n "${PV_FAIL:-}" ]]; then
    if ((${#files[@]})); then head -c 3 "${files[0]}"; else head -c 3; fi
    exit 1
fi
cat "${files[@]}"
EOF
    # lsblk: LSBLK_MOUNTS for -nro MOUNTPOINT, LSBLK_SIZE for -bndo SIZE,
    # a table otherwise.
    cat >"$STUBBIN/lsblk" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *MOUNTPOINT*) printf '%b' "${LSBLK_MOUNTS:-\n}" ;;
    *SIZE\ --*) printf '%s\n' "${LSBLK_SIZE:-1000000}" ;;
    *) printf 'NAME SIZE TYPE MODEL TRAN\nsdz  1M   disk STUB  usb\n' ;;
esac
EOF
    cat >"$STUBBIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >>"${CALLS:?}"
exec "$@"
EOF
    cat >"$STUBBIN/dd" <<'EOF'
#!/usr/bin/env bash
echo "dd $*" >>"${CALLS:?}"
cat >"${DD_OUT:?}"
EOF
    chmod +x "$STUBBIN"/*
    export PATH="$STUBBIN:$PATH"
    export DD_OUT="$BATS_TEST_TMPDIR/device.bin"

    W="$BATS_TEST_TMPDIR/w"
    mkdir -p "$W/tree/sub"
    printf 'alpha\n' >"$W/tree/a.txt"
    printf 'beta\n' >"$W/tree/sub/b.txt"
    ln -s a.txt "$W/tree/link"
    printf 'payload\n' >"$W/file.bin"
    chmod 0750 "$W/file.bin"
    cd "$W" || return 1

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../scripts/.progress.sh"
}

# hide_pv: `command -v pv` fails, as on a system without pv.
hide_pv() {
    command() {
        [[ "$1" == -v && "$2" == pv ]] && return 1
        builtin command "$@"
    }
}

@test "every command fails loudly without pv" {
    hide_pv
    local cmd
    for cmd in 'pcp file.bin out' 'ptar tree' 'puntar x.tar' 'psum file.bin' \
        'pdd file.bin /dev/sdz' 'pchain file.bin -- cat'; do
        run ${cmd}
        assert_eq "${cmd}: rc 1" '1' "$status"
        assert_contains "${cmd}: names pv" "'pv' not found on PATH (bin/tools.sh installs it)" "$output"
    done
}

@test "-h prints usage and succeeds; wrong arguments fail with usage" {
    local cmd
    for cmd in pcp ptar puntar psum pdd pchain; do
        run "${cmd}" -h
        assert_eq "${cmd} -h rc" '0' "$status"
        assert_contains "${cmd} usage" "usage: ${cmd}" "$output"
        run "${cmd}"
        assert_eq "${cmd} (no args) rc" '1' "$status"
        assert_contains "${cmd} (no args) usage" "usage: ${cmd}" "$output"
    done
}

@test "pcp copies a file with its size and name on the bar, and keeps its mode" {
    run pcp file.bin copy.bin
    assert_eq 'rc' '0' "$status"
    assert_eq 'content' 'payload' "$(cat copy.bin)"
    assert_eq 'mode kept' '750' "$(stat -c %a copy.bin)"
    assert_contains 'size and name' 'pv -s 8 -N file.bin -- file.bin' "$(cat "$PV_CALLS")"
}

@test "pcp into an existing directory keeps the name" {
    mkdir dest
    run pcp file.bin dest/
    assert_eq 'rc' '0' "$status"
    assert_eq 'dest/file.bin' 'payload' "$(cat dest/file.bin)"
}

@test "pcp never overwrites" {
    printf 'keep\n' >taken.bin
    run pcp file.bin taken.bin
    assert_eq 'rc' '1' "$status"
    assert_contains 'says why' "'taken.bin' already exists" "$output"
    assert_eq 'untouched' 'keep' "$(cat taken.bin)"
}

@test "pcp copies a directory tree through tar, links included" {
    run pcp tree copy
    assert_eq 'new target rc' '0' "$status"
    assert_eq 'nested file' 'beta' "$(cat copy/sub/b.txt)"
    assert_eq 'symlink kept' 'a.txt' "$(readlink copy/link)"
    assert_match 'sized bar' '^pv -s [0-9]+ -N tree$' "$(cat "$PV_CALLS")"
    mkdir into
    run pcp tree/ into
    assert_eq 'existing dir rc' '0' "$status"
    assert_eq 'lands under its name' 'alpha' "$(cat into/tree/a.txt)"
}

@test "pcp removes the partial copy when the copy fails" {
    PV_FAIL=1 run pcp file.bin broken.bin
    assert_eq 'file rc' '1' "$status"
    assert_eq 'partial file removed' '0' "$([[ -e broken.bin ]] && echo 1 || echo 0)"
    PV_FAIL=1 run pcp tree broken
    assert_eq 'dir rc' '1' "$status"
    assert_eq 'partial dir removed' '0' "$([[ -e broken ]] && echo 1 || echo 0)"
}

@test "ptar and puntar round-trip gzip, xz and plain tar" {
    local ext
    for ext in tar.gz tgz tar.xz tar; do
        run ptar tree "out.${ext}"
        assert_eq "${ext}: ptar rc" '0' "$status"
        assert_contains "${ext}: names the archive" "ptar: out.${ext}" "$output"
        run puntar "out.${ext}" "x-${ext}"
        assert_eq "${ext}: puntar rc" '0' "$status"
        assert_eq "${ext}: content" 'beta' "$(cat "x-${ext}/tree/sub/b.txt")"
    done
    assert_contains 'puntar bar on the archive' 'pv -N out.tar.gz -- out.tar.gz' "$(cat "$PV_CALLS")"
}

@test "ptar round-trips zstd, and defaults to it when zstd is installed" {
    command -v zstd >/dev/null || skip 'zstd not installed'
    run ptar tree
    assert_eq 'rc' '0' "$status"
    assert_contains 'default name' 'ptar: tree.tar.zst' "$output"
    run puntar tree.tar.zst x
    assert_eq 'puntar rc' '0' "$status"
    assert_eq 'content' 'alpha' "$(cat x/tree/a.txt)"
}

@test "ptar falls back to .tar.gz without zstd" {
    command() {
        [[ "$1" == -v && "$2" == zstd ]] && return 1
        builtin command "$@"
    }
    run ptar tree
    assert_eq 'rc' '0' "$status"
    assert_contains 'gzip name' 'ptar: tree.tar.gz' "$output"
}

@test "ptar refuses an unknown extension, an existing archive and a non-directory" {
    run ptar tree out.zip
    assert_eq 'zip rc' '1' "$status"
    assert_contains 'lists the formats' 'want .tar.zst, .tar.gz, .tar.xz or .tar' "$output"
    : >exists.tar.gz
    run ptar tree exists.tar.gz
    assert_eq 'existing rc' '1' "$status"
    assert_eq 'untouched' '0' "$(stat -c %s exists.tar.gz)"
    run ptar file.bin
    assert_contains 'not a directory' "'file.bin' is not a directory" "$output"
}

@test "ptar removes the partial archive when a stage fails" {
    PV_FAIL=1 run ptar tree broken.tar.gz
    assert_eq 'rc' '1' "$status"
    assert_eq 'removed' '0' "$([[ -e broken.tar.gz ]] && echo 1 || echo 0)"
}

@test "puntar reports a corrupt archive" {
    printf 'not gzip' >bad.tar.gz
    run puntar bad.tar.gz x
    assert_eq 'rc' '1' "$status"
    assert_contains 'says so' 'puntar: extract failed' "$output"
}

@test "psum prints sha256sum-style output that sha256sum -c accepts" {
    run psum file.bin
    assert_eq 'rc' '0' "$status"
    assert_eq 'same as sha256sum' "$(sha256sum file.bin)" "$output"
    printf '%s\n' "$output" >sums
    run sha256sum -c sums
    assert_eq 'verifies' '0' "$status"
    run psum file.bin md5
    assert_eq 'md5' "$(md5sum file.bin)" "$output"
}

@test "psum refuses an unknown algorithm and a missing file" {
    run psum file.bin crc32
    assert_eq 'algo rc' '1' "$status"
    assert_contains 'lists them' "unknown algorithm 'crc32'" "$output"
    run psum nope.bin
    assert_contains 'missing' "'nope.bin' does not exist" "$output"
}

@test "pdd refuses a path that is not a block device" {
    run pdd file.bin "$W/file.bin"
    assert_eq 'rc' '1' "$status"
    assert_contains 'says why' 'is not a block device' "$output"
    assert_eq 'dd never ran' '' "$(cat "$CALLS")"
}

@test "pdd refuses a device with anything mounted or used as swap" {
    __dottod_pdd_is_block() { return 0; }
    LSBLK_MOUNTS='\n/media/usb\n' run pdd file.bin /dev/sdz
    assert_eq 'mounted rc' '1' "$status"
    assert_contains 'names the mount' '/dev/sdz is in use (mounted or swap): /media/usb' "$output"
    LSBLK_MOUNTS='[SWAP]\n' run pdd file.bin /dev/sdz
    assert_contains 'swap' 'in use (mounted or swap): [SWAP]' "$output"
    assert_eq 'dd never ran' '' "$(cat "$CALLS")"
}

@test "pdd refuses an image larger than the device" {
    __dottod_pdd_is_block() { return 0; }
    LSBLK_SIZE=4 run pdd file.bin /dev/sdz
    assert_eq 'rc' '1' "$status"
    assert_contains 'says why' 'is larger than /dev/sdz' "$output"
}

@test "pdd writes only after the device name is typed back" {
    __dottod_pdd_is_block() { return 0; }
    run pdd file.bin /dev/sdz <<<'yes'
    assert_eq 'wrong answer rc' '1' "$status"
    assert_contains 'aborted' 'pdd: aborted' "$output"
    assert_eq 'dd never ran' '' "$(cat "$CALLS")"

    run pdd file.bin /dev/sdz <<<'sdz'
    assert_eq 'rc' '0' "$status"
    assert_contains 'shows the device' 'sdz  1M   disk STUB  usb' "$output"
    assert_contains 'warns' 'EVERYTHING on /dev/sdz will be overwritten by file.bin' "$output"
    assert_contains 'dd with fsync' 'dd of=/dev/sdz bs=4M conv=fsync status=none' "$(cat "$CALLS")"
    if ((EUID != 0)); then
        assert_contains 'through sudo' 'sudo dd of=/dev/sdz' "$(cat "$CALLS")"
    fi
    assert_eq 'bytes written' 'payload' "$(cat "$DD_OUT")"
}

@test "pdd decompresses an .xz image on the way" {
    __dottod_pdd_is_block() { return 0; }
    xz -c file.bin >disk.img.xz
    run pdd disk.img.xz /dev/sdz <<<'/dev/sdz'
    assert_eq 'rc' '0' "$status"
    assert_eq 'decompressed bytes' 'payload' "$(cat "$DD_OUT")"
}

@test "pchain feeds a file into a command and returns its status" {
    run pchain file.bin -- tr a-z A-Z
    assert_eq 'rc' '0' "$status"
    assert_eq 'piped' 'PAYLOAD' "$output"
    assert_contains 'named bar' 'pv -N file.bin -- file.bin' "$(cat "$PV_CALLS")"
    run pchain file.bin -- grep -q nothing-here
    assert_eq 'command status' '1' "$status"
    run pchain file.bin cat
    assert_contains 'needs --' 'usage: pchain FILE -- COMMAND' "$output"
}

@test "pvl is pv -l" {
    run alias pvl
    assert_eq 'alias' "alias pvl='pv -l'" "$output"
}

@test "completion: psum algorithms, pchain commands after --" {
    COMP_WORDS=(psum file.bin sha5)
    COMP_CWORD=2
    _psum
    assert_eq 'sha512' 'sha512' "${COMPREPLY[*]}"
    COMP_WORDS=(pchain file.bin -- tr)
    COMP_CWORD=3
    _pchain
    assert_contains 'commands' 'tr' "${COMPREPLY[*]}"
}
