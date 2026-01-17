#!/usr/bin/env bash
set -euo pipefail

# run_doer.sh - Execute ONE bead with proper context injection
#
# Usage: run_doer.sh <bead-id> <area> <agent-id>
#
# Exit codes:
#   0 = completed (tests pass, merged)
#   1 = failed/blocked
#   2 = context exhausted (progress saved)

BEAD_ID="${1:-}"
AREA="${2:-}"
AGENT_ID="${3:-}"

if [ -z "$BEAD_ID" ] || [ -z "$AREA" ] || [ -z "$AGENT_ID" ]; then
    echo "Usage: run_doer.sh <bead-id> <area> <agent-id>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Per-bead notes go to bd comments; orchestrator events go to EVENTS.jsonl
HISTORY_FILE="$PROJECT_ROOT/.claude/work_logs/bead_${BEAD_ID}_history.md"

echo "=== DOER: $AGENT_ID ==="
echo "Bead: $BEAD_ID"
echo "Area: $AREA"
echo ""

# Step 1: Verify bead is claimable (ready or in_progress by us)
echo "Checking bead status..."
BEAD_JSON=$(bd show "$BEAD_ID" --json | jq -r '.[0]' 2>/dev/null) || {
    echo "Error: Bead $BEAD_ID not found" >&2
    exit 1
}

BEAD_STATUS=$(echo "$BEAD_JSON" | jq -r '.status // empty')
BEAD_ASSIGNEE=$(echo "$BEAD_JSON" | jq -r '.assignee // empty')

if [ "$BEAD_STATUS" = "closed" ]; then
    echo "Bead $BEAD_ID is already closed" >&2
    exit 0
fi

if [ "$BEAD_STATUS" != "open" ] && [ "$BEAD_STATUS" != "in_progress" ]; then
    echo "Bead $BEAD_ID is not claimable (status: $BEAD_STATUS)" >&2
    exit 1
fi

# Step 2: Claim the bead if not already claimed by us
if [ "$BEAD_STATUS" = "open" ] || [ "$BEAD_ASSIGNEE" != "$AGENT_ID" ]; then
    echo "Claiming bead..."
    if ! bd update "$BEAD_ID" --claim --actor "$AGENT_ID" 2>/dev/null; then
        echo "Error: Failed to claim bead $BEAD_ID" >&2
        exit 1
    fi
fi

# Step 3: Create/checkout git branch
BRANCH_NAME="$AREA/$BEAD_ID"
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

echo "Setting up git branch: $BRANCH_NAME"

# Check if branch exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "Checking out existing branch..."
    git checkout "$BRANCH_NAME"
else
    echo "Creating new branch from $MAIN_BRANCH..."
    git checkout -b "$BRANCH_NAME" "$MAIN_BRANCH" 2>/dev/null || git checkout -b "$BRANCH_NAME"
fi

# Step 4: Build context
echo "Building context..."
CONTEXT_FILE=$(mktemp)
trap "rm -f $CONTEXT_FILE" EXIT

# Get bead description
BEAD_DESCRIPTION=$(echo "$BEAD_JSON" | jq -r '.title // empty')
BEAD_BODY=$(echo "$BEAD_JSON" | jq -r '.description // empty')

{
    echo "# DOER Context"
    echo ""
    echo "## Your Identity"
    echo "Agent ID: $AGENT_ID"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "## Current Bead"
    echo "ID: $BEAD_ID"
    echo "Area: $AREA"
    echo "Title: $BEAD_DESCRIPTION"
    echo ""
    if [ -n "$BEAD_BODY" ]; then
        echo "### Description"
        echo "$BEAD_BODY"
        echo ""
    fi
    echo "---"
    echo ""

    # Include work history if exists
    if [ -f "$HISTORY_FILE" ]; then
        echo "## Previous Work on This Bead"
        echo ""
        cat "$HISTORY_FILE"
        echo ""
        echo "---"
        echo ""
    fi

    # Include DOER persona
    echo "## DOER Persona"
    echo ""
    cat "$PROJECT_ROOT/.claude/agent_personas/DOER.md"
    echo ""
    echo "---"
    echo ""

    # Include system contract
    echo "## System Contract"
    echo ""
    for contract_file in "$PROJECT_ROOT/.claude/system_contract/"*.md; do
        if [ -f "$contract_file" ]; then
            echo "### $(basename "$contract_file" .md)"
            echo ""
            cat "$contract_file"
            echo ""
        fi
    done
} > "$CONTEXT_FILE"

# Step 5: Run claude with DOER persona
echo ""
echo "=== Starting DOER execution ==="
echo ""

OUTPUT_FILE=$(mktemp)

# Run claude --print (non-interactive, prints output)
# The DOER will execute the bead and output a status marker
if claude --print --dangerously-skip-permissions --system-prompt "$(cat "$CONTEXT_FILE")" \
    "Execute the bead described above. When done, include your status marker." \
    > "$OUTPUT_FILE" 2>&1; then
    CLAUDE_EXIT=0
else
    CLAUDE_EXIT=$?
fi

# Display output
cat "$OUTPUT_FILE"

