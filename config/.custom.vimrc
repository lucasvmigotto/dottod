" =============================================================================
"  ~/.vimrc  (annotated)
"
"  Legend:   "        starts a comment
"            <leader> = Space (set in section 1)
"            <C-x> = Ctrl+x    <CR> = Enter    <Esc> = Escape    <F2> = key F2
"
"  Edit this file:    <Space>ev
"  Reload it:         <Space>sv      (or  :source $MYVIMRC )
"  Forgot a shortcut: press <Space> and wait, or <Space>?
" =============================================================================


" ----- 0. Auto-install vim-plug (only runs if it is missing) -----------------
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif


" ----- 1. Leader key (must come BEFORE any <leader> mapping) -----------------
let mapleader = " "


" ----- 2. Plugins ------------------------------------------------------------
call plug#begin()

" Git
Plug 'tpope/vim-fugitive'

" Navigation
Plug 'preservim/NERDTree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'liuchengxu/vim-which-key'

" Look and feel
Plug 'flazz/vim-colorschemes'
Plug 'itchyny/lightline.vim'
Plug 'pacha/vem-tabline'
Plug 'frazrepo/vim-rainbow'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'ObserverOfTime/coloresque.vim'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" Editing
Plug 'editorconfig/editorconfig-vim'
Plug 'jiangmiao/auto-pairs'
Plug 'alvan/vim-closetag'
Plug 'tpope/vim-commentary'

" Linting (replaces syntastic, which is no longer maintained)
Plug 'dense-analysis/ale'

" vim-devicons must be loaded LAST (its docs say so)
Plug 'ryanoasis/vim-devicons'

call plug#end()


" ----- 3. Basic behaviour ----------------------------------------------------
set encoding=UTF-8
set number relativenumber       " current line number + relative numbers (helps with 5j, 12k...)
set cursorline
set hidden                      " switch buffers without being forced to save
set mouse=a                     " click, scroll and resize with the mouse
set splitright splitbelow       " new splits open right / below
set scrolloff=8                 " keep 8 lines of context around the cursor
set wildmenu                    " nicer :command completion (press Tab)
set laststatus=2                " always show the status line (lightline needs this)
set noshowmode                  " lightline already shows the mode
set timeoutlen=500              " how long Vim waits for the next key of a mapping
set ttimeoutlen=50
set updatetime=300

" Search: highlight while typing, ignore case unless you type a capital
set hlsearch incsearch ignorecase smartcase

" Indentation defaults (editorconfig overrides these per project)
set expandtab tabstop=4 shiftwidth=4 softtabstop=4

" Share the system clipboard (needs Vim built with +clipboard, e.g. vim-gtk3)
if has('clipboard')
  set clipboard=unnamedplus
endif


" ----- 4. Colors -------------------------------------------------------------
" Option B (active): terminal is NOT using the Solarized palette.
" Your old file had t_Co=16 together with termcolors=256, which contradicts itself.
set t_Co=256
let g:solarized_termcolors=256
set background=dark
silent! colorscheme solarized
" Option A: if your terminal emulator theme IS Solarized, delete the 2 lines
" set t_Co / let g:solarized_termcolors above and keep only background + colorscheme.


" ----- 5. NERDTree (file tree) -----------------------------------------------
let NERDTreeShowHidden=1
source "${HOME}/.nerdtreeignore"
let NERDTreeMinimalUI=1         " hides the help banner and the "up a dir" line
let NERDTreeWinSize=35
let NERDTreeAutoDeleteBuffer=1  " close the buffer when you delete/rename a file in the tree

nnoremap <F2> :NERDTreeToggle<CR>
nnoremap <F3> :NERDTreeFocus<CR>
nnoremap <F4> :NERDTreeFind<CR>

" augroup + autocmd! avoids duplicated autocommands every time you reload the vimrc
augroup nerdtree_custom
  autocmd!
  " `vim some/dir` opens the tree on that dir and moves to an empty buffer
  autocmd StdinReadPre * let s:std_in=1
  autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
      \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.fnameescape(argv()[0]) | endif
  " quit Vim if NERDTree is the only window left
  autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
augroup END


" ----- 6. Fuzzy finder (fzf) : find files, buffers and text ------------------
" NOTE: never put a comment at the end of a map line: Vim would treat it as
" part of the mapping. Comments go on their own line, like these.

