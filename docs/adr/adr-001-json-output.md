## ADR-001: Use JSON CLI Output for Machine-Parseable Data

**Status:** Accepted

### Context
The plugin needs to parse issue data from the `bd` CLI for display in Telescope pickers and detail views. We have two options: parse human-readable text output or use structured JSON output.

### Decision
We will use `bd --json` for all data retrieval commands, parsing JSON output in Lua before display.

### Consequences
**Easier:**
- Structured data access - no fragile text parsing
- Future-proof - JSON structure unlikely to change often
- Consistent data format across all commands

**Harder:**
- Requires bd binary to support `--json` flag (confirmed in spec)
- Must handle JSON parsing errors gracefully
- Larger memory footprint than text parsing

### Implementation Notes
- Use `vim.fn.json_decode()` for parsing
- All CLI wrapper functions return parsed Lua tables
- Cache results briefly (500ms) to avoid redundant calls