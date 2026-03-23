local M = {}

local worktree = require("custom.work_dispatch.worktree")
local registry = require("custom.work_dispatch.registry")
local ipc = require("custom.work_dispatch.ipc.handler")

local sessions = {}

local function generate_session_id()
  return "session-" .. vim.fn.system({ "uuidgen" }):gsub("%s+$", ""):gsub("%-", ""):sub(1, 8)
end

local function generate_socket_path(session_id)
  -- Use XDG_RUNTIME_DIR if available for better security
  local runtime_dir = vim.env.XDG_RUNTIME_DIR or "/tmp"
  return runtime_dir .. "/nvim-" .. session_id .. ".sock"
end

local function get_snacks()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("snacks plugin not installed - terminal features disabled", vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return nil
  end
  return snacks
end

local function get_agent_module()
  local ok, agent_module = pcall(require, "custom.agent")
  if not ok then
    vim.notify("custom.agent module not found - agent features disabled", vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return { agents = {} }
  end
  return agent_module
end

local config = {
  worktree_root = nil,
  keybind = "<leader>aa",
  max_parallel = 5,
  bead_filter = "ready",
  dispatch = {
    auto_claim = true,
    auto_focus = true,
    confirm_parallel = true,
  },
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
    if opts.dispatch then
      if opts.dispatch.auto_claim ~= nil then
        config.dispatch.auto_claim = opts.dispatch.auto_claim
      end
      if opts.dispatch.auto_focus ~= nil then
        config.dispatch.auto_focus = opts.dispatch.auto_focus
      end
      if opts.dispatch.confirm_parallel ~= nil then
        config.dispatch.confirm_parallel = opts.dispatch.confirm_parallel
      end
    end
  end

  worktree.setup({ worktree_root = config.worktree_root })

  ipc.setup()

  local agent_mod = get_agent_module()
  if agent_mod and agent_mod.setup then
    agent_mod.setup()
  end

  setup_terminal_close_handler()

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

  vim.keymap.set("n", "<leader>aa", function()
    require("custom.work_dispatch.picker").open()
  end, {
    desc = "Active Agents Picker",
    silent = true,
  })
end

function M.get_config()
  return config
end

function M.dispatch(bead_id, agent_name, opts)
  opts = opts or {}

  local agent_mod = get_agent_module()
  if not agent_mod.agents[agent_name] then
    return nil, "EINVALID: Invalid agent name: " .. agent_name
  end

  local beads_mod = require("custom.work_dispatch.beads")
  local bead = beads_mod.get_bead(bead_id)
  if not bead then
    return nil, "ENOTFOUND: Bead not found: " .. bead_id
  end

  -- Check parallel limit
  local existing = registry.find_by_bead(bead_id)
  local active_count = 0
  for _, wt in ipairs(existing) do
    if wt.status ~= "rejected" and wt.status ~= "done" then
      active_count = active_count + 1
    end
  end

  if active_count >= config.max_parallel then
    return nil, string.format(
      "Max parallel agents (%d) reached for %s",
      config.max_parallel,
      bead_id
    )
  end

  -- Check if same agent already working on this bead
  if config.dispatch.confirm_parallel then
    for _, wt in ipairs(existing) do
      if wt.agent == agent_name and wt.status ~= "rejected" and wt.status ~= "done" then
        local choice = vim.fn.confirm(
          agent_name .. " already working on " .. bead_id .. ".\nUse existing or create parallel?",
          "&Use Existing\n&Create Parallel\n&Cancel",
          1
        )
        if choice == 1 then
          return M.focus(wt.id)
        elseif choice == 3 or choice == 0 then
          return nil, "Cancelled"
        end
        -- choice == 2 continues to create parallel
        break
      end
    end
  end

  local worktree_info, err = worktree.create(bead_id, opts.title or "")
  if not worktree_info then
    return nil, err
  end

  worktree_info.bead_title = opts.title or bead.title
  worktree_info.agent = agent_name

  local entry = registry.create(worktree_info)
  if not entry then
    local remove_ok, remove_err = worktree.remove(worktree_info.name)
    if not remove_ok then
      vim.notify("Failed to cleanup worktree: " .. remove_err, vim.log.levels.WARN, {
        title = "Work Dispatch",
      })
    end
    return nil, "Failed to create registry entry"
  end

  beads_mod.create_context(worktree_info.path, bead)

  local session = M.agent.spawn({
    path = worktree_info.path,
    branch = worktree_info.branch,
    name = worktree_info.name,
    id = entry.id,
    bead_id = bead_id,
  }, agent_name)

  if not session then
    registry.update(entry.id, { status = "failed" })
    worktree.remove(worktree_info.name)
    return nil, "ESPAWN: Failed to spawn agent terminal"
  end

  sessions[session.session_id] = session

  registry.update(entry.id, {
    status = "running",
    session_id = session.session_id,
    terminal_id = session.terminal_id,
    pid = session.pid,
    nvim_socket = session.nvim_socket,
  })

  if config.dispatch.auto_claim then
    beads_mod.claim(bead_id)
  end

  if config.dispatch.auto_focus then
    M.agent.focus(session.session_id)
  end

  return {
    success = true,
    worktree = worktree_info,
    bead = bead,
    session = session,
  }
end

function M.cancel(worktree_id)
  local entry = registry.get(worktree_id)
  if not entry then
    return false, "Worktree not found"
  end

  if entry.session_id then
    M.agent.terminate(entry.session_id)
  end

  if entry.path and vim.fn.isdirectory(entry.path) == 1 then
    worktree.remove(entry.name)
  end

  registry.delete(entry.id)

  return true
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
        if not selection or not selection.value then
          return
        end
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

  if entry.needs_input then
    ipc.clear_needs_input(worktree_id)
  end

  if entry.session_id then
    local result = M.agent.focus(entry.session_id)
    if result then
      return entry
    end
  end

  if entry.agent and entry.status == "paused" then
    local worktree_info = {
      path = entry.path,
      branch = entry.branch,
      name = entry.name,
      id = entry.id,
      bead_id = entry.bead_id,
    }
    local session = M.agent.spawn(worktree_info, entry.agent)
    if session then
      sessions[session.session_id] = session
      registry.update(entry.id, {
        status = "running",
        session_id = session.session_id,
        terminal_id = session.terminal_id,
        pid = session.pid,
        nvim_socket = session.nvim_socket,
      })
      M.agent.focus(session.session_id)
      return entry
    end
  end

  local snacks = get_snacks()
  if not snacks then
    return nil, "snacks plugin required"
  end

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

  vim.fn.chdir(entry.path)

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
        if not selection or not selection.value then
          return
        end
        M.pick_agent(selection.value)
      end)
      return true
    end,
  }):find()
