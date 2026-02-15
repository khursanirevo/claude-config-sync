#!/bin/bash
# Backup functions for claude-config-sync (force full backup)

# Exit on error, unset variables, and pipe failures
set -euo pipefail

# Source common utilities
# shellcheck source=lib/common.sh
if [[ -f "$CS_ROOT/lib/common.sh" ]]; then
    source "$CS_ROOT/lib/common.sh"
else
    echo "Error: lib/common.sh not found"
    exit 1
fi

# Backup settings.json (force copy)
cs_backup_settings() {
    cs_step "[1/4] Updating settings.json..."
    if [[ -L "$CS_CLAUDE_DIR/settings.json" ]]; then
        echo "  ℹ settings.json is a symlink (skipping - already synced)"
    elif [[ -f "$CS_CLAUDE_DIR/settings.json" ]]; then
        cp "$CS_CLAUDE_DIR/settings.json" "$CS_ROOT/config/settings.json"
        echo "  ✓ Updated settings.json"
    else
        echo "  ✗ settings.json not found"
    fi
}

# Backup scripts (force copy)
cs_backup_scripts() {
    cs_step "[2/4] Updating scripts..."
    if [[ -d "$CS_CLAUDE_DIR/scripts" ]]; then
        # Check if scripts is a symlink
        if [[ -L "$CS_CLAUDE_DIR/scripts" ]]; then
            echo "  ℹ scripts/ is a symlink (skipping - already synced)"
        else
            # Use temp directory for safety
            local temp_dir
            temp_dir=$(mktemp -d)
            # Copy to temp first
            if cp -r "$CS_CLAUDE_DIR/scripts/"* "$temp_dir/" 2>/dev/null; then
                # Only remove old content if copy succeeded
                rm -rf "$CS_CONTENT_DIR/scripts/"
                mv "$temp_dir" "$CS_CONTENT_DIR/scripts/"
                echo "  ✓ Updated scripts/"
            else
                rm -rf "$temp_dir"
                echo "  ✗ Failed to copy scripts/"
                return 1
            fi
        fi
    else
        echo "  ✗ scripts/ not found"
    fi
}

# Backup skills (force copy)
cs_backup_skills() {
    cs_step "[3/4] Updating skills..."
    if [[ -d "$CS_CLAUDE_DIR/skills" ]]; then
        if [[ -L "$CS_CLAUDE_DIR/skills" ]]; then
            echo "  ℹ skills/ is a symlink (skipping - already synced)"
        else
            # Sync skills - add new ones, update existing
            for skill in "$CS_CLAUDE_DIR/skills"/*/; do
                if [[ -d "$skill" && ! -L "$skill" ]]; then
                    skill_name="$(basename "$skill")"
                    if [[ -d "$CS_CONTENT_DIR/skills/$skill_name" ]]; then
                        rm -rf "$CS_CONTENT_DIR/skills/$skill_name"
                    fi
                    cp -r "$skill" "$CS_CONTENT_DIR/skills/"
                    echo "  ✓ Updated skill: $skill_name"
                fi
            done
            echo "  ✓ Synced skills/"
        fi
    else
        echo "  ✗ skills/ not found"
    fi
}

# Backup hooks (force copy)
cs_backup_hooks() {
    cs_step "[4/4] Updating hooks..."
    if [[ -d "$CS_CLAUDE_DIR/hooks" ]]; then
        if [[ -L "$CS_CLAUDE_DIR/hooks" ]]; then
            echo "  ℹ hooks/ is a symlink (skipping - already synced)"
        else
            # Use temp directory for safety
            local temp_dir
            temp_dir=$(mktemp -d)
            # Copy to temp first
            if cp -r "$CS_CLAUDE_DIR/hooks/"* "$temp_dir/" 2>/dev/null; then
                # Only remove old content if copy succeeded
                rm -rf "$CS_CONTENT_DIR/hooks/"
                mv "$temp_dir" "$CS_CONTENT_DIR/hooks/"
                echo "  ✓ Updated hooks/"
            else
                rm -rf "$temp_dir"
                echo "  ✗ Failed to copy hooks/"
                return 1
            fi
        fi
    else
        echo "  ✗ hooks/ not found"
    fi
}

# Main backup function - force full backup
cs_backup() {
    cs_ensure_logs
    cs_cd_root

    echo "=== Claude Code Config Sync - Full Backup ==="
    echo ""
    echo "Pulling latest config from ~/.claude to $CS_ROOT"
    echo ""

    # Ensure content directories exist
    mkdir -p "$CS_CONTENT_DIR"/{scripts,skills,hooks}
    mkdir -p "$CS_ROOT/config"

    cs_backup_settings
    cs_backup_scripts
    cs_backup_skills
    cs_backup_hooks

    echo ""
    echo "=== Backup Complete! ==="
    echo ""
    echo "Review changes with: git status"
    echo "Commit with: git add . && git commit -m 'Update config'"
    echo "Push with: git push"
}

# Export functions for use in other scripts
export -f cs_backup_settings
export -f cs_backup_scripts
export -f cs_backup_skills
export -f cs_backup_hooks
export -f cs_backup

# Run backup if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cs_backup
fi
