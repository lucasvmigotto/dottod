#!/usr/bin/env bats
#
# test-fetch.bats — scripts/dottod-fetch.sh: the card is built from dottod's
# own detection and package tables, for any os-release fixture.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    FIX="${BATS_TEST_DIRNAME}/fixtures/os-release"
    unset DOT_FORCE_COLOR NO_COLOR DOT_PROMPT_STYLE
}

@test "each fixture shows its family, manager and real package names" {
    local row name family sample
    for row in "gentoo:gentoo (emerge):openssh_client -> net-misc/openssh" \
        "arch:arch (pacman):openssh_client -> openssh" \
        "fedora:redhat (dnf):vim -> vim-enhanced" \
        "alpine:alpine (apk):openssh_client -> openssh-client-default" \
        "debian:debian (apt-get):openssh_client -> openssh-client"; do
        IFS=: read -r name family sample <<<"$row"
        run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/$name"
        assert_eq "$name rc" '0' "$status"
        assert_contains "$name family" "Family    $family" "$output"
        assert_contains "$name mapping" "$sample" "$output"
    done
}

@test "a simulated alpine reports musl; a simulated shell has no host version" {
    run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/alpine"
    assert_contains 'musl' 'Libc      musl' "$output"
    assert_contains 'plain shell line' $'Shell     bash\n' "$output"$'\n'
}

@test "an unsupported distribution says so and lists no packages" {
    run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/unknown"
    assert_eq 'rc' '0' "$status"
    assert_contains 'unsupported' 'unsupported (no package command would run)' "$output"
    assert_eq 'no package list' '0' "$(grep -c 'Packages' <<<"$output" || true)"
}

@test "no color codes when not on a terminal, color with DOT_FORCE_COLOR" {
    run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/gentoo"
    assert_eq 'plain' '0' "$(grep -c $'\033' <<<"$output" || true)"
    DOT_FORCE_COLOR=1 run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/gentoo"
    assert_contains 'magenta for gentoo' $'\033[35m' "$output"
}

@test "the prompt line follows DOT_PROMPT_STYLE" {
    DOT_PROMPT_STYLE=kali run "$REPO_ROOT/scripts/dottod-fetch.sh" --os-release "$FIX/debian"
    assert_contains 'kali' 'Prompt    kali' "$output"
}
