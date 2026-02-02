# Workflow Rules

1. Shaper agents only create/refine tasks; Doers only execute ready tasks.
2. All task state transitions are authoritative and handled by Itinerary CLI (shell) or TaskList tools (Claude Code).
3. Any ambiguity discovered by a Doer must be logged and handled by a Shaper.
4. Task state is the single source of truth; logs are supplementary but recommended.

# Testing Rules

1. Any task that modifies code must include automated tests (unless `needs_tests: false`).
2. A task may only be marked `completed` when all its associated tests pass.
3. Existing tests must not regress. If any pre-existing test fails after task execution, the task is considered failed.
4. Doers must run tests before marking a task complete. If tests fail, the task status must be updated appropriately and the issue logged.

# Test Boundary Rules

1. Test Writers may ONLY write to files matching the project's test boundary glob patterns.
2. Doers may ONLY write to files NOT matching the project's test boundary glob patterns.
3. These boundaries are enforced via Claude Code PreToolUse hooks, not just persona instructions.
4. Test boundary patterns are defined in the project-level config, established during scaffolding.

# Logging Rules

Logging uses a hybrid approach:

## Per-Task Structured Logs
1. Each Doer attempt is logged in a structured format (see DESIGN.md for format).
2. Logs include timestamp, agent name, outcome, and learnings for the next Doer.
3. Logs are attached to the task for institutional memory across attempts.

## Event Stream (EVENTS.jsonl)
1. All system-level events are logged to `.nobrakes/EVENTS.jsonl` (one JSON object per line).
2. Events include: doer_spawned, doer_completed, doer_failed, review_passed, review_failed, escalation, crash_timeout, etc.
3. JSONL format is merge-friendly and append-only.
4. Escalation events are additionally printed to stdout.

## General
1. Task state (via Itinerary/TaskList) is authoritative; logs are supplementary audit trails.
2. All events should include timestamp, task_id (if applicable), and agent name.

# Git Workflow Rules

1. Each task must be executed on a separate branch:
   - Branch naming: `<area>/<semantic-task-id>` (e.g., `backend/backend-create-login`)
   - The semantic task ID is the human-readable identifier assigned by the Shaper
2. Doers must commit **incrementally** as meaningful progress is made:
   - Include tests and code changes
   - Commit messages should include the task's semantic ID
   - Example: `feat(backend-create-login): implement login endpoint`
3. Doers must not merge, rebase, or modify unrelated branches
4. Merge strategy: **rebase onto main** (handled by the Reviewer hook, not by Doers)
5. Branches can only be merged after:
   - Feature branch is rebased onto current main
   - Full validation suite passes post-rebase
   - File lock is acquired (serializes concurrent merges)
6. Shapers may reference branch history for patterns, but must not commit code

# Permission Rules

1. No subprocess runs with `--dangerously-skip-permissions`
2. Branch sandboxing is enforced via Claude Code PreToolUse hooks
3. Test boundary enforcement is enforced via Claude Code PreToolUse hooks
4. The Reviewer pipeline is triggered via Claude Code PostToolUse hook on `git commit`
5. General command execution uses deny-pattern validation (block dangerous, allow everything else)
