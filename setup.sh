#!/bin/bash
# Initial setup script - run on first machine to create the git repo

set -e

CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

echo "=== Claude Code Config Sync - Initial Setup ==="
echo ""

# Check if this is first run
if [[ -f .git/config ]]; then
    echo "Git repo already exists. Skipping init."
else
    echo "[1/4] Initializing git repo..."
    git init
    git branch -M main
fi

echo ""
echo "[2/4] Backing up configuration files..."

# Copy settings.json
if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
    cp "$CLAUDE_DIR/settings.json" settings.json
    echo "  ✓ settings.json"
else
    echo "  ✗ settings.json not found"
fi

# Copy scripts
mkdir -p scripts
if [[ -d "$CLAUDE_DIR/scripts" ]]; then
    cp -r "$CLAUDE_DIR/scripts/"* scripts/ 2>/dev/null || true
    echo "  ✓ scripts/"
else
    echo "  ✗ scripts/ not found"
fi

# Copy .claude.json (MCP servers, plugins)
if [[ -f "$HOME/.claude.json" ]]; then
    cp "$HOME/.claude.json" .claude.json
    echo "  ✓ .claude.json (MCP servers)"
else
    echo "  ✗ .claude.json not found"
fi

# Copy skills (excluding symlinks to .agents)
mkdir -p skills
if [[ -d "$CLAUDE_DIR/skills" ]]; then
    # Copy only actual skill directories, not symlinks
    for skill in "$CLAUDE_DIR/skills"/*/; do
        if [[ -d "$skill" && ! -L "$skill" ]]; then
            cp -r "$skill" "skills/$(basename "$skill")"
        fi
    done
    echo "  ✓ skills/ ($(ls -1 skills/ | wc -l) skills)"
else
    echo "  ✗ skills/ not found"
fi

# Copy hooks
mkdir -p hooks
if [[ -d "$CLAUDE_DIR/hooks" ]]; then
    cp -r "$CLAUDE_DIR/hooks/"* hooks/ 2>/dev/null || true
    echo "  ✓ hooks/"
else
    echo "  ✗ hooks/ not found"
fi

# Extract .zshrc additions (claude aliases)
if grep -q "c=claude" ~/.zshrc 2>/dev/null; then
    echo ""
    echo "[3/4] Extracting .zshrc aliases..."
    # Extract the Claude Code section from .zshrc
    sed -n '/# Claude Code aliases/,/^$/p' ~/.zshrc > zshrc-aliases.txt 2>/dev/null || true
    if [[ -s zshrc-aliases.txt ]]; then
        echo "  ✓ zshrc-aliases.txt"
    fi
else
    echo "  ✗ No Claude aliases found in .zshrc"
fi

echo ""
echo "[4/4] Creating .gitignore..."

cat > .gitignore << 'GITIGNORE'
# Machine-specific settings
settings.local.json

# Session data (don't sync)
projects/
history.jsonl
debug/
file-history/
session-env/
shell-snapshots/
paste-cache/
plans/
tasks/
todos/
statsig/
ide/
stats-cache.json

# Built-in plugins (install via npm)
plugins/

# OS files
.DS_Store
Thumbs.db
GITIGNORE

echo "  ✓ .gitignore created"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Review the files in $SYNC_DIR"
echo "  2. git add . && git commit -m 'Initial Claude Code config backup'"
echo "  3. Create a GitHub/GitLab repo and run:"
echo "     git remote add origin <your-repo-url>"
echo "     git push -u origin main"
echo ""
echo "On new machines, clone and run ./install.sh"
