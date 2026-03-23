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

  vim.api.nvim_create_user_command('BdShow', function(opts)
    require('beads.preview').show(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command('BdShowH', function(opts)
    require('beads.preview').show_horizontal(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command('BdOpen', function(opts)
    require('beads.navigation').open_issue_url(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command('BdGraph', function(opts)
    require('beads.graph').graph(opts.args)
  end, { nargs = '?' })

  vim.api.nvim_create_user_command('BdStatus', function()
    require('beads.status').status()
  end, {})
end

return M