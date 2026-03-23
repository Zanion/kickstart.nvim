return {
  -- Beads plugin (bd CLI integration via Telescope)
  dir = '/home/zanion/dotfiles/nvim/.config/nvim/.worktrees/feature-beads-plugin',
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
