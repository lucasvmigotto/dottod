-- dottod user commands.
vim.api.nvim_create_user_command('DottodProfile', function()
  local profiles = require('dottod.profiles')
  vim.notify('dottod profile: ' .. profiles.name, vim.log.levels.INFO)
end, { desc = 'Show active dottod profile' })

vim.api.nvim_create_user_command('DottodHealth', function()
  vim.cmd('checkhealth dottod')
end, { desc = 'Run dottod health check' })
