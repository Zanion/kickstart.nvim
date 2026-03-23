local M = {}

local config = {
  worktree_root = nil,
}

local function get_repo_root()
  local cwd = vim.fn.getcwd()
  local output = vim.fn.system({
    "git",
    "-C",
    cwd,
    "rev-parse",
    "--show-toplevel",
  })
  if vim.v.shell_error ~= 0 then
    return cwd
  end
  return vim.fn.fnamemodify(output:gsub("%s+$", ""), ":p"):gsub("/$", "")
end

--- Run git in repo root so worktrees/branches are always created in the intended repo
--- (Neovim cwd may differ from the project root).
local function git_cmd(repo_root, git_args)
  local cmd = { "git", "-C", repo_root }
  vim.list_extend(cmd, git_args)

  if vim.system then
    local r = vim.system(cmd, { text = true }):wait()
    if r.code ~= 0 then
      return nil, (r.stderr or "") .. (r.stdout or "")
    end
    return r.stdout or "", nil
  end

  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, out
  end
  return out, nil
end

local function resolve_path(path)
  if not path then
    return nil
  end

  if path:match("^/") then
    return path
  elseif path:match("^~") then
    return vim.fn.expand(path)
  else
    return vim.fn.fnamemodify(get_repo_root() .. "/" .. path, ":p")
  end
end

function M.get_root()
  local root = config.worktree_root or ".worktree/"
  return resolve_path(root)
end

function M.ensure_root()
  local root = M.get_root()
  if vim.fn.isdirectory(root) == 0 then
    vim.fn.mkdir(root, "p")
  end
  return root
end

function M.is_gitignored(root)
  local gitignore_path = get_repo_root() .. "/.gitignore"
  if vim.fn.filereadable(gitignore_path) == 0 then
    return false
  end

  local content = vim.fn.readfile(gitignore_path)
  if not content then
    return false
  end

  local root_name = vim.fn.fnamemodify(root, ":t")
  for _, line in ipairs(content) do
    if line == root_name or line == root or line == "./" .. root_name then
      return true
    end
  end
  return false
end

function M.add_to_gitignore(root)
  local gitignore_path = get_repo_root() .. "/.gitignore"
  local root_name = vim.fn.fnamemodify(root, ":t")

  local lines = {}
  if vim.fn.filereadable(gitignore_path) == 1 then
    lines = vim.fn.readfile(gitignore_path)
  end

  for _, line in ipairs(lines) do
    if line == root_name or line == root then
      return true
    end
  end

  table.insert(lines, root_name)
  -- Ensure .gitignore has trailing newline
  table.insert(lines, "")
  vim.fn.writefile(lines, gitignore_path)
  return true
end

local function generate_slug(title)
  if not title or title == "" then
    return "untitled"
  end

  title = title:sub(1, 100):lower()
  title = title:gsub("[%s_]+", "-")
  title = title:gsub("[^a-z0-9%-]", "")
  title = title:gsub("%-+", "-")
  title = title:gsub("^%-", ""):gsub("%-$", "")
  title = title:sub(1, 50)

  if title == "" then
    return "untitled"
  end

  return title
end

local function build_worktree_name(bead_id, slug, counter)
  if counter == 1 or not counter then
    return string.format("feature-%s-%s", bead_id, slug)
  else
    return string.format("feature-%s-%d-%s", bead_id, counter, slug)
  end
end

local function get_existing_worktrees()
  local root = M.get_root()
  if vim.fn.isdirectory(root) == 0 then
    return {}
  end

  local repo_root = get_repo_root()
  local output, err = git_cmd(repo_root, { "worktree", "list", "--porcelain" })
  if not output then
    return {}
  end

  local worktrees = {}
  local current = nil

  for line in output:gmatch("[^\r\n]+") do
    if line:match("^worktree ") then
      if current then
        table.insert(worktrees, current)
      end
      current = {
        path = line:gsub("^worktree ", ""),
      }
    elseif line:match("^branch ") and current then
      current.branch = line:gsub("^branch ", "")
    end
  end

  if current then
    table.insert(worktrees, current)
  end

  return worktrees
