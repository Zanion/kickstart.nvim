return {
  'beads.nvim',
  lazy = false,
  init = function()
    local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':p:h')
    package.path = package.path .. ';' .. plugin_dir .. '/?.lua;' .. plugin_dir .. '/?/init.lua'
  end,
  config = function()
    require('beads').setup({})
  end,
}