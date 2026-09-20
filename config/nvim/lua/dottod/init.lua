-- dottod Neovim core: options, keymaps, autocmds, commands, plugins,
-- then the optional user-local override (never shipped, never overwritten).
require('dottod.options')
require('dottod.keymaps')
require('dottod.autocmds')
require('dottod.commands')

require('lazy').setup({
  spec = { { import = 'dottod.plugins' } },
  lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
  defaults = { lazy = true, version = '*' },
  install = { missing = true, colorscheme = { 'tokyonight', 'habamax' } },
  checker = { enabled = false }, -- explicit :Lazy update; never phone home on startup
  change_detection = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = { 'gzip', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin' },
    },
  },
})

-- Optional user-local customization. Missing file is fine; errors are shown once.
local ok, err = pcall(require, 'dottod_local')
if not ok and not tostring(err):match('module.*dottod_local.*not found') then
  vim.notify('dottod_local failed to load: ' .. tostring(err), vim.log.levels.ERROR)
end