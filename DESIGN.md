# nobrakes Design

This document captures resolved design decisions for the nobrakes workflow. See README.md for the high-level overview.

---

## Architecture

- **Runtime**: Local CLI + shell orchestrator
- **Tech stack (V1)**: Shell scripts orchestrating Claude Code subprocesses
- **Deployment model**: nobrakes lives INSIDE the target project repo (like `.github/workflows` or `.nobrakes/`)
- **Task backend**: [Claude Code TaskList](https://docs.anthropic.com/en/docs/claude-code) for persistence, [Itinerary](https://github.com/thurn/itinerary) CLI for shell access. Both read/write the same underlying files (`~/.claude/tasks/<task_list_id>/`).
- **Event system**: Unified append-only JSONL event stream (`EVENTS.jsonl`). All system events are logged. Consumers (notifications, dashboards, Shaper reshape) tail the stream.
- **Concurrency**: Configurable limit on simultaneous Doers, implemented via shell background processes
- **Test examples**: Separate repos that nobrakes is installed into

---

## Work Items (Tasks)

### Integration
- Work items are tracked using Claude Code's native TaskList system
- Shell scripts interact with tasks via the [Itinerary](https://github.com/thurn/itinerary) CLI; Claude Code subprocesses use native TaskList tools (`TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`)
- Both access the same persistence files -- no adapter layer needed
- Tasks can be grouped using labels (e.g., `auth`, `onboarding`) for human readability
- The dependency graph handles blocking automatically -- tasks with unmet dependencies are not returned by `itinerary ready`

### Status Model

Tasks use Claude Code's native statuses, with metadata for additional states:

| Concept | TaskList Status | Metadata | Notes |
|---------|----------------|----------|-------|
| ready | `pending` | -- | No unmet dependencies |
| in_progress | `in_progress` | -- | Claimed by a Doer |
| done | `completed` | -- | Work finished and merged |
| blocked | `pending` | -- | Has unmet dependencies (automatic) |
| failed | `pending` | `last_outcome: "failed"`, `attempt_count: N` | Returned to ready pool for retry |
| escalated | `pending` | `escalated: true` | Orchestrator filters out; needs human attention |

### Assignment
- The task `owner` field serves as the locking mechanism
- Itinerary's `pop` command provides atomic ready + claim + show
- Enables concurrency (multiple Doers working in parallel on independent tasks)
- Provides provenance -- which Doer worked on what
- Each Doer instance has a unique name identifier (from NAMES.json)

### Task Metadata
- `needs_tests`: Whether a Test Writer runs before the Doer (default: `true`, opt-out for exceptions like scaffolding or docs)
- `attempt_count`: Number of Doer attempts on this task (incremented on failure)
- `last_outcome`: Result of the last Doer attempt (`completed`, `failed`, `context_exhausted`)
- `escalated`: Whether this task has been escalated to a human
- Set by the Shaper during planning (needs_tests) and updated by the orchestrator (attempt tracking)

---

## Personas & Responsibilities

### Shaper (AI, interactive)
- Two modes: **initial shaping** (vision -> strategy) and **reshaping** (escalations -> graph modifications)
- Produces a dependency graph of tasks
- Sets per-task metadata including `needs_tests` flag
- Session ends with explicit `/commit-strategy` approval
- Human acts as "OSS project maintainer" -- gatekeeper for all scope changes

#### Shaper Analogy

| Claude Code Plan Mode | Shaper Session |
|----------------------|----------------|
| Explore codebase, gather context | Discuss vision, clarify requirements |
| Design implementation approach | Design work breakdown |
| Write to plan file | Create tasks with dependencies |
| `ExitPlanMode` | `/commit-strategy` |
| User approves plan | User approves task graph |
| Execute plan | Tasks enter ready pool, orchestrator takes over |

The key difference: plan mode produces a linear narrative plan, while the Shaper produces a **dependency graph** where parallelism is explicit. This lets the orchestrator maximize throughput by running independent tasks concurrently.

#### Granularity Guidance
- Each task should be completable by a single Doer in one session
- If a task is too large, the Shaper should break it into smaller tasks with dependencies
- If a task is too small (trivial), consider combining with related work
- Rule of thumb: a task is one coherent unit of work with a clear "done" condition

#### Re-shaping
- The human can invoke the Shaper in "reshape" mode to modify the existing graph
- Triggered by: escalations, new ideas, scope changes
- Reshape mode ingests recent escalation events from `EVENTS.jsonl` as context
- Each reshape session produces an increment to the work graph
- New tasks can depend on existing tasks (completed or not)

---

### Doer (AI, autonomous -- Claude Code subprocess)
- Pure executor with narrow scope
- Reads task requirements and works towards task completion
- Can ONLY operate on/commit to its assigned branch (enforced via Claude Code hooks)
- Can ONLY write to non-test files (enforced via Claude Code PreToolUse hook using test boundary glob patterns from project config)
- Cannot create tasks or modify the work graph
- Can only escalate ("I think X also needs to happen") -- never expand scope directly
- Reads prior attempt history for institutional memory
- Gives up on: context exhaustion OR 3 failed test attempts
- Documents progress in structured log format

#### Giving Up
Doers give up under two conditions:
1. **Context exhaustion**: Context window is running low; Doer wraps up, documents progress, exits
2. **Repeated test failures**: Tests fail and Doer can't determine why after 3 attempts

When giving up, Doers:
1. Document their progress in a structured log (see format below)
2. Decide whether to preserve or delete their branch:
   - **Preserve** if meaningful progress was made that the next Doer could use
   - **Delete** if the branch is a mess that would confuse more than help
3. Leave task status as `pending` (returns to ready pool); orchestrator increments `attempt_count` in metadata

#### Structured Log Format
Each attempt is logged as a structured comment on the task:

```markdown
## Attempt 1
- **Doer**: Ada
- **Outcome**: completed | gave_up_context | gave_up_tests | failed_review
- **Branch preserved**: yes | no (deleted)
- **Summary**: <what was accomplished>
- **Blockers**: <what stopped progress, if any>
- **Learnings**: <insights for the next Doer>
```

#### Doer Naming
- Doers are named sequentially from a static list of human names (A-Z)
- Names are defined in `NAMES.json` and can be customized
- Names are assigned globally as Doers are spawned, not per-task
- Example: Ada works on task 1 and completes it; Bowie is assigned to task 2; Cleo picks up task 3; Bowie gives up and Dmitri takes over task 2
- 26 names available; after Zara it wraps back to Ada (but this should be rare)

---

### Test Writer (AI, autonomous -- Claude Code subprocess)
- Separate agent that runs BEFORE the Doer (when `needs_tests: true`)
- Has its own persona (TEST_WRITER.md), separate from the Doer
- Reads task requirements, writes failing tests
- Doer's job becomes: make the tests pass
- **Hard enforcement**: Can ONLY write to files matching test boundary glob patterns (from project config). Cannot write implementation code. Enforced via Claude Code PreToolUse hook, not just persona instructions.
- Reads project-level config for where tests should live and what test framework to use (established during scaffolding)
- Similar constraints as Doer: documents progress, gives up on context exhaustion, limited to assigned branch

#### Test Boundary Enforcement
- Project config defines test boundary as glob patterns (e.g., `["tests/**", "src/**/*.test.ts", "**/__tests__/**"]`)
- Established during scaffolding tasks
- Claude Code PreToolUse hook checks every file write/edit against these patterns:
  - **Test Writer**: ONLY allowed to write to paths matching test patterns
  - **Doer**: ONLY allowed to write to paths NOT matching test patterns
- This is a hard boundary, not a suggestion -- prevents incentive misalignment

---

### Orchestrator (deterministic shell script)
- The main control loop. **Not LLM-based** -- preserves the smart/dumb boundary.
- Queries for ready tasks via `itinerary ready` (or `itinerary pop` for atomic claim)
- Checks task metadata before spawning: filters out escalated tasks, checks `attempt_count` against retry threshold
- Creates branch on first attempt (`<area>/<semantic-task-id>`)
- On retries: checks out existing branch (if preserved) or creates fresh from main (if deleted)
- Spawns Claude Code subprocesses for Test Writer and/or Doer
- For parallel execution: spawns multiple background `claude` processes up to configured concurrency limit
- Assigns unique Doer name (sequential A-Z from NAMES.json)
- Writes all events to JSONL event stream
- Prints escalation events to stdout for human visibility

---

### Reviewer (deterministic, hook-triggered)
- **Not a separate process or loop**. Triggered by a Claude Code PostToolUse hook on `git commit`.
- On every Doer commit, the hook checks task status. If the task is not marked for review, no-op.
- When the Doer marks a task for review and commits, the hook triggers the review pipeline.

#### Review Pipeline
1. **Acquire file lock** (serializes concurrent reviews from parallel Doers)
2. **Rebase** feature branch onto current main
3. **Run validation suite** (tests, lint, type-check, build -- from project config)
4. On pass: **fast-forward merge** to main, delete feature branch, mark task `completed`
5. On rebase conflict: **escalate** to human (typed escalation event)
6. On test failure: mark task back to `pending`, log failure
7. **Release file lock**

The file lock ensures that even with parallel Doers finishing near-simultaneously, merges to main are serialized. Only one rebase/validate/merge cycle runs at a time.

#### Why Hook-Triggered
- Event-driven: no polling loop, no separate process
- Fires only on Claude Code agent commits (not manual human commits)
- Runs inline -- the Doer's process blocks until review completes, then exits. The Doer has nothing left to do after its final commit anyway.
- Consistent with the hook infrastructure already used for branch sandboxing and test boundary enforcement

---

## Permission Model

Doer and Test Writer subprocesses run with explicit permissions. **No `--dangerously-skip-permissions`.**

### Claude Code Hooks

Three hooks enforce the workflow contract:

1. **PreToolUse (branch sandboxing)**: Inspects Bash tool calls for git operations. Rejects:
   - `git checkout` to any branch other than the assigned one
   - `git branch -d/-D` (branch deletion)
   - `git branch` creation
   - `git push --force`
   - `git merge`, `git rebase` (Doers don't do these)
   - Modifications to `.claude/` config or hook files

2. **PreToolUse (test boundary)**: Inspects file write/edit operations. Based on the subprocess role:
   - Test Writer: rejects writes to paths NOT matching test glob patterns
   - Doer: rejects writes to paths matching test glob patterns

3. **PostToolUse (Reviewer trigger)**: Fires after `git commit`. Checks task status. If marked for review, runs the review pipeline with file lock.

### General Command Execution
- Hook-based validation with a deny-pattern approach
- Block known-dangerous patterns (destructive commands, config modification)
- Allow everything else (tests, builds, linters, package managers, etc.)
- The hook logic validates; it doesn't enumerate allowed commands

---

## Escalation System

### Types
Escalations are events in the JSONL event stream with specific metadata:
- `type`: `rebase_conflict` | `repeated_failure` | `doer_suggestion`
- `target`: `"human"` (for now, extensible to other targets later)

### Triggers
- After 3 failed attempts on the same task (orchestrator checks `attempt_count` in metadata)
- Rebase conflicts during review (immediate)
- Doer suggestions ("I think X also needs to happen")

### Flow
- Escalation events are written to `EVENTS.jsonl` AND printed to stdout
- Human processes them through Shaper "reshape" mode
- Reshape mode ingests recent escalation events as context
- Analogy: like outside-contributor-submitted GitHub issues on an OSS project

### Escalation Contents
When escalating to a human, the event includes:
- All Doer logs from failed attempts
- Summary of approaches tried
- Hypothesis about why it's failing:
  - Missing context or requirements?
  - Flawed/ambiguous requirements?
  - Genuinely hard problem?
  - External dependency or environment issue?

### Future
- Consumers can tail `EVENTS.jsonl` for any event type
- Notification daemon (OS notifications, Slack, etc.) watches for escalation events
- Dashboard reads the full stream for real-time status
- Mailbox/routing concept for escalation targets beyond "human"

---

## Branch & Git Model

Convention: `<area>/<semantic-task-id>`

Examples:
- `backend/backend-create-login`
- `frontend/frontend-dashboard-ui`
- `infra/infra-ci-pipeline`

The semantic task ID is the human-readable identifier assigned by the Shaper, preserved through task creation and branch naming.

Merge strategy: **rebase onto main**
- Before merging, the Reviewer rebases the feature branch onto current main
- This ensures the feature's tests are validated against the latest state of main
- Catches semantic conflicts (code that merges cleanly but breaks when combined)
- Results in linear history on main

Ownership:
- **Orchestrator** creates branches
- **Doer** is sandboxed to assigned branch (Claude Code hooks prevent rogue behavior: no creating branches, no deleting branches, no operations on other branches)
- **Reviewer** (hook-triggered) handles rebase, merge, and branch cleanup
- Previous Doer decides whether to preserve or delete branch on give-up

---

## Bootstrapping

- First tasks in any project are scaffolding/infrastructure tasks (clearly marked as such)
- These opt out of Test Writer (`needs_tests: false`)
- Scaffolding tasks establish:
  - Project structure
  - Test framework
  - Test boundary glob patterns (which directories/file patterns are "test code")
  - Reviewer validation suite config (what commands to run: tests, lint, build, etc.)
- After scaffolding, a project-level config exists and defines the contract for all subsequent work

---

## Crash Handling

- Timeout-based: if Doer shows no activity for X minutes, assume crash
- Release task claim, log the timeout event to JSONL, return task to ready pool
- Default timeout: **30 minutes**
- Configurable per-project in project-level config

---

## Event Stream

All system events are logged to `.nobrakes/EVENTS.jsonl` (append-only, one JSON object per line).

### Event Types
- `doer_spawned`: Doer subprocess started for a task
- `doer_completed`: Doer finished successfully
- `doer_failed`: Doer failed or gave up
- `test_writer_spawned`: Test Writer subprocess started
- `test_writer_completed`: Test Writer finished
- `review_started`: Reviewer pipeline triggered
- `review_passed`: Validation passed, merge successful
- `review_failed`: Validation failed, task returned to ready
- `rebase_conflict`: Rebase failed, escalation triggered
- `escalation`: Task escalated to human (repeated failure, conflict, or suggestion)
- `crash_timeout`: Doer presumed crashed, task released

### Event Schema
```json
{
  "ts": "2025-01-15T10:30:00Z",
  "event": "doer_completed",
  "task_id": "backend-create-login",
  "agent": "Ada",
  "metadata": {}
}
```

### V1 Consumers
- Orchestrator stdout (escalation events only)
- Shaper reshape mode (filters for escalation events as input context)

### Future Consumers
- OS notification daemon
- Real-time dashboard
- Slack/webhook integration
- Automated conflict resolver

---

## User Journeys

8 identified ways a user interacts with the system:

1. **Shaper interaction** ("The Forge") -- forging/refining a plan (interactive)
2. **Task board** ("The Board") -- viewing task status, dependency graph, history/post-mortem
3. **Escalation handling** ("Decision Desk") -- receiving and responding to escalations
4. **System health** -- is the orchestrator running? what's active?
5. **Doer observation** -- watching a specific Doer work in real-time
6. **Reviewer activity** -- merge/reject events, test output
7. **System control** ("Breaker Box"?) -- start, stop, pause, reconfigure the orchestrator
8. **Project bootstrap** -- first-time setup of nobrakes in a repo

These are user journeys, not necessarily one UI section per journey.

---

## Open Questions (Deferred)

- Custom persona names (low priority) -- should users be able to rename personas?
  - If implemented, keep sensible defaults for discoverability
- Merge commit message format
- User journey UI implementation details
- How to measure framework effectiveness across simple vs complex examples
