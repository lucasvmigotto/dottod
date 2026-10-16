#!/usr/bin/env bash
# .custom.bashrc — dottod interactive bash customization (linked to ~/.bashrc).
# Prompt styles live in styles/ (robbyrussell default, kali, powerline).
# No plugins, no frameworks: plain bash only. Interactive shells only.

export EDITOR='vim'
export LANG=en_US.UTF-8

# Tool paths: prepend each once (reload-safe, no duplicates on re-source).
for _d in "${HOME}/.cargo/bin" "${HOME}/.bun/bin" "${HOME}/.local/bin"; do
    if [[ -d "${_d}" ]]; then
        case ":${PATH}:" in
            *":${_d}:"*) ;;
            *) export PATH="${_d}:${PATH}" ;;
        esac
    fi
done
unset _d

# Only for interactive shells
[[ $- != *i* ]] && return

# Prompt style (styles/prompt-<name>.sh): DOT_PROMPT_STYLE in the
# environment (this shell), else the name saved in ~/.prompt-style (every
# new shell; `prompt-style <name>` writes it), else robbyrussell. readlink
# -f follows ~/.bashrc -> repo symlink to find the checkout.
__dottod_prompt_style_file() { printf '%s' "${DOT_PROMPT_STYLE_FILE:-${HOME}/.prompt-style}"; }

# Prints "<style><TAB><where it came from>" (style possibly invalid).
__dottod_prompt_style_resolve() {
    local style="${DOT_PROMPT_STYLE:-}" file
    if [[ -n "${style}" ]]; then
        printf '%s\t%s\n' "${style}" 'DOT_PROMPT_STYLE, this shell'
        return 0
    fi
    file="$(__dottod_prompt_style_file)"
    if [[ -r "${file}" ]]; then
        IFS= read -r style <"${file}" || true
        style="${style//[[:space:]]/}"
        [[ -n "${style}" ]] && printf '%s\t%s\n' "${style}" "${file/#"${HOME}"/\~}" && return 0
    fi
    printf '%s\t%s\n' robbyrussell default
}

# A style name is a plain word with its styles/prompt-<name>.sh: a value
# read from a file must never point anywhere else.
__dottod_prompt_style_valid() {
    [[ "${1}" =~ ^[a-z0-9][a-z0-9_-]*$ && -f "${2}/styles/prompt-${1}.sh" ]]
}

if [[ -n "${BASH_SOURCE[0]:-}" ]] && command -v readlink >/dev/null 2>&1; then
    _dottod_root="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
    IFS=$'\t' read -r _dottod_style _dottod_from < <(__dottod_prompt_style_resolve)
    if ! __dottod_prompt_style_valid "${_dottod_style}" "${_dottod_root}"; then
        printf 'dottod: unknown prompt style %s (from %s), using robbyrussell; prompt-style lists them\n' "${_dottod_style}" "${_dottod_from}" >&2
        _dottod_style="robbyrussell"
    fi
    # Drop any dottod prompt hook a previous load registered, so `reload`
    # with a new DOT_PROMPT_STYLE switches styles instead of stacking them
    # (the last hook to run would otherwise keep owning PS1).
    _dottod_pc=";${PROMPT_COMMAND:-};"
    for _dottod_hook in __dottod_prompt_segments __dottod_prompt_powerline __dottod_prompt_kali __dottod_prompt; do
        _dottod_pc="${_dottod_pc//;${_dottod_hook};/;}"
    done
    _dottod_pc="${_dottod_pc#;}"
    PROMPT_COMMAND="${_dottod_pc%;}"
    unset _dottod_pc _dottod_hook
    # shellcheck disable=SC1090 # resolved relative to this file
    [[ -f "${_dottod_root}/styles/prompt-${_dottod_style}.sh" ]] && source "${_dottod_root}/styles/prompt-${_dottod_style}.sh"
    unset _dottod_style _dottod_from _dottod_root
fi

# dottod shell utilities (aliases + functions): pure definitions, silent
# on source. readlink -f follows ~/.bashrc -> repo symlink to find the
# checkout. Only the hidden scripts/.*.sh libraries — never scripts/*.sh
# (those are unguarded programs: sourcing one would execute it in this
# shell and `exit` would close it).
if [[ -n "${BASH_SOURCE[0]:-}" ]] && command -v readlink >/dev/null 2>&1; then
    _dottod_root="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
    for _dotfile in "${_dottod_root}"/scripts/.*.sh; do
        # shellcheck disable=SC1090 # resolved relative to this file
        [[ -f "${_dotfile}" ]] && source "${_dotfile}"
    done
    unset _dotfile _dottod_root
