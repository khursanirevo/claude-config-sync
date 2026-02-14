#!/bin/bash
# Auto-sync script (run by cron)
# This does a silent sync + commit + push

# Get the script root directory
CS_ROOT="${CS_ROOT:-$HOME/claude-config-sync}"

# Source common utilities
# shellcheck source=lib/common.sh
if [[ -f "$CS_ROOT/lib/common.sh" ]]; then
    source "$CS_ROOT/lib/common.sh"
else
    echo "Error: lib/common.sh not found" >&2
    exit 1
fi

LOG_FILE="$CS_LOG_DIR/auto-sync.log"

cs_cd_root
cs_ensure_logs

# Load Slack webhook config if exists
cs_load_slack_config

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Auto-sync started ==="
cs_slack_notify "🔄 Auto-sync started at $(date '+%Y-%m-%d %H:%M')" "#439FE0"

# Run sync (capture output)
SYNC_OUTPUT=$(bash "$CS_LIB_DIR/sync.sh" 2>&1)
echo "$SYNC_OUTPUT" >> "$LOG_FILE"

# Check if there are changes
if git diff-index --quiet HEAD -- 2>/dev/null; then
    log "No changes detected"
    log "=== Auto-sync complete (no changes) ==="
    echo "" >> "$LOG_FILE"
    exit 0
fi

# Add and commit
git add -A
COMMIT_MSG="Auto-sync: $(date '+%Y-%m-%d %H:%M')"
git commit -m "$COMMIT_MSG" >> "$LOG_FILE" 2>&1

# Push
git push >> "$LOG_FILE" 2>&1

log "=== Auto-sync complete (changes pushed) ==="

# Send success notification with changes summary
CHANGES_COUNT=$(git diff HEAD~1 --name-only | wc -l)
cs_slack_notify "✅ Sync complete!\n\n*Changes:* $CHANGES_COUNT file(s) updated\n*Commit:* $COMMIT_MSG\n*Host:* $(hostname)" "#36a64f"

echo "" >> "$LOG_FILE"
