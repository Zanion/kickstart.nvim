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

    -- Keep the default keybindings structure but override them with our desired flags
    -- The default <leader>A prefix will still be used
    vim.keymap.set('n', '<leader>Ao', ':AiderOpen --vim --editor "nvim" --dark-mode<CR>', { desc = 'Open Aider (with vim and nvim editor)' })

    -- The default <leader>Am for adding modified files remains unchanged since we don't need to customize it

    -- Additional keybindings for specific use cases
    vim.keymap.set('n', '<leader>A4', ':AiderOpen -4 --vim --editor "nvim --wait" editor<CR>', { desc = 'Open Aider with GPT-4' })
    vim.keymap.set(
      'n',
      '<leader>As',
      ':AiderOpen --model anthropic/claude-3-7-sonnet-20250219 --vim --editor "nvim --wait"<CR>',
      { desc = 'Open Aider with Claude 3.7 Sonnet' }
    )
  end,
}
