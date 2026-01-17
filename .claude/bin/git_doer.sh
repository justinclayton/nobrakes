#!/usr/bin/env bash
set -euo pipefail

# git_doer.sh - Simplified wrapper for run_doer.sh
#
# Usage: git_doer.sh <bead-id> <area>
#
# This is a convenience wrapper that generates an agent ID and calls run_doer.sh

BEAD_ID="${1:-}"
AREA="${2:-}"

if [ -z "$BEAD_ID" ] || [ -z "$AREA" ]; then
    echo "Usage: git_doer.sh <bead-id> <area>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate agent ID
AGENT_ID="doer-$(date +%s)-$$"

# Delegate to run_doer.sh
exec "$SCRIPT_DIR/run_doer.sh" "$BEAD_ID" "$AREA" "$AGENT_ID"