# Step 6: Parse output for status marker
STATUS_LINE=$(grep -o '\[STATUS: [A-Z_]*\]' "$OUTPUT_FILE" | tail -1 || echo "")
DOER_STATUS=""

case "$STATUS_LINE" in
    "[STATUS: COMPLETED]")
        DOER_STATUS="completed"
        ;;
    "[STATUS: CONTEXT_EXHAUSTED]")
        DOER_STATUS="context_exhausted"
        ;;
    "[STATUS: BLOCKED]")
        DOER_STATUS="blocked"
        ;;
    "[STATUS: FAILED]")
        DOER_STATUS="failed"
        ;;
    *)
        echo ""
        echo "Error: No valid status marker found in output" >&2
        echo "DOER must emit [STATUS: COMPLETED|CONTEXT_EXHAUSTED|BLOCKED|FAILED]" >&2
        # Missing status marker = failed, never assume success
        DOER_STATUS="failed"
        ;;
esac

echo ""
echo "=== DOER Status: $DOER_STATUS ==="

# Step 7: Handle based on status
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

case "$DOER_STATUS" in
    "completed")
        echo "Committing and marking done..."

        # Commit any changes (including untracked files)
        # Check for: unstaged changes, staged changes, OR untracked files
        HAS_CHANGES=false
        if ! git diff --quiet || ! git diff --cached --quiet; then
            HAS_CHANGES=true
        elif [ -n "$(git ls-files --others --exclude-standard)" ]; then
            HAS_CHANGES=true
        fi

        if [ "$HAS_CHANGES" = true ]; then
            git add -A
            git commit -m "feat($BEAD_ID): complete bead execution

Co-Authored-By: $AGENT_ID" || true
        fi

        # Merge to main BEFORE marking bead as done
        # This ensures we don't close the bead if merge fails
        echo "Merging to $MAIN_BRANCH..."

        # Stash any uncommitted changes (e.g., from logging) before checkout
        STASH_NEEDED=false
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "Stashing uncommitted changes before checkout..."
            git stash push -m "auto-stash before merge for $BEAD_ID"
            STASH_NEEDED=true
        fi

        if ! git checkout "$MAIN_BRANCH"; then
            echo "Error: Failed to checkout $MAIN_BRANCH" >&2
            [ "$STASH_NEEDED" = true ] && git stash pop || true
            rm -f "$OUTPUT_FILE"
            exit 1
        fi

        if ! git merge "$BRANCH_NAME" --no-edit; then
            echo "Error: Merge conflict, aborting merge and returning to $BRANCH_NAME" >&2
            git merge --abort 2>/dev/null || true
            git checkout "$BRANCH_NAME"
            [ "$STASH_NEEDED" = true ] && git stash pop || true
            rm -f "$OUTPUT_FILE"
            exit 1
        fi

        # Restore stashed changes if any
        [ "$STASH_NEEDED" = true ] && git stash pop || true

        # Only mark bead as done AFTER successful merge
        "$SCRIPT_DIR/complete_bead.sh" "$BEAD_ID" "done" "$AGENT_ID"

        # Log completion as bead comment
        bd comments add "$BEAD_ID" "[$TIMESTAMP] Completed by $AGENT_ID" --author "$AGENT_ID" 2>/dev/null || true

        rm -f "$OUTPUT_FILE"
        exit 0
        ;;

    "context_exhausted")
        echo "Saving progress for continuation..."

        # Commit any progress (including untracked files)
        HAS_CHANGES=false
        if ! git diff --quiet || ! git diff --cached --quiet; then
            HAS_CHANGES=true
        elif [ -n "$(git ls-files --others --exclude-standard)" ]; then
            HAS_CHANGES=true
        fi

        if [ "$HAS_CHANGES" = true ]; then
            git add -A
            git commit -m "wip($BEAD_ID): progress checkpoint

Context exhausted, continuation needed.

Co-Authored-By: $AGENT_ID" || true
        fi

        # Log context exhaustion as bead comment
        bd comments add "$BEAD_ID" "[$TIMESTAMP] Context exhausted, progress saved. Continuation needed." --author "$AGENT_ID" 2>/dev/null || true

        rm -f "$OUTPUT_FILE"
        exit 2
        ;;

    "blocked")
        echo "Bead is blocked, needs SHAPER attention..."

        # Update bead status
        bd update "$BEAD_ID" -s "blocked" --actor "$AGENT_ID" 2>/dev/null || true

        # Log block as bead comment
        bd comments add "$BEAD_ID" "[$TIMESTAMP] Blocked - needs SHAPER attention" --author "$AGENT_ID" 2>/dev/null || true

        rm -f "$OUTPUT_FILE"
        exit 1
        ;;

    "failed")
        echo "Bead execution failed..."

        # Update bead status
        "$SCRIPT_DIR/complete_bead.sh" "$BEAD_ID" "failed" "$AGENT_ID" || true

        # Log failure as bead comment
        bd comments add "$BEAD_ID" "[$TIMESTAMP] Failed - encountered unrecoverable error" --author "$AGENT_ID" 2>/dev/null || true

        rm -f "$OUTPUT_FILE"
        exit 1
        ;;
esac
