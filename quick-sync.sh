#!/bin/bash
# Quick sync + commit + push in one command

set -e

SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

# Load Slack webhook config if exists
if [ -f ".slack-config" ]; then
    source .slack-config
fi

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
        }" > /dev/null
}

echo "=== Quick Sync ==="
echo ""

# Run sync
./sync.sh

echo ""
echo "=== Committing & Pushing ==="
echo ""

# Add everything
git add -A

# Check if there's anything to commit
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "No changes to commit."
    exit 0
fi

# Commit with auto-generated message
COMMIT_MSG="Sync: $(date +'%Y-%m-%d %H:%M')"

git commit -m "$COMMIT_MSG

Auto-synced from ~/.claude"

# Push
git push

# Get changes count
CHANGES_COUNT=$(git diff HEAD~1 --name-only | wc -l)

# Send success notification
slack_notify "✅ Manual sync complete!\n\n*Changes:* $CHANGES_COUNT file(s) updated\n*Commit:* $COMMIT_MSG\n*Host:* $(hostname)" "#36a64f"

echo ""
echo "=== Done! ==="
