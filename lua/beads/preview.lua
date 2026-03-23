local config = require('beads.config')
local util = require('beads.util')
local Job = require('plenary.job')

local M = {}

local function run_bd_show(args, callback)
  local cfg = config.get()
  local cmd = cfg.binary

  local output = {}
  Job:new({
    command = cmd,
    args = args,
    on_stdout = function(_, line)
      table.insert(output, line)
    end,
    on_stderr = function(_, err)
      vim.notify('bd error: ' .. err, vim.log.levels.WARN)
    end,
    on_exit = function()
      local combined = table.concat(output, '')
      local result = util.parse_json_output(combined)
      callback(result)
    end,
  }):start()
end

local function format_issue(issue)
  local lines = {}

  table.insert(lines, string.format('ID: %s', issue.id))
  table.insert(lines, string.format('Title: %s', issue.title))
  table.insert(lines, string.format('Type: %s', issue.issue_type))
  table.insert(lines, string.format('State: %s', issue.state))

  if issue.labels and #issue.labels > 0 then
    table.insert(lines, 'Labels: ' .. table.concat(issue.labels, ', '))
  end

  table.insert(lines, '')

  if issue.description then
    table.insert(lines, 'Description:')
    table.insert(lines, issue.description)
    table.insert(lines, '')
  end

  if issue.dependencies and #issue.dependencies > 0 then
    table.insert(lines, 'Dependencies:')
    for _, dep in ipairs(issue.dependencies) do
      table.insert(lines, '  - ' .. dep)
    end
  end

  return lines
end

function M.show(id, split_type)
  split_type = split_type or 'vertical'

  run_bd_show({ 'show', id, '--json' }, function(issue)
    if not issue or not issue.id then
      vim.notify('Issue not found: ' .. id, vim.log.levels.ERROR)
      return
    end

    local bufname = string.format('beads://issue/%s', id)
    local lines = format_issue(issue)

    local cmd = split_type == 'vertical' and 'vsplit' or 'split'

    -- Check for existing buffer
    local existing = util.find_buffer(bufname)
    if existing then
      vim.cmd(cmd)
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, existing)
      vim.api.nvim_buf_set_option(existing, 'modifiable', true)
      vim.api.nvim_buf_set_lines(existing, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(existing, 'modifiable', false)
    else
      vim.cmd(cmd)
      local bufnr = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(bufnr, bufname)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(bufnr, 'readonly', true)
      vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
      vim.api.nvim_set_current_buf(bufnr)
    end
  end)
end

function M.show_horizontal(id)
  M.show(id, 'horizontal')
end

return M
