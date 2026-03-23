local M = {}

local registry = require("custom.work_dispatch.registry")
local beads = require("custom.work_dispatch.beads")

local function get_snacks()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks or nil
end

local function extract_bead_number(bead_id)
  if not bead_id or bead_id == "" then
    return nil
  end
  return bead_id:match("%d+")
end

local function has_uncommitted_changes(path)
  local result = vim.fn.system({
    "git", "status", "--porcelain"
  }, nil, { cwd = path })

  return vim.v.shell_error == 0 and result and result ~= ""
end

local function get_remote(path)
  local result = vim.fn.system({
    "git", "remote", "get-url", "origin"
  }, nil, { cwd = path })

  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result:gsub("%s+$", "")
end

function M.validate(worktree_id)
  local worktree = registry.get(worktree_id)

  if not worktree then
    return false, "Worktree not found"
  end

  if vim.fn.isdirectory(worktree.path) == 0 then
    return false, "Worktree directory does not exist"
  end

  if worktree.status == "done" then
    return false, "Already merged"
  end

  if worktree.status == "rejected" then
    return false, "Work was rejected"
  end

  local remote = get_remote(worktree.path)
  if not remote then
    return false, "No git remote configured"
  end

  return true
end

function M.commit(worktree_id)
  local worktree = registry.get(worktree_id)
  if not worktree then
    return false, "Worktree not found"
  end

  if not has_uncommitted_changes(worktree.path) then
    return true
  end

  vim.fn.system({
    "git", "add", "-A"
  }, nil, { cwd = worktree.path })

  if vim.v.shell_error ~= 0 then
    return false, "Failed to stage changes"
  end

  local bead_num = extract_bead_number(worktree.bead_id or "")
  local commit_msg = string.format([[
feat(%s): %s

%s

Closes #%s
]],
    worktree.bead_id or "unknown",
    (worktree.bead_title or "Untitled"):sub(1, 50),
    worktree.bead_title or "Untitled",
    bead_num
  )

  local result = vim.fn.system({
    "git", "commit", "-m", commit_msg
  }, nil, { cwd = worktree.path })

  if vim.v.shell_error ~= 0 then
    return false, "Commit failed: " .. result
  end

  return true
end

function M.push(branch, worktree_path)
  local result = vim.fn.system({
    "git", "push", "-u", "origin", branch
  }, nil, { cwd = worktree_path })

  if vim.v.shell_error ~= 0 then
    if result:match("rejected") then
      return false, "PUSH_REJECTED: Push rejected - branch may need rebasing"
    elseif result:match("no upstream") then
      return false, "PUSH_NO_UPSTREAM: Remote branch not found"
    else
      return false, "Push failed: " .. result
    end
  end

  local commit = result:match("(%x+)%.%.%s*(%x+)")
  return true, commit
end

function M.create_pr(worktree)
  local title = string.format("feat(%s): %s",
    worktree.bead_id or "unknown",
    worktree.bead_title or "Untitled"
  )

  local bead_num = extract_bead_number(worktree.bead_id or "")

  local body = string.format([[
## Summary
<!-- Brief description of changes -->

## Changes
<!-- Summary of what was implemented -->

## Testing
- [ ] Tests added/updated
- [ ] Manual testing completed

## Notes
<!-- Any additional context -->

Implements **%s**

Closes #%s
]],
    worktree.bead_id or "unknown",
    bead_num
  )

  -- Detect base branch (main or master)
  local base = "main"
  local base_check = vim.fn.system({
    "git", "rev-parse", "--verify", "main"
  }, nil, { cwd = worktree.path })
  if vim.v.shell_error ~= 0 then
    base = "master"
  end

  local result = vim.fn.system({
    "gh", "pr", "create",
    "--title", title,
    "--body", body,
    "--head", worktree.branch,
    "--base", base
  }, nil, { cwd = worktree.path })

  if vim.v.shell_error ~= 0 then
    if result:match("pull request already exists") then
      return false, "PR_EXISTS: Pull request already exists"
    end
    return false, "PR creation failed: " .. result
  end

  local url = result:match("(https://github%.com/[^\n]+)")
  return true, url
end

function M.close_bead(bead_id, path)
  local result = vim.fn.system({
    "bd", "close", bead_id,
    "--reason", "Implemented"
  }, nil, { cwd = path })

  if vim.v.shell_error ~= 0 then
    vim.notify("Warning: Failed to close bead: " .. result, vim.log.levels.WARN, {
      title = "Work Dispatch",
    })
    return false
  end

  return true
end

function M.notify_success(pr_url)
  local snacks = get_snacks()
  if snacks and snacks.notify then
    snacks.notify(pr_url, "info", {
      title = "Merge Complete",
      actions = {
        {
          id = "open-pr",
          label = "Open PR",
        },
        {
          id = "dismiss",
          label = "Dismiss",
        },
      },
      callback = function(notif, action)
        if action and action.id == "open-pr" then
          vim.fn.system({ "xdg-open", pr_url })
        end
      end,
    })
  else
    vim.notify("PR created: " .. pr_url, vim.log.levels.INFO, {
      title = "Merge Complete",
    })
  end
end

function M.execute(worktree_id)
  local valid, err = M.validate(worktree_id)
  if not valid then
    return { success = false, error = err }
  end

  local worktree = registry.get(worktree_id)
  if not worktree then
    return { success = false, error = "Worktree not found" }
  end

  local commit_ok, commit_err = M.commit(worktree_id)
  if not commit_ok then
    return { success = false, error = commit_err }
  end

  local push_ok, push_result = M.push(worktree.branch, worktree.path)
  if not push_ok then
    return { success = false, error = push_result }
  end

  local pr_ok, pr_url = M.create_pr(worktree)
  if not pr_ok then
    return { success = false, error = pr_url }
  end

  M.close_bead(worktree.bead_id, worktree.path)

  registry.update(worktree_id, {
    status = "done",
    pr_url = pr_url,
    merge_commit = push_result,
    merged_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })

  M.notify_success(pr_url)

  return { success = true, pr_url = pr_url }
end

return M
