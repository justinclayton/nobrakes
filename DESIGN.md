# nobrakes Design Decisions

This document captures resolved design decisions for the nobrakes workflow. See README.md for the high-level overview.

---

## Work Items & Beads

### Integration
- Work items are tracked using [Beads](https://github.com/steveyegge/beads)
- Each work item is a bead; beads can be organized under epics for categorization
- Beads' dependency graph handles blocking automatically - work that depends on incomplete work is marked as blocked and not assignable

### Assignment Field
- The assignment field serves as an atomic locking mechanism
- Enables future concurrency (multiple Doers working in parallel on independent beads)
- Provides provenance - which Doer worked on what
- Each Doer instance has a unique identifier (e.g., `doer-a3f8c2` or `bead-123-doer-1`)

### Assigner Logic
The Assigner picks beads where:
- `status = Ready`
- All dependencies are `status = Complete`
- `assignment = null` (not claimed by another Doer)

---

## Doer Behavior

### Test Requirements
- **TDD by default**, with an explicit escape hatch
- Doers must either:
  1. Write tests for their work, OR
  2. Explicitly declare why tests don't apply (logged for human review)
- Rationale: Tests provide a clear "done" signal; the Reviewer loop assumes tests exist

### Doer Naming
- Doers are named sequentially from a static list of human names (A-Z)
- Names are defined in `NAMES.json` and can be customized
- Names are assigned globally as Doers are spawned, not per-bead
- Example: Ada works on bead 1 and completes it; Bowie is assigned to bead 2; Cleo picks up bead 3; Bowie gives up and Dmitri takes over bead 2
- This provides a rough chronological sequence - you can infer "Dmitri came after Bowie" from the letters
- 26 names available; after Zara it wraps back to Ada (but this should be rare)

### Reading Prior Context
- When a Doer starts, it reads any existing comments on its assigned bead
- This provides institutional memory from previous attempts
- Prevents repeating the same failed approaches

### Giving Up
Doers give up under two conditions:
1. **Context exhaustion**: Context window is running low; Doer wraps up, documents progress, exits
2. **Repeated test failures**: Tests fail and Doer can't determine why after 3 attempts

When giving up, Doers:
1. Document their progress in a structured log (see format below)
2. Decide whether to preserve or delete their branch:
   - **Preserve** if meaningful progress was made that the next Doer could use
   - **Delete** if the branch is a mess that would confuse more than help
3. Leave status unchanged (bead returns to Ready pool)

### Structured Log Format
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

---

## Escalation Protocol

### When to Escalate
- After X failed attempts on the same bead (default: 3)
- Configurable per-project or per-bead

### Escalation Contents
When escalating to a human, include:
- All Doer logs from failed attempts
- Summary of approaches tried
- Hypothesis about why it's failing:
  - Missing context or requirements?
  - Flawed/ambiguous requirements?
  - Genuinely hard problem?
  - External dependency or environment issue?

---

## Shaper Behavior

### Mental Model
The Shaper session is analogous to Claude Code's plan mode:

| Claude Code Plan Mode | Shaper Session |
|----------------------|----------------|
| Explore codebase, gather context | Discuss vision, clarify requirements |
| Design implementation approach | Design work breakdown |
| Write to plan file | Create beads with dependencies |
| `ExitPlanMode` | `/commit-strategy` |
| User approves plan | User approves bead graph |
| Execute plan | Beads enter Ready queue, Assigner takes over |

The key difference: plan mode produces a linear-ish narrative plan (phases happen roughly in order), while the Shaper produces a **dependency graph** where parallelism is explicit. This lets the Assigner maximize throughput by running independent beads concurrently.

### Completion Criteria
- The Shaper session ends with an explicit approval command: `/commit-strategy`
- Nothing enters the Ready queue until the human approves
- This prevents:
  - Accidental commits if the human walks away mid-conversation
  - Scope creep (human must consciously approve the full graph)
  - Ambiguity about when shaping ends and execution begins

### Re-shaping
- The human can invoke the Shaper again at any time to add more beads
- Each Shaper session produces an increment to the work graph
- New beads can depend on existing beads (completed or not)
- This supports iterative development - you don't need to plan everything upfront

### Granularity Guidance
- Each bead should be completable by a single Doer in one session
- If a bead is too large, the Shaper should break it into smaller beads with dependencies
- If a bead is too small (trivial), consider combining with related work
- Rule of thumb: a bead is one coherent unit of work with a clear "done" condition

---

## Branch Naming

Convention: `<type>/bead-<bead-id>`

Examples:
- `feature/bead-123`
- `fix/bead-456`

One branch per bead. If a Doer gives up and another takes over, they continue on the same branch (either building on the work or resetting it). The Doer's name in the structured log provides provenance for who did what.

---

## Open Questions (Still Unresolved)

### Custom Persona Names
- Low priority, but: should users be able to rename personas (Shaper -> "Po", Reviewer -> "Marge", etc.)?
- If implemented, keep sensible defaults for discoverability

