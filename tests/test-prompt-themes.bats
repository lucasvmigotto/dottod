#!/usr/bin/env bats
#
# test-prompt-themes.bats — styles/segments.sh and the segmented themes
# (spec 018): rendering, folding, the cached stack versions and container
# count (refreshed in the background, stubbed toolchains and podman), and
# silence when anything fails.

load helpers

THEMES=(pastel tokyonight gruvbox catppuccin)

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$HOME"
    unset DOT_PROMPT_VERSIONS DOT_PROMPT_CONTAINERS DOT_PROMPT_GLYPHS DOT_PROMPT_SLOW
    # Stub bin first on PATH: podman and toolchains only when a test adds them.
    export STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"
    export PATH="$STUBS:$PATH"

    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/src"
    git -C "$PROJ" init -q -b main
    git -C "$PROJ" config user.email t@t
    git -C "$PROJ" config user.name t
    git -C "$PROJ" commit -q --allow-empty -m init
    OUTSIDE="$BATS_TEST_TMPDIR/plain"
    mkdir -p "$OUTSIDE"
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

# Renders <theme> in <dir>: stdout is the expanded prompt, stderr whatever
# the prompt printed (must stay empty).
render() {
    local theme="$1" dir="$2" script="$BATS_TEST_TMPDIR/render.sh"
    cat >"$script" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
exec 2>"$BATS_TEST_TMPDIR/prompt.err"
${PROMPT_COMMAND%%;*}
printf '%s' "${PS1@P}"
SH
    (cd "$dir" && DOT_PROMPT_STYLE="$theme" bash -i "$script" 2>/dev/null)
}

# Raw PS1 (unexpanded) of <theme> in <dir>.
raw_ps1() {
    local theme="$1" dir="$2" script="$BATS_TEST_TMPDIR/raw.sh"
    cat >"$script" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
${PROMPT_COMMAND%%;*}
printf '%s' "$PS1"
SH
    (cd "$dir" && DOT_PROMPT_STYLE="$theme" bash -i "$script" 2>/dev/null)
}

# Waits up to 5s for a background refresh to write <file>.
wait_for() {
    local i
    for ((i = 0; i < 50; i++)); do
        [[ -s "$1" && ! -e "$1.lock" ]] && return 0
        sleep 0.1
    done
    printf 'FAIL: %s never written\n' "$1" >&2
    return 1
}

no_stderr() {
    if [[ -s "$BATS_TEST_TMPDIR/prompt.err" ]]; then
        printf 'FAIL: the prompt printed to stderr:\n%s\n' "$(cat "$BATS_TEST_TMPDIR/prompt.err")" >&2
        return 1
    fi
}

@test "every theme renders user, project, branch and stack in a repo" {
    touch "$PROJ/package.json"
    local t out
    for t in "${THEMES[@]}"; do
        out="$(render "$t" "$PROJ/src")"
        assert_contains "$t project" 'proj/src' "$out"
        assert_contains "$t branch" 'main' "$out"
        assert_contains "$t node glyph" $'' "$out"
        assert_contains "$t time" "$(date +%H:)" "$out"
        assert_contains "$t prompt char" '❯' "$out"
        no_stderr
    done
}

