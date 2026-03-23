# beads.nvim

A Neovim plugin for interacting with [bd](https://github.com/beads-cli/beads) (Beads), a CLI tool for managing issues across multiple issue trackers. This plugin provides Telescope pickers, issue previews, dependency graphs, and quick navigation to issues.

## Requirements

- Neovim 0.9+
- [bd](https://github.com/beads-cli/beads) CLI binary installed and in PATH
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

### Using lazy.nvim

```lua
-- lua/custom/plugins/beads.lua
return {
  'beads.nvim',
  lazy = false,
  init = function()
    local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':p:h')
    package.path = package.path .. ';' .. plugin_dir .. '/?.lua;' .. plugin_dir .. '/?/init.lua'
  end,
  config = function()
    require('beads').setup({})
  end,
}
```

### Manual Installation

If you're not using a plugin manager, add the plugin to your runtimepath and initialize it:

```lua
-- in your init.lua or a separate file
vim.cmd [[ set runtimepath+=path/to/beads.nvim ]]
require('beads').setup({})
```

## Quick Start

After installation, the plugin registers the following commands:

```vim
:BdList       " List all issues
:BdReady      " List ready issues
:BdBlocked    " List blocked issues
:BdSearch     " Live search issues
:BdQuery      " Query with custom expression
:BdShow 123   " Show issue 123 in vertical split
:BdShowH 123  " Show issue 123 in horizontal split
:BdOpen 123   " Open issue 123 in browser
:BdGraph      " Show dependency graph
:BdStatus     " Show database status
```

## Configuration

Configure the plugin by passing options to `setup()`:

```lua
require('beads').setup({
  -- Path to the bd binary (default: 'bd')
  binary = 'bd',

  -- Keymaps for Telescope pickers
  keymaps = {
    open = '<CR>',          -- Open in browser
    show = '<leader>i',     -- Show issue preview
    close = 'q',            -- Close picker/graph
  },

  -- Graph float window dimensions
  graph_width = 80,
  graph_height = 24,
})
```

### Default Configuration

```lua
{
  binary = 'bd',
  keymaps = {
    open = '<CR>',
    show = '<leader>i',
    close = 'q',
  },
  graph_width = 80,
  graph_height = 24,
}
```

## Command Reference

| Command | Description |
|---------|-------------|
| `:BdList` | Open a Telescope picker with all issues |
| `:BdReady` | List issues marked as ready |
| `:BdBlocked` | List issues that are blocked |
| `:BdSearch` | Live search - type to filter issues |
| `:BdQuery` | Query picker - enter a bd query expression |
| `:BdShow <id>` | Show issue details in a vertical split |
| `:BdShowH <id>` | Show issue details in a horizontal split |
| `:BdOpen <id>` | Open the issue in your default browser |
| `:BdGraph [id]` | Display dependency graph in a floating window |
| `:BdGraph --all` | Show full dependency graph for all issues |
| `:BdGraph --box` | Show graph in box format |
| `:BdGraph --compact` | Show graph in compact format |
| `:BdStatus` | Display database status and statistics |

## Keybindings

### Telescope Picker Keymaps

While in a Telescope picker:

| Key | Action |
|-----|--------|
| `<CR>` | Open selected issue in browser |
| `<leader>i` | Show issue preview in split |
| `<Esc>` or `q` | Close picker |

### Graph Float Keymaps

| Key | Action |
|-----|--------|
| `q` | Close graph window |
| `<Esc>` | Close graph window |

## Usage Examples

### List All Issues

```vim
:BdList
```

### Find Ready Issues

```vim
:BdReady
```

### Search for Issues

```vim
:BdSearch
-- Then type your search query
```

### Query Specific Issues

```vim
:BdQuery
-- Enter query expression (e.g., "type:bug status:open")
```

### View Issue Details

```vim
:BdShow 123
```

### Open in Browser

```vim
:BdOpen 123
```

### View Dependency Graph

```vim
:BdGraph              " Graph for current issue
:BdGraph 123          " Graph for specific issue
:BdGraph --all        " Full graph for all issues
:BdGraph --box        " Box format
:BdGraph 123 --compact " Compact format for specific issue
```

## Architecture

The plugin is organized into the following modules:

- `init.lua` - Main entry point, registers the setup function
- `config.lua` - Configuration management and defaults
- `commands.lua` - Vim command registration
- `pickers.lua` - Telescope picker implementations
- `preview.lua` - Issue preview in splits
- `navigation.lua` - Browser opening functionality
- `graph.lua` - Dependency graph floating window
- `status.lua` - Database status display

All modules communicate through the shared configuration in `config.lua`.

## Troubleshooting

### Binary Not Found

Ensure the `bd` binary is installed and available in your PATH. You can specify a custom path:

```lua
require('beads').setup({
  binary = '/full/path/to/bd',
})
```

### Telescope Not Loaded

The plugin depends on Telescope. Ensure it's installed and loaded before `beads.nvim`.

### JSON Parse Errors

The plugin expects `bd` to output JSON with the `--json` flag. Ensure your version of bd supports this flag.

## License

MIT