fi

# Self-update notice (scripts/.update.sh): silent unless a newer release tag
# is cached; the network refresh runs detached and never blocks startup.
if command -v _dottod_update_check >/dev/null 2>&1; then
    _dottod_update_check
fi

# ──────────────────────────────────────────────────────────────
# Shell options & history (sane interactive defaults)
# ──────────────────────────────────────────────────────────────
shopt -s histappend cmdhist checkwinsize globstar autocd cdspell 2>/dev/null
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '

# Colors for ls/grep
if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto'
else
    alias ls='ls -G' # macOS/BSD
fi
alias grep='grep --color=auto'

# ──────────────────────────────────────────────────────────────
# Aliases (handy defaults)
# ──────────────────────────────────────────────────────────────
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias lsa='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias md='mkdir -p'
alias rd='rmdir'
alias h='history'
alias hgrep='history | grep'
alias path='echo -e "${PATH//:/\\n}"'

# Git shortcuts
alias g='git'
alias gst='git status'
alias gss='git status -s'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcmsg='git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git pull'
alias gp='git push'
alias glg='git log --oneline --decorate --graph'
alias gsw='git switch'

# ──────────────────────────────────────────────────────────────
# Utility functions
# ──────────────────────────────────────────────────────────────

# mkcd: make a directory (with parents) and cd into it  (alias: take)
mkcd() {
    if [[ $# -ne 1 ]]; then
        echo "usage: mkcd <dir>" >&2
        return 1
    fi
    mkdir -p -- "$1" && cd -- "$1" || return
}
take() { mkcd "$@"; }

# up [n]: go up n directories (default 1)
up() {
    local n=${1:-1} path=""
    [[ $n =~ ^[0-9]+$ ]] || {
        echo "usage: up [n]" >&2
        return 1
    }
    while ((n-- > 0)); do path+="../"; done
    cd "${path:-.}" || return
}

# extract: unpack almost any archive. With pv installed, tar archives and
# single-file .gz/.bz2/.xz/.zst stream through it for a progress bar
# (same results: the single-file ones still replace the compressed file);
# zip, rar and 7z read their archive directly and print their own output.
extract() {
    if [[ $# -eq 0 ]]; then
        echo "usage: extract <file>..." >&2
        return 1
    fi
    local f rc=0 bar=0
    command -v pv >/dev/null 2>&1 && bar=1
    for f in "$@"; do
        if [[ ! -f $f ]]; then
            echo "extract: '$f' is not a file" >&2
            rc=1
            continue
        fi
        if ((bar)); then
            case "${f,,}" in
                *.tar.bz2 | *.tbz2) __dottod_extract_pv "$f" '' bzip2 -dc || rc=1 ;;
                *.tar.gz | *.tgz) __dottod_extract_pv "$f" '' gzip -dc || rc=1 ;;
                *.tar.xz | *.txz) __dottod_extract_pv "$f" '' xz -dc || rc=1 ;;
                *.tar.zst | *.tzst) __dottod_extract_pv "$f" '' zstd -qdc || rc=1 ;;
                *.tar) __dottod_extract_pv "$f" '' cat || rc=1 ;;
                *.bz2) __dottod_extract_pv "$f" "${f%.*}" bzip2 -dc || rc=1 ;;
                *.gz) __dottod_extract_pv "$f" "${f%.*}" gzip -dc || rc=1 ;;
                *.xz) __dottod_extract_pv "$f" "${f%.*}" xz -dc || rc=1 ;;
                *.zst) __dottod_extract_pv "$f" "${f%.*}" zstd -qdc || rc=1 ;;
                *) bar=2 ;;
            esac
            ((bar == 2)) || continue
            bar=1
        fi
        case "${f,,}" in
            *.tar.bz2 | *.tbz2) tar xjf "$f" || rc=1 ;;
            *.tar.gz | *.tgz) tar xzf "$f" || rc=1 ;;
            *.tar.xz | *.txz) tar xJf "$f" || rc=1 ;;
            *.tar.zst | *.tzst) tar --zstd -xf "$f" || rc=1 ;;
            *.tar) tar xf "$f" || rc=1 ;;
            *.bz2) bunzip2 "$f" || rc=1 ;;
            *.gz) gunzip "$f" || rc=1 ;;
            *.xz) unxz "$f" || rc=1 ;;
            *.zip | *.jar) unzip "$f" || rc=1 ;;
            *.rar) unrar x "$f" || rc=1 ;;
            *.7z) 7z x "$f" || rc=1 ;;
            *.zst) unzstd "$f" || rc=1 ;;
            *.z) uncompress "$f" || rc=1 ;;
            *)
                echo "extract: unknown archive type '$f'" >&2
                rc=1
                ;;
        esac
    done
    return "${rc}"
}

