local telescope = require('telescope')
local pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local Finders = require('telescope.finders')
local conf = require('telescope.config').values
local action_state = require('telescope.actions.state')

local config = require('beads.config')
local util = require('beads.util')

local M = {}

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