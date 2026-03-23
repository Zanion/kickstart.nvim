# Agent Work Dispatch Manager - Acceptance Tests

**Document Version:** 1.0  
**Generated:** 2026-03-22  
**Status:** Source of Truth for Feature Completion

---

## Overview

This document defines behavioral acceptance tests for the Agent Work Dispatch Manager feature. Tests are organized by functional area and mapped to system/user requirements. All tests are **behavioral**, **automatable**, and **immutable** once finalized.

**Passing all tests = Feature Complete**

---

## Test Execution Notes

- Tests assume a Neovim environment with the work_dispatch plugin loaded
- Tests use real file operations in temporary directories
- Git operations require a valid git repository
- bd CLI must be available and configured
- gh CLI must be available for merge tests

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Test implemented |
| ⏳ | Test pending implementation |
| ❌ | Test failing |
| N/A | Not applicable |

---

## CORE WORKFLOW TESTS

### 1. Worktree Creation (UR-001, SR-001, SR-002)

#### TEST-001: Worktree Root Directory Creation
| Field | Value |
|-------|-------|
| **Test ID** | TEST-001 |
| **Title** | Worktree root directory is created automatically |
| **Requirement** | SR-001, UR-001 |
| **Preconditions** | - Plugin loaded via `require("work_dispatch").setup()` |
| **Steps** | 1. Invoke dispatch with a valid bead ID and agent name<br>2. Check if `.worktree/` directory exists |
| **Expected Results** | - `.worktree/` directory is created in repo root<br>- Directory is created before worktree operations |
| **Status** | ⏳ |

#### TEST-002: Git Worktree Creation
| Field | Value |
|-------|-------|
| **Test ID** | TEST-002 |
| **Title** | Git worktree is created with correct branch |
| **Requirement** | SR-002, UR-001 |
| **Preconditions** | - `.worktree/` directory exists<br>- Valid bead ID provided |
| **Steps** | 1. Execute dispatch for bead "bd-42" with title "Add login"<br>2. Run `git worktree list` |
| **Expected Results** | - New worktree entry exists in `git worktree list`<br>- Branch name follows pattern `feature-bd-42-add-login`<br>- Worktree path points to `.worktree/feature-bd-42-add-login/` |
| **Status** | ⏳ |

#### TEST-003: Worktree Gitignored
| Field | Value |
|-------|-------|
| **Test ID** | TEST-003 |
| **Title** | Worktree directory is gitignored |
| **Requirement** | SR-001 |
| **Preconditions** | - `.worktree/` exists |
| **Steps** | 1. Check `.gitignore` contents |
| **Expected Results** | - `.worktree/` is listed in `.gitignore` |
| **Status** | ⏳ |

#### TEST-004: Configurable Worktree Root
| Field | Value |
|-------|-------|
| **Test ID** | TEST-004 |
| **Title** | Worktree root respects user configuration |
| **Requirement** | SR-001, UR-001 |
| **Preconditions** | - Custom path configured |
| **Steps** | 1. Configure `worktree_root = "/tmp/custom-worktrees"`<br>2. Execute dispatch<br>3. Check worktree location |
| **Expected Results** | - Worktree created under configured path<br>- Not in default `.worktree/` location |
| **Status** | ⏳ |

#### TEST-005: Worktree Metadata Persistence
| Field | Value |
|-------|-------|
| **Test ID** | TEST-005 |
| **Title** | Worktree metadata is stored in registry |
| **Requirement** | SR-003 |
| **Preconditions** | - Worktree created |
| **Steps** | 1. Create worktree via dispatch<br>2. Read registry.json |
| **Expected Results** | - Entry exists in registry<br>- Contains: id, path, branch, bead_id, agent, status, timestamps |
| **Status** | ⏳ |

---

### 2. Beads Integration (UR-002, SR-004)

#### TEST-010: Fetch Ready Beads
| Field | Value |
|-------|-------|
| **Test ID** | TEST-010 |
| **Title** | Picker displays beads from `bd ready` |
| **Requirement** | SR-004, UR-002 |
| **Preconditions** | - `bd` CLI is available<br>- At least one bead exists with "ready" status |
| **Steps** | 1. Invoke picker command `<leader>aa`<br>2. Observe bead list |
| **Expected Results** | - Beads with "ready" status are shown<br>- Each bead displays: ID, title, priority |
| **Status** | ⏳ |

#### TEST-011: Bead Details Fetch
| Field | Value |
|-------|-------|
| **Test ID** | TEST-011 |
| **Title** | Full bead details are retrieved on selection |
| **Requirement** | SR-004 |
| **Preconditions** | - Valid bead ID exists |
| **Steps** | 1. Call `beads.show("bd-42")` |
| **Expected Results** | - Returns full bead object with: id, title, description, type, priority, status |
| **Status** | ⏳ |

#### TEST-012: Bead State Update on Dispatch
| Field | Value |
|-------|-------|
| **Test ID** | TEST-012 |
| **Title** | Bead status changes to in_progress on dispatch |
| **Requirement** | SR-004, UR-002 |
| **Preconditions** | - Bead in "ready" state |
| **Steps** | 1. Dispatch bead to agent<br>2. Check bead status via `bd show` |
| **Expected Results** | - Bead status is "in_progress"<br>- Bead shows agent assignment metadata |
| **Status** | ⏳ |

#### TEST-013: Bead Context Injection
| Field | Value |
|-------|-------|
| **Test ID** | TEST-013 |
| **Title** | BEADS_CONTEXT.md is created in worktree |
| **Requirement** | SR-006, UR-002 |
| **Preconditions** | - Worktree created |
| **Steps** | 1. Dispatch bead to agent<br>2. Read worktree/BEADS_CONTEXT.md |
| **Expected Results** | - File exists in worktree root<br>- Contains: bead ID, title, description, workflow instructions<br>- Properly formatted markdown |
| **Status** | ⏳ |

