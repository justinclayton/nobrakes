#!/usr/bin/env bash
set -euo pipefail

BEAD_ID="$1"
STATUS="$2"  # done or failed
AGENT="$3"   # Doer identity

# Update bead status via bd CLI
if [ "$STATUS" = "done" ]; then
    # Close the bead (marks as closed/done)
    if ! bd close "$BEAD_ID" --actor "$AGENT" 2>/dev/null; then
        echo "Failed to close bead: $BEAD_ID" >&2
        exit 1
    fi
else
    # Mark as failed
    if ! bd update "$BEAD_ID" -s "$STATUS" --actor "$AGENT" 2>/dev/null; then
        echo "Failed to update bead status: $BEAD_ID -> $STATUS" >&2
        exit 1
    fi
fi

# Log as bead comment
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
bd comments add "$BEAD_ID" "[$TIMESTAMP] Status changed to $STATUS" --author "$AGENT" 2>/dev/null || true

echo "Bead $BEAD_ID marked as $STATUS"
