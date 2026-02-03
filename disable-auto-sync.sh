#!/bin/bash
# Disable automatic daily sync

set -e

CRON_COMMENT="claude-config-sync-auto"

echo "=== Disabling Automatic Daily Sync ==="
echo ""

# Remove cron job
crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" | crontab -

echo "✓ Auto-sync disabled"
echo ""
echo "To re-enable:"
echo "  ./enable-auto-sync.sh"
