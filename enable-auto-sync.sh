#!/bin/bash
# Enable automatic daily sync via cron

set -e

SYNC_DIR="$HOME/claude-config-sync"
CRON_COMMENT="claude-config-sync-auto"

echo "=== Enabling Automatic Daily Sync ==="
echo ""

# Remove existing cron job if it exists
crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" | crontab -

# Get current crontab
current_cron=$(crontab -l 2>/dev/null || true)

# Add new cron job (runs at 9 PM daily)
cat >> /tmp/crontab.tmp << CRON
# $CRON_COMMENT - Daily sync at 9 PM
0 21 * * * $SYNC_DIR/auto-sync.sh >> $SYNC_DIR/auto-sync.log 2>&1
CRON

# Append existing cron entries
if [[ -n "$current_cron" ]]; then
    echo "$current_cron" >> /tmp/crontab.tmp
fi

# Install new crontab
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp

echo "✓ Auto-sync enabled!"
echo ""
echo "Schedule: Daily at 9:00 PM"
echo "Log file: $SYNC_DIR/auto-sync.log"
echo ""
echo "To view logs:"
echo "  tail -f $SYNC_DIR/auto-sync.log"
echo ""
echo "To disable:"
echo "  ./disable-auto-sync.sh"
echo ""
echo "To change schedule, edit crontab:"
echo "  crontab -e"
