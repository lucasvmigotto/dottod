#!/usr/bin/env bats
#
# test-os.bats — hermetic tests for lib/os.sh (spec 015, phase 1).
#
# Fixtures under tests/fixtures/os-release/ stand in for /etc/os-release
# via _DOT_OS_RELEASE_FILE; uname/getconf are stubbed on a prepended PATH
# and the musl probe reads a fake root (_DOT_LIBC_ROOT). Nothing reads the
# host's /etc/os-release or runs a package manager.

load helpers

setup() {
    FIX="${BATS_TEST_DIRNAME}/fixtures/os-release"
    STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN" "$BATS_TEST_TMPDIR/root/lib"

    cat >"$STUBBIN/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${UNAME_STUB_M:-x86_64}"
EOF
    cat >"$STUBBIN/getconf" <<'EOF'
#!/usr/bin/env bash
[[ "${GETCONF_STUB_GLIBC:-1}" == 1 ]] || exit 1
printf 'glibc 2.41\n'
EOF
    chmod +x "$STUBBIN/uname" "$STUBBIN/getconf"

    export PATH="$STUBBIN:$PATH"
    export _DOT_LIBC_ROOT="$BATS_TEST_TMPDIR/root"
    unset UNAME_STUB_M GETCONF_STUB_GLIBC

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../lib/os.sh"
}

# detect_fixture <name>: runs _os_detect against a fixture in this shell
# (not `run`, so the DOTTOD_* globals stay visible).
detect_fixture() {
    export _DOT_OS_RELEASE_FILE="${FIX}/${1}"
    _os_detect 2>"$BATS_TEST_TMPDIR/stderr"
}

@test "each supported fixture maps to its family and package manager" {
    local row name family pkg
    for row in debian:debian:apt-get ubuntu:debian:apt-get linuxmint:debian:apt-get \
        gentoo:gentoo:emerge arch:arch:pacman fedora:redhat:dnf alpine:alpine:apk; do
        IFS=: read -r name family pkg <<<"$row"
        detect_fixture "$name"
        assert_eq "$name rc" '0' "$?"
        assert_eq "$name family" "$family" "$DOTTOD_OS_FAMILY"
        assert_eq "$name pkg" "$pkg" "$DOTTOD_PKG"
        assert_eq "$name id" "$name" "$DOTTOD_OS_ID"
    done
}

@test "os-release fields unquote as the spec says" {
    detect_fixture debian
    assert_eq 'name' 'Debian GNU/Linux' "$DOTTOD_OS_NAME"
    assert_eq 'version' '13' "$DOTTOD_OS_VERSION_ID"
    detect_fixture linuxmint
    assert_eq 'quoted id_like' 'ubuntu debian' "$DOTTOD_OS_ID_LIKE"
    detect_fixture fedora
    assert_eq 'bare version' '42' "$DOTTOD_OS_VERSION_ID"
    detect_fixture gentoo
    assert_eq 'single-quoted (real gentoo file)' 'Gentoo' "$DOTTOD_OS_NAME"
    assert_eq 'single-quoted version' '2.18' "$DOTTOD_OS_VERSION_ID"
    printf "ID='alpine'\nNAME=\"a \\\\\"b\\\\\" \\\\\$c\"\n" >"$BATS_TEST_TMPDIR/quoted"
    assert_eq 'single quotes' 'alpine' "$(_os_release_get "$BATS_TEST_TMPDIR/quoted" ID)"
    assert_eq 'escapes' 'a "b" $c' "$(_os_release_get "$BATS_TEST_TMPDIR/quoted" NAME)"
}

@test "unknown distribution fails with no package manager" {
    run detect_fixture unknown
    assert_eq 'unknown rc' '1' "$status"
    detect_fixture unknown || true
    assert_eq 'family unknown' 'unknown' "$DOTTOD_OS_FAMILY"
    assert_eq 'no pkg' '' "$DOTTOD_PKG"
    assert_contains 'says unsupported' "unsupported distribution 'nixos'" "$(cat "$BATS_TEST_TMPDIR/stderr")"
}

@test "malformed and missing files fail" {
    run detect_fixture malformed
    assert_eq 'malformed rc' '1' "$status"
    detect_fixture malformed || true
    assert_eq 'malformed no pkg' '' "$DOTTOD_PKG"
    run detect_fixture does-not-exist
    assert_eq 'missing rc' '1' "$status"
}

@test "values are data: nothing in the file is executed" {
    export DOTTOD_PWNED_FILE="$BATS_TEST_TMPDIR/pwned"
    run detect_fixture injection
    assert_eq 'invalid id rejected' '1' "$status"
    assert_eq 'no file created' 'absent' "$([[ -e "$DOTTOD_PWNED_FILE" ]] && echo present || echo absent)"
}

@test "ID_LIKE is only a fallback; first supported token wins" {
    printf 'ID=debian\nID_LIKE=arch\n' >"$BATS_TEST_TMPDIR/id-first"
    export _DOT_OS_RELEASE_FILE="$BATS_TEST_TMPDIR/id-first"
    _os_detect
    assert_eq 'ID wins' 'debian' "$DOTTOD_OS_FAMILY"
    printf 'ID=someos\nID_LIKE="* Bad gentoo"\n' >"$BATS_TEST_TMPDIR/like"
    export _DOT_OS_RELEASE_FILE="$BATS_TEST_TMPDIR/like"
    _os_detect
    assert_eq 'first supported token' 'gentoo' "$DOTTOD_OS_FAMILY"
    printf 'ID=rocky\nID_LIKE="rhel"\n' >"$BATS_TEST_TMPDIR/rhel"
    export _DOT_OS_RELEASE_FILE="$BATS_TEST_TMPDIR/rhel"
    _os_detect
    assert_eq 'rhel derivative' 'redhat' "$DOTTOD_OS_FAMILY"
}

@test "architecture normalizes" {
    local row raw want
    for row in x86_64:x86_64 amd64:x86_64 aarch64:aarch64 arm64:aarch64 riscv64:riscv64; do
        IFS=: read -r raw want <<<"$row"
        assert_eq "arch $raw" "$want" "$(UNAME_STUB_M=$raw _os_arch)"
    done
}

@test "libc: musl loader wins, glibc via getconf, else unknown" {
    assert_eq 'glibc' 'glibc' "$(_os_libc)"
    assert_eq 'unknown' 'unknown' "$(GETCONF_STUB_GLIBC=0 _os_libc)"
    : >"$BATS_TEST_TMPDIR/root/lib/ld-musl-x86_64.so.1"
    assert_eq 'musl' 'musl' "$(_os_libc)"
}

@test "package manager must be on PATH after detection" {
    detect_fixture fedora
    PATH="$STUBBIN" run _os_require_pkg
    assert_eq 'dnf missing rc' '1' "$status"
    assert_contains 'explains' "'dnf' is not on PATH" "$output"
    printf '#!/usr/bin/env bash\n' >"$STUBBIN/dnf"
    chmod +x "$STUBBIN/dnf"
    PATH="$STUBBIN" run _os_require_pkg
    assert_eq 'dnf present rc' '0' "$status"
    DOTTOD_PKG='' run _os_require_pkg
    assert_eq 'no detection rc' '1' "$status"
}
