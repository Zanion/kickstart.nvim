local M = {}

function M.register()
  vim.api.nvim_create_user_command('BdList', function()
    require('beads.pickers').list()
  end, { desc = 'List all issues in Telescope' })

  vim.api.nvim_create_user_command('BdReady', function()
    require('beads.pickers').ready()
  end, { desc = 'List ready issues in Telescope' })

  vim.api.nvim_create_user_command('BdBlocked', function()
    require('beads.pickers').blocked()
  end, { desc = 'List blocked issues in Telescope' })

  vim.api.nvim_create_user_command('BdSearch', function()
    require('beads.pickers').search()
  end, { desc = 'Search issues in Telescope' })

  vim.api.nvim_create_user_command('BdStatus', function()
    require('beads.status').status()
  end, { desc = 'Show beads status' })
end

return M
