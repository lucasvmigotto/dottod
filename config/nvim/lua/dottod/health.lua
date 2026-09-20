-- dottod health check: :checkhealth dottod
local M = {}

function M.check()
  vim.health.start('dottod')

  -- Version
  local ver = vim.version()
  local cur = ('%d.%d.%d'):format(ver.major, ver.minor, ver.patch)
  if vim.fn.has('nvim-0.11') == 1 then
    vim.health.ok('Neovim ' .. cur .. ' (>= 0.11.0)')
  else
    vim.health.error(
      'Neovim ' .. cur .. ' detected, but this configuration requires Neovim 0.11+. Upgrade Neovim.',
      { 'See docs/neovim.md (version policy)', '_DOT_NVIM_ALLOW_TARBALL=1 ./bin/neovim.sh' }
    )
  end

  -- Profile
  local profiles = require('dottod.profiles')
  vim.health.info('Profile: ' .. profiles.name .. ' ($DOTTOD_NVIM_PROFILE)')

  -- Plugin manager
  local lazy_ok, lazy = pcall(require, 'lazy')
  if lazy_ok then
    local core = lazy.core and lazy.core or nil
    vim.health.ok('lazy.nvim loaded (' .. tostring(core and #core or '?') .. ' specs)')
    local lock = vim.fn.stdpath('config') .. '/lazy-lock.json'
    if vim.uv.fs_stat(lock) then
      vim.health.ok('lazy-lock.json present (reproducible plugins)')
    else
      vim.health.warn('lazy-lock.json missing; run :Lazy sync and commit the lockfile')
    end
  else
    vim.health.warn('lazy.nvim not loaded yet (first run bootstraps it; offline?)')
  end

  -- External tools
  for _, bin in ipairs({ 'git', 'rg', 'fd', 'fdfind' }) do
    if vim.fn.executable(bin) == 1 then
      vim.health.ok(bin .. ' found')
    else
      local hint = { 'sudo apt-get install ripgrep fd-find' }
      if bin == 'rg' then
        vim.health.warn('ripgrep not found; Telescope live grep is unavailable. Install ripgrep or run the minimal profile.', hint)
      elseif bin == 'fd' or bin == 'fdfind' then
        vim.health.warn(bin .. ' not found; Telescope find_files falls back to find(1).', { 'sudo apt-get install fd-find' })
      end
    end
  end

  -- dottod CLI composers
  for _, bin in ipairs({ 'lazygit', 'lazydocker', 'k9s', 'btop' }) do
    if vim.fn.executable(bin) == 1 then
      vim.health.ok(bin .. ' found (<leader>g' .. (bin == 'lazygit' and 'g' or bin == 'lazydocker' and 'k' or bin == 'k9s' and 'k' or 't') .. ')')
    else
      vim.health.info(bin .. ' not found (./bin/tools.sh installs it)')
    end
  end

  -- Terminal capability
  if vim.env.TERM ~= nil then
    vim.health.info('TERM=' .. vim.env.TERM .. (vim.env.TMUX ~= nil and ' (inside tmux)' or ''))
  end
  if vim.opt.termguicolors:get() then
    vim.health.ok('termguicolors enabled (Ghostty/tmux handle 24-bit color)')
  else
    vim.health.warn('termguicolors disabled; colorscheme may look off')
  end

  -- User override
  local local_path = vim.fn.stdpath('config') .. '/lua/dottod_local.lua'
  if vim.uv.fs_stat(local_path) then
    vim.health.ok('User override present: lua/dottod_local.lua')
  else
    vim.health.info('No user override (optional): copy lua/dottod_local.lua.example')
  end
end

return M