#### TEST-014: Bead Picker Sorting
| Field | Value |
|-------|-------|
| **Test ID** | TEST-014 |
| **Title** | Bead picker sorts by priority |
| **Requirement** | SR-004 |
| **Preconditions** | - Multiple beads with different priorities |
| **Steps** | 1. Open bead selection picker<br>2. Observe sort order |
| **Expected Results** | - Higher priority beads appear first<br>- Same priority sorted by creation date |
| **Status** | ⏳ |

#### TEST-015: Bead Search/Filter
| Field | Value |
|-------|-------|
| **Test ID** | TEST-015 |
| **Title** | Bead picker supports filtering by ID or text |
| **Requirement** | SR-004 |
| **Preconditions** | - Multiple beads exist |
| **Steps** | 1. Open bead picker<br>2. Type search query |
| **Expected Results** | - Results filter in real-time<br>- Matches bead ID or title |
| **Status** | ⏳ |

#### TEST-016: Bead CLI Error Handling
| Field | Value |
|-------|-------|
| **Test ID** | TEST-016 |
| **Title** | Graceful handling when bd CLI fails |
| **Requirement** | SR-004 |
| **Preconditions** | - bd CLI returns error |
| **Steps** | 1. Simulate bd command failure<br>2. Observe behavior |
| **Expected Results** | - User-friendly error message<br>- No crash<br>- Plugin continues to function |
| **Status** | ⏳ |

#### TEST-017: Bead ID Parsing
| Field | Value |
|-------|-------|
| **Test ID** | TEST-017 |
| **Title** | Bead ID is correctly parsed from various formats |
| **Requirement** | SR-004 |
| **Preconditions** | - Bead IDs in various formats |
| **Steps** | 1. Test with "bd-42", "nvim-abc123", "42" |
| **Expected Results** | - All formats correctly parsed<br>- Correct bead referenced |
| **Status** | ⏳ |

---

### 3. Agent Dispatch (UR-002, SR-005, SR-007)

#### TEST-020: Dispatch Command Execution
| Field | Value |
|-------|-------|
| **Test ID** | TEST-020 |
| **Title** | Dispatch creates worktree and spawns agent |
| **Requirement** | SR-005, SR-007 |
| **Preconditions** | - Valid bead and agent name |
| **Steps** | 1. Execute `require("work_dispatch").dispatch("bd-42", "gemini")`<br>2. Check worktree exists<br>3. Check agent terminal is running |
| **Expected Results** | - Worktree created under `.worktree/`<br>- Agent terminal spawned via snacks.nvim<br>- Registry updated with session info |
| **Status** | ⏳ |

#### TEST-021: Agent Terminal Environment
| Field | Value |
|-------|-------|
| **Test ID** | TEST-021 |
| **Title** | Agent receives correct environment variables |
| **Requirement** | SR-007 |
| **Preconditions** | - Agent spawned |
| **Steps** | 1. Spawn agent for dispatch<br>2. Check agent's environment |
| **Expected Results** | - `NVIM_LISTEN_ADDRESS` set to unique socket path<br>- `BEAD_ID` environment variable set<br>- `WORKTREE_ID` environment variable set<br>- `CWD` set to worktree directory |
| **Status** | ⏳ |

#### TEST-022: Unique Socket Per Session
| Field | Value |
|-------|-------|
| **Test ID** | TEST-022 |
| **Title** | Each agent session gets unique IPC socket |
| **Requirement** | SR-007, SR-008 |
| **Preconditions** | - Multiple agents running |
| **Steps** | 1. Dispatch two agents<br>2. Check socket paths |
| **Expected Results** | - Each agent has unique socket path<br>- Sockets are created under `/tmp/` |
| **Status** | ⏳ |

#### TEST-023: Session Tracking
| Field | Value |
|-------|-------|
| **Test ID** | TEST-023 |
| **Title** | Session information is tracked in registry |
| **Requirement** | SR-007 |
| **Preconditions** | - Agent spawned |
| **Steps** | 1. Create session via dispatch<br>2. Read registry |
| **Expected Results** | - Session entry contains: id, worktree_id, bead_id, agent, terminal_id, pid, status |
| **Status** | ⏳ |

#### TEST-024: Invalid Agent Name Handling
| Field | Value |
|-------|-------|
| **Test ID** | TEST-024 |
| **Title** | Dispatch handles invalid agent names gracefully |
| **Requirement** | SR-005 |
| **Preconditions** | - None |
| **Steps** | 1. Attempt dispatch with invalid agent name |
| **Expected Results** | - Clear error message<br>- No worktree created<br>- Plugin remains stable |
| **Status** | ⏳ |

#### TEST-025: Invalid Bead ID Handling
| Field | Value |
|-------|-------|
| **Test ID** | TEST-025 |
| **Title** | Dispatch handles non-existent bead ID gracefully |
| **Requirement** | SR-005 |
| **Preconditions** | - None |
| **Steps** | 1. Attempt dispatch with non-existent bead ID |
| **Expected Results** | - Error: "Bead not found"<br>- No worktree created |
| **Status** | ⏳ |

#### TEST-026: Dispatch Confirmation
| Field | Value |
|-------|-------|
| **Test ID** | TEST-026 |
| **Title** | Dispatch shows confirmation before starting |
| **Requirement** | SR-005, UR-002 |
| **Preconditions** | - Valid bead and agent |
| **Steps** | 1. Select bead and agent<br>2. Observe confirmation |
| **Expected Results** | - Shows bead title and agent name<br>- User can confirm or cancel |
| **Status** | ⏳ |

