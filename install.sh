#!/bin/bash
# Install script - run on new machines to restore config

set -e

CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

echo "=== Claude Code Config Sync - Install ==="
echo ""
echo "This will symlink config files from $SYNC_DIR to $CLAUDE_DIR"
echo ""

# Create .claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Backup existing settings.json if it exists
if [[ -f "$CLAUDE_DIR/settings.json" && ! -L "$CLAUDE_DIR/settings.json" ]]; then
    echo "[Backup] Existing settings.json → settings.json.backup"
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.backup"
fi

echo "[1/5] Installing settings.json..."
if [[ -f settings.json ]]; then
    ln -sf "$SYNC_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "  ✓ Linked settings.json"
else
    echo "  ✗ settings.json not found in repo"
fi

echo "[2/5] Installing scripts..."
mkdir -p "$CLAUDE_DIR/scripts"
if [[ -d scripts ]]; then
    for script in scripts/*; do
        if [[ -f "$script" ]]; then
            ln -sf "$SYNC_DIR/$script" "$CLAUDE_DIR/scripts/$(basename "$script")"
        fi
    done
    echo "  ✓ Linked $(ls -1 scripts/ | wc -l) scripts"
else
    echo "  ✗ scripts/ not found in repo"
fi

echo "[3/5] Installing skills..."
mkdir -p "$CLAUDE_DIR/skills"
if [[ -d skills ]]; then
    for skill in skills/*/; do
        if [[ -d "$skill" ]]; then
            ln -sf "$SYNC_DIR/$skill" "$CLAUDE_DIR/skills/$(basename "$skill")"
        fi
    done
    echo "  ✓ Linked $(ls -1 skills/ | wc -l) skills"
else
    echo "  ✗ skills/ not found in repo"
fi

echo "[4/5] Installing hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
if [[ -d hooks ]]; then
    for hook in hooks/*; do
        if [[ -f "$hook" ]]; then
            ln -sf "$SYNC_DIR/$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
        fi
    done
    echo "  ✓ Linked $(ls -1 hooks/ | wc -l) hooks"
else
    echo "  ✗ hooks/ not found in repo"
fi

echo "[5/6] Installing git pre-commit hook..."
mkdir -p .git/hooks
if [[ -f pre-commit-hook ]]; then
    cp pre-commit-hook .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "  ✓ Installed pre-commit hook"
else
    echo "  ℹ No pre-commit-hook found (skipping)"
fi

echo "[6/6] Installing sync aliases to .zshrc..."
if ! grep -q "Claude Config Sync" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'EOF'

# Claude Config Sync aliases
alias cws='~/claude-config-sync/quick-sync.sh'
alias ccs='cd ~/claude-config-sync && ./sync.sh'
EOF
    echo "  ✓ Added sync aliases to .zshrc"
    echo "    Run 'source ~/.zshrc' to apply"
else
    echo "  ✓ Sync aliases already exist in .zshrc"
fi

echo ""
echo "=== Install Complete! ==="
if [[ -f zshrc-aliases.txt ]]; then
    # Check if aliases already exist in .zshrc
    if ! grep -q "# Claude Code aliases" ~/.zshrc 2>/dev/null; then
        echo "" >> ~/.zshrc
        cat zshrc-aliases.txt >> ~/.zshrc
        echo "  ✓ Added aliases to .zshrc"
        echo "    Run 'source ~/.zshrc' to apply"
    else
        echo "  ✓ Aliases already exist in .zshrc"
    fi
else
    echo "  ℹ No zshrc-aliases.txt found (skipping)"
fi

echo ""
echo "=== Install Complete! ==="
echo ""
echo "Installed symlinks:"
echo "  settings.json → $SYNC_DIR/settings.json"
echo "  scripts/      → $SYNC_DIR/scripts/"
echo "  skills/       → $SYNC_DIR/skills/"
echo "  hooks/        → $SYNC_DIR/hooks/"
echo ""
echo "Note: These are SYMLINKS. Editing files in $SYNC_DIR"
echo "      will automatically update ~/.claude"