# __dottod_extract_pv <file> <out|''> <decompressor...>: <file> through pv
# and the decompressor, into tar (no <out>) or into <out>, which must not
# exist yet; the compressed file goes only once <out> is complete.
__dottod_extract_pv() {
    local f=$1 out=$2
    shift 2
    if [[ -n $out && -e $out ]]; then
        echo "extract: '$out' already exists" >&2
        return 1
    fi
    if [[ -z $out ]]; then
        pv -N "${f##*/}" -- "$f" | "$@" | tar xf -
    else
        pv -N "${f##*/}" -- "$f" | "$@" >"$out"
    fi
    local st=("${PIPESTATUS[@]}") s
    for s in "${st[@]}"; do
        ((s == 0)) && continue
        echo "extract: '$f' failed" >&2
        [[ -n $out ]] && rm -f -- "$out"
        return 1
    done
    [[ -z $out ]] || rm -f -- "$f"
}

# bak: quick timestamped backup of a file/dir
bak() {
    [[ $# -ge 1 ]] || {
        echo "usage: bak <path>..." >&2
        return 1
    }
    local p
    for p in "$@"; do
        cp -a -- "$p" "${p%/}.bak.$(date +%Y%m%d-%H%M%S)"
    done
}

# cdf: cd to the directory containing a file
cdf() { cd -- "$(dirname -- "$1")" || return; }

# ff: find files by name (case-insensitive) under cwd
ff() { find . -iname "*$1*" 2>/dev/null; }

# fd-style grep helper: search text in files (uses rg if present)
gr() {
    if command -v rg >/dev/null 2>&1; then
        rg -n --hidden -g '!.git' "$@"
    else
        grep -rnI --exclude-dir=.git "$@" .
    fi
}

# psg: search running processes
psg() { ps aux | grep -i "[${1:0:1}]${1:1}"; }

# port: what's listening on a TCP port
port() {
    [[ $# -eq 1 ]] || {
        echo "usage: port <number>" >&2
        return 1
    }
    if command -v ss >/dev/null 2>&1; then
        ss -ltnp "sport = :$1" 2>/dev/null
    else
        lsof -iTCP:"$1" -sTCP:LISTEN -n -P
    fi
}

# serve: quick static HTTP server (default port 8000)
serve() { python3 -m http.server "${1:-8000}"; }

# mkcdt: make a temp dir and cd into it
mkcdt() { cd "$(mktemp -d)" || return; }

# dirsize: sizes of items in cwd, sorted
dirsize() { du -sh -- * .[!.]* 2>/dev/null | sort -h; }

# weather-free "what's my IP"
myip() {
    curl -s https://ifconfig.me
    echo
}

# gcl: git clone and cd into the repo
gcl() {
    git clone "$@" || return
    local last="${!#}"
    last="${last%/}"
    last="${last##*/}"
    last="${last%.git}"
    [[ -d $last ]] && cd -- "$last" || return
}

# Quick reload
# shellcheck disable=SC1090 # user-local file by design
reload() { source ~/.bashrc && echo "reloaded ~/.bashrc"; }

# prompt-style [--dry-run] [name]: switch the prompt style. <name> is
# saved in ~/.prompt-style, so new shells use it too; --dry-run changes
# only this shell (DOT_PROMPT_STYLE). No name lists the styles, * marking
# the current one and where it comes from. --preview [name...] renders
# them here, in this directory, changing nothing. Styles:
# styles/prompt-*.sh.
__dottod_prompt_styles() {
    local root f name
    root="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
    for f in "${root}"/styles/prompt-*.sh; do
        [[ -f "${f}" ]] || continue
        name="${f##*/prompt-}"
        printf '%s\n' "${name%.sh}"
    done
}
# __dottod_prompt_preview <root> <name>: prints <name>'s prompt as it
# would render here — in a subshell: the style's hook runs once, PS1 is
# expanded (${PS1@P}, bash 4.4+) and nothing of this shell changes.
__dottod_prompt_preview() {
    (
        PROMPT_COMMAND=''
        # shellcheck disable=SC1090 # a validated styles/prompt-<name>.sh
        source "${1}/styles/prompt-${2}.sh" >/dev/null 2>&1 || exit 1
        true
        ${PROMPT_COMMAND%%;*} 2>/dev/null
        local out="${PS1@P}"
        out="${out//$'\001'/}"
        printf '%s\e[0m\n' "${out//$'\002'/}"
    )
}
prompt-style() {
    local dry=0 preview=0 name='' root file tmp current from
    local -a names=()
    while (($# > 0)); do
        case "${1}" in
            --dry-run) dry=1 ;;
            --preview) preview=1 ;;
            -h | --help)
                printf 'usage: prompt-style [--dry-run] [name]\n'
                printf '       prompt-style --preview [name...]\n'
                printf '  (no name)  list the styles; * marks the current one\n'
                printf '  name       use it here and in new shells (saved in %s)\n' "$(__dottod_prompt_style_file)"
                printf '  --dry-run  use it in this shell only; the saved style stays\n'
                printf '  --preview  show how each style (or the named ones) renders here\n'
                return 0
                ;;
            -*)
                printf 'prompt-style: unknown option %s\n' "${1}" >&2
                return 2
                ;;
            *)
                name="${1}"
                names+=("${1}")
                ;;
        esac
        shift
    done
    root="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"

    if ((preview)); then
        if ((dry)); then
            printf 'prompt-style: --preview changes nothing; drop --dry-run\n' >&2
            return 2
        fi
        if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
            printf 'prompt-style: --preview needs bash 4.4 or newer\n' >&2
            return 1
        fi
        if ((${#names[@]} == 0)); then
            while IFS= read -r name; do names+=("${name}"); done < <(__dottod_prompt_styles)
        fi
        IFS=$'\t' read -r current from < <(__dottod_prompt_style_resolve)
        local first=1
        for name in "${names[@]}"; do
            if ! __dottod_prompt_style_valid "${name}" "${root}"; then
                printf 'prompt-style: unknown style %s (want: %s)\n' "${name}" "$(__dottod_prompt_styles | paste -sd' ' -)" >&2
                return 1
            fi
            ((first)) || printf '\n'
            first=0
            if [[ "${name}" == "${current}" ]]; then
                printf '\e[1m* %s\e[0m  (current, %s)\n' "${name}" "${from}"
            else
                printf '\e[1m  %s\e[0m\n' "${name}"
            fi
            __dottod_prompt_preview "${root}" "${name}"
        done
        return 0
    fi

    if [[ -z "${name}" ]]; then
        IFS=$'\t' read -r current from < <(__dottod_prompt_style_resolve)
        while IFS= read -r name; do
            if [[ "${name}" == "${current}" ]]; then
                printf '* %s  (%s)\n' "${name}" "${from}"
            else
                printf '  %s\n' "${name}"
            fi
        done < <(__dottod_prompt_styles)
        return 0
    fi
    if ! __dottod_prompt_style_valid "${name}" "${root}"; then
        printf 'prompt-style: unknown style %s (want: %s)\n' "${name}" "$(__dottod_prompt_styles | paste -sd' ' -)" >&2
        return 1
    fi

    if ((dry)); then
        export DOT_PROMPT_STYLE="${name}"
    else
        file="$(__dottod_prompt_style_file)"
        tmp="${file}.$$"
        if ! { printf '%s\n' "${name}" >"${tmp}" && mv -f "${tmp}" "${file}"; }; then
            rm -f "${tmp}"
            printf 'prompt-style: could not write %s\n' "${file}" >&2
            return 1
        fi
        # The saved style applies here too: drop a this-shell override.
        unset DOT_PROMPT_STYLE
    fi
    # shellcheck disable=SC1091 # the checkout's own bashrc
    source "${root}/config/.custom.bashrc"
    if ((dry)); then
        printf 'prompt-style: %s in this shell only\n' "${name}"
    else
        printf 'prompt-style: %s, saved in %s\n' "${name}" "${file/#"${HOME}"/\~}"
    fi
}
_prompt_style() {
    local cur="${COMP_WORDS[COMP_CWORD]}" name
    COMPREPLY=()
    while IFS= read -r name; do COMPREPLY+=("${name}"); done < <(compgen -W "--dry-run --preview $(__dottod_prompt_styles)" -- "${cur}")
}
complete -F _prompt_style prompt-style
