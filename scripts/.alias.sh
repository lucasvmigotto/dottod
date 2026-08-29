#!/usr/bin/env bash

alias ll='ls -lAhF'
alias lll='ll | less'

alias historyg='history | grep'
alias historygn='history | grep -v'

alias ipexit='echo "$(wget -qO- https://ipecho.net/plain)"'

alias commitcount='git shortlog --summary --numbered --all --no-merges'

alias dockerc-ls="docker container ls -a --format 'table {{.ID}} | {{.Names}}\t | {{.State}}\t| {{.Ports}}'"
alias dockeri-ls="docker image ls -a --format 'table {{.ID}} | {{.Tag}}\t | {{.Repository}}'"
