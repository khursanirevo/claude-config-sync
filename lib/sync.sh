#!/bin/bash
# Core sync logic for claude-config-sync

# Source common utilities
# shellcheck source=lib/common.sh
if [[ -f "$CS_ROOT/lib/common.sh" ]]; then
    source "$CS_ROOT/lib/common.sh"
else
    echo "Error: lib/common.sh not found"
    exit 1
fi

# Change counter for tracking sync changes
CS_CHANGE_COUNT=0

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
        ((CS_CHANGE_COUNT++))
        return
    fi

    # Check if changed (for directories, check if any file changed)
    if [[ -d "$source" ]]; then
        if ! diff -q -r "$source" "$dest" &>/dev/null; then
            rm -rf "$dest"
            cp -r "$source" "$dest"
            echo "  [UPDATED] $name"
            ((CS_CHANGE_COUNT++))
        fi
    else
        if ! diff -q "$source" "$dest" &>/dev/null; then
            cp "$source" "$dest"
            echo "  [UPDATED] $name"
            ((CS_CHANGE_COUNT++))
        fi
    fi
}

# Sync settings.json
cs_sync_settings() {
    cs_step "[1/7] Checking settings.json..."
    backup_if_changed "$CS_CLAUDE_DIR/settings.json" "$CS_ROOT/config/settings.json" "settings.json"
}

