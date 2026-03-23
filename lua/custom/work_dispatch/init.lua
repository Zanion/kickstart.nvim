local M = {}

local worktree = require("custom.work_dispatch.worktree")
local registry = require("custom.work_dispatch.registry")
local agent = require("custom.agent")

local config = {
  worktree_root = nil,
  keybind = "<leader>aa",
  max_parallel = 5,
  bead_filter = "ready",
}

function M.setup(opts)
  if opts then
    if opts.worktree_root ~= nil then
      config.worktree_root = opts.worktree_root
    end
    if opts.keybind ~= nil then
      config.keybind = opts.keybind
    end
    if opts.max_parallel ~= nil then
      config.max_parallel = opts.max_parallel
    end
    if opts.bead_filter ~= nil then
      config.bead_filter = opts.bead_filter
    end
  end

  worktree.setup({ worktree_root = config.worktree_root })

  vim.api.nvim_create_user_command("WorkDispatch", function()
    M.pick_dispatch()
  end, {
    desc = "Open work dispatch picker",
  })

  vim.api.nvim_create_user_command("WorkDispatchList", function()
    M.list_active()
  end, {
    desc = "List active worktrees",
  })

  if config.keybind and config.keybind ~= "" then
    vim.keymap.set("n", config.keybind, function()
      M.pick_dispatch()
    end, {
      desc = "Work Dispatch",
      silent = true,
    })
  end
end

function M.get_config()
  return config
end

function M.dispatch(bead_id, agent_name, opts)
  opts = opts or {}

  local worktree_info, err = worktree.create(bead_id, opts.title or "")
  if not worktree_info then
    return nil, err
  end

  worktree_info.bead_title = opts.title
  worktree_info.agent = agent_name

  local entry = registry.create(worktree_info)
  if not entry then
    worktree.remove(worktree_info.name)
    return nil, "Failed to create registry entry"
  end

  local snacks = require("snacks")
  local cmd = agent_name

  local env = {
    "BEAD_ID=" .. bead_id,
    "WORKTREE_ID=" .. entry.id,
    "NVIM_WORKTREE=" .. worktree_info.path,
  }

  if opts.env then
    for k, v in pairs(opts.env) do
      table.insert(env, k .. "=" .. v)
    end
  end

  local full_cmd = table.concat(env, " ") .. " " .. cmd

  snacks.terminal.toggle(full_cmd, {
    cwd = worktree_info.path,
    win = { style = "float", border = "rounded" },
  })

  registry.update(entry.id, {
    status = "running",
    session_id = os.date("%s"),
  })

  return entry
end

function M.list_active()
  local worktrees = registry.list()

  if #worktrees == 0 then
    vim.notify("No active worktrees", vim.log.levels.INFO, {
      title = "Work Dispatch",
    })
    return
  end

  local items = {}
  for _, wt in ipairs(worktrees) do
    table.insert(items, {
      id = wt.id,
      display = string.format("%s (%s) - %s", wt.name, wt.agent or "unknown", wt.status),
      name = wt.name,
      bead_id = wt.bead_id,
      agent = wt.agent,
      status = wt.status,
    })
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Active Worktrees",
    finder = finders.new_table {
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.name,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.focus(selection.value.id)
      end)
      return true
    end,
  }):find()
end

function M.focus(worktree_id)
  local entry = registry.get(worktree_id)
  if not entry then
    vim.notify("Worktree not found: " .. worktree_id, vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return nil, "Worktree not found"
  end

  local snacks = require("snacks")
  local terminal_matcher = entry.agent or "worktree"

  for _, terminal in pairs(snacks.terminal.list()) do
    local buf = terminal.buf
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match(terminal_matcher) and name:match(entry.path) then
        terminal:open()
        return entry
      end
    end
  end

  vim.notify("Terminal not found for: " .. entry.name, vim.log.levels.WARN, {
    title = "Work Dispatch",
  })

  vim.cmd("cd " .. vim.fn.fnameescape(entry.path))

  return entry
end

function M.pick_dispatch()
  local beads = require("custom.work_dispatch.beads")
  local ready_beads = beads.get_ready()

  if #ready_beads == 0 then
    vim.notify("No ready beads found", vim.log.levels.INFO, {
      title = "Work Dispatch",
    })
    return
  end

  local items = {}
  for _, bead in ipairs(ready_beads) do
    table.insert(items, {
      id = bead.id,
      display = bead.title,
      title = bead.title,
      priority = bead.priority,
    })
  end

  table.sort(items, function(a, b)
    return (a.priority or 4) < (b.priority or 4)
  end)

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Select Bead",
    finder = finders.new_table {
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.id,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.pick_agent(selection.value)
      end)
      return true
    end,
  }):find()
end

function M.pick_agent(bead)
  local agent_list = {}
  for name, _ in pairs(agent.agents) do
    table.insert(agent_list, {
      name = name,
      display = name,
    })
  end

  if #agent_list == 0 then
    vim.notify("No agents configured", vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Select Agent",
    finder = finders.new_table {
      results = agent_list,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.name,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.dispatch(bead.id, selection.value.name, {
          title = bead.title,
        })
      end)
      return true
    end,
  }):find()
end

function M.get_status(worktree_id)
  local entry = registry.get(worktree_id)
  if not entry then
    return nil
  end
  return entry.status
end

function M.set_status(worktree_id, status)
  return registry.set_status(worktree_id, status)
end

M.worktree = worktree
M.registry = registry
M.beads = nil
M.agent = agent

function M.load_beads()
  if not M.beads then
    M.beads = require("custom.work_dispatch.beads")
  end
  return M.beads
end

return M
