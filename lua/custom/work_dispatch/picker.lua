local M = {}

local registry = require("custom.work_dispatch.registry")

local agent_icons = {
  gemini = "🤖",
  claude = "🧠",
  opencode = "🔧",
  anthropic = "🔵",
  default = "○",
}

local status_icons = {
  running = "●",
  needs_input = "⚠",
  paused = "○",
  done = "✓",
  rejected = "✗",
  ready = "○",
}

local status_colors = {
  running = "TelescopeResultsIcon",
  needs_input = "TelescopeResultsCommentIcon",
  paused = "TelescopeResultsNumber",
  done = "TelescopeResultsSpecialComment",
  rejected = "TelescopeResultsLineNr",
  ready = "TelescopeResultsNumber",
}

local current_filters = {}
local picker_instance = nil

local function get_all_worktrees()
  registry.invalidate_cache()
  return registry.list()
end

local function entry_maker(entry)
  local icon = agent_icons[entry.agent] or agent_icons.default
  local status_icon = status_icons[entry.status] or "○"
  local needs_input_mark = entry.needs_input and "⚠" or " "

  return {
    value = entry,
    display = string.format(
      "%s %-8s │ %-12s │ %-30s │ %s %s",
      icon,
      entry.agent or "unknown",
      entry.bead_id or "",
      entry.name or "",
      status_icon,
      needs_input_mark
    ),
    ordinal = string.format(
      "%s %s %s %s",
      entry.agent or "",
      entry.bead_id or "",
      entry.name or "",
      entry.status or ""
    ),
  }
end

local function sort_entries(entries)
  table.sort(entries, function(a, b)
    local a_val = a.value
    local b_val = b.value

    if a_val.needs_input and not b_val.needs_input then
      return true
    elseif not a_val.needs_input and b_val.needs_input then
      return false
    end

    if a_val.needs_input and b_val.needs_input then
      local a_time = a_val.needs_input_since or a_val.created_at or ""
      local b_time = b_val.needs_input_since or b_val.created_at or ""
      return a_time < b_time
    end

    local status_priority = {
      running = 1,
      needs_input = 2,
      paused = 3,
      ready = 4,
      done = 5,
      rejected = 6,
    }
    local a_priority = status_priority[a_val.status] or 10
    local b_priority = status_priority[b_val.status] or 10
    if a_priority ~= b_priority then
      return a_priority < b_priority
    end

    local a_time = a_val.created_at or ""
    local b_time = b_val.created_at or ""
    return a_time < b_time
  end)
  return entries
end

local function apply_filters(worktrees, opts)
  if not opts then
    opts = current_filters
  end

  local filtered = {}
  for _, wt in ipairs(worktrees) do
    local include = true

    if opts.agent and opts.agent ~= "" then
      include = include and (wt.agent == opts.agent)
    end

    if opts.status and opts.status ~= "" then
      include = include and (wt.status == opts.status)
    end

    if opts.bead_id and opts.bead_id ~= "" then
      include = include and (wt.bead_id == opts.bead_id)
    end

    if include then
      table.insert(filtered, wt)
    end
  end

  return filtered
end

