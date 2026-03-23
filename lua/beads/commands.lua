local M = {}

function M.register()
  vim.api.nvim_create_user_command('BdList', function()
    require('beads.pickers').list()
  end, {})

  vim.api.nvim_create_user_command('BdReady', function()
    require('beads.pickers').ready()
  end, {})

  vim.api.nvim_create_user_command('BdBlocked', function()
    require('beads.pickers').blocked()
  end, {})

  vim.api.nvim_create_user_command('BdSearch', function()
    require('beads.pickers').search()
  end, {})

  vim.api.nvim_create_user_command('BdQuery', function()
    require('beads.pickers').query()
  end, {})
end

return M