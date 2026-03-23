local M = {}

local registry = require("custom.work_dispatch.registry")
local beads = require("custom.work_dispatch.beads")

local function get_snacks()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks or nil
end

local function get_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.validate(worktree_id)
  local worktree = registry.get(worktree_id)

  if not worktree then
    return false, "Worktree not found", nil
  end

  if worktree.status == "rejected" then
    return false, "Work was already rejected", nil
  end

  if worktree.status == "done" then
    return false, "Cannot reject completed work", nil
  end

  return true, nil, worktree
end

function M.kill_terminal(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  local session_id = worktree.session_id
  if not session_id then
    return true
  end

  local snacks = get_snacks()
  if not snacks then
    return true
  end

  for _, terminal in pairs(snacks.terminal.list()) do
    if terminal.id == session_id then
      terminal:close()
      break
    end
  end

  return true
end

function M.update_registry(worktree_id, reason)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  registry.update(worktree_id, {
    status = "rejected",
    rejected_at = get_timestamp(),
    rejected_reason = reason,
  })

  return true
end

function M.update_bead(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  if not worktree.bead_id then
    return true
  end

  local ok, err = beads.set_status(worktree.bead_id, "rejected")
  if not ok then
    vim.notify("Warning: Failed to update bead status: " .. (err or "unknown"), vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return false, err
  end

  return true
end

function M.notify(reason)
  local snacks = get_snacks()
  if snacks and snacks.notify then
    snacks.notify("Work rejected: " .. (reason or "No reason provided"), "warn", {
      title = "Work Dispatch",
    })
  else
    vim.notify("Work rejected: " .. (reason or "No reason provided"), vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
  end
end

function M.execute(worktree_id, reason)
  -- Validate returns the worktree object
  local valid, err, worktree = M.validate(worktree_id)
  if not valid then
    return { success = false, error = err }
  end

  -- Use worktree from validate instead of redundant registry.get()
  local kill_ok = M.kill_terminal(worktree_id)
  
  -- Check bead update (don't fail整个 reject, but log warning)
  local bead_ok = M.update_bead(worktree_id)
  if not bead_ok then
    vim.notify("Warning: Failed to update bead status", vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
  end

  local reg_ok = M.update_registry(worktree_id, reason)
  if not reg_ok then
    return { success = false, error = "Failed to update registry" }
  end

  M.notify(reason)

  return {
    success = true,
    worktree_id = worktree_id,
    reason = reason,
  }
end

return M
