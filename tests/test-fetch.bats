#!/usr/bin/env bats
#
# test-fetch.bats — scripts/dottod-fetch.sh: the card is built from dottod's
# own detection and package tables, for any os-release fixture, and drawn
# by fastfetch when it is installed (a stub here), else as plain text.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    FIX="${BATS_TEST_DIRNAME}/fixtures/os-release"
    unset DOT_FORCE_COLOR NO_COLOR DOT_PROMPT_STYLE
    # No fastfetch unless a test installs the stub.
    export _DOT_FETCH_CMD=dottod-no-such-fastfetch
}

# Plain card with runs of spaces squeezed: "Family debian (apt-get)".
fetch_plain() {
    "$REPO_ROOT/scripts/dottod-fetch.sh" "$@" | tr -s ' '
}

# A fastfetch stub: records its arguments and a copy of the config it got.
use_stub() {
    local bin="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin"
    cat >"$bin/fastfetch" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/ff.args"
while (($#)); do
    [[ $1 == --config ]] && cp "$2" "$BATS_TEST_TMPDIR/ff.json" && printf '%s\n' "$2" >"$BATS_TEST_TMPDIR/ff.path"
    shift
done
EOF
    chmod +x "$bin/fastfetch"
    export _DOT_FETCH_CMD="$bin/fastfetch" BATS_TEST_TMPDIR
}

@test "each fixture shows its family, manager and real package names" {
    local row name family sample
    for row in "gentoo:gentoo (emerge):openssh_client net-misc/openssh" \
        "arch:arch (pacman):openssh_client openssh" \
        "fedora:redhat (dnf):vim vim-enhanced" \
        "alpine:alpine (apk):openssh_client openssh-client-default" \
        "debian:debian (apt-get):openssh_client openssh-client"; do
        IFS=: read -r name family sample <<<"$row"
        run fetch_plain --os-release "$FIX/$name"
        assert_eq "$name rc" '0' "$status"
        assert_contains "$name family" "Family $family" "$output"
        assert_contains "$name mapping" "$sample" "$output"
    done
}

@test "a simulated alpine reports musl; a simulated shell has no host version" {
    run fetch_plain --os-release "$FIX/alpine"
    assert_contains 'musl' 'Libc musl' "$output"
    assert_contains 'plain shell line' $'Shell bash\n' "$output"$'\n'
}

@test "an unsupported distribution says so and lists no packages" {
    run fetch_plain --os-release "$FIX/unknown"
    assert_eq 'rc' '0' "$status"
    assert_contains 'unsupported' 'unsupported (no package command would run)' "$output"
    assert_eq 'no package list' '0' "$(grep -c 'Packages' <<<"$output" || true)"
}

@test "the prompt line follows DOT_PROMPT_STYLE" {
    DOT_PROMPT_STYLE=kali run fetch_plain --os-release "$FIX/debian"
    assert_contains 'kali' 'Prompt kali' "$output"
}

@test "fastfetch draws a simulated system with its logo and the card as valid JSON" {
    use_stub
    run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/gentoo"
    assert_eq 'rc' '0' "$status"
    assert_contains 'gentoo logo' $'--logo\ngentoo' "$(cat "$BATS_TEST_TMPDIR/ff.args")"
    assert_contains 'no color off a terminal' $'--pipe\ntrue' "$(cat "$BATS_TEST_TMPDIR/ff.args")"
    run python3 -c 'import json,sys; m=json.load(open(sys.argv[1]))["modules"]; print("\n".join(x["key"]+"="+x["format"] for x in m if isinstance(x, dict) and "key" in x)); print("probes", sum(isinstance(x, str) and x != "separator" for x in m))' "$BATS_TEST_TMPDIR/ff.json"
    assert_eq 'json parses' '0' "$status"
    assert_contains 'family line' 'Family=gentoo (emerge)' "$output"
    assert_contains 'package line' '  openssh_client=net-misc/openssh' "$output"
    assert_contains 'no host probes when simulated' 'probes 0' "$output"
    assert_eq 'config removed' '0' "$([[ -e "$(cat "$BATS_TEST_TMPDIR/ff.path")" ]] && echo 1 || echo 0)"
}

@test "fastfetch on this system: its own logo and probes, color when forced" {
    use_stub
    DOT_FORCE_COLOR=1 run "$REPO_ROOT/scripts/dottod-fetch.sh"
    assert_eq 'rc' '0' "$status"
    assert_eq 'no logo override' '0' "$(grep -c -- '--logo' "$BATS_TEST_TMPDIR/ff.args" || true)"
    assert_contains 'color forced' $'--pipe\nfalse' "$(cat "$BATS_TEST_TMPDIR/ff.args")"
    assert_contains 'host probes' '"kernel"' "$(cat "$BATS_TEST_TMPDIR/ff.json")"
}

@test "--plain skips fastfetch; quotes and backslashes stay valid JSON" {
    use_stub
    run "$REPO_ROOT/scripts/dottod-fetch.sh" --plain --os-release "$FIX/debian"
    assert_eq 'stub not called' '0' "$([[ -e "$BATS_TEST_TMPDIR/ff.args" ]] && echo 1 || echo 0)"
    printf 'ID=debian\nNAME="Odd \\"q\\" \\\\ name"\nVERSION_ID=13\n' >"$BATS_TEST_TMPDIR/os-release"
    run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$BATS_TEST_TMPDIR/os-release"
    run python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$BATS_TEST_TMPDIR/ff.json"
    assert_eq 'json parses' '0' "$status"
}
