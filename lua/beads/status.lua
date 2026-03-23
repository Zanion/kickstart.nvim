local config = require('beads.config')
local util = require('beads.util')
local Job = require('plenary.job')

local M = {}

local function run_bd_status(callback)
  local cfg = config.get()
  local cmd = cfg.binary

  local output = {}
  Job:new({
    command = cmd,
    args = { 'status', '--json' },
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

local function format_status(status)
  local lines = {}

  table.insert(lines, '=== Beads Database Status ===')
  table.insert(lines, '')

  if status.summary then
    local s = status.summary

    table.insert(lines, 'Issue Counts by State:')
    table.insert(lines, string.format('  Open:        %d', s.open_issues or 0))
    table.insert(lines, string.format('  In Progress: %d', s.in_progress_issues or 0))
    table.insert(lines, string.format('  Blocked:     %d', s.blocked_issues or 0))
    table.insert(lines, string.format('  Closed:      %d', s.closed_issues or 0))
    table.insert(lines, string.format('  Ready:       %d', s.ready_issues or 0))
    table.insert(lines, '')
    table.insert(lines, string.format('Total Issues: %d', s.total_issues or 0))
    table.insert(lines, '')

    if s.pinned_issues and s.pinned_issues > 0 then
      table.insert(lines, string.format('Pinned Issues: %d', s.pinned_issues))
    end

    if s.deferred_issues and s.deferred_issues > 0 then
      table.insert(lines, string.format('Deferred Issues: %d', s.deferred_issues))
    end

    if s.epics_eligible_for_closure and s.epics_eligible_for_closure > 0 then
      table.insert(lines, string.format('Epics Eligible for Closure: %d', s.epics_eligible_for_closure))
    end

    if s.average_lead_time_hours and s.average_lead_time_hours > 0 then
      table.insert(lines, string.format('Average Lead Time: %.1f hours', s.average_lead_time_hours))
    end
  end

  if status.owners and #status.owners > 0 then
    table.insert(lines, '')
    table.insert(lines, 'Owners:')
    for _, owner in ipairs(status.owners) do
      table.insert(lines, string.format('  - %s', owner))
    end
  end

  if status.repositories and #status.repositories > 0 then
    table.insert(lines, '')
    table.insert(lines, 'Repositories:')
    for _, repo in ipairs(status.repositories) do
      table.insert(lines, string.format('  - %s', repo))
    end
  end

  table.insert(lines, '')
  table.insert(lines, '--- Raw JSON Output ---')
  table.insert(lines, vim.json.encode(status))

  return lines
end

function M.status()
  run_bd_status(function(status)
    if not status then
      vim.notify('Failed to get status', vim.log.levels.ERROR)
      return
    end

    local bufname = 'beads://status'
    local lines = format_status(status)

    -- Check for existing buffer
    local existing = util.find_buffer(bufname)
    if existing then
      vim.cmd('vsplit')
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, existing)
      vim.api.nvim_buf_set_option(existing, 'modifiable', true)
      vim.api.nvim_buf_set_lines(existing, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(existing, 'modifiable', false)
    else
      vim.cmd('vsplit')
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

return M
