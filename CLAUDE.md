# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Config Sync is a Bash-based CLI tool that syncs Claude Code configuration across multiple machines via Git. It automatically detects new/changed/deleted skills, scripts, hooks, and configuration files from `~/.claude/` and maintains them in a git repository for easy synchronization.

## Architecture

The project follows a modular Bash script structure:

- **`bin/`** - User-facing CLI commands
  - `claude-sync` - Main unified CLI with command dispatcher (sync, quick, backup, status, auto-enable, etc.)
  - `install` - Sets up symlinks from `~/claude-config-sync/config/` to `~/.claude/` on new machines
  - `setup` - Initial setup for first machine (backs up config and creates git repo)
  - `reinstall` - Clean reinstall (removes symlinks and reinstalls)

- **`lib/`** - Core library code (internal functions)
  - `common.sh` - Shared utilities (logging, colors, Slack notifications, path management)
  - `sync.sh` - Incremental sync logic with auto-detection (uses `diff` for change detection)
  - `backup.sh` - Force full backup functions

- **`config/`** - Synced configuration files (symlinked to `~/.claude/`)
  - `settings.json` - Main Claude Code settings
  - `.claude.json` - Global Claude config (MCP servers, project settings)
  - `plugins.txt` - Plugin list for marketplace

- **`content/`** - Synced user content from `~/.claude/`
  - `skills/` - Custom skills (auto-detected incrementally)
  - `scripts/` - Custom scripts
  - `hooks/` - Custom hooks

- **`automation/`** - Automation scripts
  - `auto-sync.sh` - Cron job script for daily automated sync
  - `git-hooks/pre-commit` - Pre-commit hook that auto-runs sync before git commits

## Key Environment Variables

- `CS_ROOT` - Root directory (default: `$HOME/claude-config-sync`)
- `CS_CLAUDE_DIR` - Source directory (`$HOME/.claude`)
- `CS_LIB_DIR`, `CS_BIN_DIR`, `CS_CONFIG_DIR`, `CS_CONTENT_DIR`, `CS_LOG_DIR` - Path exports

## Common Commands

**Quick sync (recommended workflow):**
```bash
claude-sync quick      # Sync + commit + push in one command
# or use alias:
cs-quick
```

**Other sync operations:**
```bash
claude-sync sync       # Incremental sync only (no git operations)
claude-sync backup     # Force full backup (copies all files)
claude-sync status     # Show sync status, file counts, git status
```

**Auto-sync management:**
```bash
claude-sync auto-enable    # Enable daily auto-sync (default: 9 PM)
claude-sync auto-disable   # Disable daily auto-sync
```

**Installation:**
```bash
./bin/setup          # First machine: backup config and create git repo
./bin/install        # New machine: create symlinks to ~/.claude
```

## How Sync Works

The `sync.sh` script implements incremental sync using `diff` for change detection:

1. **Settings** - Syncs `~/.claude/settings.json` to `config/settings.json`
2. **Scripts** - Syncs scripts from `~/.claude/scripts/` to `content/scripts/`
3. **Skills** - Auto-detects new/updated/deleted skills from `~/.claude/skills/`
4. **Hooks** - Syncs hooks from `~/.claude/hooks/` to `content/hooks/`
5. **MCP/Global Config** - Syncs `~/.claude.json` to `config/.claude.json`
6. **Plugins** - Extracts plugin list from `~/.claude/plugins/installed_plugins.json` using `jq`

Change detection outputs `[NEW]`, `[UPDATED]`, `[DELETED]` markers and tracks total changes.

## What Gets Synced vs. What Doesn't

**Synced:**
- `config/settings.json` - Main settings (permissions, status line, enabled plugins)
- `config/.claude.json` - Global config (MCP servers, project settings)
- `config/plugins.txt` - Plugin list
- `content/skills/` - Custom skills
- `content/scripts/` - Custom scripts
- `content/hooks/` - Custom hooks

**NOT synced (machine-specific):**
- `config/settings.local.json` - Contains API tokens and secrets
- `projects/` - Session history
- `history.jsonl` - Command history
- Session data, todos, tasks, logs, cache files

## Dependencies

- **jq** - Required for JSON parsing (plugins.txt generation, .claude.json handling)
- **git** - For version control
- **bash** - Shell interpreter
- **curl** - For Slack webhook notifications

## Slack Notifications (Optional)

Slack webhook URL can be configured in `.slack-config` (gitignored file):
```bash
echo "SLACK_WEBHOOK_URL='https://hooks.slack.com/services/YOUR/WEBHOOK/URL'" > ~/.claude-config-sync/.slack-config
```

## Pre-commit Hook

The pre-commit hook in `automation/git-hooks/pre-commit` automatically runs sync before every git commit, ensuring config is always up-to-date when pushing changes.

## Testing Changes

When modifying the sync logic or adding new features:
1. Test sync operations: `claude-sync sync`
2. Test quick sync: `claude-sync quick`
3. Check status: `claude-sync status`
4. Review logs: `tail -f logs/sync.log`
5. For auto-sync changes: `tail -f logs/auto-sync.log`

## Shell Aliases

After running `./bin/install`, these aliases are available (after sourcing shell config):
- `cs` - Show help
- `cs-sync` - Sync changes
- `cs-quick` - Sync + commit + push
- `cs-status` - Show status

Apply immediately with `source ~/.zshrc` or `source ~/.bashrc`.
