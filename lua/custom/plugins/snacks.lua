return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    terminal = {
      enabled = true,
    },
  },
  keys = {
    -- Normal mode toggle
    { "<leader>tt", function() Snacks.terminal.toggle("zsh", { win = { style = "float", border = "rounded" } }) end, desc = "Toggle Floating Terminal" },
    {
      "<leader>tg",
      function()
        require("custom.gemini").toggle_gemini()
      end,
      desc = "Toggle Gemini CLI",
    },
    {
      "<leader>ts",
      function()
        require("custom.gemini").pick_session()
      end,
      desc = "Select Gemini Session",
    },
  },
}
