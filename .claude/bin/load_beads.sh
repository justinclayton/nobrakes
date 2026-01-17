#!/usr/bin/env bash
set -euo pipefail

# load_beads.sh - Convert SHAPER JSON output to bd CLI commands
#
# Usage: load_beads.sh <json_file>
#   json_file: Path to SHAPER JSON output file

JSON_FILE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVENTS_FILE="$PROJECT_ROOT/.claude/work_logs/EVENTS.jsonl"
ID_MAP_FILE="$PROJECT_ROOT/.claude/work_logs/bead_id_map.json"

if [ -z "$JSON_FILE" ]; then
    echo "Usage: load_beads.sh <json_file>" >&2
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File not found: $JSON_FILE" >&2
    exit 1
fi

# Initialize ID map if it doesn't exist
if [ ! -f "$ID_MAP_FILE" ]; then
    echo "{}" > "$ID_MAP_FILE"
fi

# Validate JSON
if ! jq empty "$JSON_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in $JSON_FILE" >&2
    exit 1
fi

echo "Loading beads from: $JSON_FILE"

# Extract epic name (optional)
EPIC_NAME=$(jq -r '.epic // empty' "$JSON_FILE")
if [ -n "$EPIC_NAME" ]; then
    echo "Epic: $EPIC_NAME"
fi

# Count beads
BEAD_COUNT=$(jq '.beads | length' "$JSON_FILE")
echo "Found $BEAD_COUNT beads to create"

# First pass: Create all beads and build ID mapping
echo ""
echo "=== Pass 1: Creating beads ==="

# Temporary file for new mappings
TEMP_MAP=$(mktemp)
trap "rm -f $TEMP_MAP" EXIT
cp "$ID_MAP_FILE" "$TEMP_MAP"

for i in $(seq 0 $((BEAD_COUNT - 1))); do
    SEMANTIC_ID=$(jq -r ".beads[$i].id" "$JSON_FILE")
    AREA=$(jq -r ".beads[$i].area" "$JSON_FILE")
    DESCRIPTION=$(jq -r ".beads[$i].description" "$JSON_FILE")
    STATUS=$(jq -r ".beads[$i].status // \"ready\"" "$JSON_FILE")

    echo "Creating bead: $SEMANTIC_ID ($AREA)"

    # Create bead with bd CLI
    # Use --silent to get only the ID back
    # Add area as a label for filtering
    BD_ID=$(bd create "$DESCRIPTION" \
        -l "area:$AREA" \
        -l "semantic:$SEMANTIC_ID" \
        -p 2 \
        --silent 2>/dev/null) || {
        echo "  Error: Failed to create bead $SEMANTIC_ID" >&2
        continue
    }

    echo "  Created: $BD_ID"

    # Update ID mapping
    jq --arg semantic "$SEMANTIC_ID" --arg bd "$BD_ID" \
        '. + {($semantic): $bd}' "$TEMP_MAP" > "${TEMP_MAP}.new" && mv "${TEMP_MAP}.new" "$TEMP_MAP"

    # Log creation event (JSONL format)
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq -n -c --arg ts "$TIMESTAMP" \
       --arg id "$BD_ID" \
       --arg semantic "$SEMANTIC_ID" \
       --arg agent "load_beads" \
       --arg event "bead_created" \
       '{"timestamp": $ts, "bead_id": $id, "semantic_id": $semantic, "agent": $agent, "event": $event}' \
       >> "$EVENTS_FILE"
done

# Save updated ID map
cp "$TEMP_MAP" "$ID_MAP_FILE"

# Second pass: Add dependencies
echo ""
echo "=== Pass 2: Adding dependencies ==="

for i in $(seq 0 $((BEAD_COUNT - 1))); do
    SEMANTIC_ID=$(jq -r ".beads[$i].id" "$JSON_FILE")
    DEPS=$(jq -r ".beads[$i].depends_on // [] | .[]" "$JSON_FILE")

    if [ -z "$DEPS" ]; then
        continue
    fi

    # Get the bd ID for this bead
    BD_ID=$(jq -r --arg s "$SEMANTIC_ID" '.[$s] // empty' "$ID_MAP_FILE")
    if [ -z "$BD_ID" ]; then
        echo "Warning: No bd ID found for $SEMANTIC_ID, skipping dependencies" >&2
        continue
    fi

    for DEP_SEMANTIC in $DEPS; do
        DEP_BD_ID=$(jq -r --arg s "$DEP_SEMANTIC" '.[$s] // empty' "$ID_MAP_FILE")
        if [ -z "$DEP_BD_ID" ]; then
            echo "Warning: Dependency $DEP_SEMANTIC not found for $SEMANTIC_ID" >&2
            continue
        fi

        echo "Adding dependency: $SEMANTIC_ID depends on $DEP_SEMANTIC"
        echo "  ($BD_ID depends on $DEP_BD_ID)"

        # bd dep add <blocked> <blocker> - the first arg depends on the second
        if ! bd dep add "$BD_ID" "$DEP_BD_ID" 2>/dev/null; then
            echo "  Warning: Failed to add dependency" >&2
        fi
    done
done

echo ""
echo "=== Load complete ==="
echo "ID mapping saved to: $ID_MAP_FILE"
echo ""
echo "Ready beads:"
bd ready --pretty 2>/dev/null || bd ready
