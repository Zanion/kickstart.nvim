local M = {}

local config = {
  cmd_prefix = "bd",
}

-- Valid status values for validation
local VALID_STATUSES = {
  ["ready"] = true,
  ["in_progress"] = true,
  ["claimed"] = true,
  ["blocked"] = true,
  ["needs_review"] = true,
  ["done"] = true,
  ["implemented"] = true,
  ["cancelled"] = true,
  ["duplicate"] = true,
  ["rejected"] = true,
}

function M.setup(opts)
  if opts and opts.cmd_prefix then
    config.cmd_prefix = opts.cmd_prefix
  end
end

local function run_bd_command(args)
  local cmd = config.cmd_prefix .. " " .. args
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return nil, {
      code = vim.v.shell_error,
      message = output or "Beads command failed",
      cmd = cmd,
    }
  end

  if not output or output == "" then
    return {}, nil
  end

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok then
    return nil, {
      code = -1,
      message = "Failed to parse JSON output",
      cmd = cmd,
      raw = output,
    }
  end

  return decoded, nil
end

function M.get_ready()
  local beads, err = run_bd_command("ready --json")
  if err then
    vim.notify("Failed to fetch ready beads: " .. err.message, vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return {}
  end
  
  if not beads or (type(beads) == "table" and #beads == 0) then
    vim.notify("No ready beads found", vim.log.levels.DEBUG, {
      title = "Work Dispatch",
    })
  end
  
  return beads or {}
end

function M.get_bead(bead_id)
  if not bead_id or bead_id == "" then
    return nil, "Invalid bead ID"
  end

  local parsed_id = M.parse_id(bead_id)
  local bead, err = run_bd_command("show " .. parsed_id .. " --json")

  if err then
    vim.notify("Failed to fetch bead " .. bead_id .. ": " .. err.message, vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return nil, err.message
  end

  return bead, nil
end

function M.update_status(bead_id, status)
  if not bead_id or bead_id == "" then
    return nil, "Invalid bead ID"
  end

  if not status or status == "" then
    return nil, "Invalid status"
  end

  -- Validate status for injection
  if not status:match("^[%w_%-]+$") then
    return nil, "Invalid status format"
  end

  local parsed_id = M.parse_id(bead_id)
  local cmd_args

  if status == "in_progress" or status == "claimed" then
    cmd_args = "update " .. parsed_id .. " --claim --json"
  elseif status == "ready" then
    cmd_args = "update " .. parsed_id .. " --unclaim --json"
  elseif status == "done" or status == "implemented" then
    cmd_args = "close " .. parsed_id .. ' --reason "Implemented" --json'
  elseif status == "cancelled" then
    cmd_args = "close " .. parsed_id .. ' --reason "Cancelled" --json'
  elseif status == "duplicate" then
    cmd_args = "close " .. parsed_id .. ' --reason "Duplicate" --json'
  elseif status == "rejected" then
    cmd_args = "close " .. parsed_id .. ' --reason "Rejected" --json'
  else
    -- Validate arbitrary status
    if not VALID_STATUSES[status] then
      vim.notify("Warning: Non-standard status '" .. status .. "' used", vim.log.levels.WARN, {
        title = "Work Dispatch",
      })
    end
    cmd_args = "update " .. parsed_id .. " --status " .. status .. " --json"
  end

  local result, err = run_bd_command(cmd_args)

  if err then
    vim.notify("Failed to update bead " .. bead_id .. ": " .. err.message, vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return nil, err.message
  end

  return true, nil
end

function M.claim(bead_id)
  return M.update_status(bead_id, "in_progress")
end

function M.unclaim(bead_id)
  return M.update_status(bead_id, "ready")
end

function M.close(bead_id, reason)
  if not reason or reason == "" then
    reason = "Implemented"
  end
  return M.update_status(bead_id, reason)
end

function M.parse_id(bead_id)
  if not bead_id or bead_id == "" then
    return nil
  end

  local patterns = {
    "^([%w]+%-[%w]+)$",
    "^([%w]+%.[%w]+)$",
    "^([%w]+)$",
  }

  for _, pattern in ipairs(patterns) do
    local match = bead_id:match(pattern)
    if match then
      return match
    end
  end

  return bead_id
end

function M.create_context(worktree_path, bead)
  if not worktree_path or worktree_path == "" then
    return nil, "Invalid worktree path"
  end

  if not bead or type(bead) ~= "table" then
    return nil, "Invalid bead object"
  end

  if vim.fn.isdirectory(worktree_path) == 0 then
    return nil, "Worktree directory does not exist: " .. worktree_path
  end

  local context_path = vim.fn.joinpath(worktree_path, "BEADS_CONTEXT.md")
  local content = M.generate_context(bead)

  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local write_result = vim.fn.writefile(lines, context_path)
  if write_result ~= 0 then
    -- Get more specific error
    local err_msg = "Failed to write context file to " .. context_path
    if vim.fn.isdirectory(vim.fn.fnamemodify(context_path, ":h")) == 0 then
      err_msg = err_msg .. " - parent directory not writable"
    end
    return nil, err_msg
  end

  return true, nil
end

function M.generate_context(bead)
  local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

  local content = string.format([[# Bead: %s

## Title
%s

## Priority
%s

## Type
%s

---

## Description
%s

---

## Workflow

You must follow the beads-workflow:

1. **Claim**: Update bead status (already claimed for you)
2. **Analyze**: Understand requirements, ask clarifying questions
3. **Implement**: Write code following project conventions
4. **Test**: Verify your implementation
5. **Land**: Commit, push, and create PR

### Commit Format
```
feat(%s): %s

%s

Closes #%s
```

### PR Title Format
```
feat(%s): %s
```

---

## Project Context

Project: work_dispatch
Repository: (configured in git remote)
Main Branch: main

---

*Generated by work_dispatch on %s*
]],
    bead.id or "unknown",
    bead.title or "Untitled",
    bead.priority or "unknown",
    bead.issue_type or "task",
    bead.description or "No description provided.",
    bead.id or "unknown",
    (bead.title or "Untitled"):sub(1, 50),
    bead.title or "Untitled",
    M.extract_number(bead.id or ""),
    bead.id or "unknown",
    bead.title or "Untitled",
    timestamp
  )

  return content
end

function M.extract_number(bead_id)
  local num = bead_id:match("%d+")
  return num or "0"
end

function M.is_available()
  local cmd = config.cmd_prefix .. " --version"
  local output = vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

-- Required by SR-004: Set arbitrary status on bead
function M.set_status(bead_id, status)
  if not bead_id or bead_id == "" then
    return nil, "Invalid bead ID"
  end

  if not status or status == "" then
    return nil, "Invalid status"
  end

  -- Validate status for injection
  if not status:match("^[%w_%-]+$") then
    return nil, "Invalid status format"
  end

  local parsed_id = M.parse_id(bead_id)
  local cmd_args = "update " .. parsed_id .. " --status " .. status .. " --json"

  local result, err = run_bd_command(cmd_args)

  if err then
    vim.notify("Failed to set bead status " .. bead_id .. ": " .. err.message, vim.log.levels.ERROR, {
      title = "Work Dispatch",
    })
    return nil, err.message
  end

  return true, nil
end

-- Required by SR-006: Read back bead context from worktree
function M.get_context(worktree_path)
  if not worktree_path or worktree_path == "" then
    return nil, "Invalid worktree path"
  end

  local context_path = vim.fn.joinpath(worktree_path, "BEADS_CONTEXT.md")

  if vim.fn.filereadable(context_path) == 0 then
    return nil, "Context file not found"
  end

  local lines = vim.fn.readfile(context_path)
  if not lines or #lines == 0 then
    return nil, "Empty context file"
  end

  local content = table.concat(lines, "\n")

  -- Parse basic fields from the context markdown
  local bead = {}

  -- Extract bead ID from "# Bead: {id}"
  local id_match = content:match("# Bead: ([^\n]+)")
  bead.id = id_match and id_match:match("^%s*(.-)%s*$") or nil

  -- Extract title from "## Title\n{title}"
  local title_match = content:match("## Title\n([^\n]+)")
  bead.title = title_match and title_match:match("^%s*(.-)%s*$") or nil

  -- Extract priority from "## Priority\n{priority}"
  local priority_match = content:match("## Priority\n([^\n]+)")
  bead.priority = priority_match and tonumber(priority_match:match("%d+")) or nil

  -- Extract type from "## Type\n{type}"
  local type_match = content:match("## Type\n([^\n]+)")
  bead.issue_type = type_match and type_match:match("^%s*(.-)%s*$") or nil

  -- Extract description
  local desc_start = content:find("## Description\n")
  if desc_start then
    local desc_section = content:sub(desc_start + 15)
    local _, desc_end = desc_section:find("\n---")
    if desc_end then
      bead.description = desc_section:sub(1, desc_end - 1):match("^%s*(.-)%s*$")
    end
  end

  return bead, nil
end

-- API aliases for consistency with requirements
M.show = M.get_bead
M.ready = M.get_ready

return M
