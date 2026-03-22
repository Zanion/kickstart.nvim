local M = {}

-- Cache for the session list
M.session_cache = nil
M.is_refreshing = false

-- Function to parse the raw gemini output into a table
local function parse_sessions(stdout)
  local sessions = { { id = "new", text = "  <New Session>", cmd = "gemini" } }
  for line in stdout:gmatch("[^\r\n]+") do
    local id = line:match("%[([a-f0-9%-]+)%]$")
    if id then
      local display_text = line:gsub("^%s*%d+%.%s*", ""):gsub("%s*%[[a-f0-9%-]+%]$", "")
      table.insert(sessions, {
        id = id,
        text = "󰚩  " .. display_text,
        cmd = "gemini --resume " .. id,
      })
    end
  end
  return sessions
end

-- Refresh the session cache asynchronously
function M.refresh_sessions(callback)
  if M.is_refreshing then return end
  M.is_refreshing = true

  vim.system({ "gemini", "--list-sessions" }, { text = true }, function(obj)
    vim.schedule(function()
      M.is_refreshing = false
      if obj.code == 0 then
        M.session_cache = parse_sessions(obj.stdout)
        if callback then callback(M.session_cache) end
      end
    end)
  end)
end

-- Function to find an existing Gemini terminal instance using Snacks API
local function get_gemini_terminal()
  local snacks = require("snacks")
  -- Snacks.terminal.list() returns all active terminal instances
  for _, terminal in pairs(snacks.terminal.list()) do
    local buf = terminal.buf
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      -- Match "gemini" in the buffer name (which includes the command)
      if name:match("gemini") then
        return terminal
      end
    end
  end
  return nil
end

function M.toggle_gemini()
  local terminal = get_gemini_terminal()

  if terminal then
    -- If it exists, toggle the window
    terminal:toggle()
    return
  end

  -- If not running, show the session picker
  M.pick_session()
end

function M.show_picker(sessions)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local snacks = require("snacks")

  pickers.new({}, {
    prompt_title = "Gemini: Select Session to Resume",
    finder = finders.new_table {
      results = sessions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.text,
          ordinal = entry.text,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        
        -- Use 'env' command prefix to set NVIM without overriding the entire env table.
        -- This ensures the shell inherits PATH, HOME, and other variables naturally.
        local cmd = string.format("env NVIM=%s %s", vim.fn.shellescape(vim.v.servername), selection.value.cmd)

        snacks.terminal.toggle(cmd, {
          win = { style = "float", border = "rounded" },
        })
        
        -- Refresh cache for next time
        vim.defer_fn(function() M.refresh_sessions() end, 1000)
      end)
      return true
    end,
  }):find()
end

function M.pick_session()
  if M.session_cache then
    M.show_picker(M.session_cache)
    M.refresh_sessions()
  else
    local loading = vim.notify("Fetching Gemini sessions...", vim.log.levels.INFO, {
      title = "Gemini",
      icon = "󰚩 ",
      timeout = false,
    })
    M.refresh_sessions(function(sessions)
      if loading then vim.notify(nil, nil, { replace = loading, timeout = 1 }) end
      M.show_picker(sessions)
    end)
  end
end

function M.setup()
  M.refresh_sessions()
end

return M
