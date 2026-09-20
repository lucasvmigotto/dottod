-- dottod utilities shared by plugin specs and language modules.
local M = {}

function M.has(bin)
  return vim.fn.executable(bin) == 1
end

function M.notify_missing(feature, what)
  vim.notify(
    ("%s not found; %s is unavailable. Install %s or use the minimal profile."):format(feature, what, feature),
    vim.log.levels.WARN
  )
end

-- Buffer-local LSP keymaps attached once per buffer.
function M.lsp_keymaps(bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end
  map('n', 'K', vim.lsp.buf.hover, 'Hover documentation')
  map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
  map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
  map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
  map('n', 'gr', vim.lsp.buf.references, 'List references')
  map('n', '<leader>lr', vim.lsp.buf.rename, 'Rename symbol')
  map('n', '<leader>la', vim.lsp.buf.code_action, 'Code action')
  map('n', '<leader>lf', function()
    vim.lsp.buf.format({ async = true })
  end, 'Format buffer (LSP)')
  map('i', '<C-k>', vim.lsp.buf.signature_help, 'Signature help')
  map('n', '<leader>ls', vim.lsp.buf.document_symbol, 'Document symbols')
  map('n', '<leader>lw', vim.lsp.buf.workspace_symbol, 'Workspace symbols')
end

return M
