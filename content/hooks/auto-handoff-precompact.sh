#!/bin/bash

# Auto-Handoff PreCompact Hook
# This hook triggers automatic handoff creation when context approaches limit.
# It outputs instructions that Claude will execute immediately.
#
# How it works:
#   Hook outputs message → Claude reads message → Claude executes the skill
#
# Installation:
#   1. Copy this script to ~/.claude/hooks/
#   2. Make it executable: chmod +x ~/.claude/hooks/auto-handoff-precompact.sh
#   3. Add to ~/.claude/settings.json (see README for details)

cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 AUTO-HANDOFF TRIGGERED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL: The context is approaching its limit. You MUST now
run the handoff skill to preserve conversation state.

Execute: /handoff

After handoff completes, inform the user they should:
1. Run: /clear
2. Start fresh conversation with: @HANDOFF.md

This preserves all context better than auto-compact would.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
