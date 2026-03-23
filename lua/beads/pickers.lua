local telescope = require('telescope')
local pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local Finders = require('telescope.finders')
local conf = require('telescope.config').values
local action_state = require('telescope.actions.state')

local config = require('beads.config')
local Job = require('plenary.job')

local M = {}

local function parse_json_output(output)
  local ok, result = pcall(vim.json.decode, output)
  if not ok then
    vim.notify('Failed to parse bd output: ' .. result, vim.log.levels.ERROR)
    return {}
  end
  return result
end

local function run_bd_command(args, callback)
  local cfg = config.get()
  local cmd = cfg.binary
  table.insert(args, 1, cmd)
  table.insert(args, '--json')

  Job:new({
    command = cmd,
    args = args,
    on_stdout = function(_, output)
      callback(output)
    end,
    on_stderr = function(_, err)
      vim.notify('bd error: ' .. err, vim.log.levels.WARN)
    end,
  }):start()
end

local function make_entry(issue)
  return {
    value = issue,
    display = string.format('%s [%s] %s', issue.id, issue.issue_type, issue.title),
    ordinal = issue.id .. ' ' .. issue.title .. ' ' .. (issue.description or ''),
  }
end

local function open_preview(prompt_bufnr)
  local selection = action_state.get_selected_entry(prompt_bufnr)
  Actions.close(prompt_bufnr)
  vim.cmd(string.format(':BdShow %s', selection.value.id))
end

local function open_in_browser(prompt_bufnr)
  local selection = action_state.get_selected_entry(prompt_bufnr)
  Actions.close(prompt_bufnr)
  vim.cmd(string.format(':BdOpen %s', selection.value.id))
end

local function get_issues_list(args, callback)
  local output = {}
  local job = Job:new({
    command = config.get().binary,
    args = vim.list_extend({ '--json' }, args),
    on_stdout = function(_, line)
      table.insert(output, line)
    end,
    on_stderr = function(_, err)
      vim.notify('bd error: ' .. err, vim.log.levels.WARN)
    end,
    on_exit = function()
      local combined = table.concat(output, '')
      local issues = parse_json_output(combined)
      callback(issues)
    end,
  })
  job:start()
end

function M.list()
  pickers.new({}, {
    prompt_title = 'Beads - All Issues',
    finder = Finders.new_oneshot_job({
      command = { config.get().binary, 'list', '--json' },
      entry_maker = function(entry)
        local ok, issue = pcall(vim.json.decode, entry)
        if ok then
          return make_entry(issue)
        end
        return nil
      end,
    }),
    sorter = conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', open_in_browser)
      map('i', config.get().keymaps.show, open_preview)
      return true
    end,
  }):find()
end

function M.ready()
  pickers.new({}, {
    prompt_title = 'Beads - Ready Issues',
    finder = Finders.new_oneshot_job({
      command = { config.get().binary, 'ready', '--json' },
      entry_maker = function(entry)
        local ok, issue = pcall(vim.json.decode, entry)
        if ok then
          return make_entry(issue)
        end
        return nil
      end,
    }),
    sorter = conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', open_in_browser)
      map('i', config.get().keymaps.show, open_preview)
      return true
    end,
  }):find()
end

function M.blocked()
  pickers.new({}, {
    prompt_title = 'Beads - Blocked Issues',
    finder = Finders.new_oneshot_job({
      command = { config.get().binary, 'blocked', '--json' },
      entry_maker = function(entry)
        local ok, issue = pcall(vim.json.decode, entry)
        if ok then
          return make_entry(issue)
        end
        return nil
      end,
    }),
    sorter = conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', open_in_browser)
      map('i', config.get().keymaps.show, open_preview)
      return true
    end,
  }):find()
end

function M.search()
  pickers.new({}, {
    prompt_title = 'Beads - Search',
    finder = Finders.new_job({
      command = function(prompt)
        return { config.get().binary, 'search', prompt, '--json' }
      end,
      entry_maker = function(entry)
        local ok, issue = pcall(vim.json.decode, entry)
        if ok then
          return make_entry(issue)
        end
        return nil
      end,
      maximum_results = 100,
    }),
    sorter = conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', open_in_browser)
      map('i', config.get().keymaps.show, open_preview)
      return true
    end,

  }):find()
end

function M.query()
  vim.ui.input({ prompt = 'Enter BD query expression: ' }, function(query)
    if not query or query == '' then
      return
    end

    pickers.new({}, {
      prompt_title = 'Beads - Query: ' .. query,
      finder = Finders.new_oneshot_job({
        command = { config.get().binary, 'query', query, '--json' },
        entry_maker = function(entry)
          local ok, issue = pcall(vim.json.decode, entry)
          if ok then
            return make_entry(issue)
          end
          return nil
        end,
      }),
      sorter = conf.generic_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        map('i', '<CR>', open_in_browser)
        map('i', config.get().keymaps.show, open_preview)
        return true
      end,
    }):find()
  end)
end

return M