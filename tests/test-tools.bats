#!/usr/bin/env bats
#
# test-tools.bats — hermetic tests for bin/tools.sh (spec 011 / 015 phase 7):
# bat/fd name aliases, gh per distro family, extras validation.
#
# Each probe runs in a fresh bash with tools.sh sourced (its BASH_SOURCE
# guard keeps _main from running); _install_packages and _priv only
# record, so no package manager or privilege is ever used.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    FIX="${BATS_TEST_DIRNAME}/fixtures/os-release"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALLS"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUBBIN"
    export PATH="$HOME/.local/bin:$STUBBIN:/usr/bin:/bin"
    unset DOT_TOOLS_EXTRA
}

stub() {
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$CALLS"\n' "$1" >"$STUBBIN/$1"
    chmod +x "$STUBBIN/$1"
}

probe() {
    run bash -c "
        set -Eeuo pipefail
        source '${REPO_ROOT}/bin/tools.sh'
        command() {
            if [[ \"\$1\" == -v ]]; then
                case \" \${HIDE_CMDS:-} \" in *\" \$2 \"*) return 1 ;; esac
            fi
            builtin command \"\$@\"
        }
        _install_packages() { printf 'PKGS:%s\n' \"\$*\" >>\"\$CALLS\"; }
        _priv() { printf 'PRIV:%s\n' \"\$*\" >>\"\$CALLS\"; }
        _download() { : >\"\$2\"; printf 'DL:%s\n' \"\$1\" >>\"\$CALLS\"; }
        ${1}
    "
}

@test "debian's batcat and fdfind get the plain names" {
    stub batcat
    stub fdfind
    export HIDE_CMDS='bat fd'
    probe '_tools_alias bat batcat; _tools_alias fd fdfind'
    assert_eq 'rc' '0' "$status"
    assert_eq 'bat -> batcat' "$STUBBIN/batcat" "$(readlink "$HOME/.local/bin/bat")"
    assert_eq 'fd -> fdfind' "$STUBBIN/fdfind" "$(readlink "$HOME/.local/bin/fd")"
}

@test "other distros' bat gets the batcat name, and nothing is linked twice" {
    stub bat
    export HIDE_CMDS='batcat'
    probe '_tools_alias bat batcat'
    assert_eq 'batcat -> bat' "$STUBBIN/bat" "$(readlink "$HOME/.local/bin/batcat")"
    stub batcat
    rm -f "$HOME/.local/bin/batcat"
    unset HIDE_CMDS
    probe '_tools_alias bat batcat'
    assert_eq 'both present: no link' '0' "$([[ -e "$HOME/.local/bin/batcat" ]] && echo 1 || echo 0)"
}

@test "gh comes from the distro package outside Debian" {
    local os
    for os in gentoo arch fedora alpine; do
        : >"$CALLS"
        _DOT_OS_RELEASE_FILE="$FIX/$os" HIDE_CMDS=gh probe '_github_cli_install'
        assert_contains "$os: gh requested" 'PKGS:gh' "$(cat "$CALLS")"
        assert_eq "$os: no apt repository" '0' "$(grep -c 'cli.github.com\|PRIV:' "$CALLS" || true)"
    done
}

@test "gh on Debian adds the signed apt repository first" {
    _DOT_OS_RELEASE_FILE="$FIX/debian" HIDE_CMDS=gh probe '
        dpkg() { echo amd64; }
        _github_cli_install
    '
    local calls
    calls="$(cat "$CALLS")"
    assert_contains 'keyring downloaded' 'DL:https://cli.github.com/packages/githubcli-archive-keyring.gpg' "$calls"
    assert_contains 'source written' 'PRIV:tee /etc/apt/sources.list.d/github-cli.list' "$calls"
    assert_contains 'index refreshed' 'PRIV:env DEBIAN_FRONTEND=noninteractive apt-get update -qq' "$calls"
    assert_eq 'gh requested last' 'PKGS:gh' "$(tail -n1 "$CALLS")"
}

@test "extras accept gh, httpie, chafa, fastfetch and all; dropped tools are rejected" {
    DOT_TOOLS_EXTRA=gh,httpie,chafa,fastfetch probe '_extras_validate'
    assert_eq 'known extras rc 0' '0' "$status"
    DOT_TOOLS_EXTRA=all probe '_extras_validate'
    assert_eq 'all rc 0' '0' "$status"
    DOT_TOOLS_EXTRA=lazygit probe '_extras_validate'
    assert_eq 'dropped tool rc 1' '1' "$status"
    assert_contains 'lists the valid ones' 'want: gh,httpie,chafa,fastfetch' "$output"
}

@test "the core install includes pv (the progress shortcuts need it)" {
    probe '_main'
    assert_eq 'rc' '0' "$status"
    assert_match 'pv in the core packages' '^PKGS:.* fzf pv shellcheck ' "$(head -n1 "$CALLS")"
}
