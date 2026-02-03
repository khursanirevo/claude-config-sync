#!/bin/bash
# Incremental sync script - automatically backs up new/changed skills and config

set -e

CLAUDE_DIR="$HOME/.claude"
SYNC_DIR="$HOME/claude-config-sync"
cd "$SYNC_DIR"

echo "=== Claude Code Config Sync - Incremental Backup ==="
echo ""

CHANGE_COUNT=0

# Function to backup a file/directory if changed
backup_if_changed() {
    local source="$1"
    local dest="$2"
    local name="$3"

    if [[ ! -e "$source" ]]; then
        return
    fi

    if [[ ! -e "$dest" ]]; then
        # New file/directory
        if [[ -d "$source" ]]; then
            cp -r "$source" "$dest"
        else
            cp "$source" "$dest"
        fi
        echo "  [NEW] $name"
        ((CHANGE_COUNT++))
        return
    fi

    # Check if changed (for directories, check if any file changed)
    if [[ -d "$source" ]]; then
        if ! diff -q -r "$source" "$dest" &>/dev/null; then
            rm -rf "$dest"
            cp -r "$source" "$dest"
            echo "  [UPDATED] $name"
            ((CHANGE_COUNT++))
        fi
    else
        if ! diff -q "$source" "$dest" &>/dev/null; then
            cp "$source" "$dest"
            echo "  [UPDATED] $name"
            ((CHANGE_COUNT++))
        fi
    fi
}

echo "[1/6] Checking settings.json..."
backup_if_changed "$CLAUDE_DIR/settings.json" "settings.json" "settings.json"

echo "[2/6] Checking scripts..."
mkdir -p scripts
if [[ -d "$CLAUDE_DIR/scripts" ]]; then
    for script in "$CLAUDE_DIR/scripts"/*; do
        if [[ -f "$script" ]]; then
            backup_if_changed "$script" "scripts/$(basename "$script")" "scripts/$(basename "$script")"
        fi
    done
    # Check for deleted scripts
    for script in scripts/*; do
        if [[ -f "$script" ]] && [[ ! -f "$CLAUDE_DIR/scripts/$(basename "$script")" ]]; then
            rm "$script"
            echo "  [DELETED] scripts/$(basename "$script")"
            ((CHANGE_COUNT++))
        fi
    done
fi

echo "[3/6] Checking skills..."
mkdir -p skills
if [[ -d "$CLAUDE_DIR/skills" ]]; then
    for skill in "$CLAUDE_DIR/skills"/*/; do
        if [[ -d "$skill" && ! -L "$skill" ]]; then
            skill_name="$(basename "$skill")"
            backup_if_changed "$skill" "skills/$skill_name" "skills/$skill_name"
        fi
    done
    # Check for deleted skills
    for skill in skills/*/; do
        if [[ -d "$skill" ]] && [[ ! -d "$CLAUDE_DIR/skills/$(basename "$skill")" ]]; then
            rm -rf "$skill"
            echo "  [DELETED] skills/$(basename "$skill")"
            ((CHANGE_COUNT++))
        fi
    done
    echo "  Total skills: $(ls -1 skills/ | wc -l)"
fi

echo "[4/6] Checking hooks..."
mkdir -p hooks
if [[ -d "$CLAUDE_DIR/hooks" ]]; then
    for hook in "$CLAUDE_DIR/hooks"/*; do
        if [[ -f "$hook" ]]; then
            backup_if_changed "$hook" "hooks/$(basename "$hook")" "hooks/$(basename "$hook")"
        fi
    done
fi

echo "[5/6] Checking plugins..."
if [[ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ]]; then
    # Extract plugin list and update plugins.txt
    jq -r '.plugins | to_entries[] | "\(.key)@\(.value[0].scope // "user")' \
        "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null > plugins.txt.new 2>/dev/null || true

    if [[ -s plugins.txt.new ]]; then
        if ! diff -q plugins.txt.new plugins.txt &>/dev/null; then
            mv plugins.txt.new plugins.txt
            echo "  [UPDATED] plugins.txt"
            ((CHANGE_COUNT++))
        else
            rm -f plugins.txt.new
        fi
    fi
fi

echo "[6/6] Checking shell aliases..."
# Extract and backup zshrc aliases
if grep -q "c=claude" ~/.zshrc 2>/dev/null; then
    sed -n '/# Claude Code aliases/,/^$/p' ~/.zshrc > zshrc-aliases.txt 2>/dev/null || true
    if [[ -s zshrc-aliases.txt ]]; then
        if ! diff -q zshrc-aliases.txt zshrc-aliases.txt.bak &>/dev/null 2>/dev/null; then
            echo "  [UPDATED] zshrc-aliases.txt"
            ((CHANGE_COUNT++))
        fi
        cp zshrc-aliases.txt zshrc-aliases.txt.bak
    fi
fi

echo ""
if [[ $CHANGE_COUNT -eq 0 ]]; then
    echo "=== No changes detected ==="
    echo "Everything is already in sync."
else
    echo "=== Sync Complete! ($CHANGE_COUNT change(s)) ==="
    echo ""
    echo "Commit changes:"
    echo "  git add ."
    echo "  git commit -m 'Sync: $(date +'%Y-%m-%d %H:%M')'"
    echo "  git push"
fi
