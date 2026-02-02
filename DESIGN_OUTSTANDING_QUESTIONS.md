# Outstanding Design Questions

## Resolved

### 1. Task Backend
- **What system?** Claude Code TaskList for persistence, Itinerary CLI for shell access. Both read/write the same files.
- **Why not bd/beads?** Shell orchestrator needs CLI access; Itinerary provides this while sharing Claude Code's native persistence format.
- **Why not pure TaskList?** Shell orchestrator can't call TaskList tools (they're Claude Code-only). Itinerary bridges this gap.

### 2. Status Model
- **What statuses?** Aligned with Claude Code native: `pending`, `in_progress`, `completed`.
- **Failed/blocked/escalated?** Tracked via task metadata, not status. `blocked` is implicit (pending + unmet deps). `failed` = pending + `last_outcome: "failed"`. `escalated` = pending + `escalated: true`.

### 3. Reviewer Behavior
- **What does it check?** Configurable validation suite (tests, lint, type-check, build -- user-defined). Established during scaffolding.
- **How is it triggered?** Claude Code PostToolUse hook on `git commit`. Checks task status; no-ops unless task is marked for review.
- **Merge strategy?** Rebase feature branch onto current main, run validation, fast-forward merge.
- **Rebase conflicts?** Escalates to human (typed escalation event in JSONL).
- **Concurrent merges?** Serialized via file lock.
- **Merge commit format?** Deferred (minor detail).

### 4. Orchestrator Model
- **LLM or shell?** Shell script. Preserves the smart/dumb boundary. No LLM in orchestration loop.
- **Parallelism?** Background `claude` processes, up to configurable concurrency limit.
- **Why not subagents?** LLM-in-the-loop introduces non-determinism (context drift, unauthorized decisions). Shell can't have opinions, which is the point.

### 5. Branch Naming
- **Convention?** `<area>/<semantic-task-id>` (e.g., `backend/backend-create-login`)
- **Semantic ID?** Human-readable identifier assigned by the Shaper, preserved through task creation and branch naming.

### 6. Doer Permissions
- **Skip permissions?** No. `--dangerously-skip-permissions` is out of the design entirely.
- **Branch sandboxing?** Claude Code PreToolUse hook rejects disallowed git operations.
- **Test boundary?** Claude Code PreToolUse hook enforces file write restrictions based on test glob patterns.
- **General commands?** Deny-pattern approach: block known-dangerous patterns, allow everything else.

### 7. Test Writer
- **Separate persona?** Yes, TEST_WRITER.md with its own persona and directives.
- **Enforcement?** Hard boundary via hooks, not just persona instructions. Test Writer can ONLY write test files; Doer can ONLY write non-test files.
- **Test patterns?** Glob patterns in project config (e.g., `["tests/**", "src/**/*.test.ts"]`), established during scaffolding.

### 8. Failure Modes
- **Doer crash?** Timeout-based: no activity for 30 minutes (configurable) -> release claim, return to ready pool.
- **Retry tracking?** `attempt_count` in task metadata, incremented by orchestrator on failure.
- **Escalation trigger?** After 3 failed attempts, orchestrator sets `escalated: true` in metadata.

### 9. Event System
- **Architecture?** Unified append-only JSONL event stream (`.nobrakes/EVENTS.jsonl`).
- **V1 consumers?** Orchestrator stdout (escalations only) + Shaper reshape mode (filters JSONL for context).
- **Future?** Any consumer can tail the stream: notification daemon, dashboard, webhooks, etc.

### 10. Doer Naming
- **Convention?** Sequential from NAMES.json (Ada through Zara), assigned globally by orchestrator.
- **Storage?** Task `owner` field.

### 11. Runtime Model
- **Where does it run?** Local CLI + shell orchestrator.
- **How are Doers spawned?** Claude Code subprocesses via `claude --print`.
- **State persistence?** Claude Code TaskList files (`~/.claude/tasks/<task_list_id>/`).
- **Tech stack?** Shell scripts for orchestration, Claude Code for agent work.

---

## Still Open / Deferred

- Merge commit message format
- User journey UI implementation details
- How to measure framework effectiveness across simple vs complex examples
- Custom persona names (low priority) -- should users be able to rename personas?
- Notification mechanisms beyond stdout (tied to future event stream consumers)
