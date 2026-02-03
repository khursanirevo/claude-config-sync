#!/bin/bash
# Backup script - run to pull latest changes from ~/.claude to the repo

set -e

CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

echo "=== Claude Code Config Sync - Backup ==="
echo ""
echo "Pulling latest config from ~/.claude to $SYNC_DIR"
echo ""

echo "[1/4] Updating settings.json..."
if [[ -L "$CLAUDE_DIR/settings.json" ]]; then
    echo "  ℹ settings.json is a symlink (skipping - already synced)"
elif [[ -f "$CLAUDE_DIR/settings.json" ]]; then
    cp "$CLAUDE_DIR/settings.json" settings.json
    echo "  ✓ Updated settings.json"
else
    echo "  ✗ settings.json not found"
fi

echo "[2/4] Updating scripts..."
if [[ -d "$CLAUDE_DIR/scripts" ]]; then
    # Check if scripts is a symlink
    if [[ -L "$CLAUDE_DIR/scripts" ]]; then
        echo "  ℹ scripts/ is a symlink (skipping - already synced)"
    else
        rm -rf scripts/
        cp -r "$CLAUDE_DIR/scripts/" .
        echo "  ✓ Updated scripts/"
    fi
else
    echo "  ✗ scripts/ not found"
fi

echo "[3/4] Updating skills..."
if [[ -d "$CLAUDE_DIR/skills" ]]; then
    if [[ -L "$CLAUDE_DIR/skills" ]]; then
        echo "  ℹ skills/ is a symlink (skipping - already synced)"
    else
        # Sync skills - add new ones, update existing
        for skill in "$CLAUDE_DIR/skills"/*/; do
            if [[ -d "$skill" && ! -L "$skill" ]]; then
                skill_name="$(basename "$skill")"
                if [[ -d "skills/$skill_name" ]]; then
                    rm -rf "skills/$skill_name"
                fi
                cp -r "$skill" "skills/"
                echo "  ✓ Updated skill: $skill_name"
            fi
        done
        echo "  ✓ Synced skills/"
    fi
else
    echo "  ✗ skills/ not found"
fi

echo "[4/4] Updating hooks..."
if [[ -d "$CLAUDE_DIR/hooks" ]]; then
    if [[ -L "$CLAUDE_DIR/hooks" ]]; then
        echo "  ℹ hooks/ is a symlink (skipping - already synced)"
    else
        rm -rf hooks/
        cp -r "$CLAUDE_DIR/hooks/" .
        echo "  ✓ Updated hooks/"
    fi
else
    echo "  ✗ hooks/ not found"
fi

echo ""
echo "=== Backup Complete! ==="
echo ""
echo "Review changes with: git status"
echo "Commit with: git add . && git commit -m 'Update config'"
echo "Push with: git push"
