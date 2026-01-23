# nobrakes Design

This document captures resolved design decisions for the nobrakes workflow. See README.md for the high-level overview.

---

## Architecture

- **Runtime**: Local CLI + background daemon
- **Tech stack (V1)**: Shell scripts orchestrating Claude Code
- **Deployment model**: nobrakes lives INSIDE the target project repo (like `.github/workflows` or `.beads/`)
- **Loop trigger**: Event-driven (specific events TBD during event system design)
- **Concurrency**: Configurable limit on simultaneous Doers
- **Test examples**: Separate repos that nobrakes is installed into

---

## Work Items & Beads

### Integration
- Work items are tracked using [Beads](https://github.com/steveyegge/beads)
- Each work item is a bead; beads can be organized under epics for categorization
- Beads' dependency graph handles blocking automatically - work that depends on incomplete work is marked as blocked and not assignable

### Assignment Field
- The assignment field serves as an atomic locking mechanism
- Enables concurrency (multiple Doers working in parallel on independent beads)
- Provides provenance - which Doer worked on what
- Each Doer instance has a unique name identifier (from NAMES.json)

### Bead Metadata
- `needs_tests`: Whether a Test Writer runs before the Doer (default: `true`, opt-out for exceptions like scaffolding or docs)
- Set by the Shaper during planning

---

## Personas & Responsibilities

### Shaper (AI, interactive)
- Two modes: **initial shaping** (vision → strategy) and **reshaping** (escalations → graph modifications)
- Produces a dependency graph of beads
- Sets per-bead metadata including `needs_tests` flag
- Session ends with explicit `/commit-strategy` approval
- Human acts as "OSS project maintainer" - gatekeeper for all scope changes

#### Shaper Analogy

| Claude Code Plan Mode | Shaper Session |
|----------------------|----------------|
| Explore codebase, gather context | Discuss vision, clarify requirements |
| Design implementation approach | Design work breakdown |
| Write to plan file | Create beads with dependencies |
| `ExitPlanMode` | `/commit-strategy` |
| User approves plan | User approves bead graph |
| Execute plan | Beads enter Ready queue, Assigner takes over |

The key difference: plan mode produces a linear narrative plan, while the Shaper produces a **dependency graph** where parallelism is explicit. This lets the Assigner maximize throughput by running independent beads concurrently.

#### Granularity Guidance
- Each bead should be completable by a single Doer in one session
- If a bead is too large, the Shaper should break it into smaller beads with dependencies
- If a bead is too small (trivial), consider combining with related work
- Rule of thumb: a bead is one coherent unit of work with a clear "done" condition

#### Re-shaping
- The human can invoke the Shaper in "reshape" mode to modify the existing graph
- Triggered by: escalations, new ideas, scope changes
- Each reshape session produces an increment to the work graph
- New beads can depend on existing beads (completed or not)

---

### Doer (AI, autonomous - Claude Code subprocess)
- Pure executor with narrow scope
- Reads task requirements from bead and works towards task completion
- Can ONLY operate on/commit to its assigned branch (enforced via Claude hooks)
- Cannot create tasks or modify the work graph
- Can only escalate ("I think X also needs to happen") - never expand scope directly
- Reads prior attempt comments on its bead for institutional memory
- Gives up on: context exhaustion OR 3 failed test attempts
- Documents progress in structured log format on the bead

#### Giving Up
Doers give up under two conditions:
1. **Context exhaustion**: Context window is running low; Doer wraps up, documents progress, exits
2. **Repeated test failures**: Tests fail and Doer can't determine why after 3 attempts

When giving up, Doers:
1. Document their progress in a structured log (see format below)
2. Decide whether to preserve or delete their branch:
   - **Preserve** if meaningful progress was made that the next Doer could use
   - **Delete** if the branch is a mess that would confuse more than help
3. Leave status unchanged (bead returns to Ready pool)

#### Structured Log Format
Each attempt is logged as a structured comment on the bead:

```markdown
## Attempt 1
- **Doer**: ada
- **Outcome**: completed | gave_up_context | gave_up_tests | failed_review
- **Branch preserved**: yes | no (deleted)
- **Summary**: <what was accomplished>
- **Blockers**: <what stopped progress, if any>
- **Learnings**: <insights for the next Doer>
```

#### Doer Naming
- Doers are named sequentially from a static list of human names (A-Z)
- Names are defined in `NAMES.json` and can be customized
- Names are assigned globally as Doers are spawned, not per-bead
- Example: Ada works on bead 1 and completes it; Bowie is assigned to bead 2; Cleo picks up bead 3; Bowie gives up and Dmitri takes over bead 2
- 26 names available; after Zara it wraps back to Ada (but this should be rare)

---

### Test Writer (AI, autonomous - Claude Code subprocess)
- Separate agent that runs BEFORE the Doer (when `needs_tests: true`)
- Essentially a specialized Doer with a different directive
- Reads task requirements from bead, writes failing tests
- Doer's job becomes: make the tests pass
- Separation prevents the Doer from gaming the system with weak/dishonest tests
- Reads project-level config for where tests / other validations should live (so Reviewer can find them)
- Must write tests conforming to the project-level established test framework (set during scaffolding)
- Similar constraints as Doer: documents progress, gives up on context exhaustion, limited to assigned branch

---

### Assigner (deterministic script)
- Picks beads where: `status=Ready`, all deps complete, `assignment=null`
- Creates branch on first attempt (`<type>/bead-<id>`)
- On retries: checks out existing branch (if preserved) or creates fresh from main (if deleted)
- Spawns Claude Code subprocess for Test Writer and/or Doer
- Assigns unique Doer name (sequential A-Z from NAMES.json)

---

### Reviewer (deterministic script)
- Runs configurable check list (tests, lint, type-check, build - user-defined)
- Project-level config lives in target project/repo, established during scaffolding beads
- On pass: rebases against main, validates again, merges, validates AGAIN, cleans up branch
- On fail: logs failure, reverts bead to Ready
- On rebase conflict: escalates to human (typed escalation)

---

## Escalation System

### Types
Escalations are first-class events with metadata:
- `type`: conflict | repeated_failure | doer_suggestion | etc.
- `target`: "human" (for now, extensible to other targets later)

### Triggers
- After X failed attempts on the same bead (default: 3)
- Rebase conflicts (immediate)
- Doer suggestions ("I think X also needs to happen")

### Flow
- Escalations are queued for human review
- Human processes them through Shaper "reshape" mode
- Analogy: like outside-contributor-submitted GitHub issues on an OSS project

### Escalation Contents
When escalating to a human, include:
- All Doer logs from failed attempts
- Summary of approaches tried
- Hypothesis about why it's failing:
  - Missing context or requirements?
  - Flawed/ambiguous requirements?
  - Genuinely hard problem?
  - External dependency or environment issue?

### Future
- Adapt into fuller event bus system so non-humans could handle certain events (example: merge conflicts)
- Mailbox/routing concept for escalation targets beyond "human"

---

## Branch & Git Model

Convention: `<type>/bead-<bead-id>`

Examples:
- `feature/bead-123`
- `fix/bead-456`

Ownership:
- **Assigner** creates branches
- **Doer** is sandboxed to assigned branch (Claude hooks prevent rogue behavior: no creating branches, no deleting branches, no operations on other branches)
- **Reviewer** handles rebase, merge, and branch cleanup
- Previous Doer decides whether to preserve or delete branch on give-up

---

## Bootstrapping

- First beads in any project are scaffolding/infrastructure beads (clearly marked as such)
- These opt out of Test Writer (`needs_tests: false`)
- Scaffolding beads establish: project structure, test framework, AND project-level config
- After scaffolding, a project-level config exists and defines the contract for all subsequent work
- The Reviewer config (what commands to run) is part of this project-level config

---

## Crash Handling

- Timeout-based: if Doer shows no activity for X minutes, assume crash
- Release bead lock, log the timeout, return bead to Ready
- Configurable timeout duration

---

## User Journeys

8 identified ways a user interacts with the system:

1. **Shaper interaction** ("The Forge") - forging/refining a plan (interactive)
2. **Task board** ("The Board") - viewing bead status, dependency graph, history/post-mortem
3. **Escalation handling** ("Decision Desk") - receiving and responding to escalations
4. **System health** - is the daemon running? what's active?
5. **Doer observation** - watching a specific Doer work in real-time
6. **Reviewer activity** - merge/reject events, test output
7. **System control** ("Breaker Box"?) - start, stop, pause, reconfigure the daemon
8. **Project bootstrap** - first-time setup of nobrakes in a repo

These are user journeys, not necessarily one UI section per journey.

---

## Open Questions (Deferred)

- Custom persona names (low priority) - should users be able to rename personas?
- If implemented, keep sensible defaults for discoverability
