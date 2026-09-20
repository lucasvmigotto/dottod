-- dottod UI: colorscheme, statusline, which-key, icons, indent guides.
-- Terminal-first: no animations, no heavy UI. Everything lazy-loads except
-- the colorscheme + statusline (upstream recommends loading these early).
return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = { style = 'night', terminal_colors = true },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme('tokyonight')
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    dependencies = { 'nvim-mini/mini.icons' },
    opts = {
      options = { theme = 'tokyonight', globalstatus = true, section_separators = '', component_separators = '' },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
    },
  },
  {
    'nvim-mini/mini.icons',
    lazy = true,
    opts = {},
    config = function(_, opts)
      require('mini.icons').setup(opts)
      pcall(require('mini.icons').mock_nvim_web_devicons)
    end,
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      delay = 300,
      spec = {
        { '<leader>b', group = 'buffers' },
        { '<leader>c', group = 'code' },
        { '<leader>d', group = 'diagnostics/debug' },
        { '<leader>f', group = 'find' },
        { '<leader>g', group = 'git' },
        { '<leader>l', group = 'lsp' },
        { '<leader>p', group = 'project' },
        { '<leader>t', group = 'terminal/testing' },
        { '<leader><Tab>', group = 'tabs' },
        { '<leader>gh', group = 'git hunks' },
      },
    },
  },
  {
    -- indent guides (modern successor of vim-indent-guides)
    'lukas-reineke/indent-blankline.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    main = 'ibl',
    opts = { indent = { char = '│' }, scope = { enabled = true } },
  },
  {
    -- color preview (successor of coloresque.vim)
    'NvChad/nvim-colorizer.lua',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = { user_default_options = { names = false, tailwind = true } },
  },
}
