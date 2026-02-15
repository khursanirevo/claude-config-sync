# Claude Code Config Sync

Sync your Claude Code configuration across machines via Git.

## What Gets Synced

- `config/settings.json` - Main Claude Code settings (permissions, status line, etc.)
- `config/.claude.json` - Global Claude config (MCP servers, plugins)
- `config/plugins.txt` - Plugin list for Claude Code plugin marketplace
- `content/scripts/` - Custom scripts (context-bar.sh, etc.)
- `content/skills/` - Custom skills (**incremental auto-detection**)
- `content/hooks/` - Custom hooks
- `plugins/manifests/` - Plugin installation manifests (**NEW**)
  - `installed_plugins.json` - List of installed plugins with versions
  - `known_marketplaces.json` - Registered plugin marketplaces
- `plugins/marketplaces/` - Plugin marketplace registries (**NEW**)

## What Doesn't Get Synced

- `config/settings.local.json` - Machine-specific settings (API tokens, etc.)
- `projects/` - Session history
- `history.jsonl` - Command history
- Session data, todos, tasks, logs, etc.
- Plugin cache files (`~/.claude/plugins/cache/`) - Can be re-downloaded

## Quick Start

### First Machine (Initial Setup)

```bash
./bin/setup          # Backup current config and create git repo
git add . && git commit -m "Initial Claude Code config backup"
git remote add origin <your-repo-url>
git push -u origin main
```

### New Machine (Restore)

```bash
git clone <your-repo-url> ~/claude-config-sync
cd ~/claude-config-sync
./bin/install        # Symlink config files to ~/.claude
./bin/install-plugins  # Restore plugin marketplaces and plugins (optional)
source ~/.zshrc       # or source ~/.bashrc
```

## Daily Workflow

The new `claude-sync` CLI provides all functionality:

```bash
# Quick sync (recommended)
cs-quick              # Sync + commit + push in one command

# Or use the full command
claude-sync quick     # Same as above

# Other commands
cs-sync              # Incremental sync only
cs-status            # Show sync status
cs                   # Show all available commands
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `claude-sync sync` | Incremental sync - detects new/changed skills |
| `claude-sync quick` | Sync + commit + push in one command |
| `claude-sync backup` | Force full backup (copy all files) |
| `claude-sync status` | Show current sync status |
| `claude-sync auto-enable` | Enable daily auto-sync (cron) |
| `claude-sync auto-disable` | Disable daily auto-sync |
| `claude-sync help` | Show help message |

## Shell Aliases

After running `./bin/install`, these aliases are available:

```bash
cs                   # Show help
cs-sync             # Sync changes
cs-quick            # Sync + commit + push
cs-status           # Show status
```

To apply aliases immediately: `source ~/.zshrc` or `source ~/.bashrc`

## Automatic Daily Sync

Set up automatic daily backups:

```bash
cd ~/claude-config-sync
claude-sync auto-enable
```

**Default schedule:** 9:00 PM daily

**To customize schedule:**
```bash
crontab -e
# Change the time: 0 21 * * * → 0 12 * * * (for noon)
```

**View logs:**
```bash
tail -f ~/claude-config-sync/logs/auto-sync.log
```

**Disable:**
```bash
claude-sync auto-disable
```

## Directory Structure

```
claude-config-sync/
├── bin/                     # User-facing commands
│   ├── claude-sync          # Main CLI
│   ├── install              # Install on new machine
│   └── setup                # Initial setup
│
├── lib/                     # Core logic (internal)
│   ├── common.sh            # Shared utilities
│   ├── sync.sh              # Sync functions
│   └── backup.sh            # Backup functions
│
├── config/                  # Configuration files
│   ├── settings.json        # Main settings
│   ├── .claude.json         # Global Claude config
│   └── plugins.txt          # Plugin list
│
├── content/                 # User content to sync
│   ├── skills/              # Custom skills
│   ├── scripts/             # Custom scripts
│   └── hooks/               # Custom hooks
│
├── automation/              # Automation scripts
│   ├── auto-sync.sh         # Cron job script
│   └── git-hooks/
│       └── pre-commit       # Pre-commit hook
│
├── logs/                    # Log files (gitignored)
├── docs/                    # Additional documentation
├── README.md                # This file
└── .gitignore               # Git ignore rules
```

## Skills Auto-Detection

The `claude-sync sync` command automatically:
- ✅ Detects **new skills** created by Claude/claudeception
- ✅ Detects **updated skills**
- ✅ Detects **deleted skills**
- ✅ Syncs all changes to the repo

No manual file management needed!

## Pre-commit Hook

A pre-commit hook is installed that auto-runs sync before every commit, ensuring your config is always up-to-date when you push changes.

## Slack Notifications (Optional)

To receive Slack notifications on auto-sync:

1. Create a Slack Incoming Webhook
2. Save the webhook URL to `~/.claude-config-sync/.slack-config`:

```bash
echo "SLACK_WEBHOOK_URL='https://hooks.slack.com/services/YOUR/WEBHOOK/URL'" > ~/.claude-config-sync/.slack-config
```

## Example Workflow

```bash
# You create a new skill in Claude
# Claude adds it to ~/.claude/skills/my-new-skill/

# Run quick sync
cs-quick

# Output:
#   [NEW] content/skills/my-new-skill
#   Total skills: 58
# === Sync Complete! (1 change(s)) ===
# === Committing & Pushing ===
# === Done! ===
```