end

local function get_counter_for_bead(bead_id)
  local repo_root = get_repo_root()
  local output, err = git_cmd(repo_root, { "worktree", "list", "--porcelain" })
  if not output then
    return 0
  end

  local max_counter = 0

  -- Parse git worktree list and extract counters from branches
  local current_branch = nil
  for line in output:gmatch("[^\r\n]+") do
    if line:match("^worktree ") then
      -- New worktree entry, reset current_branch
      current_branch = nil
    elseif line:match("^branch ") then
      current_branch = line:gsub("^branch ", "")
      -- Look for counter in branch name: feature-{bead-id}-{counter}-{slug}
      -- Match pattern like "feature-bd-42-1-some-feature"
      if current_branch then
        -- Escape bead_id for use in Lua pattern
        local escaped_id = bead_id:gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
        local counter = current_branch:match("feature%-" .. escaped_id .. "%-(%d+)%-")
        if counter then
          max_counter = math.max(max_counter, tonumber(counter))
        end
      end
    end
  end

  return max_counter
end

function M.create(bead_id, title, opts)
  opts = opts or {}
  local counter = opts.counter or (get_counter_for_bead(bead_id) + 1)
  local slug = opts.slug or generate_slug(title)

  local name = build_worktree_name(bead_id, slug, counter)

  -- Validate length (git branch name limit is 255 chars)
  if #name > 255 then
    return nil, "ENAME: Worktree name too long (max 255 chars)"
  end

  local root = M.ensure_root()
  local path = root .. "/" .. name

  if vim.fn.isdirectory(path) == 1 then
    return nil, "EEXIST: Worktree already exists"
  end

  local branch = name

  local repo_root = get_repo_root()
  local _, err = git_cmd(repo_root, {
    "worktree",
    "add",
    "-b",
    branch,
    path,
    "HEAD",
  })
  if err then
    return nil, "EGIT: " .. err
  end

  if not M.is_gitignored(root) then
    M.add_to_gitignore(root)
  end

  return {
    path = path,
    branch = branch,
    name = name,
    bead_id = bead_id,
  }
end

function M.list()
  local repo_root = get_repo_root()
  local output, err = git_cmd(repo_root, { "worktree", "list", "--porcelain" })
  if not output then
    return {}
  end

  local worktrees = {}
  local current = nil

  for line in output:gmatch("[^\r\n]+") do
    if line:match("^worktree ") then
      if current then
        table.insert(worktrees, current)
      end
      current = {
        path = line:gsub("^worktree ", ""),
      }
    elseif line:match("^branch ") and current then
      current.branch = line:gsub("^branch ", "")
    end
  end

  if current then
    table.insert(worktrees, current)
  end

  return worktrees
end

function M.remove(worktree_id)
  local path = worktree_id
  if not path:match("^/") then
    path = M.get_root() .. "/" .. worktree_id
  end

  if vim.fn.isdirectory(path) == 0 then
    return false, "ENOTDIR: Worktree not found"
  end

  local repo_root = get_repo_root()
  local _, rm_err = git_cmd(repo_root, { "worktree", "remove", path })
  if rm_err then
    return false, "EGIT: " .. rm_err
  end

  return true
end

function M.get_path(worktree_id)
  if worktree_id:match("^/") then
    return worktree_id
  end
  return M.get_root() .. "/" .. worktree_id
end

function M.exists(name)
  local worktrees = M.list()
  for _, wt in ipairs(worktrees) do
    local wt_name = vim.fn.fnamemodify(wt.path, ":t")
    if wt_name == name then
      return true
    end
  end
  return false
end

function M.setup(opts)
  if opts and opts.worktree_root ~= nil then
    config.worktree_root = opts.worktree_root
  end
end

return M