#### TEST-027: Dispatch Cleanup on Failure
| Field | Value |
|-------|-------|
| **Test ID** | TEST-027 |
| **Title** | Partial worktree is cleaned up on dispatch failure |
| **Requirement** | SR-005 |
| **Preconditions** | - Dispatch fails mid-process |
| **Steps** | 1. Simulate failure during dispatch<br>2. Check filesystem |
| **Expected Results** | - No partial worktree left behind<br>- Registry clean |
| **Status** | ⏳ |

---

### 4. Session Management (UR-003, SR-007)

#### TEST-030: Agent Session Lifecycle
| Field | Value |
|-------|-------|
| **Test ID** | TEST-030 |
| **Title** | Session status transitions correctly |
| **Requirement** | SR-007 |
| **Preconditions** | - Agent running |
| **Steps** | 1. Spawn agent (status: running)<br>2. Close terminal (status: paused)<br>3. Focus agent (status: running) |
| **Expected Results** | - Session status updates on terminal close/open |
| **Status** | ⏳ |

#### TEST-031: Terminal Close Detection
| Field | Value |
|-------|-------|
| **Test ID** | TEST-031 |
| **Title** | Terminal close event is detected and handled |
| **Requirement** | SR-007 |
| **Preconditions** | - Agent terminal open |
| **Steps** | 1. Close agent terminal window<br>2. Check registry status |
| **Expected Results** | - Session status changes to "paused"<br>- Terminal buffer reference cleared |
| **Status** | ⏳ |

#### TEST-032: Session Resumption
| Field | Value |
|-------|-------|
| **Test ID** | TEST-032 |
| **Title** | Closed terminal can be respawned |
| **Requirement** | SR-007, SR-012 |
| **Preconditions** | - Session in "paused" state |
| **Steps** | 1. Press `<CR>` on paused session in picker |
| **Expected Results** | - New terminal spawns<br>- Session status changes to "running"<br>- Same worktree used |
| **Status** | ⏳ |

---

### 5. IPC Notifications (UR-004, SR-008, SR-009)

#### TEST-040: Needs-Input Notification Received
| Field | Value |
|-------|-------|
| **Test ID** | TEST-040 |
| **Title** | Agent can send needs-input notification to Neovim |
| **Requirement** | SR-008, UR-004 |
| **Preconditions** | - Agent running with valid socket<br>- IPC handler registered |
| **Steps** | 1. Agent sends `needs_input` notification via socket<br>2. Check notification displayed |
| **Expected Results** | - nvim-notify shows notification with message<br>- Picker visual indicator updates |
| **Status** | ⏳ |

#### TEST-041: Needs-Input Registry Update
| Field | Value |
|-------|-------|
| **Test ID** | TEST-041 |
| **Title** | Needs-input state is tracked in registry |
| **Requirement** | SR-009 |
| **Preconditions** | - Agent sent needs_input notification |
| **Steps** | 1. Agent sends notification<br>2. Read registry |
| **Expected Results** | - `needs_input` = true<br>- `needs_input_since` = timestamp |
| **Status** | ⏳ |

#### TEST-042: Status Update Notification
| Field | Value |
|-------|-------|
| **Test ID** | TEST-042 |
| **Title** | Agent status updates are received and handled |
| **Requirement** | SR-008, UR-004 |
| **Preconditions** | - Agent running |
| **Steps** | 1. Agent sends `status` notification<br>2. Observe behavior |
| **Expected Results** | - Status logged or shown via notify<br>- No error thrown |
| **Status** | ⏳ |

#### TEST-043: Needs-Input Clear on Focus
| Field | Value |
|-------|-------|
| **Test ID** | TEST-043 |
| **Title** | Needs-input state clears when user focuses agent |
| **Requirement** | SR-009 |
| **Preconditions** | - Session has `needs_input = true` |
| **Steps** | 1. Press `<CR>` to focus agent<br>2. Agent sends acknowledgment<br>3. Check registry |
| **Expected Results** | - `needs_input` = false<br>- `needs_input_since` = nil |
| **Status** | ⏳ |

---

### 6. Picker UI (UR-005, SR-010)

#### TEST-050: Single Keybind Opens Picker
| Field | Value |
|-------|-------|
| **Test ID** | TEST-050 |
| **Title** | Default keybind opens agent picker |
| **Requirement** | SR-010, UR-005 |
| **Preconditions** | - Plugin loaded |
| **Steps** | 1. Press `<leader>aa` |
| **Expected Results** | - Telescope picker opens<br>- Shows "Active Agents" title |
| **Status** | ⏳ |

#### TEST-051: Picker Displays Active Agents
| Field | Value |
|-------|-------|
| **Test ID** | TEST-051 |
| **Title** | Picker lists all active agent worktrees |
| **Requirement** | SR-010, UR-005 |
| **Preconditions** | - Multiple agents running |
| **Steps** | 1. Open picker<br>2. Observe entries |
| **Expected Results** | - All active worktrees shown<br>- Each entry shows: Agent icon, Bead ID, Branch name, Status |
| **Status** | ⏳ |

#### TEST-052: Visual Status Indicators
| Field | Value |
|-------|-------|
| **Test ID** | TEST-052 |
| **Title** | Different status states have distinct visual indicators |
| **Requirement** | SR-010, UR-005 |
| **Preconditions** | - Agents in various states |
| **Steps** | 1. Create agents with different statuses<br>2. Open picker |
| **Expected Results** | - Running: green circle `●`<br>- Needs Input: yellow warning `⚠`<br>- Done: blue check `✓`<br>- Rejected: red X `✗` |
| **Status** | ⏳ |

