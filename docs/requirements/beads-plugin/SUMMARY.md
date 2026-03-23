# Beads Plugin Requirements Summary

## Feature Name
**beads-plugin** - Integration of `bd` (beads) CLI issue tracker into Neovim

## User Requirements Index

| ID | Title | Status | Description |
|----|-------|--------|-------------|
| UR-001 | View Issues List with Telescope Picker | Finalized | List all open issues via `:BdList` |
| UR-002 | View Ready Issues | Finalized | List issues ready to work via `:BdReady` |
| UR-003 | View Blocked Issues | Finalized | List blocked issues via `:BdBlocked` |
| UR-004 | Search Issues Full-Text | Finalized | Live grep search via `:BdSearch` |
| UR-005 | Query Issues with Advanced Query Language | Finalized | BDQL search via `:BdQuery` |
| UR-006 | Preview Issue Details | Finalized | Show issue in vertical split via `:BdShow` |
| UR-007 | Open Issue in Browser | Finalized | Open issue URL via `:BdOpen` |
| UR-008 | View Dependency Graph | Finalized | Terminal graph in float via `:BdGraph` |
| UR-009 | Plugin Configuration | Finalized | Setup API with workspace discovery |
| UR-010 | View Database Status | Finalized | Show DB stats via `:BdStatus` |

## System Requirements Index

| ID | Title | Priority | Description |
|----|-------|----------|-------------|
| SR-001 | bd CLI Invocation Layer | Critical | Wrapper for `bd --json` commands |
| SR-002 | Telescope Picker Integration | Critical | Native picker API integration |
| SR-003 | Live Grep Search with Debounce | High | Debounced search implementation |
| SR-004 | Query Language Picker | High | Query expression picker |
| SR-005 | Issue Detail View | Critical | Vertical split detail display |
| SR-006 | Browser Open Action | High | Cross-platform browser opening |
| SR-007 | Neovim Command Registration | Critical | All user commands registration |
| SR-008 | Workspace Database Discovery | High | Auto-discover .beads/ path |
| SR-009 | Dependency Graph Float Window | High | Terminal-based graph display |
| SR-010 | Plugin Configuration API | Critical | Setup function for config |

## User-to-System Requirement Mapping

| UR | Mapped SRs |
|----|------------|
| UR-001 | SR-001, SR-002, SR-003, SR-004, SR-007 |
| UR-002 | SR-001, SR-002, SR-003, SR-004, SR-007 |
| UR-003 | SR-001, SR-002, SR-003, SR-004, SR-007 |
| UR-004 | SR-001, SR-002, SR-003, SR-005, SR-007 |
| UR-005 | SR-001, SR-002, SR-003, SR-004, SR-007 |
| UR-006 | SR-001, SR-005, SR-006, SR-007 |
| UR-007 | SR-005, SR-006 |
| UR-008 | SR-001, SR-005, SR-008 |
| UR-009 | SR-001, SR-002, SR-009 |
| UR-010 | SR-001, SR-005, SR-006 |

## Architectural Decision Records Index

| ID | Title | Status |
|----|-------|--------|
| ADR-001 | Use JSON CLI Output for Machine-Parseable Data | Accepted |
| ADR-002 | Telescope Native Picker Integration | Accepted |
| ADR-003 | Terminal-Based Graph Visualization | Accepted |
| ADR-004 | Workspace-Relative Database Path Discovery | Accepted |

## Dependencies Graph

```
SR-001 (bd CLI)
    |
    +-- SR-002 (Picker Integration)
    |       |
    |       +-- SR-003 (Live Grep)
    |       |
    |       +-- SR-004 (Query Picker)
    |
    +-- SR-005 (Issue Detail View)
    |       |
    |       +-- SR-006 (Browser Action)
    |
    +-- SR-007 (Commands) - depends on all above
    |
    +-- SR-008 (Workspace Discovery)
    |
    +-- SR-009 (Graph Float) - depends on SR-001

SR-010 (Config) - independent module
```

## Key Architectural Decisions

1. **JSON over Text Parsing**: Use `bd --json` for all data retrieval to avoid fragile text parsing
2. **Telescope Integration**: Leverage telescope.nvim native API for pickers instead of custom UI
3. **Terminal Graph**: Delegate visualization to bd CLI's terminal output rather than custom Lua rendering
4. **Workspace Discovery**: Search upward for `.beads/*.db` to support multi-project workflows

## Next Steps

All User Requirements and System Requirements are finalized. The `acceptance-tester` subagent should now:
1. Review requirements for completeness
2. Generate acceptance test suites for each requirement
3. Verify test coverage aligns with acceptance criteria