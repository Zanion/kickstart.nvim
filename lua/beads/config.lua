local M = {
  config = {
    binary = 'bd',
    keymaps = {
      open = '<CR>',
      show = '<leader>i',
      close = 'q',
    },
    graph_width = 80,
    graph_height = 24,
  },
}

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end
end

function M.get()
  return M.config
end

return M