#### TEST-053: Sorting Priority
| Field | Value |
|-------|-------|
| **Test ID** | TEST-053 |
| **Title** | Agents needing input appear first |
| **Requirement** | SR-010 |
| **Preconditions** | - Mixed statuses present |
| **Steps** | 1. Create agents with needs_input and running<br>2. Open picker |
| **Expected Results** | - Needs-input agents sorted to top<br>- Sorted by wait time (oldest first) |
| **Status** | ⏳ |

#### TEST-054: Picker Filters
| Field | Value |
|-------|-------|
| **Test ID** | TEST-054 |
| **Title** | Picker can filter by agent, status, or bead |
| **Requirement** | SR-010 |
| **Preconditions** | - Multiple worktrees exist |
| **Steps** | 1. Open picker<br>2. Press `<leader>fa`<br>3. Select "gemini" |
| **Expected Results** | - Only gemini agents shown<br>- Other agents hidden |
| **Status** | ⏳ |

---

### 7. Terminal Preview (UR-005, SR-011)

#### TEST-060: Preview Shows Terminal Output
| Field | Value |
|-------|-------|
| **Test ID** | TEST-060 |
| **Title** | Preview pane displays agent terminal output |
| **Requirement** | SR-011, UR-005 |
| **Preconditions** | - Agent running with output |
| **Steps** | 1. Open picker<br>2. Select agent with running terminal<br>3. Observe preview pane |
| **Expected Results** | - Terminal scrollback shown in preview<br>- ANSI codes stripped or rendered |
| **Status** | ⏳ |

#### TEST-061: Preview Refresh on Selection
| Field | Value |
|-------|-------|
| **Test ID** | TEST-061 |
| **Title** | Preview updates when selection changes |
| **Requirement** | SR-011 |
| **Preconditions** | - Multiple agents running |
| **Steps** | 1. Select agent A (see output A)<br>2. Select agent B |
| **Expected Results** | - Preview shows agent B's output |
| **Status** | ⏳ |

#### TEST-062: Live Preview Refresh
| Field | Value |
|-------|-------|
| **Test ID** | TEST-062 |
| **Title** | Preview updates periodically while open |
| **Requirement** | SR-011 |
| **Preconditions** | - Agent producing output |
| **Steps** | 1. Select agent with running output<br>2. Wait 2 seconds<br>3. Check preview |
| **Expected Results** | - New output appears in preview |
| **Status** | ⏳ |

#### TEST-063: Closed Terminal Preview State
| Field | Value |
|-------|-------|
| **Test ID** | TEST-063 |
| **Title** | Preview handles closed terminal gracefully |
| **Requirement** | SR-011 |
| **Preconditions** | - Terminal was closed |
| **Steps** | 1. Close agent terminal<br>2. Select agent in picker<br>3. Observe preview |
| **Expected Results** | - Shows "Terminal closed" message<br>- Provides restart hint |
| **Status** | ⏳ |

---

### 8. Agent Focus Action (SR-012)

#### TEST-070: Enter Key Focuses Agent
| Field | Value |
|-------|-------|
| **Test ID** | TEST-070 |
| **Title** | Enter key opens/focuses agent terminal |
| **Requirement** | SR-012 |
| **Preconditions** | - Agent in picker |
| **Steps** | 1. Select agent entry<br>2. Press `<CR>` |
| **Expected Results** | - Terminal window opens or comes to front<br>- Focus moves to terminal |
| **Status** | ⏳ |

#### TEST-071: Focus Toggle
| Field | Value |
|-------|-------|
| **Test ID** | TEST-071 |
| **Title** | Focus on already focused terminal toggles visibility |
| **Requirement** | SR-012 |
| **Preconditions** | - Agent terminal already focused |
| **Steps** | 1. Press `<CR>` on focused agent |
| **Expected Results** | - Terminal toggles (hides/shows) |
| **Status** | ⏳ |

#### TEST-072: Focus Respawns Closed Session
| Field | Value |
|-------|-------|
| **Test ID** | TEST-072 |
| **Title** | Focus action respawns terminal if closed |
| **Requirement** | SR-012 |
| **Preconditions** | - Session in "paused" state |
| **Steps** | 1. Select paused session<br>2. Press `<CR>` |
| **Expected Results** | - New terminal spawned in worktree<br>- Session status updates to "running" |
| **Status** | ⏳ |

---

### 9. Merge Action (UR-006, SR-013)

#### TEST-080: Merge Keybind Triggers Action
| Field | Value |
|-------|-------|
| **Test ID** | TEST-080 |
| **Title** | Merge action triggered via keybind |
| **Requirement** | SR-013, UR-006 |
| **Preconditions** | - Agent with completed work |
| **Steps** | 1. Select agent in picker<br>2. Press `<leader>m` |
| **Expected Results** | - Merge process begins<br>- Confirmation shown |
| **Status** | ⏳ |

#### TEST-081: Uncommitted Changes Auto-Commit
| Field | Value |
|-------|-------|
| **Test ID** | TEST-081 |
| **Title** | Uncommitted changes are auto-committed on merge |
| **Requirement** | SR-013 |
| **Preconditions** | - Worktree has uncommitted changes |
| **Steps** | 1. Create uncommitted changes in worktree<br>2. Execute merge |
| **Expected Results** | - Changes committed with standardized message<br>- Commit follows format: `feat({bead_id}): {title}` |
| **Status** | ⏳ |

