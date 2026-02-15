#!/bin/bash

# Auto-Handoff Context Check Hook
# Runs on every UserPromptSubmit to check if context is low.
# If context usage is above threshold, triggers handoff skill.
#
# This replaces the PreCompact approach since PreCompact only fires
# when auto-compact is enabled.

# Threshold percentage - trigger handoff when context exceeds this
THRESHOLD=45

# Read hook input (JSON)
input=$(cat)

# Get transcript path
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Skip if no transcript
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    exit 0
fi

# Get context window size
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

# Calculate current context usage from transcript
context_length=$(jq -s '
    map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
    last |
    if . then
        (.message.usage.input_tokens // 0) +
        (.message.usage.cache_read_input_tokens // 0) +
        (.message.usage.cache_creation_input_tokens // 0)
    else 0 end
' < "$transcript_path")

# Skip if no data yet
if [[ "$context_length" -eq 0 ]]; then
    exit 0
fi

# Calculate percentage
pct=$((context_length * 100 / max_context))

# Trigger handoff if above threshold
if [[ $pct -ge $THRESHOLD ]]; then
    cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 AUTO-HANDOFF TRIGGERED (Context at ${pct}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL: Context at ${pct}%. You MUST immediately run the handoff
skill BEFORE responding to the user's message.

IMMEDIATE ACTION REQUIRED: /handoff

Do NOT respond to the user until handoff completes.

This preserves all context better than auto-compact would.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
fi
