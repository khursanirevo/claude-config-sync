#!/bin/bash
# Quick sync + commit + push in one command

set -e

SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

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
git commit -m "Sync: $(date +'%Y-%m-%d %H:%M')

Auto-synced from ~/.claude"

# Push
git push

echo ""
echo "=== Done! ==="