#### TEST-082: Branch Pushed to Remote
| Field | Value |
|-------|-------|
| **Test ID** | TEST-082 |
| **Title** | Branch is pushed to remote before PR |
| **Requirement** | SR-013, UR-006 |
| **Preconditions** | - Valid remote configured |
| **Steps** | 1. Execute merge<br>2. Check remote |
| **Expected Results** | - `git push -u origin {branch}` executed<br>- Branch exists on remote |
| **Status** | ⏳ |

#### TEST-083: PR Created with Correct Format
| Field | Value |
|-------|-------|
| **Test ID** | TEST-083 |
| **Title** | PR is created with proper title and body |
| **Requirement** | SR-013, UR-006 |
| **Preconditions** | - gh CLI available and authenticated |
| **Steps** | 1. Execute merge<br>2. Check created PR |
| **Expected Results** | - Title: `feat({bead_id}): {title}`<br>- Body references bead ID and closes issue |
| **Status** | ⏳ |

#### TEST-084: Bead Closed on Merge
| Field | Value |
|-------|-------|
| **Test ID** | TEST-084 |
| **Title** | Bead is closed after successful merge |
| **Requirement** | SR-013, UR-006 |
| **Preconditions** | - gh PR created |
| **Steps** | 1. Execute merge<br>2. Check bead status |
| **Expected Results** | - Bead status = "done" or "Implemented"<br>- PR URL stored |
| **Status** | ⏳ |

#### TEST-085: Merge Success Notification
| Field | Value |
|-------|-------|
| **Test ID** | TEST-085 |
| **Title** | Success notification shows PR URL |
| **Requirement** | SR-013 |
| **Preconditions** | - Merge successful |
| **Steps** | 1. Execute merge<br>2. Observe notification |
| **Expected Results** | - nvim-notify shows "PR created" message<br>- PR URL included in notification |
| **Status** | ⏳ |

---

### 10. Reject Action (UR-006, SR-014)

#### TEST-090: Reject Keybind Triggers Action
| Field | Value |
|-------|-------|
| **Test ID** | TEST-090 |
| **Title** | Reject action triggered via keybind |
| **Requirement** | SR-014, UR-006 |
| **Preconditions** | - Running agent |
| **Steps** | 1. Select agent in picker<br>2. Press `<leader>r` |
| **Expected Results** | - Confirmation prompt appears |
| **Status** | ⏳ |

#### TEST-091: Reject Keeps Worktree
| Field | Value |
|-------|-------|
| **Test ID** | TEST-091 |
| **Title** | Rejected worktree is preserved |
| **Requirement** | SR-014, UR-006 |
| **Preconditions** | - Worktree exists |
| **Steps** | 1. Reject agent work<br>2. Check worktree directory |
| **Expected Results** | - Worktree directory still exists<br>- Files preserved |
| **Status** | ⏳ |

#### TEST-092: Bead Status Updated to Rejected
| Field | Value |
|-------|-------|
| **Test ID** | TEST-092 |
| **Title** | Bead status changes to rejected (not closed) |
| **Requirement** | SR-014, UR-006 |
| **Preconditions** | - Bead in "in_progress" state |
| **Steps** | 1. Reject work<br>2. Check bead status |
| **Expected Results** | - Bead status = "rejected"<br>- Bead NOT closed |
| **Status** | ⏳ |

#### TEST-093: Rejected Agent Terminal Closed
| Field | Value |
|-------|-------|
| **Test ID** | TEST-093 |
| **Title** | Agent terminal is closed on reject |
| **Requirement** | SR-014 |
| **Preconditions** | - Agent running |
| **Steps** | 1. Reject work<br>2. Check terminal status |
| **Expected Results** | - Terminal closed<br>- Session status = "rejected" |
| **Status** | ⏳ |

#### TEST-094: Visual Indicator for Rejected
| Field | Value |
|-------|-------|
| **Test ID** | TEST-094 |
| **Title** | Rejected agents show visual indicator in picker |
| **Requirement** | SR-014 |
| **Preconditions** | - Agent rejected |
| **Steps** | 1. Open picker<br>2. Find rejected agent |
| **Expected Results** | - Red X indicator `✗`<br>- Status text shows "rejected" |
| **Status** | ⏳ |

---

### 11. Reset Action (UR-006, SR-015)

#### TEST-100: Reset Keybind Triggers Action
| Field | Value |
|-------|-------|
| **Test ID** | TEST-100 |
| **Title** | Reset action triggered via keybind |
| **Requirement** | SR-015, UR-006 |
| **Preconditions** | - Rejected or paused agent |
| **Steps** | 1. Select rejected agent<br>2. Press `<leader>R` |
| **Expected Results** | - Confirmation shown<br>- Reset process begins |
| **Status** | ⏳ |

#### TEST-101: Reset Relaunches Agent
| Field | Value |
|-------|-------|
| **Test ID** | TEST-101 |
| **Title** | Reset spawns new agent on same worktree |
| **Requirement** | SR-015 |
| **Preconditions** | - Rejected agent |
| **Steps** | 1. Execute reset<br>2. Check terminal |
| **Expected Results** | - New terminal spawned<br>- Same worktree directory used<br>- Same bead context |
| **Status** | ⏳ |

#### TEST-102: Needs-Input Cleared on Reset
| Field | Value |
|-------|-------|
| **Test ID** | TEST-102 |
| **Title** | Needs-input state is cleared on reset |
| **Requirement** | SR-015 |
| **Preconditions** | - Agent with needs_input = true |
| **Steps** | 1. Reset agent<br>2. Check registry |
| **Expected Results** | - `needs_input` = false<br>- `needs_input_since` = nil |
| **Status** | ⏳ |

