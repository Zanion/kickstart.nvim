return {
  -- Beads plugin (bd CLI integration via Telescope)
  -- Local plugin: lua/beads/ is part of the config
  dir = vim.fn.stdpath('config'),
  name = 'beads',
  lazy = false,
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('beads').setup({})
  end,
}
