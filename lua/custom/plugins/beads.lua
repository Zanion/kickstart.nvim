return {
  -- Beads plugin (bd CLI integration via Telescope)
  -- Plugin files are in lua/beads/ which is on the runtime path
  name = 'beads',
  lazy = false,
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    local ok, beads = pcall(require, 'beads')
    if ok then
      beads.setup({})
    end
  end,
}
