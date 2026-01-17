# Workflow Rules

1. Shaper agents only create/refine beads; Doers only execute ready beads.
2. All bead state transitions are authoritative and handled by the CLI.
3. Any ambiguity discovered by a Doer must be logged and handled by a Shaper.
4. Bead state is the single source of truth; logs are supplementary but recommended.

# Testing Rules

1. Any bead that modifies code must include automated tests.
2. A bead may only be marked `done` when all its associated tests pass.
3. Existing tests must not regress. If any pre-existing test fails after bead execution, the bead is considered failed.
4. Doers must run tests before marking a bead complete. If tests fail, the bead status must be updated to `failed` or `blocked` and the issue logged.

# Logging Rules

Logging uses a hybrid approach:

## Per-Bead Notes (bd comments)
1. Bead-specific events (claim, completion, failure, context exhaustion) are logged as comments on the bead using `bd comments add`.
2. Comments include timestamp and agent ID for traceability.
3. Use `bd comments <bead-id>` to view a bead's history.

## Orchestrator Events (EVENTS.jsonl)
1. System-level events are logged to `.claude/work_logs/EVENTS.jsonl` (one JSON object per line).
2. Events include: iteration_complete, iteration_paused, iteration_failed, bead_created.
3. JSONL format is merge-friendly and append-only.

## General
1. The CLI state (`bd`) is authoritative; logs are supplementary audit trails.
2. All events should include timestamp, bead_id (if applicable), and agent.

# Git Workflow Rules

1. Each bead must be executed in a separate branch:
   - Branch naming: <area>/<bead-id> (e.g., backend/backend-create-login)
2. Doers must commit **incrementally** as meaningful progress is made:
   - Include tests and code changes
   - Commit messages should include bead ID
   - Example: feat(backend-create-login): implement login endpoint
3. Doers must not merge, rebase, or modify unrelated branches
4. Branch can be merged only after all bead work is complete and tests pass
5. Shapers may reference branch history for patterns, but must not commit code

