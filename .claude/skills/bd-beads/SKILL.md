---
name: bd-beads
description: Create and manage beads (issues with dependencies) using the `bd` CLI. Use this skill when creating beads, managing epics, or working with the bead dependency graph.
---

# Bead Management with `bd` CLI

## Critical Rule

**NEVER edit `.beads/issues.jsonl` directly.** Always use the `bd` CLI. The CLI is authoritative for all bead operations.

## Creating Beads

### Basic syntax

```bash
bd create "Title/description of the bead" [flags]
```

### Key flags

| Flag | Purpose | Example |
|------|---------|---------|
| `--parent <id>` | Attach to epic | `--parent nobrakes-abc` |
| `--deps <ids>` | Set dependencies (comma-separated) | `--deps nobrakes-abc.1,nobrakes-abc.2` |
| `-l <labels>` | Add labels | `-l area:frontend` |
| `-t <type>` | Issue type | `-t epic` or `-t task` |
| `-d <desc>` | Extended description | `-d "More details here"` |
| `--silent` | Output only the ID | `--silent` |

### Creating an epic with children

```bash
# 1. Create the epic
EPIC=$(bd create "My Epic Title" --type epic -d "Epic description" --silent)

# 2. Create children with --parent and --deps
CHILD1=$(bd create "First task" --parent $EPIC --silent)
CHILD2=$(bd create "Second task" --parent $EPIC --deps $CHILD1 --silent)
CHILD3=$(bd create "Third task" --parent $EPIC --deps $CHILD1,$CHILD2 --silent)
```

### Dependency patterns

- No dependencies: omit `--deps`
- Single dependency: `--deps nobrakes-abc.1`
- Multiple dependencies: `--deps nobrakes-abc.1,nobrakes-abc.2,nobrakes-abc.3`

## Viewing Beads

```bash
# Show dependency graph for an epic
bd graph <epic-id>

# Show beads ready for work (no blockers)
bd ready

# Show details of a specific bead
bd show <bead-id>

# List all open beads
bd list --status open
```

## Workflow for Shapers

1. Elicit requirements from user
2. Design the bead graph (epic + children with dependencies)
3. Create the epic: `bd create "Epic title" --type epic --silent`
4. Create child beads with `--parent` and `--deps` flags
5. Verify with `bd graph <epic-id>`
6. Show `bd ready` to confirm what's available for doers

## ID Format

- Epics: `<prefix>-<id>` (e.g., `nobrakes-2jd`)
- Children: `<epic-id>.<n>` (e.g., `nobrakes-2jd.1`, `nobrakes-2jd.2`)

## Labels Convention

- `area:frontend` - Frontend work
- `area:backend` - Backend work
- `area:infra` - Infrastructure/DevOps
- `area:docs` - Documentation
