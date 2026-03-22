return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    terminal = {
      enabled = true,
    },
  },
  config = function(_, opts)
    require("snacks").setup(opts)
    require("custom.agent").setup()
  end,
  keys = {
    { "<leader>tt", function() Snacks.terminal.toggle("zsh", { win = { style = "float", border = "rounded" } }) end, desc = "Toggle Floating Terminal" },
    {
      "<leader>ta",
      function()
        require("custom.agent").toggle()
      end,
      desc = "Toggle Agent Picker",
    },
    {
      "<leader>tg",
      function()
        require("custom.agent").toggle_agent("gemini")
      end,
      desc = "Toggle Gemini",
    },
    {
      "<leader>tc",
      function()
        require("custom.agent").toggle_agent("cursor")
      end,
      desc = "Toggle Cursor",
    },
    {
      "<leader>tl",
      function()
        require("custom.agent").toggle_agent("claude")
      end,
      desc = "Toggle Claude",
    },
    {
      "<leader>to",
      function()
        require("custom.agent").toggle_agent("opencode")
      end,
      desc = "Toggle OpenCode",
    },
  },
}
