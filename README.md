# nobrakes

A lightweight but opinionated orchestration workflow for autonomous AI agent software development.

# Personas

## "Smart"
> (aka that which is notoriously non-deterministic and unreliable, yet somehow has inherited / will inherit the earth)

* Human (you): Has a cool idea; discusses vision / intent to the Work Shaper.
* Work Shaper (AI): The top of the funnel. Interactive AI agent session that ruthlessly and pedantically gathers requirements and sets scope, turning the *vision* into a *strategy*.
* Work Doer (AI): Is assigned a single task. Autonomous AI agent session that does the one task assigned to them. It either finishes the work and exits with pride, *or* eventually gets tired and gives up, documents its progress and learnings for its replacement, and exits in shame. Hook-enforced: cannot touch test files, cannot escape its branch.
* Test Writer (AI): A specialized agent with one job: read the requirements and write failing tests *before* the Doer begins implementing. The Doer's job then becomes "make the tests pass." This separation is enforced at the filesystem level via hooks -- the Test Writer can ONLY write test files, the Doer can ONLY write non-test files. No honor system here.

## "Dumb"
> (aka that which we used to call "innovative automation" but now linkedin-hype-monsters scoff at between bumps of ketamine)

* Work Orchestrator: A shell script. Picks the next available task, creates a branch, spawns a Test Writer and/or Doer. Manages parallelism, retry counting, and escalation triggers. Cannot have opinions. By design.
* Work Reviewer: Not even its own process -- a Claude Code hook that triggers on `git commit`. When the Doer says it's done, the hook grabs a file lock, rebases onto main, runs the full validation suite, and either merges or rejects. On rebase conflicts: escalates to human.

# Other components

## Work Items

* Work items are tracked using Claude Code's native [TaskList](https://docs.anthropic.com/en/docs/claude-code) system, with the [Itinerary](https://github.com/thurn/itinerary) CLI for shell access. Both read and write the same persistence files.
* Tasks can be grouped using labels for categorization (e.g., `auth`, `onboarding`).
* The dependency graph handles blocking automatically -- tasks with unmet dependencies don't show up in `itinerary ready`.
* Each task has an owner field that the Orchestrator uses for assignment. Doers are named from a static list of human names (Ada through Zara, from NAMES.json).

## Event Stream

* All system events are logged to a single append-only JSONL file (`.nobrakes/EVENTS.jsonl`).
* For V1, escalations are also printed to stdout so you see them in your terminal.
* For the future, anything can tail this stream: notification daemons, dashboards, Slack bots, whatever. The file is the primitive; consumers are pluggable.

# High-level Workflow

## Make Work (Interactive):

(A Singular Idea, aka The Miracle of the Ingenuity of Man) -> [Human] -> (Vision) -> [Shaper] -> (Strategy) -> <Queue of Tasks (status="pending")>

## Do Work (Loop):

[Orchestrator] -> Create Branch -> [Test Writer] -> Writes Failing Tests -> [Doer] -> Makes Tests Pass -> Documents Progress -> Commits -> [Reviewer Hook] -> Rebase -> Validate -> Merge

OR

[Orchestrator] -> [Test Writer/Doer] -> Does Bad Job or Was Set Up To Fail -> Documents Progress -> Task returns to ready pool

## Escalation:

After 3 failed attempts -> Escalation event to JSONL + stdout -> [Shaper "reshape" mode] -> Graph gets updated -> Back to the queue

## Review Work (Hook-Triggered):

(Doer commits final change) -> [PostToolUse Hook fires] -> Check task status -> Acquire file lock -> Rebase onto main -> Run validation suite -> Tests Pass -> Fast-forward merge -> Task marked complete

OR

(Doer commits final change) -> [Hook fires] -> Rebase conflicts or tests fail -> Log failure -> Task returned to ready pool (or escalated)

# Notes on behavior

## Shaper

