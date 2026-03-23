local M = {}

-- Cache for the session list
M.session_cache = nil
M.is_refreshing = false
M.callbacks = {}

-- Function to parse the raw gemini output into a table
local function parse_sessions(stdout)
  local sessions = { { id = "new", text = "  <New Session>", cmd = "gemini" } }
  local found_sessions = {}
  
  -- Parse output: 1. Description... (time) [id]
  for line in stdout:gmatch("[^\r\n]+") do
    local id = line:match("%[([a-f0-9%-]+)%]$")
    if id then
      local display_text = line:gsub("^%s*%d+%.%s*", ""):gsub("%s*%[[a-f0-9%-]+%]$", "")
      table.insert(found_sessions, {
        id = id,
        text = "󰚩  " .. display_text,
        cmd = "env NVIM=" .. vim.fn.shellescape(vim.v.servername) .. " gemini --resume " .. id,
      })
    end
  end

  -- Reverse chronological order
  for i = #found_sessions, 1, -1 do
    table.insert(sessions, found_sessions[i])
  end
  
  return sessions
end

-- Refresh the session cache asynchronously
function M.refresh_sessions(callback)
  if callback then
    table.insert(M.callbacks, callback)
  end

  if M.is_refreshing then return end
  M.is_refreshing = true

  vim.system({ "gemini", "--list-sessions" }, { text = true }, function(obj)
    vim.schedule(function()
      M.is_refreshing = false
      if obj.code == 0 then
        M.session_cache = parse_sessions(obj.stdout)
      else
        M.session_cache = { { id = "new", text = "  <New Session>", cmd = "gemini" } }
        vim.notify("Failed to fetch Gemini sessions", vim.log.levels.ERROR)
      end

      -- Call all queued callbacks
      for _, cb in ipairs(M.callbacks) do
        cb(M.session_cache)
      end
      M.callbacks = {}
    end)
  end)
end

-- Function to find an existing Gemini terminal instance using Snacks API
local function get_gemini_terminal()
  local snacks = require("snacks")
  for _, terminal in pairs(snacks.terminal.list()) do
    local buf = terminal.buf
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
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
    terminal:toggle()
    return
  end

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
          win = { style = "float", border = "rounded" },
        })
        
        vim.defer_fn(function() M.refresh_sessions() end, 1000)
      end)
      return true
    end,
  }):find()
end

function M.pick_session()
  if M.session_cache and not M.is_refreshing then
    M.show_picker(M.session_cache)
    M.refresh_sessions()
  else
    local notify = require("notify")
    local loading = notify("Fetching Gemini sessions...", vim.log.levels.INFO, {
      title = "Gemini",
      icon = "󰚩 ",
      timeout = false,
    })
    
    M.refresh_sessions(function(sessions)
      notify("Gemini Ready", vim.log.levels.INFO, {
        replace = loading,
        icon = "󰄬 ",
        timeout = 2000,
      })
      M.show_picker(sessions)
    end)
  end
end

function M.setup()
  -- Use a slightly deferred initialization to ensure nvim-notify is ready
  vim.defer_fn(function()
    local notify = require("notify")
    local loading = notify("Initializing Gemini...", vim.log.levels.INFO, {
      title = "Gemini",
      icon = "󰚩 ",
      timeout = false,
    })
    
    M.refresh_sessions(function()
      notify("Gemini Ready", vim.log.levels.INFO, {
        replace = loading,
        icon = "󰄬 ",
        timeout = 2000,
      })
    end)
  end, 500)
end

return M
