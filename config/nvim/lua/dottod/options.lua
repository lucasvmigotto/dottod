-- dottod options: terminal-first, quiet UI, persistent undo.
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = 'yes'
opt.termguicolors = true
opt.background = 'dark'

opt.hidden = true
opt.mouse = '' -- terminal multiplexers own the mouse; enable explicitly if wanted
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.laststatus = 2
opt.showmode = false
opt.timeoutlen = 500
opt.ttimeoutlen = 50
opt.updatetime = 300

opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.smartindent = true
opt.wrap = false
opt.breakindent = true

opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.writebackup = false

opt.completeopt = { 'menu', 'menuone', 'noselect' }
opt.wildmode = { 'longest:full', 'full' }
opt.shortmess:append('c')

if vim.fn.has('clipboard') == 1 then
  opt.clipboard = 'unnamedplus'
end
