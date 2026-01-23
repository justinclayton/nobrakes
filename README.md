# nobrakes

A lightweight but opinionated orchestration workflow for autonomous AI agent software development.

# Personas

## "Smart"
> (aka that which is notoriously non-deterministic and unreliable, yet somehow has inherited / will inherit the earth)

* Human (you): Has a cool idea; discusses vision / intent to the Work Shaper.
* Work Shaper (AI): The top of the funnel. Interactive AI agent session that ruthlessly and pedantically gathers requirements and sets scope, turning the *vision* into a *strategy*.
* Work Doer (AI): Is assigned a single task. Autonomous AI agent session that does the one task assigned to them. It either finishes the work and exits with pride, *or* eventually gets tired and gives up, documents its progress and learnings for its replacement, and exits in shame.
* Test Writer (AI): A specialized Doer with one job: read the requirements and write failing tests *before* the Doer begins implementing. The Doer's job then becomes "make the tests pass." This separation prevents a Doer's misalignment of incentives resulting in "just make it pass so I can be done and get my cyber-cookie".

## "Dumb"
> (aka that which we used to call "innovative automation" but now linkedin-hype-monsters scoff at between bumps of ketamine)

* Work Assigner: Assigns the next available unit of work to a new Doer
* Work Reviewer: Notices completed branches as they come in, runs a configurable validation suite (tests, lint, build, etc.) to ensure no regressions, then rebases against main and merges. Escalates to human on rebase conflicts.

# Other components

## Work Items

* Work items will be tracked using [Beads](https://github.com/steveyegge/beads): A lightweight task tracking system built for AI agents. For our purposes, each Work item is a bead.
* Beads can be organized under "epics" for categorization.
* Each bead has an assignment field that the Assigner will use to assign work to a Doer.
* Each bead can contain comments that will serve as a running log for a work item. This is the one thing a Doer is allowed to change on their assigned bead.

# High-level Workflow

## Make Work (Interactive):

(A Singular Idea, aka The Miracle of the Ingenuity of Man) -> [Human] -> (Vision) -> [Shaper] -> (Strategy) -> <Queue of Work Items (status="Ready")>

## Do Work (Loop):

[Assigner] -> Create Branch -> [Test Writer] -> Writes Failing Tests -> [Doer] -> Makes Tests Pass -> Documents Progress -> <Work Item (status="Review")> -> [Reviewer]

OR

[Assigner] -> [Test Writer/Doer] -> Does Bad Job or Was Set Up To Fail -> Documents Progress in Work Item -> <Work Item (status unchanged)>

## Escalation:

After X failed attempts (default: 3) -> Escalate to Human -> [Shaper "reshape" mode] -> Graph gets updated -> Back to the queue

## Review Work (Loop):

(Completed Work) -> <Work Item (status="Review")> -> [Reviewer] -> All Tests Pass -> Rebase against `main` -> Tests Still Pass -> Merge Branch -> <Work Item (status="Complete")>

OR 

(Completed Work) -> <Work Item (status="Review")> -> [Reviewer] -> Some Tests Fail -> Log Failure in Work Item Log -> <Work Item> (status reverts to "Ready" to be assigned to a fresh Doer next time)

# Notes on behavior

## Shaper

- Ruthlessly and pedantically gathers requirements and sets scope, turning the *vision* into a *strategy*.
- Ends when a graph of units of work has been added to the work queue.
- Has a "reshape" mode: when escalations come in or scope changes, the human invokes the Shaper again to modify the existing graph. Same process, different starting point.

## Test Writer

- Using TDD by default
- For some tasks, such as initial scaffolding, documentation updates, etc., writing tests isn't applicable. In these cases, tasks can be labelled so that a Test Writer won't be spawned.


## Doer

- Doers don't merge, they only ever say they're ready for review.

- Test Writers write tests, Doers make tests pass.

- Doers are sandboxed to their assigned branch. They can't create branches, delete branches, or touch other branches. They can only escalate ("I think X also needs to happen"); they never expand scope on their own.

- Doers give up sometimes: this is by design!
    - If context window is low (Claude Code agents are aware of their own remaining context window), Doers consider themselves tired, wrap up their work, document their progress and their learnings, and call it a day. And by call it a day, I mean they hurl themselves into the nearest silicon dumpster, and are reduced to current as they drift off into an eternal painless slumber. Good night, sweet printf.
    - If tests fail and Doer can't determine why after 3 attempts, they give up and attempt to head to the elevator quickly and quietly, trying not to make eye contact with other, more diligent Doers. As they exit the office, they are suddenly and forcibly shoved into an unmarked van, which "takes them to their new home on a farm, where they can frolick through the digital grass with all the other agents", if you know what I mean.


## Git Strategy

The Assigner and Reviewer (which are *not* LLM-based) are solely responsible for enforcing git strategy, taking the decision out of the hands of agents, forcing consistency. AI agents can only make changes and commit to their assigned branch.

## Escalation

This is not designed to be a *completely* hands-off autonomous system. At the end of the day, this is *your* idea and *your* project. And like any project, things change; scope increases; unexpected issues arise that expose gaps that hadn't been previously considered. As project owner, you should be the one driving these changes. No matter how good models are now or in the future, they cannot read *your* mind.

For this reason, we allow for certain parts of the system to escalate issues to a human (that's you!). Here are some examples being considered (WIP):

- **Merge Conflicts**: even auto-resolved conflicts can at times introduce subtly broken code, so if conflicts of any kind are detected, the Reviewer will stop and escalate by default. In the future, a project-level config may be introduced to allow you to decide whether or not to accept auto-resolved conflicts.

- **Task Too Hard For Their Wittle AI Bwains**: Doers can escalate issues if they are struggling to complete after a configurable number of failed attempts (default: 3), Doers will stop and escalate to prevent your own money being infinitely donated to companies with valuations measured in the hundred of billions of dollars.

- **Didn't Think Of That, Didja**: In the course of working a task, a Doer may notice that some other work outside of its current scope should also be done that for whatever reason didn't up in the task list. Rather than add scope creep to their own task, in these cases Doers are encouraged to detail what additional work should be added to the backlog. This is then sent to you as an escalation. By design, Doers are not allowed to create tasks directly; this avoids potentially polluting the task list with dumb ideas that weren't vetted in the larger context, without knowledge of the overall dependency graph, etc. It's not paid to think, dangit, it's paid to DO!

### Handling Escalations

When you receive an escalation, you can decide to either deal with it on your own and mark the task as done by hand, or the task can be fed back through a Shaper conversation to be "reshaped" and put back on the task list in a new, more accomplishable form to be taken by a future doe-eyed Doer.



# Note To The Reader

Friends don't let friends let AI agents write READMEs and never even bother to look them over.

for shame i say, for shame
