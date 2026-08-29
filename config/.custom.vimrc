call plug#begin()

Plug 'flazz/vim-colorschemes'
Plug 'preservim/NERDTree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'frazrepo/vim-rainbow'
Plug 'itchyny/lightline.vim'
Plug 'editorconfig/editorconfig-vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'ObserverOfTime/coloresque.vim'
Plug 'TaDaa/vimade'
Plug 'scrooloose/syntastic'
Plug 'pacha/vem-tabline'
Plug 'alvan/vim-closetag'
Plug 'jiangmiao/auto-pairs'

call plug#end()

se t_Co=16
let g:solarized_termcolors=256
set background=dark
colorscheme solarized

let NERDTreeShowHidden=1
let NERDTreeIgnore=['\.git$', '^node_modules$']
nnoremap <F2> :NERDTreeToggle<CR>
nnoremap <F3> :NERDTreeFocus<CR>
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
    \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

set encoding=UTF-8
set guifont=RobotoRegular\ 11

let g:rainbow_active = 1

set noshowmode
let g:lightline = { 'colorscheme': 'solarized' }
