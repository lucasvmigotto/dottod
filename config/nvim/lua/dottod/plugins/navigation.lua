-- dottod navigation: Telescope fuzzy finding + neo-tree explorer.
-- Preserves the Vim fzf workflow (<C-p> files, <leader>g grep) with modern
-- pickers. Missing rg/fd degrades gracefully (Telescope falls back).
local function telescope_keys()
  local builtin = function(picker)
    return function()
      require('telescope.builtin')[picker]()
    end
  end
  return {
    { '<C-p>', builtin('find_files'), desc = 'Find files' },
    { '<leader>ff', builtin('find_files'), desc = 'Find files' },
    { '<leader>fg', builtin('live_grep'), desc = 'Live grep' },
    { '<leader>fw', builtin('grep_string'), desc = 'Grep current word' },
    { '<leader>fb', builtin('buffers'), desc = 'Buffers' },
    { '<leader>fh', builtin('oldfiles'), desc = 'Recent files' },
    { '<leader>f:', builtin('commands'), desc = 'Commands' },
    { '<leader>f?', builtin('keymaps'), desc = 'Keymaps' },
    { '<leader>fd', builtin('diagnostics'), desc = 'Diagnostics' },
    { '<leader>fs', builtin('lsp_document_symbols'), desc = 'Document symbols' },
    { '<leader>fS', builtin('lsp_workspace_symbols'), desc = 'Workspace symbols' },
    { '<leader>fr', builtin('resume'), desc = 'Resume picker' },
    { '<leader>bb', builtin('buffers'), desc = 'List buffers' },
  }
end

return {
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    keys = telescope_keys(),
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-mini/mini.icons',
      { 'nvim-telescope/telescope-ui-select.nvim' },
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable('make') == 1
        end,
      },
    },
    opts = function()
      local actions = require('telescope.actions')
      return {
        defaults = {
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<Esc>'] = actions.close,
            },
          },
          vimgrep_arguments = (function()
            local args = {
              'rg', '--color=never', '--no-heading', '--with-filename',
              '--line-number', '--column', '--smart-case', '--hidden',
              '--glob', '!.git/',
            }
            if vim.fn.executable('rg') == 0 then
              return nil -- Telescope falls back to grep
            end
            return args
          end)(),
        },
        pickers = {
          find_files = {
            find_command = (function()
              if vim.fn.executable('fd') == 1 then
                return { 'fd', '--type', 'f', '--hidden', '--exclude', '.git' }
              elseif vim.fn.executable('fdfind') == 1 then
                return { 'fdfind', '--type', 'f', '--hidden', '--exclude', '.git' }
              end
              return nil
            end)(),
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require('telescope')
      telescope.setup(opts)
      pcall(telescope.load_extension, 'ui-select')
      pcall(telescope.load_extension, 'fzf')
    end,
  },
  {
    -- File explorer: NERDTree successor. Single explorer, no overlap.
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    keys = {
      { '<F2>', '<cmd>Neotree toggle<cr>', desc = 'Toggle file tree' },
      { '<F3>', '<cmd>Neotree focus<cr>', desc = 'Focus file tree' },
      { '<F4>', '<cmd>Neotree reveal<cr>', desc = 'Reveal current file' },
      { '<leader>e', '<cmd>Neotree toggle<cr>', desc = 'Toggle file tree' },
      { '<leader>pe', '<cmd>Neotree toggle<cr>', desc = 'Project explorer' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-mini/mini.icons',
    },
    opts = {
      close_if_last_window = true,
      filesystem = {
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = 'open_current',
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = {
            -- Ported intent from config/.nerdtree.vimrc: dependency dirs,
            -- build output, caches, coverage, VCS internals, venvs.
            'node_modules', '.git', '.hg', '.svn', '__pycache__',
            '.pytest_cache', '.mypy_cache', '.ruff_cache', '.tox', '.nox',
            'dist', 'build', 'out', 'target', 'coverage', 'htmlcov',
            '.nyc_output', 'playwright-report', 'test-results',
            '.cache', '.parcel-cache', '.turbo', '.next', '.nuxt',
            '.idea', '.vscode', '.vs', '.DS_Store', 'Thumbs.db',
            '.venv', 'venv', 'env', '.eggs', 'vendor',
          },
          hide_by_pattern = {
            '*.pyc', '*.pyo', '*.egg-info', '*.class', '*.jar',
            '*.o', '*.obj', '*.a', '*.so', '*.dylib', '*.dll', '*.exe',
            '*.swp', '*.swo', '*~', '*.bak', '*.tmp', '*.log',
            '*.js.map', '*.tsbuildinfo', 'coverage.*',
          },
          never_show = { '.git' },
        },
      },
      window = { width = 35 },
    },
  },
}
