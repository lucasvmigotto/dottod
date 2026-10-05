#!/usr/bin/env bash
# codes — interactive project switcher (successor of `ccd`)
#
#   codes               fzf picker of every git project, newest activity first,
#                       with a git status column (branch, dirty, ahead/behind, stash)
#   codes <name>        jump to a project; typos are corrected by edit distance
#   codes -l [name]     print the table instead of cd-ing
#   codes -p [name]     print the chosen path instead of cd-ing (for scripts)
#   codes -f            `git fetch` every project first (so ⇣ behind is fresh)
#   codes -i <name>     never auto-jump; always open the picker
#
# Source it from ~/.bashrc:   source ~/codes.sh
# Requires: bash, git, find, awk, sort, xargs; fzf for the interactive picker.
#
# Config (environment variables):
#   CODES_ROOTS          colon-separated dirs to scan  (default: ~/code:~/projects:~/src:~/dev:~/work)
#   CODES_DEPTH          how deep below each root to look for repos (default 3)
#   CODES_JOBS           parallel git workers (default 8)
#   CODES_CONFIRM_FUZZY  1 = typo-corrected matches open the picker instead of auto-jumping

[[ $- != *i* ]] && return 0 2>/dev/null

# ──────────────────────────────────────────────────────────────
# Discovery
# ──────────────────────────────────────────────────────────────

__codes_roots() {
    local r IFS=:
    for r in ${CODES_ROOTS:-$HOME/codes:$HOME/code:$HOME/projects:$HOME/src:$HOME/dev:$HOME/work}; do
        r=${r%/}
        [[ -d $r ]] && printf '%s\n' "$r"
    done
}

