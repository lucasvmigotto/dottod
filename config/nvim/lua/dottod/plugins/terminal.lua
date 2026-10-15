-- dottod terminal-first workflow: native :terminal + toggleterm for
-- float/horizontal/vertical shells, plus a btop launcher.
local function term_cmd(bin, name)
  return function()
    if vim.fn.executable(bin) == 0 then
      require('dottod.utils').notify_missing(bin, name)
      return
    end
    vim.cmd('ToggleTerm direction=float exec=' .. bin)
  end
end

return {
  {
    'akinsho/toggleterm.nvim',
    cond = function()
      return require('dottod.profiles').has('terminal')
    end,
    cmd = { 'ToggleTerm', 'TermExec' },
    keys = {
      { '<leader>tt', '<cmd>ToggleTerm direction=float<cr>', desc = 'Floating terminal' },
      { '<leader>th', '<cmd>ToggleTerm direction=horizontal<cr>', desc = 'Horizontal terminal' },
      { '<leader>tv', '<cmd>ToggleTerm direction=vertical size=80<cr>', desc = 'Vertical terminal' },
      { '<C-\\>', '<cmd>ToggleTerm<cr>', desc = 'Toggle terminal' },
      { '<leader>bt', term_cmd('btop', 'btop'), desc = 'btop floating' },
    },
    opts = {
      open_mapping = [[<C-\>]],
      direction = 'float',
      float_opts = { border = 'rounded' },
      shade_terminals = false, -- keep terminal contrast under tmux/SSH
    },
  },
}
