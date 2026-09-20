-- dottod git: gitsigns gutter workflow + lazygit composer (never replaces it).
return {
  {
    'lewis6991/gitsigns.nvim',
    cond = function()
      return require('dottod.profiles').has('git')
    end,
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '│' },
        change = { text = '│' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      on_attach = function(bufnr)
        local gs = require('gitsigns')
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map('n', ']h', gs.next_hunk, 'Next hunk')
        map('n', '[h', gs.prev_hunk, 'Previous hunk')
        map('n', '<leader>ghp', gs.preview_hunk, 'Preview hunk')
        map('n', '<leader>ghs', gs.stage_hunk, 'Stage hunk')
        map('n', '<leader>ghr', gs.reset_hunk, 'Reset hunk')
        map('n', '<leader>ghS', gs.stage_buffer, 'Stage buffer')
        map('n', '<leader>ghR', gs.reset_buffer, 'Reset buffer')
        map('n', '<leader>ghb', function()
          gs.blame_line({ full = true })
        end, 'Blame line')
        map('n', '<leader>ghd', gs.diffthis, 'Diff this')
      end,
    },
  },
}
