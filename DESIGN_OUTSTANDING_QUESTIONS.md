# Outstanding Design Questions

## Resolved

### 1. Reviewer Behavior
- **What does it check?** Configurable check list (tests, lint, type-check, build - user-defined). Established during scaffolding.
- **Rebase conflicts?** Escalates to human (typed escalation with `type: conflict`).
- **Merge commit format?** Deferred (minor detail).
- **Notifications?** Deferred (tied to user journey implementation).

### 2. Assigner Mechanics
- **Trigger?** Event-driven (specific events TBD during event system design).
- **Concurrency limit?** Yes, configurable.
- **Branch creation?** Assigner creates on first attempt, checks out existing on retries.

### 3. The "Dumb" Distinction
- **What are they?** Deterministic shell scripts. No LLM involved. Simple logic only.

### 4. Runtime Model
- **Where does it run?** Local CLI + background daemon.
- **How are Doers spawned?** Claude Code subprocesses.
- **State persistence?** Beads (in-repo JSONL), project-level config (in-repo).
- **Tech stack?** Shell scripts for V1.

### 5. Observability
- **How does the human monitor?** 8 user journeys identified (see DESIGN.md). Implementation details deferred.

### 6. Failure Modes
- **Doer crash?** Timeout-based: no activity for X minutes → release lock, return to Ready.
- **Stale locks?** Same timeout mechanism handles this.
- **Assigner crash?** Not yet specified (daemon restart would pick up where it left off since state is in beads).

### 7. Test Examples
- **Where do they live?** Separate repos that nobrakes is installed into (realistic usage pattern).
- **Level of detail / measurement?** Deferred.

---

## Still Open / Deferred

- Specific events for the event-driven system (emerges from implementation)
- Mailbox/routing concept for escalation targets beyond "human"
- Notification mechanisms (tied to user journey implementation)
- Merge commit message format
- Exact timeout duration for crash handling (configurable, default TBD)
- User journey UI implementation details
- How to measure framework effectiveness across simple vs complex examples
- Custom persona names (low priority)
- **Native Task List as beads replacement**: Claude Code has a built-in Task List system (TaskCreate, TaskGet, TaskList, TaskUpdate) with support for statuses, dependencies (blocks/blockedBy), ownership, and metadata. Task lists persist to disk and can be shared across parallel Claude Code processes by setting `CLAUDE_CODE_TASK_LIST_ID=<project-name>` as an environment variable. This could potentially replace the external `bd`/beads system, giving us dependency tracking, status management, and multi-Doer coordination natively. Worth evaluating whether the feature set is sufficient (no remove-dependency operation, no JSONL export, unclear on atomic locking guarantees).
