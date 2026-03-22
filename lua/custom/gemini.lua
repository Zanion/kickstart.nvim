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

-- Function to find an existing Gemini terminal buffer
local function find_gemini_terminal()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("term:.*gemini") then
      return buf
    end
  end
  return nil
end

function M.toggle_gemini()
  local snacks = require("snacks")
  local gemini_buf = find_gemini_terminal()

  -- If it's already running, just toggle it
  if gemini_buf then
    snacks.terminal.toggle(nil, { id = "gemini" })
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
        
        snacks.terminal.toggle(selection.value.cmd, {
          id = "gemini",
          win = { style = "float", border = "rounded" },
          env = { NVIM = vim.v.servername },
        })
        -- Refresh cache for next time after selecting a session
        vim.defer_fn(function() M.refresh_sessions() end, 1000)
      end)
      return true
    end,
  }):find()
end

function M.pick_session()
  if M.session_cache then
    M.show_picker(M.session_cache)
    -- Also trigger a background refresh in case things changed
    M.refresh_sessions()
  else
    -- If cache is empty (e.g. immediate launch), show loading message and wait
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
  -- Initial background fetch on startup
  M.refresh_sessions()
end

return M
