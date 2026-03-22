local M = {}

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

function M.pick_session()
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local snacks = require("snacks")

  -- 1. Get the list of sessions
  local handle = io.popen("gemini --list-sessions 2>/dev/null")
  if not handle then
    vim.notify("Could not run gemini --list-sessions", vim.log.levels.ERROR)
    return
  end
  local result = handle:read("*a")
  handle:close()

  local sessions = { { id = "new", text = "  <New Session>", cmd = "gemini" } }
  
  -- Parse output: 1. Description... (time) [id]
  for line in result:gmatch("[^\r\n]+") do
    local id = line:match("%[([a-f0-9%-]+)%]$")
    if id then
      -- Clean up description for display
      local display_text = line:gsub("^%s*%d+%.%s*", ""):gsub("%s*%[[a-f0-9%-]+%]$", "")
      table.insert(sessions, { 
        id = id, 
        text = "󰚩  " .. display_text,
        cmd = "gemini --resume " .. id 
      })
    end
  end

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
      end)
      return true
    end,
  }):find()
end

return M
