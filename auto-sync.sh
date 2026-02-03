#!/bin/bash
# Auto-sync script (run by cron)
# This does a silent sync + commit + push

SYNC_DIR="$HOME/claude-config-sync"
LOG_FILE="$SYNC_DIR/auto-sync.log"

cd "$SYNC_DIR"

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Auto-sync started ==="

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
git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1

# Push
git push >> "$LOG_FILE" 2>&1

log "=== Auto-sync complete (changes pushed) ==="
echo "" >> "$LOG_FILE"