# One path per git working tree (.git dir *or* file, so worktrees count).
# Nested repos (submodules, vendored clones) below an already-found repo are dropped.
__codes_find() {
    local depth=${CODES_DEPTH:-3} r
    local -a roots=()
    while IFS= read -r r; do roots+=("$r"); done < <(__codes_roots)
    (( ${#roots[@]} )) || return 1

    find "${roots[@]}" -maxdepth "$((depth + 1))" \
            \( -name node_modules -o -name .venv -o -name venv -o -name .cache \
               -o -name site-packages -o -name .tox \) -prune -o \
            -name .git -prune -print 2>/dev/null \
        | sed 's|/\.git$||' \
        | awk '
            { p[NR] = $0; s[$0] = 1 }
            END {
                for (i = 1; i <= NR; i++) {
                    x = p[i]; skip = 0
                    while (sub(/\/[^\/]*$/, "", x) && x != "")
                        if (x in s) { skip = 1; break }
                    if (!skip && !seen[p[i]]++) print p[i]
                }
            }'
}

# ──────────────────────────────────────────────────────────────
# Fuzzy matching: tiers + edit distance
#   kind 0 exact | 1 prefix | 2 substring | 3 typo (approximate substring)
# Only candidates of the best kind present are emitted:  kind ds df path
#   ds = distance to the best-matching substring of the name (Sellers)
#   df = distance to the whole name (tie-breaker: prefers shorter names)
# Distance is optimal-string-alignment Damerau–Levenshtein, i.e. Levenshtein
# where swapping two adjacent characters ("pjoect") costs 1 instead of 2.
# ──────────────────────────────────────────────────────────────
__codes_match() {
    awk -v query="$1" '
    function osa(q, n, approx,    lq, ln, i, j, cost, t, qi, nj, best) {
        lq = length(q); ln = length(n)
        for (j = 0; j <= ln; j++) A[j] = approx ? 0 : j      # row 0
        for (i = 1; i <= lq; i++) {
            C[0] = i
            qi = substr(q, i, 1)
            for (j = 1; j <= ln; j++) {
                nj = substr(n, j, 1)
                cost = (qi == nj) ? 0 : 1
                t = A[j - 1] + cost                           # substitute / match
                if (A[j] + 1 < t)     t = A[j] + 1            # drop a query char
                if (C[j - 1] + 1 < t) t = C[j - 1] + 1        # extra char in name
                if (i > 1 && j > 1 && qi == substr(n, j - 1, 1) \
                    && substr(q, i - 1, 1) == nj && B[j - 2] + 1 < t)
                    t = B[j - 2] + 1                          # adjacent transposition
                C[j] = t
            }
            for (j = 0; j <= ln; j++) { B[j] = A[j]; A[j] = C[j] }
        }
        if (!approx) return A[ln]
        best = A[0]
        for (j = 1; j <= ln; j++) if (A[j] < best) best = A[j]
        return best
    }
    BEGIN { q = tolower(query); lq = length(q); t = int(lq / 3); if (t > 3) t = 3; best = 9 }
    {
        p = $0; n = p; sub(/.*\//, "", n); n = tolower(n)
        if (n == q)               { k = 0; ds = 0; df = 0 }
        else if (index(n, q) == 1) { k = 1; ds = 0; df = length(n) - lq }
        else if (index(n, q) > 0)  { k = 2; ds = 0; df = length(n) - lq }
        else {
            if (t == 0) next                                  # too short to guess
            ds = osa(q, n, 1); if (ds > t) next
            k = 3; df = osa(q, n, 0)
        }
        if (k < best) { best = k; cnt = 0 }
        if (k == best) { cnt++; K[cnt] = k; S[cnt] = ds; F[cnt] = df; P[cnt] = p }
    }
    END { for (i = 1; i <= cnt; i++) printf "%d\t%d\t%d\t%s\n", K[i], S[i], F[i], P[i] }
    ' | sort -s -t $'\t' -k2,2n -k3,3n
}

# ──────────────────────────────────────────────────────────────
# Per-repo info (runs in parallel workers; must stay self-contained)
# args: <stat flavor: gnu|bsd> <fetch: 0|1> <path>
# out : ts path head oid upstream has_ab ahead behind staged unstaged untracked conflicts stash
# ──────────────────────────────────────────────────────────────
__codes_info() {
    local flavor=$1 fetch=$2 p=$3 tm="" gd ts m stash=0 summary
    command -v timeout >/dev/null 2>&1 && tm="timeout 8"
    # Never take index.lock: avoids fighting your editor and keeps .git/index's
    # mtime meaningful (a refreshing `git status` would bump it and ruin the sort).
    export GIT_OPTIONAL_LOCKS=0

    gd=$(git -C "$p" rev-parse --absolute-git-dir 2>/dev/null) || return 0

    if [[ $fetch == 1 ]]; then
        GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes -o ConnectTimeout=5" \
            ${tm:+timeout 20} git -C "$p" fetch --quiet --prune >/dev/null 2>&1
    fi

    # last activity = newest of: HEAD commit, .git/index, .git/HEAD
    ts=$(git -C "$p" log -1 --format=%ct 2>/dev/null); ts=${ts:-0}
    while read -r m; do
        (( m > ts )) && ts=$m
    done < <(
        if [[ $flavor == gnu ]]; then stat -c %Y -- "$gd/index" "$gd/HEAD" 2>/dev/null
        else stat -f %m "$gd/index" "$gd/HEAD" 2>/dev/null; fi
    )

    [[ -s $gd/logs/refs/stash ]] && stash=$(wc -l <"$gd/logs/refs/stash")
    stash=${stash//[[:space:]]/}

    summary=$($tm git -C "$p" status --porcelain=v2 --branch --untracked-files=normal 2>/dev/null \
        | awk '
            /^# branch.oid/      { oid = $3 }
            /^# branch.head/     { head = $3 }
            /^# branch.upstream/ { up = $3 }
            /^# branch.ab/       { hasab = 1; a = $3; b = $4; sub(/^\+/, "", a); sub(/^-/, "", b); ahead = a; behind = b }
            /^[12] /             { x = substr($2, 1, 1); y = substr($2, 2, 1); if (x != ".") st++; if (y != ".") un++ }
            /^u /                { cf++ }
            /^\? /               { ut++ }
            END { printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", head, oid, up, hasab + 0, ahead + 0, behind + 0, st + 0, un + 0, ut + 0, cf + 0 }')

    printf '%s\t%s\t%s\t%s\n' "$ts" "$p" "$summary" "${stash:-0}"
}

# ──────────────────────────────────────────────────────────────
# Table: stdin = paths, stdout = "path<TAB>display" sorted by activity desc
# ──────────────────────────────────────────────────────────────
__codes_table() {
    local fetch=${1:-0} flavor=bsd fn visits
    stat -c %Y / >/dev/null 2>&1 && flavor=gnu
    visits=${XDG_STATE_HOME:-$HOME/.local/state}/codes/visits
    fn=$(declare -f __codes_info)

    tr '\n' '\0' \
        | xargs -0 -r -n1 -P "${CODES_JOBS:-8}" bash -c "$fn"'; __codes_info "$@"' _ "$flavor" "$fetch" \
        | awk -F'\t' -v OFS='\t' -v visits="$visits" '
            BEGIN {
                while ((getline l < visits) > 0) {
                    n = split(l, a, "\t")
                    if (n >= 2 && a[1] + 0 > v[a[2]] + 0) v[a[2]] = a[1]
                }
                close(visits)
            }
            { if (($2 in v) && v[$2] + 0 > $1 + 0) $1 = v[$2]; print }' \
        | sort -t $'\t' -k1,1nr \
        | awk -F'\t' -v now="$(date +%s)" -v home="$HOME" '
            BEGIN {
                E = sprintf("%c", 27)
                R = E "[0m"; B = E "[1m"; D = E "[2m"
                RED = E "[31m"; GRN = E "[32m"; YEL = E "[33m"
                BLU = E "[34m"; MAG = E "[35m"; CYN = E "[36m"
            }
            function trunc(s, w) { return length(s) > w ? substr(s, 1, w - 1) "…" : s }
            function pad(s, w,    n) { n = w - length(s); while (n-- > 0) s = s " "; return s }
            function seg(t, c) {
                plain = plain (plain == "" ? "" : " ") t
                col   = col   (col   == "" ? "" : " ") c t R
            }
            function age(ts,    d) {
                d = now - ts
                if (d < 60)       return "now"
                if (d < 3600)     return int(d / 60) "m"
                if (d < 86400)    return int(d / 3600) "h"
                if (d < 2592000)  return int(d / 86400) "d"
                if (d < 31536000) return int(d / 2592000) "mo"
                return int(d / 31536000) "y"
            }
            {
                path = $2; name = path; sub(/.*\//, "", name)
                dir = path; sub(/\/[^\/]*$/, "", dir)
                if (home != "" && index(dir, home) == 1) dir = "~" substr(dir, length(home) + 1)
                head = $3; oid = $4; up = $5; hasab = $6; ah = $7; bh = $8
                st = $9; un = $10; ut = $11; cf = $12; sh = $13
                br = head
                if (head == "(detached)") br = "@" substr(oid, 1, 7)
                if (head == "") br = "?"

                plain = ""; col = ""
                if (head == "") seg("git-error", RED)
                else {
                    if (cf > 0) seg("✖" cf, RED B)
                    if (st > 0) seg("+" st, GRN)
                    if (un > 0) seg("!" un, YEL)
                    if (ut > 0) seg("?" ut, CYN)
                    if (cf + st + un + ut == 0) seg("✔", GRN)
                    if (up == "")            seg("local", D)       # no upstream configured
                    else if (hasab + 0 == 0) seg("gone", RED)      # upstream branch deleted
                    else {
                        if (ah > 0) seg("⇡" ah, BLU)               # unpushed commits
                        if (bh > 0) seg("⇣" bh, MAG)               # upstream has new commits
                    }
                    if (sh > 0) seg("*" sh, D)
                }

                N++
                pt[N] = path; nm[N] = trunc(name, 32); bn[N] = trunc(br, 24)
                ag[N] = age($1); sp[N] = plain; sc[N] = col; dr[N] = dir
                if (length(nm[N]) > wn) wn = length(nm[N])
                if (length(bn[N]) > wb) wb = length(bn[N])
                if (length(ag[N]) > wa) wa = length(ag[N])
                if (length(plain)  > ws) ws = length(plain)
            }
            END {
                for (i = 1; i <= N; i++) {
                    fill = ""; for (k = length(sp[i]); k < ws; k++) fill = fill " "
                    printf "%s\t%s  %s  %s  %s%s  %s\n", pt[i],
                        B pad(nm[i], wn) R, MAG pad(bn[i], wb) R, D pad(ag[i], wa) R,
                        sc[i], fill, D dr[i] R
                }
            }'
}

# ──────────────────────────────────────────────────────────────
# Visit log: cd-ing through `codes` counts as activity (captures edits that
# never touch .git, e.g. a long uncommitted session)
# ──────────────────────────────────────────────────────────────
__codes_visit() {
    local f=${XDG_STATE_HOME:-$HOME/.local/state}/codes/visits tmp
    mkdir -p -- "${f%/*}" 2>/dev/null || return 0
    printf '%s\t%s\n' "$(date +%s)" "$1" >>"$f"
    if [[ $(wc -l <"$f") -gt 1000 ]]; then
        tmp=$(mktemp) \
            && awk -F'\t' '{ l[$2] = $0 } END { for (k in l) print l[k] }' "$f" >"$tmp" \
            && mv -- "$tmp" "$f"
    fi
}

__codes_usage() {
    cat <<'EOF'
usage: codes [options] [name]

  codes            pick a project (fzf), sorted by last activity, with git status
  codes <name>     jump to <name>; exact > prefix > substring > typo-tolerant match
                   (ambiguous results open the picker restricted to the candidates)

options:
  -l, --list         print the table instead of cd-ing
  -p, --path         print the selected path instead of cd-ing
  -f, --fetch        git fetch all projects first (fresh ⇣ behind counts)
  -i, --interactive  never auto-jump; always open the picker
  -h, --help         this help

status legend:
  ✔ clean   +N staged   !N modified   ?N untracked   ✖N conflicts
  ⇡N unpushed commits   ⇣N upstream commits not pulled   *N stashes
  local = branch has no upstream   gone = upstream branch was deleted
EOF
}

# ──────────────────────────────────────────────────────────────
# codes
# ──────────────────────────────────────────────────────────────
codes() {
    local list=0 printpath=0 fetch=0 always=0
    local -a args=()
    while (( $# )); do
        case $1 in
            -l|--list)        list=1 ;;
            -p|--path)        printpath=1 ;;
            -f|--fetch)       fetch=1 ;;
            -i|--interactive) always=1 ;;
            -h|--help)        __codes_usage; return 0 ;;
            --)               shift; args+=("$@"); break ;;
            -*)               echo "codes: unknown option '$1'" >&2; return 2 ;;
            *)                args+=("$1") ;;
        esac
        shift
    done
    local query="${args[*]}"
    (( list )) && always=1

    local d
    for d in git awk find xargs sort; do
        command -v "$d" >/dev/null 2>&1 || { echo "codes: '$d' is required but not on PATH" >&2; return 1; }
    done
    if (( ! list )); then
        command -v fzf >/dev/null 2>&1 || [[ -n $query ]] \
            || { echo "codes: 'fzf' is required for the interactive picker" >&2; return 1; }
    fi

    local line
    local -a all=()
    while IFS= read -r line; do all+=("$line"); done < <(__codes_find)
    if (( ${#all[@]} == 0 )); then
        echo "codes: no git projects found (roots: $(__codes_roots | paste -sd: -)); set CODES_ROOTS" >&2
        return 1
    fi

    local picked=""
    local -a pool=("${all[@]}")

    if [[ -n $query ]]; then
        # explicit path -> go straight there
        if [[ $query == */* || $query == . || $query == .. ]] && [[ -d $query ]]; then
            picked=$(cd -- "$query" && pwd)
        else
            local -a cand=()
            while IFS= read -r line; do cand+=("$line"); done < <(printf '%s\n' "${all[@]}" | __codes_match "$query")

            if (( ${#cand[@]} == 0 )); then
                echo "codes: no project resembles '$query' — showing everything" >&2
            else
                local k1 s1 p1 k2 s2 auto=0
                IFS=$'\t' read -r k1 s1 _ p1 <<<"${cand[0]}"
                if (( ${#cand[@]} == 1 )); then
                    auto=1
                else
                    IFS=$'\t' read -r k2 s2 _ _ <<<"${cand[1]}"
                    # typo tier: jump only if the best candidate is strictly closer than the runner-up
                    (( k1 == 3 && s1 < s2 )) && auto=1
                    # exact/prefix/substring tiers with several hits are ambiguous -> picker
                fi
                (( always )) && auto=0
                [[ $k1 == 3 && ${CODES_CONFIRM_FUZZY:-0} == 1 ]] && auto=0

                if (( auto )); then
                    picked=$p1
                    [[ $k1 == 3 ]] && echo "codes: '$query' → ${p1##*/}  (edit distance $s1)" >&2
                else
                    pool=()
                    for line in "${cand[@]}"; do pool+=("${line#*$'\t'*$'\t'*$'\t'}"); done
                fi
            fi
        fi
    fi

    if [[ -z $picked ]]; then
        local table
        table=$(printf '%s\n' "${pool[@]}" | __codes_table "$fetch")
        if (( list )); then
            if [[ -t 1 ]]; then printf '%s\n' "$table" | cut -f2-
            else printf '%s\n' "$table" | cut -f2- | sed $'s/\033\\[[0-9;]*m//g'; fi
            return 0
        fi
        picked=$(printf '%s\n' "$table" \
            | fzf --ansi --delimiter=$'\t' --with-nth=2 --tiebreak=index \
                  --height=70% --layout=reverse --border \
                  --prompt='codes> ' \
                  --header=$'enter: cd   ctrl-/: preview   esc: cancel\n+staged !modified ?untracked ✖conflict ⇡unpushed ⇣behind *stash  local=no upstream' \
                  --preview='git -C {1} -c color.status=always status -sb; echo; git -C {1} log -n 12 --oneline --decorate --color=always' \
                  --preview-window='right,45%,border-left,<110(down,40%,border-top)' \
                  --bind='ctrl-/:toggle-preview' \
            | cut -f1)
        [[ -z $picked ]] && return 130
    fi

    __codes_visit "$picked"
    if (( printpath )); then
        printf '%s\n' "$picked"
    else
        cd -- "$picked"
    fi
}

# Tab completion: project names + flags
_codes() {
    local cur=${COMP_WORDS[COMP_CWORD]} line
    COMPREPLY=()
    if [[ $cur == -* ]]; then
        while IFS= read -r line; do COMPREPLY+=("$line"); done \
            < <(compgen -W "-l --list -p --path -f --fetch -i --interactive -h --help" -- "$cur")
        return
    fi
    while IFS= read -r line; do COMPREPLY+=("$line"); done \
        < <(compgen -W "$(__codes_find | awk -F/ '{ print $NF }')" -- "$cur")
}
complete -F _codes codes
