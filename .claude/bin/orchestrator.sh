#!/usr/bin/env bash
set -euo pipefail

# orchestrator.sh - Main control loop for automated bead execution
#
# Usage: orchestrator.sh [options]
#   --area <area>           Filter beads by area (e.g., backend, frontend, infra)
#   --max-iterations <n>    Maximum number of beads to process (default: unlimited)
#   --sleep <seconds>       Sleep between iterations when no work (default: 0, exit instead)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVENTS_FILE="$PROJECT_ROOT/.claude/work_logs/EVENTS.jsonl"

# Parse arguments
AREA=""
MAX_ITERATIONS=0
SLEEP_TIME=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --area)
            AREA="$2"
            shift 2
            ;;
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --sleep)
            SLEEP_TIME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: orchestrator.sh [options]"
            echo ""
            echo "Options:"
            echo "  --area <area>           Filter beads by area"
            echo "  --max-iterations <n>    Maximum beads to process (0=unlimited)"
            echo "  --sleep <seconds>       Sleep when no work (0=exit instead)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=== Nobrakes Orchestrator ==="
echo "Area filter: ${AREA:-all}"
echo "Max iterations: ${MAX_ITERATIONS:-unlimited}"
echo ""

ITERATION=0

while true; do
    ITERATION=$((ITERATION + 1))

    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$ITERATION" -gt "$MAX_ITERATIONS" ]; then
        echo "Reached max iterations ($MAX_ITERATIONS), exiting"
        exit 0
    fi

    echo ""
    echo "=== Iteration $ITERATION ==="
    echo ""

    # Get next ready bead (or in_progress for continuation)
    # Filter to tasks only - epics are containers, not executable work
    if [ -n "$AREA" ]; then
        BEAD_JSON=$(bd ready -t task -l "area:$AREA" -n 1 --json 2>/dev/null || echo "[]")
    else
        BEAD_JSON=$(bd ready -t task -n 1 --json 2>/dev/null || echo "[]")
    fi

    if [ "$BEAD_JSON" = "[]" ] || [ -z "$BEAD_JSON" ]; then
        echo "No ready beads found"

        if [ "$SLEEP_TIME" -gt 0 ]; then
            echo "Sleeping for $SLEEP_TIME seconds..."
            sleep "$SLEEP_TIME"
            continue
        else
            echo "Exiting (no work available)"
            exit 0
        fi
    fi

    BEAD_ID=$(echo "$BEAD_JSON" | jq -r '.[0].id // empty')
    BEAD_AREA=$(echo "$BEAD_JSON" | jq -r '.[0].labels // [] | .[] | select(startswith("area:")) | split(":")[1]' | head -1)

    if [ -z "$BEAD_AREA" ]; then
        BEAD_AREA="unknown"
    fi

    echo "Found bead: $BEAD_ID (area: $BEAD_AREA)"

    # Generate unique agent ID for this doer instance
    AGENT_ID="doer-$(date +%s)-$$"

    echo "Spawning DOER: $AGENT_ID"
    echo ""

    # Run the doer
    DOER_EXIT=0
    "$SCRIPT_DIR/run_doer.sh" "$BEAD_ID" "$BEAD_AREA" "$AGENT_ID" || DOER_EXIT=$?

    # Log orchestrator event
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    case $DOER_EXIT in
        0)
            echo ""
            echo "DOER completed successfully"
            jq -n -c --arg ts "$TIMESTAMP" \
               --arg id "$BEAD_ID" \
               --arg agent "orchestrator" \
               --arg event "iteration_complete" \
               --arg doer "$AGENT_ID" \
               '{"timestamp": $ts, "bead_id": $id, "agent": $agent, "event": $event, "doer": $doer}' \
               >> "$EVENTS_FILE"
            ;;
        2)
            echo ""
            echo "DOER exhausted context, will continue on next iteration"
            jq -n -c --arg ts "$TIMESTAMP" \
               --arg id "$BEAD_ID" \
               --arg agent "orchestrator" \
               --arg event "iteration_paused" \
               --arg doer "$AGENT_ID" \
               '{"timestamp": $ts, "bead_id": $id, "agent": $agent, "event": $event, "doer": $doer}' \
               >> "$EVENTS_FILE"
            # Continue to next iteration - will pick up same bead if still in_progress
            ;;
        *)
            echo ""
            echo "DOER failed or blocked (exit code: $DOER_EXIT)"
            jq -n -c --arg ts "$TIMESTAMP" \
               --arg id "$BEAD_ID" \
               --arg agent "orchestrator" \
               --arg event "iteration_failed" \
               --arg exit_code "$DOER_EXIT" \
               --arg doer "$AGENT_ID" \
               '{"timestamp": $ts, "bead_id": $id, "agent": $agent, "event": $event, "exit_code": $exit_code, "doer": $doer}' \
               >> "$EVENTS_FILE"
            # Continue to next bead
            ;;
    esac

    echo ""
    echo "---"
done
