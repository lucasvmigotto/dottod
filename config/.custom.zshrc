
export EDITOR='vim'
export LANG=en_US.UTF-8
export PATH="${HOME}/.local/bin:${PATH}"

# Load dottod shell utilities (aliases + functions)
_DOTFILES_ROOT="${${(%):-%N}:A:h:h}"
for _dotfile in "${_DOTFILES_ROOT}"/scripts/*.sh(DN); do
    source "${_dotfile}"
done
unset _dotfile _DOTFILES_ROOT

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

zstyle ':omz:update' mode auto

source $ZSH/oh-my-zsh.sh

# dottod: register the sysinfo section (defined in scripts/.sysinfo.prompt.sh).
# Guarded so startup never fails if the file is absent or renamed.
if (( $+functions[_dottod_sysinfo_register] )); then
    _dottod_sysinfo_register
fi

pasteinit() {
    OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
    zle -N self-insert url-quote-magic
}

pastefinish() {
    zle -N self-insert $OLD_SELF_INSERT
}

zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish
