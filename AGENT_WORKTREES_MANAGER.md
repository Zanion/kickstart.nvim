Feature: Agent Work Dispatch Manager

I want to expand the neovim agents plugin with a feature that supports running agents on individual worktrees and branches to work on features.

The idea for the feature is as follows:

- Worktrees are stored in the project under .worktree/ that is ignored by the projects .gitignore
- Agents pick up work from a beads task for a feature that has already been fully scoped and defined by the architect/planner and then follows the beads-workflow for implementation.
- Agents conduct the work on a worktree and branch dedicated to the implementation of that feature.
- Agents can send notifications to the Neovim user via the notifications hook to signal when they need user input.
- The user can open a picker to see all open agents conducting work in a floating telescope pane.
  - The user can see with a visual indication which ones are awaiting user input.
  - The user can preview each terminal as it's selected in the right pane. I imagine this working effectively the same as the telescope file finder.
- Agents spawned on these worktrees should be allowed to operate as freely as possible within their workspace on the worktree without user input.
- There should be a ability for the user to merge or reject the work of a subagent using a keybind command from the picker/selector.
- There should be some mechanism that assigns a bead from beads to the worker agent.