@test "outside a repo the git, stack and container segments fold to one separator each" {
    local t out segs seg bg fg next i sep
    for t in "${THEMES[@]}"; do
        out="$(raw_ps1 "$t" "$OUTSIDE")"
        segs="$(sed -n "s/^__DOTTOD_THEME_SEGS='\(.*\)'$/\1/p" "$REPO_ROOT/styles/prompt-$t.sh")"
        sep="$(sed -n "s/^__DOTTOD_THEME_SEP='\(.*\)'$/\1/p" "$REPO_ROOT/styles/prompt-$t.sh")"
        [[ "$sep" == round ]] && sep=$'' || sep=$''
        read -ra list <<<"$segs"
        for ((i = 0; i < ${#list[@]}; i++)); do
            IFS=: read -r seg bg fg <<<"${list[i]}"
            [[ "$seg" == git || "$seg" == stack || "$seg" == containers ]] || continue
            next="${list[i + 1]#*:}"
            next="${next%%:*}"
            # Its colors, then straight away its separator: no text between.
            assert_contains "$t folds $seg" \
                "\\[\\e[48;5;${bg}m\\e[38;5;${fg}m\\]\\[\\e[48;5;${next}m\\e[38;5;${bg}m\\]${sep}" "$out"
        done
        assert_contains "$t still ends with time" '\A' "$out"
    done
}

@test "ASCII glyphs: a folded segment is one colored space" {
    local out
    out="$(DOT_PROMPT_GLYPHS=ascii raw_ps1 pastel "$OUTSIDE")"
    assert_contains 'folded git is a space' '\[\e[48;5;216m\e[38;5;16m\] \[\e[48;5;110m' "$out"
}

@test "stacks: all markers of the nearest directory, bun over node" {
    touch "$PROJ/package.json" "$PROJ/bun.lock" "$PROJ/pyproject.toml" "$PROJ/x.csproj"
    local out
    out="$(render catppuccin "$PROJ")"
    assert_contains 'bun' $'' "$out"
    assert_contains 'python' $'' "$out"
    assert_contains 'dotnet' $'' "$out"
    if [[ "$out" == *$''* ]]; then
        printf 'FAIL: node shown next to bun\n' >&2
        return 1
    fi
}

@test "versions are opt-in, cached and filled in the background" {
    touch "$PROJ/package.json"
    stub node 'echo v22.11.0'
    local out
    out="$(render pastel "$PROJ")"
    if [[ "$out" == *v22.11.0* ]]; then
        printf 'FAIL: version shown without DOT_PROMPT_VERSIONS\n' >&2
        return 1
    fi
    export DOT_PROMPT_VERSIONS=1
    out="$(render pastel "$PROJ")"
    if [[ "$out" == *v22.11.0* ]]; then
        printf 'FAIL: first prompt waited for the version\n' >&2
        return 1
    fi
    # The refresh may still hold its .lock: name the cache file, not the lock.
    local cached
    cached="$(ls "$XDG_CACHE_HOME"/dottod/prompt/version-node-* | head -n 1)"
    wait_for "${cached%.lock}"
    out="$(render pastel "$PROJ")"
    assert_contains 'version after refresh' 'v22.11.0' "$out"
    no_stderr
}

@test "versions from each toolchain's own output format" {
    local row stack cmd line want
    for row in "rust|rustc|rustc 1.82.0 (f6e511eec 2024-10-15)|1.82.0" \
        "go|go|go version go1.23.2 linux/amd64|1.23.2" \
        "python|python3|Python 3.13.0|3.13.0" \
        "java|java|openjdk version \"21.0.5\" 2024-10-15|21.0.5" \
        "deno|deno|deno 2.1.4 (stable, release, x86_64-unknown-linux-gnu)|2.1.4" \
        "php|php|PHP 8.3.6 (cli) (built: Apr 15 2024)|8.3.6"; do
        IFS='|' read -r stack cmd line want <<<"$row"
        stub "$cmd" "printf '%s\\n' '${line}' >&2; printf '%s\\n' '${line}'"
        assert_eq "$stack version" "$want" \
            "$(bash -c "source '$REPO_ROOT/styles/segments.sh'; __dottod_seg_version_probe $stack '$PROJ'" 2>/dev/null)"
    done
}

@test "containers: counted when their compose or devcontainer folder holds this directory" {
    stub podman "printf '%s\n' '$PROJ|' '|$PROJ/src' '/elsewhere|' '|' '${PROJ}2|' '$PROJ/src/deeper|'"
    local out
    out="$(render gruvbox "$PROJ/src")"
    if [[ "$out" == *$''* ]]; then
        printf 'FAIL: first prompt waited for podman\n' >&2
        return 1
    fi
    wait_for "$XDG_CACHE_HOME/dottod/prompt/containers"
    out="$(render gruvbox "$PROJ/src")"
    assert_contains 'project and src belong here' $'\uf4b7 2' "$out"
    out="$(render gruvbox "$BATS_TEST_TMPDIR")"
    if [[ "$out" == *$'\uf4b7'* ]]; then
        printf 'FAIL: a parent directory claims the containers below it\n' >&2
        return 1
    fi
    DOT_PROMPT_CONTAINERS=0 run render gruvbox "$PROJ"
    if [[ "$output" == *$''* ]]; then
        printf 'FAIL: DOT_PROMPT_CONTAINERS=0 still shows containers\n' >&2
        return 1
    fi
    no_stderr
}

@test "a failing podman or toolchain, or an unwritable cache, never shows" {
    touch "$PROJ/package.json"
    stub podman 'echo "podman exploded" >&2; exit 125'
    stub node 'echo "node exploded" >&2; exit 1'
    export DOT_PROMPT_VERSIONS=1
    render tokyonight "$PROJ" >/dev/null
    sleep 1
    local out
    out="$(render tokyonight "$PROJ")"
    no_stderr
    assert_contains 'still renders' 'proj' "$out"
    if [[ "$out" == *exploded* || "$out" == *$''* ]]; then
        printf 'FAIL: a failure leaked into the prompt\n' >&2
        return 1
    fi
    export XDG_CACHE_HOME=/proc/dottod-no-cache
    out="$(render tokyonight "$PROJ")"
    no_stderr
    assert_contains 'renders without a cache' 'proj' "$out"
}

@test "PS0 stamps a command's start; a slow one shows its duration" {
    local script="$BATS_TEST_TMPDIR/dur.sh" out
    cat >"$script" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
x="${PS0@P}"
[[ -z "$x" ]] || echo "PS0 printed: $x"
[[ -n "${__dottod_seg_t0:-}" ]] || echo "PS0 did not stamp"
__dottod_seg_t0=$((SECONDS - 7))
${PROMPT_COMMAND%%;*}
printf '%s\n' "${PS1@P}"
${PROMPT_COMMAND%%;*}
printf '%s\n' "${PS1@P}"
SH
    out="$(cd "$PROJ" && DOT_PROMPT_STYLE=pastel bash -i "$script" 2>/dev/null)"
    assert_eq 'PS0 silent and stamping' '0' "$(grep -c 'PS0' <<<"$out" || true)"
    # 7s, or 8s when SECONDS ticks between the stamp and the render.
    assert_eq 'duration shown once' '1' "$(grep -cE 'took [78]s' <<<"$out" || true)"
}

@test "a red prompt character after a failure" {
    local script="$BATS_TEST_TMPDIR/fail.sh"
    cat >"$script" <<'SH'
source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
false
${PROMPT_COMMAND%%;*}
printf '%s' "$PS1"
SH
    run bash -c "cd '$PROJ' && DOT_PROMPT_STYLE=catppuccin bash -i '$script' 2>/dev/null"
    assert_contains 'red' '\[\e[1;31m\]❯' "$output"
}

@test "switching between themes and the older styles replaces the hook" {
    local script="$BATS_TEST_TMPDIR/switch.sh" out
    cat >"$script" <<'SH'
for s in pastel powerline gruvbox kali tokyonight robbyrussell catppuccin; do
    DOT_PROMPT_STYLE=$s
    source "$REPO_ROOT/config/.custom.bashrc" >/dev/null 2>&1
done
printf '%s\n' "$PROMPT_COMMAND"
SH
    out="$(cd "$PROJ" && bash -i "$script" 2>/dev/null)"
    assert_eq 'one segments hook' '1' "$(grep -o '__dottod_prompt_segments' <<<"$out" | wc -l | tr -d ' ')"
    assert_eq 'no older hooks' '0' "$(grep -cE '__dottod_prompt(_powerline|_kali)?(;|$)' <<<"$out" || true)"
}

@test "branch and directory names never run as commands in the themes" {
    local sub="$PROJ/"'d$(touch${IFS}PWNED)`touch${IFS}PWNED`' t out
    mkdir -p "$sub"
    git -C "$PROJ" checkout -q -b 'x$(touch${IFS}PWNED)'
    for t in "${THEMES[@]}"; do
        out="$(render "$t" "$sub")"
        if [[ -e "$PROJ/PWNED" || -e "$sub/PWNED" ]]; then
            printf 'FAIL: %s ran a command from a name\n' "$t" >&2
            return 1
        fi
        assert_contains "$t shows the branch literally" 'x$(touch${IFS}PWNED)' "$out"
        assert_contains "$t shows the directory literally" 'd$(touch${IFS}PWNED)`touch${IFS}PWNED`' "$out"
    done
}

@test "the OS glyph follows os-release" {
    printf 'ID="gentoo"\n' >"$BATS_TEST_TMPDIR/os-release"
    run env _DOT_OS_RELEASE_FILE="$BATS_TEST_TMPDIR/os-release" bash -c "source '$REPO_ROOT/styles/segments.sh'; __dottod_seg_text os /"
    assert_eq 'gentoo glyph' $'' "$output"
    printf 'ID=nixos\n' >"$BATS_TEST_TMPDIR/os-release"
    run env _DOT_OS_RELEASE_FILE="$BATS_TEST_TMPDIR/os-release" bash -c "source '$REPO_ROOT/styles/segments.sh'; __dottod_seg_text os /"
    assert_eq 'unknown: tux' $'' "$output"
}
