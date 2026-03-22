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
  -- We don't use id="gemini" anymore, because Snacks.terminal.toggle uses tid(cmd, opts)
  -- Instead, we just check all open terminals to see if any are running gemini
  for _, terminal in pairs(snacks.terminal.get_all()) do
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
  local snacks = require("snacks")
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
        
        -- MERGE environment variables to avoid losing PATH/HOME/etc.
        local env = vim.tbl_extend("force", vim.fn.environ(), {
          NVIM = vim.v.servername,
        })

        snacks.terminal.toggle(selection.value.cmd, {
          win = { style = "float", border = "rounded" },
          env = env,
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
