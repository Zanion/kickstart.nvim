## ADR-004: Workspace-Relative Database Path Discovery

**Status:** Accepted

### Context
Users may have multiple bead databases (one per project). The plugin needs to use the correct database based on the current workspace.

### Decision
Auto-discover the beads database by searching upward from the current working directory for a `.beads/*.db` directory.

### Consequences
**Easier:**
- Works automatically for users with project-based databases
- No manual configuration needed per workspace
- Caches discovered path to avoid repeated filesystem lookups

**Harder:**
- Must handle case where no database found (fall back to default)
- False positives if `.beads/` exists but is not a valid DB
- Must invalidate cache when workspace changes

### Implementation Notes
- `beads.workspace.find_db()` searches upward from `vim.loop.cwd()`
- Checks for `.beads/*.db` glob pattern
- Stores cached path per directory (using path hash as key)
- Config option to override with explicit `db_path`