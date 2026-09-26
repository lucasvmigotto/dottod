# 003-vim — as-is technical context

- Entry: `bin/vim.sh` (apt → vim-plug → link → `vim -es PlugInstall`)
  [OBSERVED: bin/vim.sh:25].
- Config: `config/.custom.vimrc` (leader/Space, fzf, NERDTree, ALE,
  lightline) + `config/.nerdtree.vimrc` (dev-oriented ignore list)
  [OBSERVED: config/.custom.vimrc, config/.nerdtree.vimrc].
- Env: `_DOT_VIM_SCRIPT_URL` (default junegunn/vim-plug master),
  `_DOT_TARGET_USER` [OBSERVED: bin/vim.sh:26].
- Coexists with Neovim; never replaced by it
  [OBSERVED: docs/neovim.md:3].
- No dedicated test suite (shellcheck/bash -n only).