#### TEST-103: Bead Reset to Ready
| Field | Value |
|-------|-------|
| **Test ID** | TEST-103 |
| **Title** | Bead returns to ready state after reset |
| **Requirement** | SR-015 |
| **Preconditions** | - Bead in "rejected" state |
| **Steps** | 1. Reset agent<br>2. Check bead status |
| **Expected Results** | - Bead status = "ready" |
| **Status** | ⏳ |

#### TEST-104: Reset Count Tracked
| Field | Value |
|-------|-------|
| **Test ID** | TEST-104 |
| **Title** | Reset count is incremented and stored |
| **Requirement** | SR-015 |
| **Preconditions** | - Multiple resets |
| **Steps** | 1. Reset agent twice<br>2. Check registry |
| **Expected Results** | - `reset_count` incremented<br>- `last_reset` timestamp updated |
| **Status** | ⏳ |

---

### 12. Parallel Agents (UR-007, SR-016)

#### TEST-110: Multiple Agents on Same Bead
| Field | Value |
|-------|-------|
| **Test ID** | TEST-110 |
| **Title** | Same bead can be dispatched to multiple agents |
| **Requirement** | SR-016, UR-007 |
| **Preconditions** | - Bead exists |
| **Steps** | 1. Dispatch bead to gemini<br>2. Dispatch same bead to claude |
| **Expected Results** | - Both worktrees created<br>- Both agents running |
| **Status** | ⏳ |

#### TEST-111: Unique Worktree Names
| Field | Value |
|-------|-------|
| **Test ID** | TEST-111 |
| **Title** | Parallel worktrees have unique names |
| **Requirement** | SR-016, SR-002 |
| **Preconditions** | - Multiple agents on same bead |
| **Steps** | 1. Dispatch 3 agents to same bead<br>2. List worktrees |
| **Expected Results** | - Names: `feature-bd-42-{slug}`, `feature-bd-42-1-{slug}`, `feature-bd-42-2-{slug}` |
| **Status** | ⏳ |

#### TEST-112: Parallel Counter Increments
| Field | Value |
|-------|-------|
| **Test ID** | TEST-112 |
| **Title** | Counter increments correctly for parallel worktrees |
| **Requirement** | SR-016 |
| **Preconditions** | - Existing worktree with counter |
| **Steps** | 1. Check counter for existing worktrees<br>2. Create new parallel worktree |
| **Expected Results** | - New worktree gets next counter value |
| **Status** | ⏳ |

#### TEST-113: Picker Shows All Parallel Agents
| Field | Value |
|-------|-------|
| **Test ID** | TEST-113 |
| **Title** | All parallel implementations visible in picker |
| **Requirement** | SR-016, SR-010 |
| **Preconditions** | - Multiple agents on same bead |
| **Steps** | 1. Open picker<br>2. Find bead bd-42 entries |
| **Expected Results** | - All parallel implementations shown<br>- Each has correct branch name |
| **Status** | ⏳ |

#### TEST-114: Independent Merge/Reject
| Field | Value |
|-------|-------|
| **Test ID** | TEST-114 |
| **Title** | Each parallel worktree can be merged/rejected independently |
| **Requirement** | SR-016 |
| **Preconditions** | - Multiple parallel worktrees |
| **Steps** | 1. Merge one implementation<br>2. Reject another |
| **Expected Results** | - Each action affects only selected worktree<br>- Other worktrees unchanged |
| **Status** | ⏳ |

#### TEST-115: Max Parallel Limit
| Field | Value |
|-------|-------|
| **Test ID** | TEST-115 |
| **Title** | Dispatch prevented when max parallel reached |
| **Requirement** | SR-016 |
| **Preconditions** | - Max parallel (5) reached |
| **Steps** | 1. Attempt to dispatch 6th agent to same bead |
| **Expected Results** | - Error shown: "Max parallel agents reached"<br>- No new worktree created |
| **Status** | ⏳ |

---

## EDGE CASE TESTS

### Terminal Scenarios

#### TEST-200: Terminal Close During Operation
| Field | Value |
|-------|-------|
| **Test ID** | TEST-200 |
| **Title** | System handles terminal close during merge |
| **Requirement** | Edge Case |
| **Preconditions** | - Merge in progress |
| **Steps** | 1. Start merge<br>2. Close terminal mid-operation |
| **Expected Results** | - Merge completes successfully<br>- Or graceful error handling |
| **Status** | ⏳ |

#### TEST-201: Multiple Terminals Same Worktree
| Field | Value |
|-------|-------|
| **Test ID** | TEST-201 |
| **Title** | Focus selects most recent terminal if multiple exist |
| **Requirement** | SR-012 |
| **Preconditions** | - Multiple terminals for same worktree |
| **Steps** | 1. Focus agent twice quickly<br>2. Check which terminal is shown |
| **Expected Results** | - Most recent terminal focused |
| **Status** | ⏳ |

### Bead Scenarios

#### TEST-210: Bead Already Closed
| Field | Value |
|-------|-------|
| **Test ID** | TEST-210 |
| **Title** | Merge/reject prevented on already closed bead |
| **Requirement** | Edge Case |
| **Preconditions** | - Bead status = "done" |
| **Steps** | 1. Attempt merge on closed bead |
| **Expected Results** | - Error shown<br>- No action taken |
| **Status** | ⏳ |

#### TEST-211: Bead Already Assigned
| Field | Value |
|-------|-------|
| **Test ID** | TEST-211 |
| **Title** | Dispatch shows warning for already assigned bead |
| **Requirement** | UR-002 |
| **Preconditions** | - Bead already dispatched |
| **Steps** | 1. Attempt to dispatch same bead |
| **Expected Results** | - Warning shown<br>- Option to create parallel |
| **Status** | ⏳ |

