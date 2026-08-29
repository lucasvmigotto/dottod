export PATH="${HOME}/.local/bin:${PATH}"

ENABLE_CORRECTION="false"

ZSH_THEME="spaceship"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=10"

plugins=(
    sudo
    cp
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

pasteinit() {
    OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
    zle -N self-insert url-quote-magic
}

pastefinish() {
    zle -N self-insert $OLD_SELF_INSERT
}

zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish
