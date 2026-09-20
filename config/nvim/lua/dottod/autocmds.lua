-- dottod autocmds.
local group = vim.api.nvim_create_augroup('dottod', { clear = true })

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
  desc = 'Highlight yanked text',
})

-- Enter insert mode in terminals; hide line numbers there
vim.api.nvim_create_autocmd('TermOpen', {
  group = group,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.cmd.startinsert()
  end,
  desc = 'Terminal buffer defaults',
})

-- Equalize splits on resize
vim.api.nvim_create_autocmd('VimResized', {
  group = group,
  command = 'tabdo wincmd =',
  desc = 'Equalize windows on resize',
})

-- Quit when neo-tree is the last window (mirrors NERDTree behavior)
vim.api.nvim_create_autocmd('BufEnter', {
  group = group,
  callback = function()
    if #vim.api.nvim_list_wins() == 1 then
      local buf = vim.api.nvim_get_current_buf()
      local ft = vim.bo[buf].filetype
      if ft == 'neo-tree' then
        vim.cmd('quit')
      end
    end
  end,
  desc = 'Quit when explorer is the only window',
})
