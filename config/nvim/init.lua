-- dottod Neovim entry point. Keep tiny: leader first, lazy bootstrap, core.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', repo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { 'lazy.nvim bootstrap failed:\n' .. out, 'ErrorMsg' } }, true, {})
  end
end
vim.opt.rtp:prepend(lazypath)

local ok, err = pcall(require, 'dottod')
if not ok then
  vim.api.nvim_echo({ { 'dottod core failed to load:\n' .. tostring(err), 'ErrorMsg' } }, true, {})
end