### IPC Scenarios

#### TEST-220: IPC Connection Failure
| Field | Value |
|-------|-------|
| **Test ID** | TEST-220 |
| **Title** | Graceful degradation when IPC unavailable |
| **Requirement** | SR-008 |
| **Preconditions** | - Invalid or missing socket |
| **Steps** | 1. Agent attempts IPC notification<br>2. Check behavior |
| **Expected Results** | - Warning logged<br>- Agent continues running<br>- No crash |
| **Status** | ⏳ |

#### TEST-221: Invalid IPC Message
| Field | Value |
|-------|-------|
| **Test ID** | TEST-221 |
| **Title** | Invalid IPC messages are handled gracefully |
| **Requirement** | SR-008 |
| **Preconditions** | - Malformed notification received |
| **Steps** | 1. Send invalid JSON via IPC |
| **Expected Results** | - Error logged<br>- No crash<br>- Processing continues |
| **Status** | ⏳ |

### Git Scenarios

#### TEST-230: Git Push Rejection
| Field | Value |
|-------|-------|
| **Test ID** | TEST-230 |
| **Title** | Merge handles remote push rejection |
| **Requirement** | SR-013, Edge Case |
| **Preconditions** | - Remote branch diverged |
| **Steps** | 1. Execute merge<br>2. Handle push rejection |
| **Expected Results** | - Clear error message<br>- Options to rebase or abort |
| **Status** | ⏳ |

#### TEST-231: No Remote Configured
| Field | Value |
|-------|-------|
| **Test ID** | TEST-231 |
| **Title** | Merge prevents action when no remote |
| **Requirement** | SR-013 |
| **Preconditions** | - No git remote |
| **Steps** | 1. Attempt merge |
| **Expected Results** | - Error: "No git remote configured" |
| **Status** | ⏳ |

#### TEST-232: Worktree Directory Deleted
| Field | Value |
|-------|-------|
| **Test ID** | TEST-232 |
| **Title** | Reset validates worktree exists |
| **Requirement** | SR-015 |
| **Preconditions** | - Worktree manually deleted |
| **Steps** | 1. Attempt reset |
| **Expected Results** | - Error shown<br>- Offer cleanup option |
| **Status** | ⏳ |

### Configuration Scenarios

#### TEST-240: Invalid Worktree Path
| Field | Value |
|-------|-------|
| **Test ID** | TEST-240 |
| **Title** | Invalid worktree path configuration handled |
| **Requirement** | SR-001 |
| **Preconditions** | - Invalid path configured |
| **Steps** | 1. Configure non-existent absolute path<br>2. Attempt dispatch |
| **Expected Results** | - Error or auto-creation of parent directories |
| **Status** | ⏳ |

#### TEST-241: gh CLI Not Available
| Field | Value |
|-------|-------|
| **Test ID** | TEST-241 |
| **Title** | Merge gracefully handles missing gh CLI |
| **Requirement** | SR-013 |
| **Preconditions** | - gh CLI not installed |
| **Steps** | 1. Attempt merge |
| **Expected Results** | - Clear error message<br>- Setup instructions shown |
| **Status** | ⏳ |

---

## INTEGRATION TESTS

### Integration with Agent.lua

#### TEST-300: Extend Existing Agent Module
| Field | Value |
|-------|-------|
| **Test ID** | TEST-300 |
| **Title** | Integration extends, not replaces, existing agent.lua |
| **Requirement** | SR-007 |
| **Preconditions** | - custom/agent.lua exists |
| **Steps** | 1. Check agent.lua module loaded<br>2. Check worktree-aware functions available |
| **Expected Results** | - Original agent.lua functionality preserved<br>- worktree-aware methods added |
| **Status** | ⏳ |

#### TEST-301: Agent Command Configuration
| Field | Value |
|-------|-------|
| **Test ID** | TEST-301 |
| **Title** | Agent commands respect existing configuration |
| **Requirement** | SR-007 |
| **Preconditions** | - Agent configured in existing setup |
| **Steps** | 1. Check agent commands |
| **Expected Results** | - Uses configured command templates<br>- Supports configured environment |
| **Status** | ⏳ |

### Integration with bd CLI

#### TEST-310: bd Command Availability
| Field | Value |
|-------|-------|
| **Test ID** | TEST-310 |
| **Title** | System checks for bd CLI availability |
| **Requirement** | SR-004 |
| **Preconditions** | - bd not installed |
| **Steps** | 1. Load plugin |
| **Expected Results** | - Warning or error shown<br>- Clear instructions provided |
| **Status** | ⏳ |

#### TEST-311: bd JSON Parsing
| Field | Value |
|-------|-------|
| **Test ID** | TEST-311 |
| **Title** | bd output parsed correctly |
| **Requirement** | SR-004 |
| **Preconditions** | - Valid bd output |
| **Steps** | 1. Execute `bd ready --json`<br>2. Parse output |
| **Expected Results** | - Valid JSON parsed<br>- Correct data structure |
| **Status** | ⏳ |

#### TEST-312: bd Error Handling
| Field | Value |
|-------|-------|
| **Test ID** | TEST-312 |
| **Title** | bd errors handled gracefully |
| **Requirement** | SR-004 |
| **Preconditions** | - bd command fails |
| **Steps** | 1. Execute invalid bd command<br>2. Observe behavior |
| **Expected Results** | - Error captured<br>- User-friendly message shown |
| **Status** | ⏳ |

### Integration with snacks.nvim

