local M = {}

--- Parse JSON output from bd commands
--- @param output string Raw JSON string to parse
--- @return table Parsed JSON table, or empty table on error
function M.parse_json_output(output)
  local ok, result = pcall(vim.json.decode, output)
  if not ok then
    vim.notify('Failed to parse bd output: ' .. result, vim.log.levels.ERROR)
    return {}
  end
  return result
end

--- Find an existing buffer by name, returning its number or nil
--- @param bufname string Buffer name to search for
--- @return number|nil Buffer number if found
function M.find_buffer(bufname)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == bufname then
      return bufnr
    end
  end
  return nil
end

--- Get or create a buffer with the given name
--- @param bufname string Desired buffer name
--- @return number Buffer number
function M.get_or_create_buffer(bufname)
  local existing = M.find_buffer(bufname)
  if existing then
    -- Clear and reuse existing buffer
    vim.api.nvim_buf_set_lines(existing, 0, -1, false, {})
    return existing
  end
  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, bufname)
  return bufnr
end

return M
