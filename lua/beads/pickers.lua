local telescope = require('telescope')
local pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local Finders = require('telescope.finders')
local Previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local action_state = require('telescope.actions.state')

local config = require('beads.config')
local util = require('beads.util')
local Job = require('plenary.job')

local M = {}

local function make_entry(issue)
  return {
    value = issue,
    display = string.format('%s [%s] %s', issue.id, issue.issue_type, issue.title),
    ordinal = issue.id .. ' ' .. issue.title .. ' ' .. (issue.description or ''),
  }
end

--- Format issue for display
--- @param issue table Issue object
--- @return table Lines for display
local function format_issue(issue)
  local lines = {}

  table.insert(lines, string.format('ID: %s', issue.id))
  table.insert(lines, string.format('Title: %s', issue.title))
  table.insert(lines, string.format('Type: %s', issue.issue_type))
  table.insert(lines, string.format('State: %s', issue.status))

  if issue.labels and #issue.labels > 0 then
    table.insert(lines, 'Labels: ' .. table.concat(issue.labels, ', '))
  end

  table.insert(lines, '')

  if issue.description then
    table.insert(lines, 'Description:')
    table.insert(lines, issue.description)
    table.insert(lines, '')
  end

  if issue.dependencies and #issue.dependencies > 0 then
    table.insert(lines, 'Dependencies:')
    for _, dep in ipairs(issue.dependencies) do
      table.insert(lines, string.format('  - %s (%s)', dep.depends_on_id, dep.type))
    end
  end

  if issue.dependents and #issue.dependents > 0 then
    table.insert(lines, '')
    table.insert(lines, 'Dependents (blocked by this):')
    for _, dep in ipairs(issue.dependents) do
      table.insert(lines, string.format('  - %s (%s)', dep.id, dep.title or ''))
    end
  end

  return lines
end

--- Create a custom previewer for issues
--- @return table Telescope previewer
local function issue_previewer()
  return Previewers.new_buffer_previewer({
    title = 'Issue Preview',
    define_preview = function(self, entry)
      local issue = entry.value
      local lines = format_issue(issue)

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
    end,
  })
end

--- Run a bd command and return parsed JSON array
--- @param args table Command arguments
--- @param callback function Callback with parsed issues
local function run_bd_json(args, callback)
  local output = {}
  local job = Job:new({
    command = config.get().binary,
    args = vim.list_extend(args, { '--json' }),
    on_stdout = function(_, line)
      table.insert(output, line)
    end,
    on_stderr = function(_, err)
      vim.notify('bd error: ' .. err, vim.log.levels.WARN)
    end,
    on_exit = vim.schedule_wrap(function()
      local combined = table.concat(output, '')
      local ok, result = pcall(vim.json.decode, combined)
      if ok and type(result) == 'table' then
        callback(result)
      else
        vim.notify('Failed to parse bd output', vim.log.levels.ERROR)
        callback({})
      end
    end),
  })
  job:start()
end

--- Create a picker with a finder from pre-fetched data
--- @param opts table Picker options
--- @param issues table Array of issues
local function create_picker(opts, issues)
  local entries = {}
  for _, issue in ipairs(issues) do
    table.insert(entries, make_entry(issue))
  end

  pickers.new({}, {
    prompt_title = opts.prompt_title,
    finder = Finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return entry
      end,
    }),
    sorter = conf.generic_sorter(),
    previewer = issue_previewer(),
  }):find()
end

function M.list()
  run_bd_json({ 'list' }, function(issues)
    vim.schedule(function()
      create_picker({ prompt_title = 'Beads - All Issues' }, issues)
    end)
  end)
end

function M.ready()
  run_bd_json({ 'ready' }, function(issues)
    vim.schedule(function()
      create_picker({ prompt_title = 'Beads - Ready Issues' }, issues)
    end)
  end)
end

function M.blocked()
  run_bd_json({ 'blocked' }, function(issues)
    vim.schedule(function()
      create_picker({ prompt_title = 'Beads - Blocked Issues' }, issues)
    end)
  end)
end

function M.search()
  vim.ui.input({ prompt = 'Search beads: ' }, function(query)
    if not query or query == '' then
      return
    end

    run_bd_json({ 'search', query }, function(issues)
      vim.schedule(function()
        create_picker({ prompt_title = 'Beads - Search: ' .. query }, issues)
      end)
    end)
  end)
end

return M
