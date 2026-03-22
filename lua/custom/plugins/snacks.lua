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
        Snacks.terminal.toggle("gemini", {
          win = { style = "float", border = "rounded" },
          env = { NVIM = vim.v.servername },
        })
      end,
      desc = "Toggle Gemini CLI",
    },
  },
}
