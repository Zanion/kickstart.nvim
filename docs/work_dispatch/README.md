# Agent Work Dispatch Manager

## Overview

A Neovim plugin feature that supports running terminal AI agents on individual git worktrees and branches to implement features tracked via beads.

## Goals

- Agents work in isolated git worktrees
- Work assignment via beads task tracking
- Centralized picker for monitoring active agents
- Merge/reject workflow for agent output
- Multi-agent parallel implementations on same bead

## Quick Links

- [User Requirements](./user_requirements/)
- [System Requirements](./system_requirements/)
- [Architectural Decisions](./adrs/)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Work Dispatch                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌─────────────┐ │
│  │ Worktree│  │  Beads   │  │  IPC    │  │   Picker    │ │
│  │ Manager │  │   CLI    │  │ Handler │  │    UI       │ │
│  └────┬────┘  └────┬─────┘  └────┬────┘  └──────┬──────┘ │
│       │             │             │               │        │
│       └─────────────┴─────────────┴───────────────┘        │
│                              │                              │
│                    ┌──────────▼──────────┐                   │
│                    │   Snacks Terminal   │                   │
│                    │    + Agent CLI      │                   │
│                    └─────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```
