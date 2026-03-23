local M = {}

local function sanitize_url(url)
  -- Remove or escape shell metacharacters to prevent command injection
  -- Characters to sanitize: ; & | ` $ and command separators
  return url:gsub('[;&|`$%%!%[%]%{%}]', function(char)
    return '\\' .. char
  end)
end

local function get_open_cmd()
  if vim.fn.has('mac') == 1 then
    return 'open'
  elseif vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    return 'start'
  else
    -- Unix/Linux - prefer xdg-open
    return 'xdg-open'
  end
end

local function open_url(url)
  local safe_url = sanitize_url(url)
  local cmd = get_open_cmd()
  local shell_cmd

  if cmd == 'start' then
    shell_cmd = string.format('start "" "%s"', safe_url)
  else
    shell_cmd = string.format('%s "%s"', cmd, safe_url)
  end

  vim.fn.jobstart(shell_cmd, { detach = true })
end

function M.open_issue_url(issue_id)
  local config = require('beads.config')
  local binary = config.get().binary

  local output = {}
  local job = require('plenary.job').new({
    command = binary,
    args = { 'show', issue_id, '--url', '--json' },
    on_stdout = function(_, line)
      table.insert(output, line)
    end,
    on_stderr = function(_, err)
      vim.notify('bd error: ' .. err, vim.log.levels.WARN)
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify('Failed to get URL for issue: ' .. issue_id, vim.log.levels.ERROR)
        return
      end

      local combined = table.concat(output, '')
      local ok, result = pcall(vim.json.decode, combined)

      if not ok or not result or not result.url then
        vim.notify('Invalid URL response for issue: ' .. issue_id, vim.log.levels.ERROR)
        return
      end

      open_url(result.url)
    end,
  })
  job:start()
end

return M
