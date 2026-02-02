# Tasks Specification

A task is a durable unit of work in this workflow. Tasks are stored in Claude Code's native TaskList system.

## Access Patterns

- **Shell scripts** (orchestrator, etc.): Use the [Itinerary](https://github.com/thurn/itinerary) CLI
- **Claude Code subprocesses** (Doers, Test Writers, Shapers): Use native TaskList tools (`TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`)
- Both read/write the same underlying persistence files (`~/.claude/tasks/<task_list_id>/`)

## Task Fields

- `id` (string): Unique identifier (assigned by TaskList/Itinerary)
- `subject` (string): Brief title for the task
- `description` (string): Detailed instructions for a single task
- `status` (string): One of `pending`, `in_progress`, `completed` (Claude Code native)
- `owner` (string|null): Agent currently working on this task
- `blocks` (array[string]): Task IDs that this task blocks
- `blockedBy` (array[string]): Task IDs that must complete before this task
- `metadata` (object): Arbitrary key-value pairs (see below)

## Task Metadata

| Key | Type | Set by | Description |
|-----|------|--------|-------------|
| `needs_tests` | boolean | Shaper | Whether a Test Writer runs before the Doer (default: true) |
| `attempt_count` | number | Orchestrator | Number of Doer attempts (incremented on failure) |
| `last_outcome` | string | Orchestrator | Result of last attempt: `completed`, `failed`, `context_exhausted` |
| `escalated` | boolean | Orchestrator | Whether this task has been escalated to a human |
| `area` | string | Shaper | Ownership area (backend, frontend, infra, etc.) |
| `semantic_id` | string | Shaper | Human-readable identifier used in branch names |

## Status Model

| Concept | Status | Condition |
|---------|--------|-----------|
| ready | `pending` | No unmet dependencies |
| in_progress | `in_progress` | Claimed by a Doer |
| done | `completed` | Work finished and merged |
| blocked | `pending` | Has unmet dependencies (automatic via dep graph) |
| failed | `pending` | `metadata.last_outcome = "failed"` |
| escalated | `pending` | `metadata.escalated = true` |

## State Transitions

- pending -> in_progress -> completed
- pending -> in_progress -> pending (failure, returned to ready pool)
- pending (blocked) -> pending (ready, when dependencies complete)

## Rules

- Tasks must be independently executable
- Dependencies are always explicit
- No task may perform work outside its description
- CLI/tool state is authoritative; never modify persistence files directly

## Itinerary CLI Quick Reference

```bash
itinerary ready              # Find tasks with no blockers
itinerary pop                # Atomic: ready + claim + show
itinerary show <id>          # View task details
itinerary create "title"     # Create a task
itinerary update <id> ...    # Update task fields
itinerary close <id>         # Mark task completed
itinerary dep add <a> <b>    # Task a depends on task b
itinerary list               # List all tasks
itinerary tree               # Show dependency tree
itinerary graph <id>         # Show dependency graph
itinerary label <id> <label> # Add label
itinerary search <query>     # Search tasks
```