" Ctrl+p: find a file by name (fuzzy)
nnoremap <C-p> :Files<CR>
" <Space>b: jump to an open buffer
nnoremap <leader>b :Buffers<CR>
" <Space>g: search TEXT in the whole project (needs ripgrep installed)
nnoremap <leader>g :Rg<CR>
" <Space>l: search lines in the current file
nnoremap <leader>l :BLines<CR>
" <Space>h: recently opened files
nnoremap <leader>h :History<CR>
" <Space>: : list every command
nnoremap <leader>: :Commands<CR>
" <Space>? : list every mapping (great to discover shortcuts)
nnoremap <leader>? :Maps<CR>


" ----- 7. Moving around: windows and buffers ---------------------------------
" Ctrl+h/j/k/l to jump between splits (NERDTree, file, ...).
" Note: this replaces Ctrl+l (redraw); use :redraw! if you ever need it.
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" ]b / [b: next / previous buffer (the "tabs" shown by vem-tabline)
nnoremap ]b :bnext<CR>
nnoremap [b :bprevious<CR>
" <Space>x: close current buffer
nnoremap <leader>x :bdelete<CR>

" <Space>w: save    <Space>q: quit window
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
" <Space><Enter>: clear search highlight
nnoremap <leader><CR> :nohlsearch<CR>


" ----- 8. Vimrc helpers and small quality-of-life ----------------------------
nnoremap <leader>ev :edit $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

" keep the selection after indenting in visual mode
vnoremap < <gv
vnoremap > >gv


" ----- 9. Git shorthands ------------------------------------------------------
" Space + g s Git status
nnoremap <leader>gs :Git<CR>
" Space + g g Git graph
nnoremap <leader>gg :Git log --graph --oneline --decorate --all<CR>


" ----- 10. Base shorthands ----------------------------------------------------

" ----- 10.1. File writing
" Space + w Save
nnoremap <leader>w :write<CR>
" Space + q Quit
nnoremap <leader>q :quit<CR>
" Space + x Save and quit
nnoremap <leader>x :x<CR>
" Space + Q Quit without saving
nnoremap <leader>Q :q!<CR>

" ----- 10.2. Window navigation
" Space + h/j/k/l Move between windows
nnoremap <leader>h <C-w>h
nnoremap <leader>j <C-w>j
nnoremap <leader>k <C-w>k
nnoremap <leader>l <C-w>l
" Space + o Only current window
nnoremap <leader>o <C-w>o
" Space + s Horizontal split
nnoremap <leader>s :split<CR>
" Space + v Vertical split
nnoremap <leader>v :vsplit<CR>i

" ----- 10.3. Tab navigation
" Space + tn New tab
nnoremap <leader>tn :tabnew<CR>
" Space + th Previous tab
nnoremap <leader>th :tabprevious<CR>
" Space + tl Next tab
nnoremap <leader>tl :tabnext<CR>

" ----- 10.4. Buffers
" Space + bn Next buffer
nnoremap <leader>bn :bnext<CR>
" Space + bp Previous buffer
nnoremap <leader>bp :bprevious<CR>
" Space + bd Delete current buffer
nnoremap <leader>bd :bdelete<CR>

" ----- 10.5. Search
" Space + / Search current buffer
nnoremap <leader>/ /
" Space + n Clear search highlighting
nnoremap <leader>n :nohlsearch<CR>


" ----- Plugin settings ----------------------------------------------------
let g:rainbow_active = 1

" lightline draws the status line; its tabline is disabled so vem-tabline can own it
let g:lightline = {
      \ 'colorscheme': 'solarized',
      \ 'enable': { 'tabline': 0 },
      \ }

" let g:indent_guides_enable_on_vim_startup = 1   " uncomment for always-on guides
" (otherwise toggle them with <Space>ig)

let g:closetag_filenames = '*.html,*.xhtml,*.jsx,*.tsx,*.vue,*.php,*.md'

" ALE: jump between problems with ]e and [e
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '▲'
nmap ]e <Plug>(ale_next_wrap)
nmap [e <Plug>(ale_previous_wrap)

" which-key: press <Space> and wait to see the available shortcuts
let g:which_key_map = {}
silent! call which_key#register('<Space>', 'g:which_key_map')
nnoremap <silent> <leader> :<C-u>WhichKey '<Space>'<CR>
