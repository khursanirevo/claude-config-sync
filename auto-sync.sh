#!/bin/bash
# Auto-sync script (run by cron)
# This does a silent sync + commit + push

SYNC_DIR="$HOME/claude-config-sync"
LOG_FILE="$SYNC_DIR/auto-sync.log"

cd "$SYNC_DIR"

# Load Slack webhook config if exists
if [ -f ".slack-config" ]; then
    source .slack-config
fi

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Send notification to Slack
slack_notify() {
    local message="$1"
    local color="${2:-#36a64f}"  # Default green

    # Only send if webhook is configured
    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        return 0
    fi

    curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"attachments\": [{
                \"color\": \"$color\",
                \"title\": \"Claude Config Sync\",
                \"text\": \"$message\",
                \"footer\": \"$(hostname)\",
                \"ts\": $(date +%s)
            }]
        }" >> "$LOG_FILE" 2>&1
}

log "=== Auto-sync started ==="
slack_notify "🔄 Auto-sync started at $(date '+%Y-%m-%d %H:%M')" "#439FE0"

# Run sync (capture output)
SYNC_OUTPUT=$(./sync.sh 2>&1)
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
slack_notify "✅ Sync complete!\n\n*Changes:* $CHANGES_COUNT file(s) updated\n*Commit:* $COMMIT_MSG\n*Host:* $(hostname)" "#36a64f"

echo "" >> "$LOG_FILE"
