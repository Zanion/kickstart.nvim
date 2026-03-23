local config = require 'beads.config'

local M = {}

function M.setup(opts)
  config.setup(opts)
  require('beads.commands').register()
end

return M