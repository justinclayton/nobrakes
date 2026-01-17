# Beads Specification

A bead is a durable unit of work in this workflow. It has the following fields:

- `id` (string): Unique identifier
- `area` (string): Ownership (backend, frontend, infra, etc.)
- `description` (string): Detailed instructions for a single task
- `status` (string): One of `ready`, `in_progress`, `done`, `blocked`, `failed`
- `depends_on` (array[string]): IDs of beads that must be completed first
- `claimed_by` (string|null): Agent currently working on this bead
- `claim_until` (timestamp|null): Lease expiration

State transitions:
- ready → in_progress → done
- ready → in_progress → failed
- blocked → ready (when dependencies are satisfied)

Notes:
- Beads must be independently executable
- Dependencies are always explicit
- No bead may perform work outside its description

# Beads CLI Runtime

This workflow depends on the Yegge Go CLI for beads:
https://github.com/steveyegge/beads

Agents should assume that:

- The `beads` CLI is installed and available in PATH
- It provides durable state, dependency management, and locking for beads
- Doers claim beads via CLI before executing
- CLI is authoritative; never modify beads outside the CLI
- Shapers output JSON, converted to CLI formulas/molecules via adapter scripts