local function focus_agent(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  actions.close(prompt_bufnr)

  local work_dispatch = require("custom.work_dispatch")
  work_dispatch.focus(entry.id)
end

local function merge_agent(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  actions.close(prompt_bufnr)

  if entry.status == "done" then
    vim.notify("Already merged: " .. entry.name, vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return
  end

  if entry.status == "rejected" then
    vim.notify("Cannot merge rejected work: " .. entry.name, vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return
  end

  local work_dispatch = require("custom.work_dispatch")
  local merge = require("custom.work_dispatch.actions.merge")

  local ok = vim.fn.input("Merge " .. entry.name .. "? (y/n): ")
  if ok == "y" or ok == "Y" then
    local result = merge.execute(entry.id)

    if result and result.success then
      vim.notify("PR created: " .. result.pr_url, vim.log.levels.INFO, {
        title = "Merge Complete",
      })
    else
      vim.notify("Merge failed: " .. (result and result.error or "Unknown error"), vim.log.levels.ERROR, {
        title = "Work Dispatch",
      })
    end
  end
end

local function reject_agent(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  actions.close(prompt_bufnr)

  local ok = vim.fn.input("Reject " .. entry.name .. "? (y/n): ")
  if ok == "y" or ok == "Y" then
    local work_dispatch = require("custom.work_dispatch")
    work_dispatch.agent.terminate(entry.session_id)
    work_dispatch.set_status(entry.id, "rejected")
    vim.notify("Rejected: " .. entry.name, vim.log.levels.INFO, {
      title = "Work Dispatch",
    })
  end
end

local function reset_agent(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  actions.close(prompt_bufnr)

  if entry.status ~= "rejected" and entry.status ~= "paused" then
    vim.notify("Reset only available for rejected or paused agents", vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return
  end

  local work_dispatch = require("custom.work_dispatch")

  work_dispatch.set_status(entry.id, "ready")

  registry.update(entry.id, {
    reset_count = (entry.reset_count or 0) + 1,
    last_reset = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })

  vim.notify("Reset: " .. entry.name, vim.log.levels.INFO, {
    title = "Work Dispatch",
  })
end

local function filter_by_agent(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  current_filters.agent = entry.agent

  actions.close(prompt_bufnr)
  M.open()
end

local function filter_by_status(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  current_filters.status = entry.status

  actions.close(prompt_bufnr)
  M.open()
end

local function filter_by_bead(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")

  local selection = action_state.get_selected_entry()
  if not selection or not selection.value then
    return
  end

  local entry = selection.value
  current_filters.bead_id = entry.bead_id

  actions.close(prompt_bufnr)
  M.open()
end

local function clear_filters()
  current_filters = {}
  M.open()
end

function M.open()
  local worktrees = get_all_worktrees()
  local filtered = apply_filters(worktrees)

  local items = {}
  for _, wt in ipairs(filtered) do
    table.insert(items, entry_maker(wt))
  end

  local sorted = sort_entries(items)

  if #sorted == 0 then
    vim.notify("No active agents", vim.log.levels.INFO, {
      title = "Active Agents",
    })
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  -- Get snacks for terminal access
  local snacks = nil
  local ok, snacks_mod = pcall(require, "snacks")
  if ok then
    snacks = snacks_mod
  end

  -- Create terminal previewer
  local previewer = nil
  if snacks and snacks.terminal then
    local previewers = require("telescope.previewers")
    previewer = previewers.new_buffer_previewer({
      get_buffer_by_name = function(_, entry)
        return "worktree_preview:" .. entry.value.id
      end,
      define_preview = function(self, entry)
        local wt = entry.value
        
        -- Find terminal buffer for this worktree
        local terminal_buf = nil
        if snacks then
          for _, term in pairs(snacks.terminal.list()) do
            if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
              local buf_name = vim.api.nvim_buf_get_name(term.buf)
              if buf_name:match(wt.name) or buf_name:match(wt.agent or "") then
                terminal_buf = term.buf
                break
              end
            end
          end
        end
        
        -- Get terminal content
        local lines = {}
        if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
          lines = vim.api.nvim_buf_get_lines(terminal_buf, 0, -1, false)
        end
        
        if #lines == 0 then
          lines = { "Terminal not running", "Press <CR> to start agent" }
        end
        
        -- Take last 100 lines
        local max_lines = 100
        if #lines > max_lines then
          lines = vim.list_slice(lines, #lines - max_lines + 1, #lines)
        end
        
        -- Add header
        local header = {
          "=== " .. (wt.agent or "agent") .. " | " .. (wt.bead_id or "N/A") .. " | " .. (wt.status or "unknown") .. " ===",
          "",
        }
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.list_extend(header, lines))
      end,
    })
  end

  picker_instance = pickers.new({}, {
    prompt_title = "Active Agents",
    finder = finders.new_table {
      results = sorted,
      entry_maker = entry_maker,
    },
    sorter = conf.generic_sorter({}),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", focus_agent)
      map("n", "<CR>", focus_agent)

      map("i", "<leader>m", merge_agent)
      map("n", "<leader>m", merge_agent)

      map("i", "<leader>r", reject_agent)
      map("n", "<leader>r", reject_agent)

      map("i", "<leader>R", reset_agent)
      map("n", "<leader>R", reset_agent)

      map("i", "q", actions.close)
      map("n", "q", actions.close)

      -- Filter mappings (both insert and normal mode)
      map("i", "<leader>fa", filter_by_agent)
      map("n", "<leader>fa", filter_by_agent)
      map("i", "<leader>fs", filter_by_status)
      map("n", "<leader>fs", filter_by_status)
      map("i", "<leader>fb", filter_by_bead)
      map("n", "<leader>fb", filter_by_bead)
      map("i", "<leader>fc", clear_filters)
      map("n", "<leader>fc", clear_filters)

      return true
    end,
  })

  picker_instance:find()
end

function M.refresh()
  if picker_instance then
    vim.cmd("bufdo e")
    M.open()
  else
    M.open()
  end
end

function M.filter(opts)
  if opts then
    current_filters = vim.tbl_extend("force", current_filters, opts)
  end
  M.open()
end

function M.get_filters()
  return current_filters
end

function M.clear_filters()
  current_filters = {}
end

function M.set_status_icon(status)
  return status_icons[status] or "○"
end

function M.set_agent_icon(agent)
  return agent_icons[agent] or agent_icons.default
end

return M