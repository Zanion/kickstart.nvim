## ADR-002: Telescope Native Picker Integration

**Status:** Accepted

### Context
The plugin needs to provide interactive issue pickers. We could build custom UI or integrate with Telescope.

### Decision
Use Telescope's native picker API (`telescope.pickers.new`) with custom `attach_mappings` for actions.

### Consequences
**Easier:**
- Native fuzzy finding capability
- Standard Neovim UI familiar to users
- Built-in actions, keybindings, and theming
- Live grep support for search functionality

**Harder:**
- Dependency on telescope.nvim plugin
- Must follow Telescope's picker API patterns
- Less control over UI customization

### Implementation Notes
- Use `telescope.load_extension("beads")` for integration
- Custom actions via `attach_mappings` callback
- Prompt prefix for each picker type: "[Beads] List> ", etc.