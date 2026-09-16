#!/usr/bin/env bats
#
# test-ssh-merge.bats — tests for the GitHub SSH merge in bin/ssh.sh.
# Every case uses fresh temporary directories; the real user ~/.ssh is
# never touched. OpenSSH parsing is validated with `ssh -G -F` (no network).

load helpers

setup() {
    FIX="$BATS_TEST_TMPDIR/fix"
    mkdir -p "$FIX"
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    TEMPLATE="$REPO_ROOT/config/.ssh.config"
    unset _DOT_SSH_DIR
    # shellcheck disable=SC1091
    source "$REPO_ROOT/bin/ssh.sh"
    # The library enables `set -u`; drop it so the framework teardown
    # never trips on an unset variable.
    set +u
}

fresh_target() {
    local d
    d="$(mktemp -d -p "$FIX")"
    printf '%s' "$d/config"
}

@test "template is the single source of truth" {
    mapfile -t want < <(_github_wanted_options "$TEMPLATE")
    assert_eq 'template yields 6 options' '6' "${#want[@]}"
    assert_eq 'template key order' \
        "$(printf 'HostName\tgithub.com\nUser\tgit\nIdentityFile\t~/.ssh/github\nIdentitiesOnly\tyes\nAddKeysToAgent\tyes\nLogLevel\tVERBOSE')" \
        "$(printf '%s\n' "${want[@]}")"
}

