-- dottod terminal-first workflow: native :terminal + toggleterm for
-- float/horizontal/vertical shells, plus dottod CLI composers (lazygit,
-- lazydocker, k9s, btop). Nothing here duplicates those tools.
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
      {
        '<leader>gg',
        function()
          if vim.fn.executable('lazygit') == 0 then
            require('dottod.utils').notify_missing('lazygit', 'lazygit')
            return
          end
          vim.cmd('ToggleTerm direction=float exec=lazygit')
        end,
        desc = 'Lazygit floating',
      },
      { '<leader>dk', term_cmd('lazydocker', 'lazydocker'), desc = 'Lazydocker floating' },
      { '<leader>kk', term_cmd('k9s', 'k9s'), desc = 'k9s floating' },
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
