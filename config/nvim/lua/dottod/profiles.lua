-- dottod profiles: minimal | terminal | development | full.
-- Selected via $DOTTOD_NVIM_PROFILE (default development). No plugin
-- definitions here; plugins query M.has(feature) to enable themselves.
local M = {}

M.valid = { minimal = true, terminal = true, development = true, full = true }

M.name = vim.env.DOTTOD_NVIM_PROFILE or 'development'
if not M.valid[M.name] then
  vim.notify(
    ("Invalid DOTTOD_NVIM_PROFILE=%q (want minimal|terminal|development|full); using development"):format(M.name),
    vim.log.levels.WARN
  )
  M.name = 'development'
end

local features = {
  minimal = { core = true },
  terminal = { core = true, git = true, terminal = true },
  development = { core = true, git = true, terminal = true },
  full = { core = true, git = true, terminal = true },
}

function M.has(feature)
  return features[M.name][feature] == true
end

return M