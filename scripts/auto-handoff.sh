#!/bin/bash
# Auto-handoff when context exceeds 70%
# Reads from stdin (same input format as context-bar.sh)
# Usage: cat status.json | ./scripts/auto-handoff.sh

set -e

THRESHOLD=70  # Trigger handoff at 70% context

input=$(cat)

# Get transcript path
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    # No transcript yet, no need to handoff
    exit 0
fi

# Get context window size
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

# Calculate current context usage
context_length=$(jq -s '
    map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
    map(select(.message.usage.input_tokens > 0)) |
    last |
    if . then
        (.message.usage.input_tokens // 0) +
        (.message.usage.cache_read_input_tokens // 0) +
        (.message.usage.cache_creation_input_tokens // 0)
    else 0 end
' < "$transcript_path")

# Calculate percentage
pct=$((context_length * 100 / max_context))

# Check if threshold exceeded
if [[ $pct -gt $THRESHOLD ]]; then
    # Create handoff log
    log_file="$HOME/claude-config-sync/handoff.log"
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto-handoff triggered at ${pct}% (threshold: ${THRESHOLD}%)"
        echo "  Context: ${context_length} / ${max_context} tokens"
        echo "  Transcript: $transcript_path"
    } >> "$log_file"

    # Trigger handoff via dx plugin
    if command -v claude &>/dev/null; then
        echo "🔄 Context at ${pct}% - triggering auto-handoff..."
        echo "1. Clearing context..."
        echo "2. Running handoff..."
        echo "3. Reading HANDOVER.md..."

        # Output commands for Claude to execute
        cat <<'HANDOFF_COMMANDS'

<handle_action>
<tools>
None
</tools>
<execute>
Please perform the following actions:

1. **Clear the context** - Clear the conversation context to free up memory
2. **Run dx handoff** - Execute: `/dx:gha handoff`
3. **Read HANDOVER.md** - Read the file at `~/claude-config-sync/HANDOVER.md` to understand the current state

Context was at ${pct}% (${context_length}/${max_context} tokens), which exceeds the ${THRESHOLD}% threshold.
</execute>
</handle_action>

HANDOFF_COMMANDS
    fi
fi
