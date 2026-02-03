#!/bin/bash
# Helper script to push to GitHub/GitLab

set -e

SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

echo "=== Claude Code Config Sync - Push to Remote ==="
echo ""

# Check if git remote exists
if ! git remote get-url origin &>/dev/null; then
    echo "No git remote 'origin' found."
    echo ""
    echo "To add a remote, run:"
    echo "  git remote add origin <your-repo-url>"
    echo ""
    echo "Example:"
    echo "  git remote add origin git@github.com:username/claude-config-sync.git"
    echo ""
    echo "After adding the remote, run this script again."
    exit 1
fi

# Show current remote
REMOTE_URL=$(git remote get-url origin)
echo "Remote: $REMOTE_URL"
echo ""

# Commit if there are uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "Found uncommitted changes. Committing..."
    git add .
    git commit -m "Update Claude Code config"
    echo "  ✓ Committed changes"
else
    echo "No uncommitted changes."
fi

# Push
echo ""
echo "Pushing to remote..."
git push -u origin main

echo ""
echo "=== Push Complete! ==="
