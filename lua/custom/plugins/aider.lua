-- Custom plugin configuration file for aider.nvim
-- Create this file at ~/.config/nvim/lua/custom/plugins/aider.lua

return {
  'joshuavial/aider.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'folke/snacks.nvim', -- for better UI (replaces deprecated dressing.nvim)
    'rcarriga/nvim-notify', -- optional, for better notifications
  },
  config = function()
    require('aider').setup {
      -- The only supported options in the aider.nvim setup function:
      auto_manage_context = true, -- Automatically manage which files are sent to LLM
      default_bindings = false, -- Use default keybindings with leader A prefix
      debug = false, -- Enable debug logging
      ignore_buffers = { -- Buffer patterns to ignore
        '^term:',
        'NeogitConsole',
        'NvimTree_',
        'neo-tree filesystem',
      },
      border = { -- Optional styling for floating window
        style = 'rounded', -- Can be a string like "rounded" or a table of chars
        color = '#888888', -- Border color
      },
    }
  end,
}
