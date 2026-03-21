return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim", -- Neogit integrates beautifully with Diffview
    "nvim-telescope/telescope.nvim",
  },
  config = true,
  keys = {
    { "<leader>gs", "<cmd>Neogit<cr>", desc = "Git [S]tatus (Neogit)" },
  },
}
