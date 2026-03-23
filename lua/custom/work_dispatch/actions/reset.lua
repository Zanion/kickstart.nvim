local M = {}

local registry = require("custom.work_dispatch.registry")
local beads = require("custom.work_dispatch.beads")

local function get_snacks()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks or nil
end

local function get_agent_module()
  local ok, agent_module = pcall(require, "custom.agent")
  if not ok then
    vim.notify("custom.agent module not found", vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return { agents = {} }
  end
  return agent_module
end

local function get_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.validate(worktree_id)
  local worktree = registry.get(worktree_id)

  if not worktree then
    return false, "Worktree not found", nil
  end

  if vim.fn.isdirectory(worktree.path) == 0 then
    return false, "Worktree directory not found", nil
  end

  -- Allow reset on: rejected, paused, needs_input, running (re-try)
  if worktree.status == "done" then
    return false, "Cannot reset completed work", nil
  end

  return true, nil, worktree
end

function M.confirm(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false
  end

  local confirmed = vim.fn.confirm(
    string.format(
      "Reset agent for %s?\n\nAgent will be relaunched.\n%s",
      worktree.bead_id or "unknown",
      worktree.status == "rejected" and "Bead will be reset to ready state." or ""
    ),
    { "Reset", "Cancel" },
    1
  )

  return confirmed == 1
end

function M.clear_needs_input(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  registry.update(worktree_id, {
    needs_input = false,
    needs_input_since = nil,
  })

  return true
end

function M.kill_terminal(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  local snacks = get_snacks()
  if not snacks then
    return true
  end

  -- Find and close terminal by session or worktree
  for _, terminal in pairs(snacks.terminal.list()) do
    if terminal.id == worktree.session_id then
      terminal:close()
      break
    end
  end

  return true
end

function M.respawn_agent(worktree)
  local snacks = get_snacks()
  if not snacks then
    return nil, "snacks plugin required"
  end

  local agent_mod = get_agent_module()
  local agent_config = agent_mod.agents[worktree.agent]

  if not agent_config then
    return nil, "Agent not configured: " .. (worktree.agent or "unknown")
  end

  -- Generate new session
  local session_id = "session-" .. vim.fn.system({ "uuidgen" }):gsub("%s+$", ""):gsub("%-", ""):sub(1, 8)
  local runtime_dir = vim.env.XDG_RUNTIME_DIR or "/tmp"
  local nvim_socket = runtime_dir .. "/nvim-" .. session_id .. ".sock"

  local cmd = string.format(
    "NVIM_LISTEN_ADDRESS=%s BEAD_ID=%s WORKTREE_ID=%s %s",
    vim.fn.shellescape(nvim_socket),
    worktree.bead_id or "",
    worktree.id or "",
    agent_config.cmd
  )

  snacks.terminal.toggle(cmd, {
    cwd = worktree.path,
    win = { style = "float", border = "rounded" },
  })

  return session_id
end

function M.update_registry(worktree_id, new_session_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  local updates = {
    status = "running",
    needs_input = false,
    needs_input_since = nil,
    reset_count = (worktree.reset_count or 0) + 1,
    last_reset = get_timestamp(),
    session_id = new_session_id,
  }

  registry.update(worktree_id, updates)

  return true
end

function M.reset_bead(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  if not worktree.bead_id then
    return true
  end

  -- Reset bead to ready if it was rejected
  if worktree.status == "rejected" then
    local ok, err = beads.update_status(worktree.bead_id, "ready")
    if not ok then
      vim.notify("Warning: Failed to reset bead status: " .. (err or "unknown"), vim.log.levels.WARN, {
        title = "Work Dispatch",
      })
      return false, err
    end
  end

  return true
end

function M.notify(success, worktree_id)
  local worktree = registry.get(worktree_id)
  local bead_id = worktree and worktree.bead_id or worktree_id

  local msg = success and ("Agent reset for " .. bead_id) or "Failed to reset agent"
  local level = success and vim.log.levels.INFO or vim.log.levels.ERROR

  local snacks = get_snacks()
  if snacks and snacks.notify then
    snacks.notify(msg, success and "info" or "error", {
      title = "Work Dispatch",
    })
  else
    vim.notify(msg, level, {
      title = "Work Dispatch",
    })
  end
end

function M.execute(worktree_id, opts)
  opts = opts or {}

  -- Validate
  local valid, err, worktree = M.validate(worktree_id)
  if not valid then
    return { success = false, error = err }
  end

  -- Confirm if needed
  if opts.confirm ~= false then
    local confirmed = M.confirm(worktree_id)
    if not confirmed then
      return { success = false, error = "Cancelled" }
    end
  end

  -- Kill existing terminal
  M.kill_terminal(worktree_id)

  -- Reset bead to ready if rejected
  M.reset_bead(worktree_id)

  -- Clear needs_input state
  M.clear_needs_input(worktree_id)

  -- Respawn agent
  local new_session_id = M.respawn_agent(worktree)
  if not new_session_id then
    M.notify(false, worktree_id)
    return { success = false, error = "Failed to respawn agent" }
  end

  -- Update registry
  local reg_ok = M.update_registry(worktree_id, new_session_id)
  if not reg_ok then
    return { success = false, error = "Failed to update registry" }
  end

  M.notify(true, worktree_id)

  return {
    success = true,
    session_id = new_session_id,
  }
end

return M
