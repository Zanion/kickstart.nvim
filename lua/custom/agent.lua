local M = {}

M.session_cache = {}
M.is_refreshing = {}
M.callbacks = {}

M.default_agents = {
  gemini = {
    name = "Gemini",
    icon = "󰚩 ",
    cmd = "gemini",
    nvim_env = true,
    list_cmd = { "gemini", "--list-sessions" },
    resume_pattern = "gemini --resume %s",
    parse_fn = function(stdout)
      local sessions = {}
      for line in stdout:gmatch("[^\r\n]+") do
        local id = line:match("%[([a-f0-9%-]+)%]$")
        if id then
          local display = line:gsub("^%s*%d+%.%s*", ""):gsub("%s*%[[a-f0-9%-]+%]$", "")
          table.insert(sessions, {
            id = id,
            text = display,
            cmd = "gemini --resume " .. id,
          })
        end
      end
      for i = #sessions, 1, -1 do
        table.insert(sessions, sessions[i])
      end
      return sessions
    end,
    terminal_matcher = "gemini",
  },
  cursor = {
    name = "Cursor",
    icon = "󱎂 ",
    cmd = "agent",
    nvim_env = true,
    terminal_matcher = "agent",
  },
  claude = {
    name = "Claude",
    icon = "󱃔 ",
    cmd = "claude",
    nvim_env = true,
    list_cmd = { "sh", "-c", "ls -t ~/.claude/sessions/ 2>/dev/null | head -20 || echo" },
    resume_pattern = "claude -r %s",
    parse_fn = function(stdout)
      local sessions = {}
      for line in stdout:gmatch("[^\r\n]+") do
        line = line:gsub("%.md$", "")
        if line and line ~= "" then
          local parts = {}
          for part in line:gmatch("[^%-]+") do
            table.insert(parts, part)
          end
          local id = line
          local display = line
          if #parts >= 2 then
            display = parts[#parts]
          end
          display = display:gsub("^%s+", ""):gsub("%s+$", "")
          if display == "" then
            display = line
          end
          table.insert(sessions, {
            id = id,
            text = display,
            cmd = "claude -r " .. id,
          })
        end
      end
      return sessions
    end,
    terminal_matcher = "claude",
  },
  opencode = {
    name = "OpenCode",
    icon = "󱎓 ",
    cmd = "opencode",
    nvim_env = true,
    list_cmd = { "opencode", "session", "list" },
    resume_pattern = "opencode --session %s",
    parse_fn = function(stdout)
      local sessions = {}
      for line in stdout:gmatch("[^\r\n]+") do
        local id = line:match("%[([a-f0-9]+)%]") or line:match("([a-f0-9%-]+)")
        if id then
          local display = line:gsub("%[%a-%]%s*$", ""):gsub("%s*%[[a-f0-9%-]+%]%s*$", ""):gsub("^%s*", ""):gsub("%s*$", "")
          if display == "" then
            display = id
          end
          table.insert(sessions, {
            id = id,
            text = display,
            cmd = "opencode --session " .. id,
          })
        end
      end
      return sessions
    end,
    terminal_matcher = "opencode",
  },
}

M.agents = vim.deepcopy(M.default_agents)

function M.setup(opts)
  if opts and opts.agents then
    for name, config in pairs(opts.agents) do
      if M.agents[name] then
        vim.tbl_deep_extend("force", M.agents[name], config)
      else
        M.agents[name] = config
      end
    end
  end

  vim.defer_fn(function()
    local notify = require("notify")
    local loading = notify("Initializing Agents...", vim.log.levels.INFO, {
      title = "Agent Wrapper",
      icon = "󰚩 ",
      timeout = false,
    })

    local count = 0
    local total = vim.tbl_count(M.agents)

    for name, _ in pairs(M.agents) do
      M.refresh_sessions(name, function()
        count = count + 1
        if count >= total then
          notify("Agents Ready", vim.log.levels.INFO, {
            replace = loading,
            icon = "󰄬 ",
            timeout = 2000,
          })
        end
      end)
    end
  end, 500)
end

local function parse_sessions(agent_name, stdout)
  local agent = M.agents[agent_name]
  if not agent or not agent.parse_fn then
    return {}
  end
  local sessions = agent.parse_fn(stdout)
  if agent_name == "gemini" then
    local reversed = {}
    for i = #sessions, 1, -1 do
      table.insert(reversed, sessions[i])
    end
    return reversed
  end
  return sessions
end

function M.refresh_sessions(agent_name, callback)
  if not M.agents[agent_name] then
    return
  end

  if callback then
    if not M.callbacks[agent_name] then
      M.callbacks[agent_name] = {}
    end
    table.insert(M.callbacks[agent_name], callback)
  end

  if M.is_refreshing[agent_name] then
    return
  end
  M.is_refreshing[agent_name] = true

  local agent = M.agents[agent_name]
  if not agent.list_cmd then
    vim.schedule(function()
      M.is_refreshing[agent_name] = false
      M.session_cache[agent_name] = {}
      if M.callbacks[agent_name] then
        for _, cb in ipairs(M.callbacks[agent_name]) do
          cb({})
        end
        M.callbacks[agent_name] = {}
      end
    end)
    return
  end

  vim.system(agent.list_cmd, { text = true }, function(obj)
    vim.schedule(function()
      M.is_refreshing[agent_name] = false
      if obj.code == 0 then
        M.session_cache[agent_name] = parse_sessions(agent_name, obj.stdout)
      else
        M.session_cache[agent_name] = {}
      end

      if M.callbacks[agent_name] then
        for _, cb in ipairs(M.callbacks[agent_name]) do
          cb(M.session_cache[agent_name])
        end
        M.callbacks[agent_name] = {}
      end
    end)
  end)
end

local function get_agent_terminal(agent_name)
  local snacks = require("snacks")
  local matcher = M.agents[agent_name] and M.agents[agent_name].terminal_matcher or agent_name
  for _, terminal in pairs(snacks.terminal.list()) do
    local buf = terminal.buf
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match(matcher) then
        return terminal
      end
    end
  end
  return nil
end

function M.toggle_agent(agent_name)
  local terminal = get_agent_terminal(agent_name)

  if terminal then
    terminal:toggle()
    return
  end

  local agent = M.agents[agent_name]
  if agent_name == "cursor" then
    local nvim_env = agent.nvim_env and ("env NVIM=" .. vim.fn.shellescape(vim.v.servername) .. " ") or ""
    require("snacks").terminal.toggle(nvim_env .. "agent agent", {
      win = { style = "float", border = "rounded" },
    })
    return
  end

  M.pick_session(agent_name)
end

function M.pick_session(agent_name)
  if not agent_name then
    M.pick_agent()
    return
  end

  local agent = M.agents[agent_name]
  if not agent then
    return
  end

  if agent_name == "cursor" then
    local nvim_env = agent.nvim_env and ("env NVIM=" .. vim.fn.shellescape(vim.v.servername) .. " ") or ""
    require("snacks").terminal.toggle(nvim_env .. "agent ls", {
      win = { style = "float", border = "rounded" },
    })
    return
  end

  local sessions = M.session_cache[agent_name] or {}

  local notify = require("notify")
  local loading = notify("Fetching " .. agent.name .. " sessions...", vim.log.levels.INFO, {
    title = agent.name,
    icon = agent.icon,
    timeout = false,
  })

  M.refresh_sessions(agent_name, function(sessions)
    notify(agent.name .. " Ready", vim.log.levels.INFO, {
      replace = loading,
      icon = agent.icon,
      timeout = 2000,
    })
    M.show_session_picker(agent_name, sessions)
  end)
end

function M.pick_agent()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local agent_list = {}
  for name, agent in pairs(M.agents) do
    table.insert(agent_list, {
      name = name,
      text = agent.icon .. " " .. agent.name,
      display = agent.icon .. " " .. agent.name,
    })
  end

  table.sort(agent_list, function(a, b)
    return a.name < b.name
  end)

  pickers.new({}, {
    prompt_title = "Select Agent",
    finder = finders.new_table {
      results = agent_list,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.name,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.pick_session(selection.value.name)
      end)
      return true
    end,
  }):find()
end

function M.show_session_picker(agent_name, sessions)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local snacks = require("snacks")

  local agent = M.agents[agent_name]
  if not agent then
    return
  end

  local session_list = {
    {
      id = "new",
      text = "New Session",
      display = "  <New Session>",
      cmd = agent.cmd,
    },
  }

  for _, session in ipairs(sessions) do
    table.insert(session_list, {
      id = session.id,
      text = session.text,
      display = "  " .. session.text,
      cmd = session.cmd,
    })
  end

  pickers.new({}, {
    prompt_title = agent.name .. ": Select Session",
    finder = finders.new_table {
      results = session_list,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.text,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()

        local nvim_env = ""
        if agent.nvim_env then
          nvim_env = "env NVIM=" .. vim.fn.shellescape(vim.v.servername) .. " "
        end

        snacks.terminal.toggle(nvim_env .. selection.value.cmd, {
          win = { style = "float", border = "rounded" },
        })

        vim.defer_fn(function()
          M.refresh_sessions(agent_name)
        end, 1000)
      end)
      return true
    end,
  }):find()
end

function M.toggle()
  M.pick_agent()
end

return M
