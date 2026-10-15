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
    local specs = 0
    local cfg_ok, cfg = pcall(require, 'lazy.core.config')
    if cfg_ok and cfg.plugins then
      for _ in pairs(cfg.plugins) do
        specs = specs + 1
      end
    end
    vim.health.ok('lazy.nvim loaded (' .. specs .. ' specs)')
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
  -- fd is fdfind on Debian: either name counts.
  for _, bin in ipairs({ 'git', 'rg' }) do
    if vim.fn.executable(bin) == 1 then
      vim.health.ok(bin .. ' found')
    elseif bin == 'rg' then
      vim.health.warn('ripgrep not found; Telescope live grep is unavailable. Install ripgrep from your distro or run the minimal profile.')
    else
      vim.health.warn(bin .. ' not found')
    end
  end
  if vim.fn.executable('fd') == 1 or vim.fn.executable('fdfind') == 1 then
    vim.health.ok('fd found')
  else
    vim.health.warn('fd not found; Telescope find_files falls back to find(1).', { "Install fd from your distro (Debian: fd-find)" })
  end

  -- dottod CLI launcher
  if vim.fn.executable('btop') == 1 then
    vim.health.ok('btop found (<leader>bt)')
  else
    vim.health.info('btop not found (./bin/tools.sh installs it)')
  end

  -- DevContainer workflow (devcontainer-cli.nvim, terminal profiles only)
  if vim.fn.executable('devcontainer') == 1 then
    vim.health.ok('devcontainer CLI found (<leader>Du)')
  else
    vim.health.info('devcontainer CLI not found (./bin/bun.sh installs it)')
  end

  -- Terminal capability
  if vim.env.TERM ~= nil then
    vim.health.info('TERM=' .. vim.env.TERM .. (vim.env.TMUX ~= nil and ' (inside tmux)' or ''))
  end
  if vim.opt.termguicolors:get() then
    vim.health.ok('termguicolors enabled (modern terminals/tmux handle 24-bit color)')
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