---@type LazySpec
return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>y",
      function()
        require("yazi").yazi()
      end,
      desc = "Open yazi at the current file",
    },
    {
      "<leader>cw",
      function()
        require("yazi").yazi(nil, vim.fn.getcwd())
      end,
      desc = "Open yazi in the current working directory",
    },
  },
  ---@type YaziConfig
  opts = {
    open_for_directories = false,
    keymaps = {
      show_help = "<f1>",
    },
  },
}
