local config = require('beads.config')
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
    on_exit = vim.schedule_wrap(function()
      local combined = table.concat(output, '')
      local ok, result = pcall(vim.json.decode, combined)
      if ok then
        callback(result)
      else
        vim.notify('Failed to parse status output', vim.log.levels.ERROR)
        callback(nil)
      end
    end),
  }):start()
end

--- Format status for compact display in status bar
--- @param status table Status object
--- @return string Formatted status string
local function format_status_compact(status)
  if not status or not status.summary then
    return 'Beads: No data'
  end

  local s = status.summary
  return string.format(
    'Beads: %d open | %d in_progress | %d blocked | %d ready | %d closed',
    s.open_issues or 0,
    s.in_progress_issues or 0,
    s.blocked_issues or 0,
    s.ready_issues or 0,
    s.closed_issues or 0
  )
end

--- Show status in the command line area (status bar)
function M.status()
  run_bd_status(vim.schedule_wrap(function(status)
    if not status then
      vim.notify('Failed to get status', vim.log.levels.ERROR)
      return
    end

    -- Show compact status in command line (status bar)
    local msg = format_status_compact(status)
    vim.notify(msg, vim.log.levels.INFO, { title = 'Beads Status' })

    -- Also show detailed info if summary exists
    if status.summary then
      local s = status.summary
      vim.api.nvim_echo({
        { string.format('Beads: %d total issues', s.total_issues or 0), 'Normal' },
        { string.format(' | Open: %d', s.open_issues or 0), 'DiagnosticInfo' },
        { string.format(' | In Progress: %d', s.in_progress_issues or 0), 'DiagnosticWarn' },
        { string.format(' | Blocked: %d', s.blocked_issues or 0), 'DiagnosticError' },
        { string.format(' | Ready: %d', s.ready_issues or 0), 'DiagnosticOk' },
        { string.format(' | Closed: %d', s.closed_issues or 0), 'Comment' },
      }, false, {})
    end
  end))
end

return M