# Sync scripts
cs_sync_scripts() {
    cs_step "[2/7] Checking scripts..."
    mkdir -p "$CS_CONTENT_DIR/scripts"

    if [[ -d "$CS_CLAUDE_DIR/scripts" ]]; then
        for script in "$CS_CLAUDE_DIR/scripts"/*; do
            if [[ -f "$script" ]]; then
                backup_if_changed "$script" "$CS_CONTENT_DIR/scripts/$(basename "$script")" "scripts/$(basename "$script")"
            fi
        done
        # Check for deleted scripts
        for script in "$CS_CONTENT_DIR/scripts"/*; do
            if [[ -f "$script" ]] && [[ ! -f "$CS_CLAUDE_DIR/scripts/$(basename "$script")" ]]; then
                rm "$script"
                echo "  [DELETED] scripts/$(basename "$script")"
                ((CS_CHANGE_COUNT++))
            fi
        done
    fi
}

# Sync skills
cs_sync_skills() {
    cs_step "[3/7] Checking skills..."
    mkdir -p "$CS_CONTENT_DIR/skills"

    if [[ -d "$CS_CLAUDE_DIR/skills" ]]; then
        for skill in "$CS_CLAUDE_DIR/skills"/*/; do
            if [[ -d "$skill" && ! -L "$skill" ]]; then
                skill_name="$(basename "$skill")"
                backup_if_changed "$skill" "$CS_CONTENT_DIR/skills/$skill_name" "skills/$skill_name"
            fi
        done
        # Check for deleted skills
        for skill in "$CS_CONTENT_DIR/skills"/*/; do
            if [[ -d "$skill" ]] && [[ ! -d "$CS_CLAUDE_DIR/skills/$(basename "$skill")" ]]; then
                rm -rf "$skill"
                echo "  [DELETED] skills/$(basename "$skill")"
                ((CS_CHANGE_COUNT++))
            fi
        done
        echo "  Total skills: $(ls -1 "$CS_CONTENT_DIR/skills/" | wc -l)"
    fi
}

# Sync hooks
cs_sync_hooks() {
    cs_step "[4/7] Checking hooks..."
    mkdir -p "$CS_CONTENT_DIR/hooks"

    if [[ -d "$CS_CLAUDE_DIR/hooks" ]]; then
        for hook in "$CS_CLAUDE_DIR/hooks"/*; do
            if [[ -f "$hook" ]]; then
                backup_if_changed "$hook" "$CS_CONTENT_DIR/hooks/$(basename "$hook")" "hooks/$(basename "$hook")"
            fi
        done
    fi
}

# Sync .claude.json (MCP servers, plugins)
cs_sync_claude_json() {
    cs_step "[5/7] Checking .claude.json (MCP servers, plugins)..."
    backup_if_changed "$HOME/.claude.json" "$CS_ROOT/config/.claude.json" ".claude.json"
}

# Sync plugins.txt (for backward compatibility)
cs_sync_plugins_txt() {
    if [[ -f "$CS_CLAUDE_DIR/plugins/installed_plugins.json" ]]; then
        # Extract plugin list and update plugins.txt
        if command -v jq &>/dev/null; then
            jq -r '.plugins | to_entries[] | "\(.key)@\(.value[0].scope // "user")' \
                "$CS_CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null > "$CS_ROOT/config/plugins.txt.new" 2>/dev/null || true

            if [[ -s "$CS_ROOT/config/plugins.txt.new" ]]; then
                if ! diff -q "$CS_ROOT/config/plugins.txt.new" "$CS_ROOT/config/plugins.txt" &>/dev/null 2>/dev/null; then
                    mv "$CS_ROOT/config/plugins.txt.new" "$CS_ROOT/config/plugins.txt"
                    echo "  [UPDATED] plugins.txt"
                    ((CS_CHANGE_COUNT++))
                else
                    rm -f "$CS_ROOT/config/plugins.txt.new"
                fi
            fi
        fi
    fi
}

# Sync plugin manifests
cs_sync_plugin_manifests() {
    cs_step "[6/7] Checking plugin manifests..."

    mkdir -p "$CS_ROOT/plugins/manifests"

    # Sync installed_plugins.json
    if [[ -f "$CS_CLAUDE_DIR/plugins/installed_plugins.json" ]]; then
        backup_if_changed "$CS_CLAUDE_DIR/plugins/installed_plugins.json" \
            "$CS_ROOT/plugins/manifests/installed_plugins.json" "plugins/manifests/installed_plugins.json"
    fi

    # Sync known_marketplaces.json
    if [[ -f "$CS_CLAUDE_DIR/plugins/known_marketplaces.json" ]]; then
        backup_if_changed "$CS_CLAUDE_DIR/plugins/known_marketplaces.json" \
            "$CS_ROOT/plugins/manifests/known_marketplaces.json" "plugins/manifests/known_marketplaces.json"
    fi

    echo "  Total plugins: $(jq -r '.plugins | length' "$CS_CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null || echo "0")"
}

# Sync plugin marketplaces
cs_sync_plugin_marketplaces() {
    cs_step "[7/7] Checking plugin marketplaces..."

    # Note: We don't sync the actual marketplace git repos since they can be re-cloned
    # The known_marketplaces.json contains all the info needed to restore them

    local SOURCE_DIR="$CS_CLAUDE_DIR/plugins/marketplaces"

    if [[ -d "$SOURCE_DIR" ]]; then
        echo "  Total marketplaces: $(ls -1 "$SOURCE_DIR/" | wc -l)"
        echo "  (Marketplace repos are not synced - they can be re-registered from manifests)"
    fi
}

# Combined plugin sync (for backward compatibility)
cs_sync_plugins() {
    cs_sync_plugin_manifests
    cs_sync_plugin_marketplaces
    cs_sync_plugins_txt
}

# Main sync function - runs all sync operations
cs_sync() {
    cs_ensure_logs
    cs_cd_root

    echo "=== Claude Code Config Sync - Incremental Backup ==="
    echo ""

    CS_CHANGE_COUNT=0

    cs_sync_settings
    cs_sync_scripts
    cs_sync_skills
    cs_sync_hooks
    cs_sync_claude_json
    cs_sync_plugins

    echo ""

    if [[ $CS_CHANGE_COUNT -eq 0 ]]; then
        echo "=== No changes detected ==="
        echo "Everything is already in sync."
        return 0
    else
        echo "=== Sync Complete! ($CS_CHANGE_COUNT change(s)) ==="
        echo ""
        echo "Commit changes:"
        echo "  git add ."
        echo "  git commit -m 'Sync: $(date +'%Y-%m-%d %H:%M')'"
        echo "  git push"
        return 0
    fi
}

# Export functions for use in other scripts
export -f backup_if_changed
export -f cs_sync_settings
export -f cs_sync_scripts
export -f cs_sync_skills
export -f cs_sync_hooks
export -f cs_sync_claude_json
export -f cs_sync_plugins_txt
export -f cs_sync_plugin_manifests
export -f cs_sync_plugin_marketplaces
export -f cs_sync_plugins
export -f cs_sync

# Run sync if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cs_sync
fi
