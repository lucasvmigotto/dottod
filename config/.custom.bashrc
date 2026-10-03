#!/usr/bin/env bash
# .custom.bashrc — dottod interactive bash customization (linked to ~/.bashrc).
# A lightweight robbyrussell-style prompt + handy utils. No plugins, no
# frameworks: plain bash only. Interactive shells only.

# Only for interactive shells
[[ $- != *i* ]] && return

# ──────────────────────────────────────────────────────────────
# Prompt:  ➜  dirname git:(branch) ✗
#   - arrow is bold green if last command succeeded, bold red otherwise
#   - dir is cyan (basename only, like zsh %c)
#   - git:( bold blue, branch red, ) blue, ✗ yellow when dirty
#   - disable dirty check per repo: git config --local dottod.hide-dirty 1
# ──────────────────────────────────────────────────────────────
__dottod_git_info() {
    local ref
    ref=$(git symbolic-ref --short -q HEAD 2>/dev/null) \
        || ref=$(git describe --tags --exact-match HEAD 2>/dev/null) \
        || ref=$(git rev-parse --short HEAD 2>/dev/null) \
        || return

    local dirty=""
    if [[ $(git config --get dottod.hide-dirty 2>/dev/null) != 1 ]]; then
        if [[ -n $(git status --porcelain --ignore-submodules=dirty 2>/dev/null | head -n 1) ]]; then
            dirty=' \[\e[33m\]✗'
        fi
    fi

    printf '%s' ' \[\e[1;34m\]git:(\[\e[0;31m\]'"$ref"'\[\e[34m\])'"$dirty"'\[\e[0m\]'
}

__dottod_prompt() {
    local last_status=$?   # must be first line to capture $?
    local arrow

    if (( last_status == 0 )); then
        arrow='\[\e[1;32m\]➜\[\e[0m\]'
    else
        arrow='\[\e[1;31m\]➜\[\e[0m\]'
    fi

    PS1="${arrow}  \[\e[36m\]\W\[\e[0m\]$(__dottod_git_info) "
    return $last_status
}

# Prepend to PROMPT_COMMAND without clobbering existing entries
case ";${PROMPT_COMMAND};" in
    *";__dottod_prompt;"*) ;;
    *) PROMPT_COMMAND="__dottod_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac

# dottod container dispatcher (`ctr`): pure functions, silent on source.
# readlink -f follows ~/.bashrc -> repo symlink to find the checkout.
if [[ -n "${BASH_SOURCE[0]:-}" ]] && command -v readlink >/dev/null 2>&1; then
    _dottod_root="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
    if [[ -f "${_dottod_root}/scripts/.container.utils.sh" ]]; then
        # shellcheck disable=SC1091 # resolved relative to this file
        source "${_dottod_root}/scripts/.container.utils.sh"
    fi
    unset _dottod_root
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
    alias ls='ls -G'   # macOS/BSD
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
    [[ $n =~ ^[0-9]+$ ]] || { echo "usage: up [n]" >&2; return 1; }
    while (( n-- > 0 )); do path+="../"; done
    cd "${path:-.}" || return
}

# extract: unpack almost any archive
extract() {
    if [[ $# -eq 0 ]]; then
        echo "usage: extract <file>..." >&2
        return 1
    fi
    local f
    for f in "$@"; do
        if [[ ! -f $f ]]; then
            echo "extract: '$f' is not a file" >&2
            continue
        fi
        case "${f,,}" in
            *.tar.bz2|*.tbz2) tar xjf "$f" ;;
            *.tar.gz|*.tgz)   tar xzf "$f" ;;
            *.tar.xz|*.txz)   tar xJf "$f" ;;
            *.tar.zst)        tar --zstd -xf "$f" ;;
            *.tar)            tar xf "$f" ;;
            *.bz2)            bunzip2 "$f" ;;
            *.gz)             gunzip "$f" ;;
            *.xz)             unxz "$f" ;;
            *.zip|*.jar)      unzip "$f" ;;
            *.rar)            unrar x "$f" ;;
            *.7z)             7z x "$f" ;;
            *.zst)            unzstd "$f" ;;
            *.z)              uncompress "$f" ;;
            *) echo "extract: unknown archive type '$f'" >&2 ;;
        esac
    done
}

# bak: quick timestamped backup of a file/dir
bak() {
    [[ $# -ge 1 ]] || { echo "usage: bak <path>..." >&2; return 1; }
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
    [[ $# -eq 1 ]] || { echo "usage: port <number>" >&2; return 1; }
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
myip() { curl -s https://ifconfig.me; echo; }

# gcl: git clone and cd into the repo
gcl() {
    git clone "$@" || return
    local last="${!#}"
    last="${last%/}"; last="${last##*/}"; last="${last%.git}"
    [[ -d $last ]] && cd -- "$last" || return
}

# Quick reload
# shellcheck disable=SC1090 # user-local file by design
reload() { source ~/.bashrc && echo "reloaded ~/.bashrc"; }