end

function M.pick_agent(bead)
  local agent_module = get_agent_module()
  local agent_list = {}
  for name, _ in pairs(agent_module.agents or {}) do
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
        if not selection or not selection.value then
          return
        end
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
M.ipc = ipc
M.picker = nil

M.actions = {
  merge = nil,
}

function M.load_actions()
  if not M.actions.merge then
    M.actions.merge = require("custom.work_dispatch.actions.merge")
  end
  return M.actions
end

function M.load_beads()
  if not M.beads then
    M.beads = require("custom.work_dispatch.beads")
  end
  return M.beads
end

-- Socket cleanup function
local function cleanup_socket(session)
  if session and session.nvim_socket and vim.fn.filereadable(session.nvim_socket) == 1 then
    vim.fn.delete(session.nvim_socket)
  end
end

local function setup_terminal_close_handler()
  local snacks = get_snacks()
  if not snacks then
    return
  end

  vim.schedule(function()
    local term = snacks.terminal
    -- Skip if handler already set up to avoid duplicate registration
    if term and term.on_close and term.on_close._work_dispatch_setup then
      return
    end

    local close_handler = function(term_info)
      for session_id, session in pairs(sessions) do
        if session.terminal_id == term_info.id then
          -- Clean up socket on unexpected close
          cleanup_socket(session)
          registry.update(session.worktree_id, {
            status = "paused",
          })
          sessions[session_id].status = "paused"
          break
        end
      end
    end

    if term and term.on_close then
      local old_handler = term.on_close
      term.on_close = function(...)
        close_handler(...)
        if old_handler then
          old_handler(...)
        end
      end
      -- Mark as setup to prevent duplicate registration
      term.on_close._work_dispatch_setup = true
    end
  end)
