local config = require('beads.config')

local M = {}

local function get_float_opts()
  local cfg = config.get()
  local width = cfg.graph_width or 80
  local height = cfg.graph_height or 24
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  return {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
  }
end

local function parse_args(args)
  local opts = {
    id = nil,
    all = false,
    format = 'default',
  }

  if args == '' or args == nil then
    return opts
  end

  local parts = vim.split(args, '%s+')
  for _, part in ipairs(parts) do
    if part == '--all' then
      opts.all = true
    elseif part == '--box' then
      opts.format = 'box'
    elseif part == '--compact' then
      opts.format = 'compact'
    elseif part:match('^%a') and not part:match('^%-') then
      -- Validate ID format (alphanumeric, reasonable length)
      if #part <= 50 and part:match('^%w[%w%.%-_]+$') then
        opts.id = part
      end
    end
  end

  return opts
end

local function build_command(opts)
  local cmd = { config.get().binary, 'graph' }

  if opts.all then
    table.insert(cmd, '--all')
  end

  if opts.format ~= 'default' then
    table.insert(cmd, '--' .. opts.format)
  end

  if opts.id then
    table.insert(cmd, opts.id)
  end

  return cmd
end

function M.graph(args)
  local opts = parse_args(args)
  local float_opts = get_float_opts()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  local win = vim.api.nvim_open_win(buf, true, float_opts)

  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'cursorline', false)
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')

  local cmd = build_command(opts)
  local term_opts = {
    term = 'terminal',
    env = { TERM = 'xterm-256color' },
  }

  vim.fn.termopen(cmd, term_opts)

  local close_fn = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set('n', 'q', close_fn, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set('n', '<Esc>', close_fn, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set('t', '<Esc>', close_fn, { buffer = buf, silent = true, nowait = true })

  vim.cmd('startinsert')
end

return M