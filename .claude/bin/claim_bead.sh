#!/usr/bin/env bash
set -euo pipefail

AREA="$1"
AGENT="$2"

# Get next ready bead for this area (using label filter)
BEAD_JSON=$(bd ready -l "area:$AREA" -n 1 --json 2>/dev/null || echo "[]")

if [ "$BEAD_JSON" = "[]" ] || [ -z "$BEAD_JSON" ]; then
    echo "No ready beads for area: $AREA" >&2
    exit 1
fi

BEAD_ID=$(echo "$BEAD_JSON" | jq -r '.[0].id // empty')

if [ -z "$BEAD_ID" ]; then
    echo "No ready beads for area: $AREA" >&2
    exit 1
fi

# Claim the bead atomically
if ! bd update "$BEAD_ID" --claim --actor "$AGENT" 2>/dev/null; then
    echo "Failed to claim bead: $BEAD_ID" >&2
    exit 1
fi

# Log the claim as bead comment
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
bd comments add "$BEAD_ID" "[$TIMESTAMP] Claimed by $AGENT" --author "$AGENT" 2>/dev/null || true

echo "$BEAD_ID"
