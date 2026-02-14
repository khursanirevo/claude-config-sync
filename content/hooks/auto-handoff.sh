#!/bin/bash
# Seamless Auto-Handoff Hook for Claude Code
# Detects when context was cleared and restores saved state
# This hook runs before each user message

HANDOFF_STATE="$HOME/claude-config-sync/.handoff_state.json"

# Check if there's a pending handoff state to restore
if [[ -f "$HANDOFF_STATE" ]]; then
    # Read the saved state
    pct=$(jq -r '.pct // "?"' "$HANDOFF_STATE" 2>/dev/null)
    context=$(jq -r '.context // "?"' "$HANDOFF_STATE" 2>/dev/null)
    max_context=$(jq -r '.max_context // "?"' "$HANDOFF_STATE" 2>/dev/null)
    cwd=$(jq -r '.cwd // ""' "$HANDOFF_STATE" 2>/dev/null)
    branch=$(jq -r '.branch // ""' "$HANDOFF_STATE" 2>/dev/null)

    # Format last context messages
    last_context=$(jq -r '.last_context[]? // empty' "$HANDOFF_STATE" 2>/dev/null | sed 's/^/• /' | head -3)

    # Format recent files
    recent_files=$(jq -r '.recent_files[]? // empty' "$HANDOFF_STATE" 2>/dev/null | sed 's/^/  - /' | head -5)

    # Build and inject the resume message
    cat <<RESUME

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 RESUMING FROM CONTEXT HANDOFF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Previous Session Context (saved at ${pct}% usage):**

📍 **Location:** ${cwd}
🔀 **Branch:** ${branch:-"(not a git repo)"}
📊 **Context Was:** ${context} / ${max_context} tokens (${pct}%)

**Recent Task Context:**
${last_context}

**Recently Accessed Files:**
${recent_files}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Continue working on the task above. The conversation context was
cleared to free memory, but all essential state has been preserved.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RESUME

    # Delete the state file after restoring
    rm -f "$HANDOFF_STATE"

    # Log the resume
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Handoff state restored"
        echo "  Previous context: ${context} / ${max_context} tokens (${pct}%)"
    } >> "$HOME/claude-config-sync/handoff.log" 2>/dev/null
fi

# Hook produces no output when there's nothing to restore