end

M.agent = {}

function M.agent.spawn(worktree_info, agent_name)
  local snacks = get_snacks()
  if not snacks then
    return nil
  end

  local session_id = generate_session_id()
  local nvim_socket = generate_socket_path(session_id)

  local agent_mod = get_agent_module()
  local agent_config = agent_mod.agents[agent_name]
  if not agent_config then
    return nil
  end

  local cmd = agent_config.cmd

  local full_cmd = string.format(
    "NVIM_LISTEN_ADDRESS=%s BEAD_ID=%s WORKTREE_ID=%s %s",
    vim.fn.shellescape(nvim_socket),
    worktree_info.bead_id or "",
    worktree_info.id or "",
    cmd
  )

  local terminal = snacks.terminal.toggle(full_cmd, {
    cwd = worktree_info.path,
    win = { style = "float", border = "rounded" },
    id = session_id,
  })

  if not terminal then
    return nil
  end

  local session = {
    session_id = session_id,
    worktree_id = worktree_info.id,
    worktree_path = worktree_info.path,
    bead_id = worktree_info.bead_id,
    agent = agent_name,
    terminal_id = terminal.id,
    terminal_buf = terminal.buf,
    pid = terminal.pid or 0,
    nvim_socket = nvim_socket,
    status = "running",
    started_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  return session
end

function M.agent.focus(session_id)
  local session = sessions[session_id]
  if not session then
    local entry = registry.get(session_id)
    if not entry then
      return nil, "Session not found"
    end

    local worktree_info = {
      path = entry.path,
      branch = entry.branch,
      name = entry.name,
      id = entry.id,
      bead_id = entry.bead_id,
    }
    local new_session = M.agent.spawn(worktree_info, entry.agent)
    if new_session then
      sessions[new_session.session_id] = new_session
      registry.update(entry.id, {
        status = "running",
        session_id = new_session.session_id,
        terminal_id = new_session.terminal_id,
      })
      session = new_session
    else
      return nil, "Failed to respawn session"
    end
  end

  local snacks = get_snacks()
  if not snacks then
    return nil
  end

  for _, terminal in pairs(snacks.terminal.list()) do
    if terminal.id == session.terminal_id then
      terminal:open()
      return session
    end
  end

  session.status = "paused"
  registry.update(session.worktree_id, { status = "paused" })

  return nil, "Terminal not found"
end

local function cleanup_socket(session)
  if session and session.nvim_socket then
    vim.fn.delete(session.nvim_socket)
  end
end

function M.agent.terminate(session_id)
  local session = sessions[session_id]
  if not session then
    return nil, "Session not found"
  end

  local snacks = get_snacks()
  if snacks then
    for _, terminal in pairs(snacks.terminal.list()) do
      if terminal.id == session.terminal_id then
        terminal:close()
        break
      end
    end
  end

  -- Clean up socket file
  cleanup_socket(session)

  sessions[session_id] = nil

  registry.update(session.worktree_id, {
    status = "rejected",
  })

  return true
end

function M.agent.get_status(session_id)
  local session = sessions[session_id]
  if session then
    return session.status
  end

  local entry = registry.get(session_id)
  if entry then
    return entry.status
  end

  return nil
end

function M.agent.list()
  return sessions
end

function M.agent.get(session_id)
  return sessions[session_id]
end

function M.agent.get_by_worktree(worktree_id)
  local result = {}
  for _, session in pairs(sessions) do
    if session.worktree_id == worktree_id then
      table.insert(result, session)
    end
  end
  return result
end

function M.load_picker()
  if not M.picker then
    M.picker = require("custom.work_dispatch.picker")
  end
  return M.picker
end

return M
