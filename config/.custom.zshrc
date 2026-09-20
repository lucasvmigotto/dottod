
export EDITOR='vim'
export LANG=en_US.UTF-8
export PATH="${HOME}/.local/bin:${PATH}"

if [[ -d "${HOME}/.opencode/bin" ]]; then
    export PATH="${HOME}/.opencode/bin:${PATH}"
fi

if [[ -d "${HOME}/.bun/bin" ]]; then
    export PATH="${HOME}/.bun/bin:${PATH}"
fi

# Load dottod shell utilities (aliases + functions)
_DOTFILES_ROOT="${${(%):-%N}:A:h:h}"
for _dotfile in "${_DOTFILES_ROOT}"/scripts/*.sh(DN); do
    source "${_dotfile}"
done
unset _dotfile _DOTFILES_ROOT

export ZSH="$HOME/.oh-my-zsh"

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

# dottod: register the sysinfo + container + time sections (defined in
# scripts/.sysinfo.prompt.sh). Guarded so startup never fails if the file
# is absent or renamed.
if (( $+functions[_dottod_sysinfo_register] )); then
    _dottod_sysinfo_register
fi
if (( $+functions[_dottod_container_register] )); then
    _dottod_container_register
fi
if (( $+functions[_dottod_exec_time_register] )); then
    _dottod_exec_time_register
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
