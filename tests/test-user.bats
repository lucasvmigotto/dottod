#!/usr/bin/env bats
#
# test-user.bats — target-user helpers (spec 015, phase 4): home lookup
# in bin/utils.sh and the login-shell switch in bin/shell.sh.
#
# Hermetic: passwd data comes from a stubbed getent or a fixture file
# (_DOT_PASSWD_FILE), /etc/shells from _DOT_SHELLS_FILE, and _priv only
# records. The real home, /etc/passwd and the login shell are untouched.

load helpers

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALLS"
    export _DOT_NO_PACKAGES=1
    export _DOT_PASSWD_FILE="$BATS_TEST_TMPDIR/passwd"
    export _DOT_SHELLS_FILE="$BATS_TEST_TMPDIR/shells"
    cat >"$_DOT_PASSWD_FILE" <<'PW'
root:x:0:0:root:/root:/bin/bash
alice:x:1000:1000::/var/home/alice:/bin/sh
bob:x:1001:1001::/data/home/bob dir:/usr/bin/bash
nohome:x:1002:1002:::/bin/sh
PW
    printf '/bin/sh\n%s\n' "$(command -v bash)" >"$_DOT_SHELLS_FILE"
}

# probe <snippet>: fresh bash with shell.sh sourced (utils.sh with it);
# getent hidden so the passwd fixture is used, _priv record-only.
probe() {
    run bash -c "
        set -Eeuo pipefail
        source '${REPO_ROOT}/bin/shell.sh'
        command() { [[ \"\$1 \$2\" == '-v getent' ]] && return 1; builtin command \"\$@\"; }
        _priv() { printf 'PRIV:%s\n' \"\$*\" >>'${CALLS}'; }
        ${1}
    "
}

@test "home: current user is \$HOME" {
    probe 'HOME=/tmp/fake-home _dot_user_home "$(id -un)"'
    assert_eq 'rc' '0' "$status"
    assert_eq 'home' '/tmp/fake-home' "$output"
}

@test "home: other users come from passwd, any location" {
    probe '_dot_user_home alice'
    assert_eq 'alice' '/var/home/alice' "$output"
    probe '_dot_user_home bob'
    assert_eq 'bob, space in path' '/data/home/bob dir' "$output"
    probe '_dot_user_home root'
    assert_eq 'root' '/root' "$output"
}

@test "home: unknown user or empty home fails, never guesses" {
    probe '_dot_user_home ghost'
    assert_eq 'unknown rc' '1' "$status"
    assert_contains 'explains' "Cannot resolve the home directory of 'ghost'" "$output"
    probe '_dot_user_home nohome'
    assert_eq 'empty home rc' '1' "$status"
    probe 'HOME= _dot_user_home "$(id -un)"'
    assert_eq 'empty HOME rc' '1' "$status"
}

@test "home: getent is preferred when present" {
    run bash -c "
        source '${REPO_ROOT}/bin/utils.sh'
        getent() { printf 'alice:x:1000:1000::/from/getent:/bin/sh\n'; }
        _dot_user_home alice
    "
    assert_eq 'getent home' '/from/getent' "$output"
}

@test "login shell: an executable bash is kept, whatever its path" {
    probe '_bash_use_as_shell bob'
    assert_contains 'skips' 'already installed and in use' "$output"
    assert_eq 'no chsh' '' "$(cat "$CALLS")"
}

@test "login shell: switches to the bash listed in /etc/shells" {
    probe '_bash_use_as_shell alice'
    assert_eq 'rc' '0' "$status"
    assert_eq 'chsh argv' "PRIV:chsh -s $(command -v bash) alice" "$(cat "$CALLS")"
}

@test "login shell: bash missing from /etc/shells warns, never edits it" {
    printf '/bin/sh\n' >"$_DOT_SHELLS_FILE"
    probe '_bash_use_as_shell alice'
    assert_eq 'rc 0 (degraded)' '0' "$status"
    assert_contains 'warns' 'not listed in /etc/shells' "$output"
    assert_contains 'gives the command' 'sudo tee -a /etc/shells' "$output"
    assert_eq 'no chsh' '' "$(cat "$CALLS")"
}

@test "login shell: no chsh warns with the usermod alternative" {
    probe '
        command() { [[ "$1 $2" == "-v getent" || "$1 $2" == "-v chsh" ]] && return 1; builtin command "$@"; }
        _bash_use_as_shell alice
    '
    assert_eq 'rc 0 (degraded)' '0' "$status"
    assert_contains 'usermod hint' "usermod -s $(command -v bash) alice" "$output"
    assert_eq 'no privileged call' '' "$(cat "$CALLS")"
}

@test "login shell: a stale /etc/shells entry is skipped" {
    printf '/nonexistent/bin/bash\n%s\n' "$(command -v bash)" >"$_DOT_SHELLS_FILE"
    probe '_bash_use_as_shell alice'
    assert_eq 'picks the executable one' "PRIV:chsh -s $(command -v bash) alice" "$(cat "$CALLS")"
}
