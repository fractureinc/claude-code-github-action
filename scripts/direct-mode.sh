#!/bin/bash
set -e

# Get input parameters
FEEDBACK=$1
ANTHROPIC_API_KEY=$2
OUTPUT_FILE=$3

# Set Anthropic API key
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Run Claude CLI and capture output
echo "Sending request to Claude..."
echo "$FEEDBACK" | claude -p - > "$OUTPUT_FILE"

echo "Claude's response written to $OUTPUT_FILE"