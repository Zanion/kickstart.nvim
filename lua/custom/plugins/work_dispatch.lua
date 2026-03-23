return {
  "custom/work_dispatch",
  dependencies = {
    "folke/snacks.nvim",
    "nvim-telescope/telescope.nvim",
    "rcarriga/nvim-notify",
  },
  event = "VimEnter",
  config = function()
    require("custom.work_dispatch").setup()
  end,
  keys = {
    {
      "<leader>aa",
      function()
        require("custom.work_dispatch.picker").open()
      end,
      desc = "Active Agents Picker",
    },
    {
      "<leader>ad",
      function()
        require("custom.work_dispatch").pick_dispatch()
      end,
      desc = "Dispatch Work",
    },
    {
      "<leader>al",
      function()
        require("custom.work_dispatch").list_active()
      end,
      desc = "List Active Worktrees",
    },
  },
}
