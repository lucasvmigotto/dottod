-- dottod devcontainer: in-editor Dev Container workflow via the official
-- `devcontainer` CLI (installed by ./bin/bun.sh). Up/connect/exec/down
-- commands render in toggleterm floats; no new dependencies beyond the
-- terminal stack. Gated on the `terminal` feature so `minimal` stays lean.
return {
  {
    'erichlf/devcontainer-cli.nvim',
    cond = function()
      return require('dottod.profiles').has('terminal')
    end,
    dependencies = { 'akinsho/toggleterm.nvim' },
    cmd = {
      'DevcontainerUp',
      'DevcontainerConnect',
      'DevcontainerExec',
      'DevcontainerDown',
      'DevContainerToggle',
    },
    keys = {
      { '<leader>Du', '<cmd>DevcontainerUp<cr>', desc = 'DevContainer: up' },
      { '<leader>Dc', '<cmd>DevcontainerConnect<cr>', desc = 'DevContainer: connect' },
      { '<leader>Dd', '<cmd>DevcontainerDown<cr>', desc = 'DevContainer: down' },
      { '<leader>De', '<cmd>DevcontainerExec<cr>', desc = 'DevContainer: exec' },
    },
    opts = {
      interactive = false,
      toplevel = true,
      remove_existing_container = true,
      shell = 'bash',
      nvim_binary = 'nvim',
    },
  },
}