@test "case A: missing config is installed verbatim" {
    T="$(fresh_target)"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'case A matches template' "$(cat "$TEMPLATE")" "$(cat "$T")"
    assert_eq 'case A mode 600' '600' "$(stat -c %a "$T")"
    assert_eq 'case A no backup' '0' "$([[ -e "$T.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "case B: unrelated config preserved, block appended once" {
    T="$(fresh_target)"
    printf 'Host myserver\n    HostName example.com\n    User me\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_contains 'unrelated host kept' 'Host myserver' "$(cat "$T")"
    assert_contains 'unrelated value kept' 'HostName example.com' "$(cat "$T")"
    assert_contains 'github block added' 'Host github.com' "$(cat "$T")"
    assert_contains 'github user added' 'User git' "$(cat "$T")"
    assert_eq 'backup created' '1' "$([[ -e "$T.dottod.bak" ]] && echo 1 || echo 0)"
    assert_eq 'backup holds original' 'Host myserver' "$(head -n1 "$T.dottod.bak")"
    before="$(cat "$T")"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'second run byte-identical' "$before" "$(cat "$T")"
    assert_eq 'single Host github.com' '1' "$(grep -ci '^Host github.com' "$T")"
}

@test "complete block is untouched without backup" {
    T="$(fresh_target)"
    cp "$TEMPLATE" "$T"
    chmod 600 "$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'complete block unchanged' "$(cat "$TEMPLATE")" "$(cat "$T")"
    assert_eq 'complete block no backup' '0' "$([[ -e "$T.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "partial block gains only the missing keys" {
    T="$(fresh_target)"
    printf 'Host github.com\n    HostName github.com\n    User git\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'partial gets 4 missing keys' '7' "$(wc -l <"$T")"
    assert_contains 'identity added' 'IdentityFile ~/.ssh/github' "$(cat "$T")"
    assert_contains 'agent added' 'AddKeysToAgent yes' "$(cat "$T")"
}

@test "conflicting user values are never overwritten" {
    T="$(fresh_target)"
    printf 'Host github.com\n    HostName github.com\n    User deploy\n    IdentityFile ~/.ssh/id_rsa\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_contains 'user value preserved' 'User deploy' "$(cat "$T")"
    assert_eq 'user not duplicated' '1' "$(grep -ci '^[[:space:]]*user[[:space:]=]' "$T")"
    assert_contains 'identity value preserved' 'IdentityFile ~/.ssh/id_rsa' "$(cat "$T")"
    assert_contains 'missing still added' 'IdentitiesOnly yes' "$(cat "$T")"
}

@test "wildcard blocks are not treated as github.com" {
    T="$(fresh_target)"
    printf 'Host *\n    ForwardAgent yes\n\nHost *.example.com\n    User me\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'wildcard untouched + block appended' '1' "$(grep -ci '^Host github.com' "$T")"
    assert_contains 'wildcard kept' 'ForwardAgent yes' "$(cat "$T")"
}

@test "case-insensitive host token is recognized" {
    T="$(fresh_target)"
    printf 'HOST GitHub.COM\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/github\n    IdentitiesOnly yes\n    AddKeysToAgent yes\n    LogLevel VERBOSE\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'recognized block not duplicated' '1' "$(grep -ci '^host[[:space:]]\+github\.com$' "$T")"
    assert_eq 'no backup when complete' '0' "$([[ -e "$T.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "double-quoted complete block is recognized" {
    T="$(fresh_target)"
    printf 'Host "github.com"\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/github\n    IdentitiesOnly yes\n    AddKeysToAgent yes\n    LogLevel VERBOSE\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'quoted block not duplicated' '1' "$(grep -ci '^host[[:space:]]\+"github\.com"$' "$T")"
    assert_eq 'quoted block no backup' '0' "$([[ -e "$T.dottod.bak" ]] && echo 1 || echo 0)"
}

@test "double-quoted partial block gains missing keys" {
    T="$(fresh_target)"
    printf 'Host "github.com"\n    User git\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_contains 'quoted partial gets missing keys' 'IdentityFile ~/.ssh/github' "$(cat "$T")"
    assert_eq 'quoted partial single host line' '1' "$(grep -ci '^host[[:space:]]' "$T")"
}

@test "double-quoted wildcard still gets an appended block" {
    T="$(fresh_target)"
    printf 'Host "*.example.com"\n    User me\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'quoted wildcard gets appended block' '1' "$(grep -ci '^Host github.com' "$T")"
    assert_contains 'quoted wildcard kept' 'Host "*.example.com"' "$(cat "$T")"
}

@test "inserted keys stay inside the block before Match" {
    T="$(fresh_target)"
    printf 'Host github.com\n    User git\n\nMatch host myserver\n    ForwardAgent yes\n' >"$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    github_line="$(grep -n '^Host github.com' "$T" | cut -d: -f1)"
    match_line="$(grep -n '^Match' "$T" | cut -d: -f1)"
    ident_line="$(grep -n 'IdentityFile' "$T" | head -n1 | cut -d: -f1)"
    if (( ident_line > github_line && ident_line < match_line )); then
        return 0
    fi
    printf 'FAIL: inserted keys must stay inside block\n' >&2
    return 1
}

@test "legacy template symlink is replaced by a real file" {
    T="$(fresh_target)"
    ln -s "$TEMPLATE" "$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'legacy symlink replaced' '0' "$([[ -L "$T" ]] && echo 1 || echo 0)"
    assert_contains 'replacement has github block' 'Host github.com' "$(cat "$T")"
}

@test "user symlink elsewhere is preserved, target merged" {
    T="$(fresh_target)"
    printf 'Host myserver\n    User me\n' >"$T.real"
    ln -s "$T.real" "$T"
    _merge_github_config "$T" "$TEMPLATE" >/dev/null
    assert_eq 'user symlink kept' '1' "$([[ -L "$T" ]] && echo 1 || echo 0)"
    assert_contains 'link target merged' 'Host github.com' "$(cat "$T.real")"
}

@test "openssh accepts merged results with effective values" {
    T1="$(fresh_target)"
    printf 'Host myserver\n    User me\n' >"$T1"
    _merge_github_config "$T1" "$TEMPLATE" >/dev/null
    T2="$T1.real"
    printf 'Host myserver\n    User me\n' >"$T2"
    ln -s "$T2" "$T1.link"
    _merge_github_config "$T1.link" "$TEMPLATE" >/dev/null
    run ssh -G -F "$T1" github.com
    assert_eq 'ssh accepts plain merge' '0' "$status"
    run ssh -G -F "$T2" github.com
    assert_eq 'ssh accepts link-target merge' '0' "$status"
    eff="$(ssh -G -F "$T2" github.com 2>/dev/null)"
    assert_contains 'effective hostname' 'hostname github.com' "$eff"
    assert_contains 'effective identityfile' 'identityfile ~/.ssh/github' "$eff"
    assert_contains 'effective identitiesonly' 'identitiesonly yes' "$eff"
    # NB: `ssh -G` canonicalizes yes -> true in its output.
    assert_contains 'effective addkeystoagent' 'addkeystoagent true' "$eff"
}

@test "main end-to-end uses an isolated dir and is idempotent" {
    export _DOT_SSH_DIR="$BATS_TEST_TMPDIR/dotssh"
    _main >/dev/null
    assert_eq 'main creates config' '1' "$([[ -f "$_DOT_SSH_DIR/config" ]] && echo 1 || echo 0)"
    assert_eq 'main dir 700' '700' "$(stat -c %a "$_DOT_SSH_DIR")"
    assert_eq 'main config 600' '600' "$(stat -c %a "$_DOT_SSH_DIR/config")"
    _main >/dev/null
    assert_eq 'main idempotent' '1' "$(grep -ci '^Host github.com' "$_DOT_SSH_DIR/config")"
}
