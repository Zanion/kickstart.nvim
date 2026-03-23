## ADR-003: Terminal-Based Graph Visualization

**Status:** Accepted

### Context
The plugin needs to display dependency graphs. We could use a Lua-rendered graph (e.g., using canvas or unicode art) or use the terminal-based output from bd.

### Decision
Use terminal-based visualization in a floating window, leveraging bd's built-in graph formatting (default DAG, --box, --compact).

### Consequences
**Easier:**
- Leverages bd's existing visualization capabilities
- Rich formatting options already implemented
- Simpler Lua code - just render terminal output
- Consistent with bd CLI experience

**Harder:**
- Less interactive than a custom graph (no clickable nodes)
- Depends on terminal capabilities for rendering
- Less control over colors/styling

### Implementation Notes
- Use `vim.term_open()` or `nvim_open_term` for float
- Execute `bd graph [id] --format=<type>` based on user option
- Handle window close via keybinding in terminal mode