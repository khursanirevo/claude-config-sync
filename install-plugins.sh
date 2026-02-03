#!/bin/bash
# Install NPM plugins on new machine

set -e

echo "=== Claude Code Config Sync - Install Plugins ==="
echo ""

PLUGINS_FILE="$HOME/claude-config-sync/plugins.txt"

if [[ ! -f "$PLUGINS_FILE" ]]; then
    echo "# Add one plugin per line, e.g.:" > "$PLUGINS_FILE"
    echo "# dx@ykdojo" >> "$PLUGINS_FILE"
    echo "# cc-safe" >> "$PLUGINS_FILE"
    echo "Created $PLUGINS_FILE - add your plugins there"
    exit 0
fi

echo "Installing plugins from $PLUGINS_FILE..."
echo ""

while IFS= read -r plugin; do
    # Skip comments and empty lines
    [[ "$plugin" =~ ^#.*$ ]] && continue
    [[ -z "$plugin" ]] && continue

    echo "Installing: $plugin"
    claude mcp add -s user "$plugin" || echo "  ✗ Failed to install $plugin"
done < "$PLUGINS_FILE"

echo ""
echo "=== Plugin Install Complete! ==="
