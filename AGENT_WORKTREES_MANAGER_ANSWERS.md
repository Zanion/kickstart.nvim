The architect has identified key architectural decisions that need clarification:
Clarifying Questions

1. Worktree Naming & Lifecycle
Q: How should worktrees be named?
- A: feature-{bead-id}-{slug} (e.g., feature-bd-42-add-worktree-manager)
- B: agent-{agent-name}-{bead-id} (e.g., agent-gemini-bd-42)
- C: User-defined at dispatch time
- D: Other?

Answer: I think it should actually be A but also leave room for the slug to have incrementer, so multiple agents can work on the same bead on their own worktrees. It should also support user defined at dispatch time as an option.

Q: Auto-cleanup after merge/reject, or keep for inspection?
Answer: I think it should be kept for inspection.

2. Agent "Needs Input" Signaling
Q: How should agents signal they need user input?
- A: Marker file in worktree (.needs_input)
- B: IPC via NVIM_LISTEN_ADDRESS with RPC calls
- C: Special log pattern ([NEEDS_INPUT])
- D: Named pipe / Unix socket

Answer: Notifications should be sent to the NVIM server address. Basically the same way we are currently sending Gemini notifications.

3. Merge/Reject Workflow
Q: What should happen on "Merge"?
- A: Auto-create PR
- B: Stage files, user commits manually
- C: Other

Answer: We should do the workflow we establish that prepares and creates the PR.

Q: What should happen on "Reject"?
- A: Delete worktree/branch
- B: Keep for inspection, close bead only

Answer: B, keep for inspection. We don't want to close the bead as it wasn't completed if rejected. We might want to be able to re-enter/reset the agent.

4. Beads Assignment
Q: How should beads be assigned to agents?
- A: User picks bead from bd ready and dispatches
- B: Auto-assign (round-robin, least-busy)
- C: Agent claims next "ready" bead autonomously
- D: Hybrid

Answer: I want it to be A, the user manually sends the bead from a list of ready beaads.

5. Terminal Preview
Q: How should telescope preview show terminal content?
- A: Live terminal buffer
- B: Periodic snapshot to temp file
- C: Scrollback via NVIM env + RPC

Answer: If we can do a live terminal buffer that would be the best.

6. Multi-Agent Coordination
Q: Should multiple agents work on the same bead?

Answer: If multiple agents work on the same bead, it should be as parallell competing implementations on their own worktrees.

7. Configuration
Q: Should .worktree/ location be configurable?

Answer: Yes, it should be configurable
