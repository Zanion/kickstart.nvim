return {
  "sindrets/diffview.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Git [D]iff Open" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Git File [H]istory" },
    { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Git [Q]uit Diffview" },
  },
  opts = {
    enhanced_diff_hl = true, -- Better syntax highlighting in diffs
    use_icons = true,
  },
}
