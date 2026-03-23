# Beads Neovim Plugin Specification

## Overview

Plugin to integrate the `bd` (beads) CLI issue tracker into Neovim, providing Telescope-powered pickers for viewing and managing beads issues.

## Core Features (Phase 1 - Viewing)

### 1. Telescope Pickers

| Picker | bd Command | Description |
|--------|------------|-------------|
| List Issues | `bd list` | Fuzzy search all open issues |
| Ready Issues | `bd ready` | Show issues ready to work (no blockers) |
| Blocked Issues | `bd blocked` | Show blocked issues |
| Search Issues | `bd search <query>` | Full-text search across issues |
| Query Issues | `bd query <expr>` | Advanced query language search |

### 2. Issue Preview

- `:BdShow <issue-id>` - Show full issue details in split
- Display: title, type, state, labels, description, dependencies

### 3. Issue Navigation

- `:BdOpen <issue-id>` - Open issue in browser (bd show --url)
- Jump to issue from any picker selection

### 4. Dependency Graph

- `:BdGraph [issue-id]` - Show dependency graph in float window
- Uses terminal-native DAG visualization (default)
- `--all` option: show all open issues grouped by connected component
- Format options: default (DAG), --box (ASCII boxes), --compact (tree)

## Commands

```
:BdList         - Open issues list picker
:BdReady        - Open ready issues picker  
:BdBlocked      - Open blocked issues picker
:BdSearch       - Search issues picker
:BdQuery        - Query issues picker
:BdShow <id>    - Show issue details in split
:BdOpen <id>    - Open issue in browser
:BdStatus       - Show database statistics
:BdGraph [id]   - Show dependency graph (float)
```

## Configuration

```lua
require("beads").setup({
  -- Path to bd binary (default: "bd")
  binary = "bd",
  
  -- Default options passed to bd commands
  list_opts = {
    -- default filters for bd list
    state = "open",
  },
  
  -- Keybindings
  keymaps = {
    open = "<CR>",
    show = "<leader>i",
    close = "q",
  },
})
```

## Technical Notes

- Use `bd --json` for machine-parseable output
- Parse JSON output in Lua for Telescope display
- Leverage Telescope's `attach_mappings` for actions
- Use Neovim splits/floats for detail views and graph

## Future Phases (Out of Scope)

- Issue creation/editing via Telescope forms
- Comments, labels, dependencies management
- Integration with other bd workflows