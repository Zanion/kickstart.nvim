local M = {}

local registry = require("custom.work_dispatch.registry")

local _server_started = false

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
  vim.api.nvim_create_autocmd("RpcNotify", {
    group = vim.api.nvim_create_augroup("WorkDispatchIPC", { clear = true }),
    callback = function(args)
      local data = args.data or {}
      local method = data.method
      local rpc_args = data.args or {}

      if method == "plugin_notify" then
        local event = rpc_args[1]
        local payload = rpc_args[2] or {}
        if event then
          M.handle(event, payload)
        end
      end
    end,
  })
end

function M.handle(event, payload)
  if not payload or type(payload) ~= "table" then
    vim.notify("IPC: Invalid payload for event " .. tostring(event), vim.log.levels.WARN, {
      title = "Work Dispatch IPC",
    })
    return
  end

  if event == "needs_input" then
    M.update_registry(payload.worktree_id, event, payload)
    M.show_notification(payload)
    M.refresh_picker()
  elseif event == "status" then
    M.update_registry(payload.worktree_id, event, payload)
    vim.notify(payload.message or "Status update", vim.log.levels.INFO, {
      title = "Agent Status",
    })
  elseif event == "complete" then
    M.update_registry(payload.worktree_id, event, payload)
    M.show_notification(payload)
    M.refresh_picker()
  elseif event == "error" then
    M.update_registry(payload.worktree_id, event, payload)
    vim.notify(payload.message or "Agent error", vim.log.levels.ERROR, {
      title = "Agent Error",
    })
    M.refresh_picker()
  else
    vim.notify("IPC: Unknown event type: " .. tostring(event), vim.log.levels.WARN, {
      title = "Work Dispatch IPC",
    })
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
