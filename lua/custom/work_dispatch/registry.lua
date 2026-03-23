local M = {}

local worktree = require("custom.work_dispatch.worktree")

local registry_cache = nil

local STATUSES = {
  "ready",
  "running",
  "needs_input",
  "paused",
  "done",
  "rejected",
}

local function get_registry_path()
  local root = worktree.get_root()
  return root .. "/registry.json"
end

local function generate_uuid()
  return vim.fn.system({ "uuidgen" }):gsub("%s+$", ""):gsub("%-", ""):sub(1, 8)
end

local function get_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.load()
  -- Return cached data if available
  if registry_cache then
    return registry_cache
  end

  local path = get_registry_path()

  if vim.fn.filereadable(path) == 0 then
    local data = { version = 1, worktrees = {} }
    registry_cache = data
    return data
  end

  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then
    local data = { version = 1, worktrees = {} }
    registry_cache = data
    return data
  end

  local content = table.concat(lines, "\n")
  local ok, data = pcall(vim.json.decode, content)

  if not ok or not data then
    local empty_data = { version = 1, worktrees = {} }
    registry_cache = empty_data
    return empty_data
  end

  registry_cache = data
  return data
end

function M.save(data)
  local path = get_registry_path()
  local root = worktree.get_root()

  if vim.fn.isdirectory(root) == 0 then
    vim.fn.mkdir(root, "p")
  end

  local temp_path = path .. ".tmp"
  local content = vim.json.encode(data)

  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  vim.fn.writefile(lines, temp_path)

  vim.fn.rename(temp_path, path)
  registry_cache = data

  return true
end

function M.create(worktree_info)
  local data = M.load()

  -- Validate status if provided
  if worktree_info.status then
    local valid = false
    for _, s in ipairs(STATUSES) do
      if s == worktree_info.status then
        valid = true
        break
      end
    end
    if not valid then
      return nil, "Invalid status: " .. worktree_info.status
    end
  end

  local entry = {
    id = generate_uuid(),
    path = worktree_info.path,
    branch = worktree_info.branch,
    name = worktree_info.name,
    bead_id = worktree_info.bead_id,
    bead_title = worktree_info.bead_title or nil,
    agent = worktree_info.agent or nil,
    session_id = nil,
    status = worktree_info.status or "ready",
    needs_input = false,
    needs_input_since = nil,
    created_at = get_timestamp(),
    updated_at = get_timestamp(),
    merge_commit = nil,
    pr_url = nil,
  }

  table.insert(data.worktrees, entry)
  M.save(data)

  return entry
end

function M.get(id)
  local data = M.load()

  for _, wt in ipairs(data.worktrees) do
    if wt.id == id or wt.name == id then
      return wt
    end
  end

  return nil
end

function M.list()
  local data = M.load()
  return data.worktrees or {}
end

function M.update(id, updates)
  local data = M.load()

  for i, wt in ipairs(data.worktrees) do
    if wt.id == id or wt.name == id then
      for key, value in pairs(updates) do
        if key ~= "id" and key ~= "created_at" then
          data.worktrees[i][key] = value
        end
      end
      data.worktrees[i].updated_at = get_timestamp()
      M.save(data)
      return data.worktrees[i]
    end
  end

  return nil
end

function M.delete(id)
  local data = M.load()

  local found = false
  local new_worktrees = {}

  for _, wt in ipairs(data.worktrees) do
    if wt.id == id or wt.name == id then
      found = true
    else
      table.insert(new_worktrees, wt)
    end
  end

  if found then
    data.worktrees = new_worktrees
    M.save(data)
  end

  return found
end

function M.find_by_bead(bead_id)
  local data = M.load()
  local results = {}

  for _, wt in ipairs(data.worktrees) do
    if wt.bead_id == bead_id then
      table.insert(results, wt)
    end
  end

  return results
end

function M.find_by_status(status)
  local data = M.load()
  local results = {}

  for _, wt in ipairs(data.worktrees) do
    if wt.status == status then
      table.insert(results, wt)
    end
  end

  return results
end

function M.find_by_name(name)
  -- Delegate to get() for consistency
  return M.get(name)
end

function M.get_names_by_bead(bead_id)
  local worktrees = M.find_by_bead(bead_id)
  local names = {}

  for _, wt in ipairs(worktrees) do
    table.insert(names, wt.name)
  end

  return names
end

function M.set_status(id, status)
  local valid = false
  for _, s in ipairs(STATUSES) do
    if s == status then
      valid = true
      break
    end
  end

  if not valid then
    return nil, "Invalid status: " .. status
  end

  return M.update(id, { status = status })
end

function M.set_needs_input(id, needs_input)
  local updates = {
    needs_input = needs_input,
    needs_input_since = needs_input and get_timestamp() or nil,
  }

  if needs_input then
    updates.status = "needs_input"
  else
    updates.status = "running"
  end

  return M.update(id, updates)
end

function M.invalidate_cache()
  registry_cache = nil
end

-- Alias functions for API consistency with requirements
M.get_by_bead = M.find_by_bead
M.get_by_status = M.find_by_status
M.remove = M.delete

return M