#### TEST-320: Terminal Spawn via Snacks
| Field | Value |
|-------|-------|
| **Test ID** | TEST-320 |
| **Title** | Terminals spawned using snacks.nvim API |
| **Requirement** | SR-007 |
| **Preconditions** | - snacks.nvim available |
| **Steps** | 1. Dispatch agent<br>2. Check snacks.terminal.list() |
| **Expected Results** | - Terminal appears in snacks list<br>- Correct configuration applied |
| **Status** | ⏳ |

#### TEST-321: Terminal Lifecycle via Snacks
| Field | Value |
|-------|-------|
| **Test ID** | TEST-321 |
| **Title** | Terminal kill/close uses snacks API |
| **Requirement** | SR-007 |
| **Preconditions** | - Terminal running |
| **Steps** | 1. Kill terminal via plugin<br>2. Check snacks list |
| **Expected Results** | - Terminal removed from snacks list |
| **Status** | ⏳ |

### Integration with Telescope

#### TEST-330: Picker Uses Telescope
| Field | Value |
|-------|-------|
| **Test ID** | TEST-330 |
| **Title** | Agent picker implemented via telescope |
| **Requirement** | SR-010 |
| **Preconditions** | - telescope installed |
| **Steps** | 1. Open picker<br>2. Check implementation |
| **Expected Results** | - Uses telescope.pick() or similar<br>- Standard telescope keybinds work |
| **Status** | ⏳ |

#### TEST-331: Custom Previewer Registered
| Field | Value |
|-------|-------|
| **Test ID** | TEST-331 |
| **Title** | Custom terminal previewer registered with telescope |
| **Requirement** | SR-011 |
| **Preconditions** | - Picker open |
| **Steps** | 1. Open picker<br>2. Select entry |
| **Expected Results** | - Custom previewer renders terminal output |
| **Status** | ⏳ |

### Integration with nvim-notify

#### TEST-340: Notifications via nvim-notify
| Field | Value |
|-------|-------|
| **Test ID** | TEST-340 |
| **Title** | User notifications use nvim-notify |
| **Requirement** | SR-008 |
| **Preconditions** | - nvim-notify available |
| **Steps** | 1. Trigger notification (merge, reject, etc.)<br>2. Observe display |
| **Expected Results** | - Uses nvim-notify popup<br>- Styled appropriately |
| **Status** | ⏳ |

---

## TEST COVERAGE SUMMARY

### By Requirement Area

| Area | Tests | Coverage |
|------|-------|----------|
| Worktree Management (SR-001, SR-002, SR-003) | 5 | 100% |
| Beads Integration (SR-004, SR-006) | 8 | 100% |
| Agent Dispatch (SR-005, SR-007) | 12 | 100% |
| Session Management (SR-007) | 3 | 100% |
| IPC Notifications (SR-008, SR-009) | 4 | 100% |
| Picker UI (SR-010) | 5 | 100% |
| Terminal Preview (SR-011) | 4 | 100% |
| Agent Focus (SR-012) | 3 | 100% |
| Merge Action (SR-013) | 6 | 100% |
| Reject Action (SR-014) | 5 | 100% |
| Reset Action (SR-015) | 5 | 100% |
| Parallel Agents (SR-016) | 6 | 100% |
| Edge Cases | 11 | 100% |
| Integration | 10 | 100% |

### By User Requirement

| User Requirement | Tests | Coverage |
|-----------------|-------|----------|
| UR-001: Worktree Isolation | 5 | 100% |
| UR-002: Beads-Aware Work Assignment | 12 | 100% |
| UR-003: Agent Workflow Compliance | 3 | 100% |
| UR-004: Agent Notification | 4 | 100% |
| UR-005: Agent Picker with Preview | 9 | 100% |
| UR-006: Merge and Reject Actions | 16 | 100% |
| UR-007: Multi-Agent Parallel | 6 | 100% |

### Test Statistics

| Metric | Count |
|--------|-------|
| Total Test Cases | 83 |
| Core Workflow Tests | 62 |
| Edge Case Tests | 11 |
| Integration Tests | 10 |
| System Requirements Covered | 16/16 |
| User Requirements Covered | 7/7 |

---

## TEST EXECUTION CHECKLIST

### Pre-Flight
- [ ] Neovim loaded with plugin
- [ ] `bd` CLI available and configured
- [ ] `gh` CLI available and authenticated
- [ ] snacks.nvim installed
- [ ] telescope installed
- [ ] nvim-notify installed
- [ ] Git repository initialized

### Execution Order
1. **Foundation Tests** (TEST-001 to TEST-027)
   - Worktree creation
   - Beads integration
   - Agent dispatch validation
   
2. **Core Workflow Tests** (TEST-030 to TEST-072)
   - Session management
   - IPC notifications
   - Picker UI
   - Terminal preview
   - Agent focus

3. **Action Tests** (TEST-080 to TEST-115)
   - Merge action
   - Reject action
   - Reset action
   - Parallel agents

4. **Advanced Tests** (TEST-200 to TEST-340)
   - Edge cases
   - Integration

---

## IMPLEMENTATION NOTES

### Test Philosophy
- Tests are **behavioral**, not implementation-specific
- Tests verify **what happens**, not **how it's done**
- Tests are **deterministic** and **reproducible**
- Tests are **independent** and can run in any order

### Test Data
- Use real git operations where possible
- Use temporary directories for worktrees
- Mock only external dependencies (bd/gh CLI output)
- Ensure test cleanup after each test

### Test Environment
- Tests should be runnable via `:WorkDispatchRunTests` command
- Tests should output clear pass/fail results
- Failed tests should show: Test ID, Expected, Actual, Steps to reproduce

---

*This document serves as the source of truth for feature completion. When all tests pass, the feature is considered complete.*
