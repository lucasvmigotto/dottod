-- dottod core keymaps. Plugin-specific maps live with their plugin spec
-- (buffer-local for LSP). Every custom map carries a desc for which-key.
local map = vim.keymap.set

-- Windows: Ctrl-hjkl between splits
map('n', '<C-h>', '<C-w>h', { desc = 'Go to left window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Go to lower window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Go to upper window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Go to right window' })

-- Buffers
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })

-- Files
map('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save file' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit window' })
map('n', '<leader>x', '<cmd>x<cr>', { desc = 'Save and quit' })
map('n', '<leader>Q', '<cmd>q!<cr>', { desc = 'Quit without saving' })

-- Search
map('n', '<leader><CR>', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlight' })
map('n', '<leader>n', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlight' })
map('n', '<leader>/', '/', { desc = 'Search current buffer' })

-- Splits / tabs (mirrors Vim workflow; `t` prefix is owned by terminal/testing)
map('n', '<leader>s', '<cmd>split<cr>', { desc = 'Horizontal split' })
map('n', '<leader>v', '<cmd>vsplit<cr>', { desc = 'Vertical split' })
map('n', '<leader>o', '<C-w>o', { desc = 'Only current window' })
map('n', '<leader><Tab>n', '<cmd>tabnew<cr>', { desc = 'New tab' })
map('n', '<leader><Tab>d', '<cmd>tabclose<cr>', { desc = 'Close tab' })
map('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
map('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })
map('n', '<leader>bn', '<cmd>bnext<cr>', { desc = 'Next buffer' })
map('n', '<leader>bp', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
map('n', '<leader>bd', '<cmd>bdelete<cr>', { desc = 'Delete buffer' })

-- Quickfix navigation (failures land here from tests/grep)
map('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quickfix item' })
map('n', '[q', '<cmd>cprevious<cr>', { desc = 'Previous quickfix item' })

-- Config helpers
map('n', '<leader>ev', '<cmd>edit $MYVIMRC<cr>', { desc = 'Edit init.lua' })
map('n', '<leader>sv', '<cmd>source $MYVIMRC<cr>', { desc = 'Reload config' })

-- Keep visual selection after indent
map('v', '<', '<gv', { desc = 'Indent left (keep selection)' })
map('v', '>', '>gv', { desc = 'Indent right (keep selection)' })

-- Terminal: double-Esc leaves terminal mode
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Testing (command-driven, works in every profile): run project tests in a
-- terminal split; inspect failures in the quickfix list.
map('n', '<leader>ta', function()
  local cmd
  if vim.fn.filereadable('Makefile') == 1 then
    cmd = 'make test'
  elseif vim.fn.filereadable('package.json') == 1 then
    cmd = 'npm test'
  elseif vim.fn.glob('pytest.ini') ~= '' or vim.fn.glob('pyproject.toml') ~= '' then
    cmd = 'pytest'
  elseif vim.fn.filereadable('Cargo.toml') == 1 then
    cmd = 'cargo test'
  elseif vim.fn.filereadable('go.mod') == 1 then
    cmd = 'go test ./...'
  end
  if not cmd then
    vim.notify('No recognized test entrypoint (Makefile/pytest/npm/cargo/go).', vim.log.levels.WARN)
    return
  end
  vim.cmd('split | terminal ' .. cmd)
end, { desc = 'Run project tests' })
map('n', '<leader>tq', '<cmd>copen<cr>', { desc = 'Open quickfix (failures)' })
