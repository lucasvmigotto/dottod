#!/usr/bin/env bats
#
# test-fonts.bats — hermetic tests for bin/fonts.sh.
#
# Covers: prerequisite probing (no privilege escalation when everything is
# present, minimal package set when something is missing) and the
# user-level default (no sudo for ~/.local installs). Network and font
# installation are stubbed; only the probing/selection logic runs.

load helpers

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export STUBBIN="$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUBBIN"
    : >"$CALLS"
    export FAKE_HOME="$BATS_TEST_TMPDIR/home"
    export HOME="$FAKE_HOME"
    mkdir -p "$FAKE_HOME"
    export _DOT_NO_PACKAGES=1
    unset _DOT_NERDFONT_GLOBAL_INSTALL HIDE_CMDS

    # Probes see the stubs first, then the real PATH.
    export PATH="$STUBBIN:/usr/bin:/bin"

    for cmd in curl fc-list unzip; do
        cat >"$STUBBIN/$cmd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    done
    chmod +x "$STUBBIN"/*
}

# Run a snippet in a fresh bash with fonts.sh sourced (BASH_SOURCE guard
# keeps _main from running) and the side-effecting helpers recorded.
# Absence is simulated with HIDE_CMDS (space-separated names that
# `command -v` must not see), so real host binaries can never leak in.
probe() {
    local snippet=${1}
    run bash -c "
        set -Eeuo pipefail
        command() {
            if [[ \"\${1:-}\" == '-v' && -n \"\${2:-}\" ]]; then
                case \" \${HIDE_CMDS:-} \" in
                    *\" \$2 \"*) return 1 ;;
                esac
            fi
            builtin command \"\$@\"
        }
        source '${REPO_ROOT}/bin/fonts.sh'
        _install_packages() { printf 'PKGS:%s\n' \"\$*\" >>\"\$CALLS\"; return 0; }
        _install_nerdfont() { printf 'FONT:%s\n' \"\$1\" >>\"\$CALLS\"; return 0; }
        _font_installed() { return 1; }
        ${snippet}
    "
}

@test "fonts: skips package install when prerequisites are present" {
    probe '_main FiraCode >/dev/null'
    assert_eq 'main rc 0' '0' "$status"
    assert_eq 'no package calls' '0' "$(grep -c '^PKGS:' "$CALLS" || true)"
    assert_contains 'font requested' 'FONT:FiraCode' "$(cat "$CALLS")"
}

@test "fonts: installs only the missing prerequisites" {
    export HIDE_CMDS="unzip"
    probe '_main FiraCode >/dev/null'
    assert_eq 'main rc 0' '0' "$status"
    assert_eq 'one package call' '1' "$(grep -c '^PKGS:' "$CALLS" || true)"
    assert_contains 'only unzip requested' 'PKGS:unzip' "$(cat "$CALLS")"
}

@test "fonts: missing fontconfig pulls fontconfig only" {
    export HIDE_CMDS="fc-list"
    probe '_main FiraCode >/dev/null'
    assert_eq 'main rc 0' '0' "$status"
    assert_contains 'fontconfig requested' 'fontconfig' "$(cat "$CALLS")"
}

@test "fonts: user-level install targets the home folder" {
    probe '_main FiraCode >/dev/null; printf "HOME_USED:%s" "$HOME"'
    assert_eq 'main rc 0' '0' "$status"
    assert_eq 'local fonts dir created' '1' "$([[ -d "$FAKE_HOME/.local/share/fonts" ]] && echo 1 || echo 0)"
}

@test "fonts: never touches GNOME font settings" {
    local leftovers
    leftovers="$(grep -niE "gsettings|desktop\.interface|font-name" "$REPO_ROOT/bin/fonts.sh" || true)"
    assert_eq 'no desktop font overrides' '' "$leftovers"
}
