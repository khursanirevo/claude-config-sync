#!/bin/bash
# Quick check of context usage - triggers handoff if > 70%

set -e

TRANSCRIPT_DIR="${HOME}/.claude/transcripts"
SYNC_DIR="${HOME}/claude-config-sync"

# Find most recent transcript
latest_transcript=$(ls -t "$TRANSCRIPT_DIR"/*.json 2>/dev/null | head -1)

if [[ -z "$latest_transcript" ]]; then
    echo "No recent transcript found"
    exit 0
fi

# Get model info from transcript (Claude Code stores this in the transcript)
model_name=$(jq -r 'last | select(.message.content) | .model.display_name // "claude-sonnet-4-5" // "unknown"' "$latest_transcript" 2>/dev/null || echo "unknown")
cwd=$(jq -r 'last | select(.message.content) | .cwd // "'"$(pwd)"'"' "$latest_transcript" 2>/dev/null || echo "$(pwd)")
max_context=200000  # Default context window for Sonnet 4.5

# Build JSON input for auto-handoff script
status_json=$(jq -n \
    --arg transcript_path "$latest_transcript" \
    --arg cwd "$cwd" \
    '{
        transcript_path: $transcript_path,
        cwd: $cwd,
        context_window: {context_window_size: 200000}
    }')

# Run auto-handoff check
echo "$status_json" | "$SYNC_DIR/scripts/auto-handoff.sh"
