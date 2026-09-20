-- dottod plugin specs aggregator. lazy.nvim imports each module in this
-- directory via { import = 'dottod.plugins' }; this file holds only the
-- shared core library every other spec depends on.
return {
  { 'nvim-lua/plenary.nvim', lazy = true },
}
