local M = {}

local registry = require("custom.work_dispatch.registry")

M.refresh_timer = nil
M.current_entry = nil
M.preview_bufnr = nil

local default_opts = {
  max_lines = 100,
  refresh_interval = 1500,
}

local current_opts = vim.tbl_extend("force", {}, default_opts)

function M.setup(opts)
  current_opts = vim.tbl_extend("force", current_opts, opts or {})
end

function M.strip_ansi(text)
  return text:gsub("\27%[[%d;]*m", "")
end

function M.format_lines(lines)
  local formatted = {}
  for _, line in ipairs(lines) do
    table.insert(formatted, M.strip_ansi(line))
  end
  return formatted
end

function M.get_terminal_buf(worktree_id)
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks or not snacks.terminal then
    return nil
  end

  local wt = registry.get(worktree_id)
  if not wt then
    return nil
  end

  for _, term in pairs(snacks.terminal.list()) do
    if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
      local buf_name = vim.api.nvim_buf_get_name(term.buf)
      if buf_name:match(wt.name) or buf_name:match(wt.agent or "") then
        return term.buf
      end
    end
  end

  return nil
end

function M.is_closed(session_id)
  local term_buf = M.get_terminal_buf(session_id)
  return term_buf == nil or not vim.api.nvim_buf_is_valid(term_buf)
end

function M.show(session_id)
  local wt = registry.get(session_id)
  if not wt then
    return { "No active session" }
  end

  local term_buf = M.get_terminal_buf(session_id)

  local lines = {}
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
    lines = M.format_lines(lines)
  end

  if #lines == 0 then
    lines = { "Terminal not running", "Press <CR> to start agent" }
  end

  if #lines > current_opts.max_lines then
    lines = vim.list_slice(lines, #lines - current_opts.max_lines + 1, #lines)
  end

  local header = {
    "=== " .. (wt.agent or "agent") .. " | " .. (wt.bead_id or "N/A") .. " | " .. (wt.status or "unknown") .. " ===",
    "",
  }

  return vim.list_extend(header, lines)
end

function M.refresh(session_id)
  return M.show(session_id)
end

function M.render_to_buf(bufnr, session_id)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = M.show(session_id)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

function M.start_live_refresh(winid, bufnr, session_id)
  M.stop_live_refresh()

  M.preview_bufnr = bufnr
  M.current_entry = session_id

  M.refresh_timer = vim.loop.new_timer()
  M.refresh_timer:start(
    current_opts.refresh_interval,
    current_opts.refresh_interval,
    vim.schedule_wrap(function()
      if not winid or not vim.api.nvim_win_is_valid(winid) then
        M.stop_live_refresh()
        return
      end

      if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        M.stop_live_refresh()
        return
      end

      M.render_to_buf(bufnr, session_id)
    end)
  )
end

function M.stop_live_refresh()
  if M.refresh_timer then
    M.refresh_timer:stop()
    if not M.refresh_timer:is_closing() then
      M.refresh_timer:close()
    end
    M.refresh_timer = nil
  end

  M.preview_bufnr = nil
  M.current_entry = nil
end

return M
