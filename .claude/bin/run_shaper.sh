#!/usr/bin/env bash
set -euo pipefail

# run_shaper.sh - Interactive SHAPER session with system contract injected
#
# Usage: run_shaper.sh [output_file]
#   output_file: Where to save the SHAPER's JSON output (default: stdout instructions)

OUTPUT_FILE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Build system prompt from SHAPER persona + system contract
build_system_prompt() {
    echo "# SHAPER System Prompt"
    echo ""
    cat "$PROJECT_ROOT/.claude/agent_personas/SHAPER.md"
    echo ""
    echo "---"
    echo "# System Contract"
    echo ""
    for contract_file in "$PROJECT_ROOT/.claude/system_contract/"*.md; do
        if [ -f "$contract_file" ]; then
            echo "## $(basename "$contract_file" .md)"
            echo ""
            cat "$contract_file"
            echo ""
        fi
    done
    echo "---"
    echo ""
    echo "# Output Instructions"
    echo ""
    echo "When you have finished shaping the work, output your final JSON wrapped in a code block:"
    echo ""
    echo '```json'
    echo '{'
    echo '  "epic": "...",  '
    echo '  "beads": [...]'
    echo '}'
    echo '```'
    echo ""
    if [ -n "$OUTPUT_FILE" ]; then
        echo "The human will save your JSON output to: $OUTPUT_FILE"
    fi
}

# Create temporary file for system prompt
SYSTEM_PROMPT_FILE=$(mktemp)
trap "rm -f $SYSTEM_PROMPT_FILE" EXIT

build_system_prompt > "$SYSTEM_PROMPT_FILE"

echo "Starting interactive SHAPER session..."
echo "System contract and SHAPER persona loaded."
if [ -n "$OUTPUT_FILE" ]; then
    echo "When done, copy the JSON output to: $OUTPUT_FILE"
fi
echo ""
echo "---"
echo ""

# Run claude interactively with the system prompt
claude --system-prompt "$SYSTEM_PROMPT_FILE"