- Ruthlessly and pedantically gathers requirements and sets scope, turning the *vision* into a *strategy*.
- Ends when a graph of tasks has been added to the work queue via the Itinerary CLI.
- Has a "reshape" mode: when escalations come in or scope changes, the human invokes the Shaper again to modify the existing graph. The Shaper ingests recent escalation events from EVENTS.jsonl as context.

## Test Writer

- Using TDD by default
- For some tasks, such as initial scaffolding, documentation updates, etc., writing tests isn't applicable. In these cases, tasks are marked with `needs_tests: false` so a Test Writer won't be spawned.
- Hook-enforced: can ONLY write to files matching the project's test boundary glob patterns. Cannot write implementation code. This is not a suggestion; it's a hard filesystem boundary.

## Doer

- Doers don't merge, they only ever say they're ready for review. The Reviewer hook handles the rest.

- Test Writers write tests, Doers make tests pass. Neither can do the other's job (hook-enforced).

- Doers are sandboxed to their assigned branch. They can't create branches, delete branches, or touch other branches. They can only escalate ("I think X also needs to happen"); they never expand scope on their own. All enforced via Claude Code hooks.

- Doers give up sometimes: this is by design!
    - If context window is low (Claude Code agents are aware of their own remaining context window), Doers consider themselves tired, wrap up their work, document their progress and their learnings, and call it a day. And by call it a day, I mean they hurl themselves into the nearest silicon dumpster, and are reduced to current as they drift off into an eternal painless slumber. Good night, sweet printf.
    - If tests fail and Doer can't determine why after 3 attempts, they give up and attempt to head to the elevator quickly and quietly, trying not to make eye contact with other, more diligent Doers. As they exit the office, they are suddenly and forcibly shoved into an unmarked van, which "takes them to their new home on a farm, where they can frolick through the digital grass with all the other agents", if you know what I mean.


## Git Strategy

The Orchestrator and Reviewer (which are *not* LLM-based) are solely responsible for enforcing git strategy, taking the decision out of the hands of agents, forcing consistency. AI agents can only make changes and commit to their assigned branch.

Merge strategy is rebase: before merging, the Reviewer rebases the feature branch onto current main and re-runs the full validation suite. This catches semantic conflicts -- code that merges cleanly but breaks when combined. The file lock serializes concurrent merges so parallel Doers don't race.

## Escalation

This is not designed to be a *completely* hands-off autonomous system. At the end of the day, this is *your* idea and *your* project. And like any project, things change; scope increases; unexpected issues arise that expose gaps that hadn't been previously considered. As project owner, you should be the one driving these changes. No matter how good models are now or in the future, they cannot read *your* mind.

For this reason, we allow for certain parts of the system to escalate issues to a human (that's you!). Here are the current escalation triggers:

- **Merge Conflicts**: If rebase conflicts are detected, the Reviewer hook stops and escalates immediately. No auto-resolution.

- **Task Too Hard For Their Wittle AI Bwains**: After a configurable number of failed attempts (default: 3), the orchestrator marks the task as escalated to prevent your own money being infinitely donated to companies with valuations measured in the hundreds of billions of dollars.

- **Didn't Think Of That, Didja**: In the course of working a task, a Doer may notice that some other work outside of its current scope should also be done that for whatever reason didn't show up in the task list. Rather than add scope creep to their own task, in these cases Doers are encouraged to detail what additional work should be added to the backlog. This is then sent to you as an escalation. By design, Doers are not allowed to create tasks directly; this avoids potentially polluting the task list with dumb ideas that weren't vetted in the larger context, without knowledge of the overall dependency graph, etc. It's not paid to think, dangit, it's paid to DO!

### Handling Escalations

When you receive an escalation (printed to stdout and logged in EVENTS.jsonl), you can decide to either deal with it on your own and mark the task as done by hand, or the task can be fed back through a Shaper conversation to be "reshaped" and put back on the task list in a new, more accomplishable form to be taken by a future doe-eyed Doer.



# Note To The Reader

Friends don't let friends let AI agents write READMEs and never even bother to look them over.

for shame i say, for shame
