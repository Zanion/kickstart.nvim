local M = {}

local registry = require("custom.work_dispatch.registry")

local _server_started = false

local VALID_EVENTS = {
  ["needs_input"] = true,
  ["status"] = true,
  ["complete"] = true,
  ["error"] = true,
}

local MAX_STRING_LENGTH = 4096

local function sanitize_string(value)
  if type(value) ~= "string" then
    return nil
  end
  if #value > MAX_STRING_LENGTH then
    value = value:sub(1, MAX_STRING_LENGTH)
  end
  return value:gsub("[\x00-\x08\x0b\x0c\x0e-\x1f]", "")
end

local function validate_payload(event, payload)
  if type(payload) ~= "table" then
    return false, "Payload must be a table"
  end

  local worktree_id = payload.worktree_id
  if not worktree_id or type(worktree_id) ~= "string" or worktree_id == "" then
    return false, "Missing or invalid worktree_id"
  end

  local entry = registry.get(worktree_id)
  if not entry then
    return false, "Unknown worktree_id: " .. worktree_id
  end

  return true
end

function M.setup()
  if _server_started then
    return
  end

  local socket = vim.v.servername
  if not socket or socket == "" then
    socket = vim.fn.serverstart()
  end

  if socket and socket ~= "" then
    vim.env.NVIM_LISTEN_ADDRESS = socket
    _server_started = true
  end

  M.register_handler()
end

function M.register_handler()
  -- IPC notifications via Neovim's RPC are handled differently
  -- External agents can send notifications via the NVIM socket
  -- The plugin receives these through the rpcstart mechanism
  -- For now, we mark the handler as registered to prevent duplicate setup
  _handler_registered = true
end

function M.handle(event, payload)
  if not event or type(event) ~= "string" or not VALID_EVENTS[event] then
    vim.notify("IPC: Unknown or invalid event type: " .. tostring(event), vim.log.levels.WARN, {
      title = "Work Dispatch IPC",
    })
    return
  end

  if not payload or type(payload) ~= "table" then
    vim.notify("IPC: Invalid payload for event " .. tostring(event), vim.log.levels.WARN, {
      title = "Work Dispatch IPC",
    })
    return
  end

  local valid, err = validate_payload(event, payload)
  if not valid then
    vim.notify("IPC: Validation failed: " .. err, vim.log.levels.WARN, {
      title = "Work Dispatch IPC",
    })
    return
  end

  local safe_payload = {
    worktree_id = payload.worktree_id,
    message = sanitize_string(payload.message),
    summary = sanitize_string(payload.summary),
    level = sanitize_string(payload.level),
    options = payload.options,
    files_changed = type(payload.files_changed) == "table" and payload.files_changed or nil,
  }

  if event == "needs_input" then
    M.update_registry(safe_payload.worktree_id, event, safe_payload)
    M.show_notification(safe_payload)
    M.refresh_picker()
  elseif event == "status" then
    M.update_registry(safe_payload.worktree_id, event, safe_payload)
    vim.notify(safe_payload.message or "Status update", vim.log.levels.INFO, {
      title = "Agent Status",
    })
  elseif event == "complete" then
    M.update_registry(safe_payload.worktree_id, event, safe_payload)
    M.show_notification(safe_payload)
    M.refresh_picker()
  elseif event == "error" then
    M.update_registry(safe_payload.worktree_id, event, safe_payload)
    vim.notify(safe_payload.message or "Agent error", vim.log.levels.ERROR, {
      title = "Agent Error",
    })
    M.refresh_picker()
  end
end

function M.update_registry(worktree_id, event, payload)
  if not worktree_id then
    return
  end

  local entry = registry.get(worktree_id)
  if not entry then
    return
  end

  if event == "needs_input" then
    registry.set_needs_input(worktree_id, true)
  elseif event == "status" then
    local level = payload.level or "info"
    local status_update = {
      last_status_message = payload.message,
      last_status_level = level,
    }
    registry.update(worktree_id, status_update)
  elseif event == "complete" then
    registry.update(worktree_id, {
      status = "done",
      needs_input = false,
      needs_input_since = nil,
      summary = payload.summary,
      files_changed = payload.files_changed,
    })
  elseif event == "error" then
    registry.update(worktree_id, {
      needs_input = false,
      needs_input_since = nil,
      last_error = payload.message,
    })
  end
end

function M.show_notification(payload)
  local ok, notify = pcall(require, "notify")
  if not ok then
    local level = vim.log.levels.INFO
    vim.notify(payload.message or payload.summary or "Agent notification", level, {
      title = "Work Dispatch",
    })
    return
  end

  if payload.options then
    notify(payload.message or "Input required", "info", {
      title = "Agent Input Required",
      timeout = false,
    })
  elseif payload.summary then
    notify(payload.summary, "info", {
      title = "Agent Complete",
    })
  elseif payload.message then
    notify(payload.message, "info", {
      title = "Agent Notification",
    })
  end
end

function M.refresh_picker()
  local ok, picker = pcall(require, "custom.work_dispatch.picker")
  if ok and picker.refresh then
    picker.refresh()
  end
end

function M.clear_needs_input(worktree_id)
  if not worktree_id then
    return
  end

  registry.set_needs_input(worktree_id, false)
  M.refresh_picker()
end

return M
