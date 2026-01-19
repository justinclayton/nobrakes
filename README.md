# nobrakes

A lightweight but opinionated orchestration workflow for autonomous AI agent software development.

# Personas

## "Smart"
> (aka that which is notoriously non-deterministic and unreliable, yet somehow has inherited / will inherit the earth)

* Human (you): Has a cool idea; discusses vision / intent to the Work Shaper.
* Work Shaper (AI): The top of the funnel. Interactive AI agent session that ruthlessly and pedantically gathers requirements and sets scope, turning the *vision* into a *strategy*.
* Work Doer (AI): Is assigned a single task. Autonomous AI agent session that does the one task assigned to them. It either finishes the work and exits with pride, *or* eventually gets tired and gives up, documents its progress and learnings for its replacement, and exits in shame.

## "Dumb"
> (aka that which we used to call "innovative automation" but now linkedin-hype-monsters scoff at between bumps of ketamine)

* Work Assigner: Assigns the next available unit of work to a new Doer
* Work Reviewer): Notices completed branches as they come in, runs full test suite to ensure no regressions have been introduced, then merges branch using a rebase-against-main strategy.

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

[Assigner] -> Create Branch -> <Work Item (status="In Progress")>+[Doer] -> Does Work Good -> Documents Progress in Work Item Log -> <Work Item (status="Review")> -> [Reviewer]

OR

[Assigner] -> <Work>+[Doer] -> Does Bad Job or Was Set Up To Fail -> Documents Progress in Work Item -> <Work Item (status unchanged)>

## Review Work (Loop):

(Completed Work) -> <Work Item (status="Review")> -> [Reviewer] -> All Tests Pass -> Rebase and Merge Branch -> <Work Item (status="Complete")>

OR 

(Completed Work) -> <Work Item (status="Review")> -> [Reviewer] -> Some Tests Fail -> Log Failure in Work Item Log -> <Work Item> (status reverts to "Ready" to be assigned to a fresh Doer next time)

# Random ideas for this that need a place to go

## Shaper

- Ruthlessly and pedantically gathers requirements and sets scope, turning the *vision* into a *strategy*.
- Ends when a graph of units of work has been added to the work queue.

## Doer

- Doers don't merge, they only ever say they're ready for review.

- Doers write tests!

Q: Should it be TDD/BDD by necessity? Should this be a toggle?

- Doers give up sometimes: this is by design!
    - If context window is low (Claude Code agents are aware of their own remaining context window), Doers consider themselves tired, wrap up their work, document their progress and their learnings, and call it a day. And by call it a day, I mean they hurl themselves into the nearest silicon dumpster, and are reduced to current as they drift off into an eternal painless slumber. Good night, sweet printf.
    - If tests fail and Doer can't determine why after 3 attempts, they give up and attempt to head to the elevator quickly and quietly, trying not to make eye contact with other, more diligent Doers. As they exit the offie, they are suddenly and forcibly shoved into an unmarked van, which "takes them to their new home on a farm, where they can frolick through the digital grass with all the other agents".

Q: If multiple Doers have failed to make progress on an item after X attempts, should there be an "escalate to human" protocol?

## System

Q: Maybe the user should be allowed to name their various personas. Maybe you want the Shaper to be called "Po", because it feels like a Product Owner or X-Wing pilot. Maybe you want the Reviewer to be called "Marge", because it merges. Maybe you want the Assigner to be called "Mr. Fuckleface", because it reminds you of your old manager from Burger King, Mr. Fuckleface.

# Note To The Reader

Friends don't let friends let AI agents write READMEs and never even bother to look them over.

for shame i say, for shame
