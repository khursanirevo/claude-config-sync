#!/usr/bin/env bash
# rtk-hook-version: 2
# RTK Claude Code hook — rewrites commands to use rtk for token savings.
# Requires: rtk >= 0.23.0, jq
#
# IMPROVED: Filters out commands that shouldn't be rewritten to prevent errors
#
# This is a thin delegating hook: all rewrite logic lives in `rtk rewrite`,
# which is the single source of truth (src/discover/registry.rs).
# To add or change rewrite rules, edit the Rust registry — not this file.

if ! command -v jq &>/dev/null; then
  exit 0
fi

if ! command -v rtk &>/dev/null; then
  exit 0
fi

# Version guard: rtk rewrite was added in 0.23.0.
# Older binaries: warn once and exit cleanly (no silent failure).
RTK_VERSION=$(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -n "$RTK_VERSION" ]; then
  MAJOR=$(echo "$RTK_VERSION" | cut -d. -f1)
  MINOR=$(echo "$RTK_VERSION" | cut -d. -f2)
  # Require >= 0.23.0
  if [ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 23 ]; then
    echo "[rtk] WARNING: rtk $RTK_VERSION is too old (need >= 0.23.0). Upgrade: cargo install rtk" >&2
    exit 0
  fi
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# ============================================================================
# STEP 1: Filter out commands that should NOT be rewritten
# ============================================================================

# Function to check if command should be skipped
should_skip_cmd() {
  local cmd="$1"

  # Skip if already an rtk command
  if [[ "$cmd" == rtk* ]]; then
    return 0  # Skip
  fi

  # Skip simple utilities with numeric flags (common source of errors)
  # These patterns cause rtk to generate invalid syntax
  if [[ "$cmd" =~ ^[[:space:]]*(tail|head|wc|cut|sed|awk|grep)[[:space:]]+-[0-9] ]]; then
    return 0  # Skip
  fi

  # Skip commands that are unlikely to benefit from rtk
  local base_cmd
  base_cmd=$(echo "$cmd" | awk '{print $1}')
  
  case "$base_cmd" in
    # File operations that don't need rewriting
    cat|less|more|zless|zmore|bat|tail|head|wc|nl|od|xxd|hexdump)
      return 0  # Skip
      ;;
    # Text processing that doesn't benefit from rtk
    cut|tr|sort|uniq|shuf|tee|split|csplit)
      return 0  # Skip
      ;;
    # Simple system commands
    ls|dir|pwd|cd|date|uptime|whoami|id|groups)
      return 0  # Skip
      ;;
    # Test commands
    echo|printf|true|false|test)
      return 0  # Skip
      ;;
    # Package managers (don't interfere)
    apt|yum|dnf|pacman|brew|npm|yarn|pnpm|pip|cargo|gem)
      return 0  # Skip
      ;;
    # Git commands that work fine as-is
    git)
      # Only skip if it's a simple git command without complex flags
      # git status, git log, etc. are fine
      return 0  # Skip for now - can be refined later
      ;;
  esac

  return 1  # Don't skip - let rtk try to rewrite it
}

# Check if we should skip this command
if should_skip_cmd "$CMD"; then
  exit 0  # Pass through without rewriting
fi

# ============================================================================
# STEP 2: Delegate to rtk rewrite (only for commands that passed the filter)
# ============================================================================

# Delegate all rewrite logic to the Rust binary.
# rtk rewrite exits 1 when there's no rewrite — hook passes through silently.
REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null) || exit 0

# No change — nothing to do.
if [ "$CMD" = "$REWRITTEN" ]; then
  exit 0
fi

# ============================================================================
# STEP 3: Validate the rewritten command before using it
# ============================================================================

# Additional safety check: ensure rewritten command is valid
# This catches cases where rtk rewrite produces invalid syntax
if [[ "$REWRITTEN" =~ rtk\ read\ -[0-9] ]]; then
  # rtk read with numeric flag is invalid - skip this rewrite
  exit 0
fi

# If rewritten command contains error patterns, skip it
if [[ "$REWRITTEN" =~ error|Error|ERROR|unexpected|failed|Failed ]]; then
  exit 0
fi

# ============================================================================
# STEP 4: Apply the rewrite
# ============================================================================

ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "RTK auto-rewrite",
      "updatedInput": $updated
    }
  }'
