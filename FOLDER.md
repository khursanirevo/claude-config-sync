# Claude Config Sync - Folder Structure

This document describes the restructured repository layout for better organization and maintainability.

## Directory Structure

```
claude-config-sync/
├── bin/                         # User-facing executable commands
│   ├── claude-sync              # Main CLI tool (unified command)
│   ├── install                  # Install symlinks on new machines
│   └── setup                    # Initial setup for first machine
│
├── lib/                         # Core library code (internal use)
│   ├── common.sh                # Shared utilities (logging, Slack, etc.)
│   ├── sync.sh                  # Incremental sync logic
│   └── backup.sh                # Force backup functions
│
├── config/                      # Configuration files
│   ├── settings.json            # Main Claude Code settings (symlinked)
│   ├── settings.json.example    # Template for new installations
│   ├── .claude.json             # Global Claude config (MCP, plugins)
│   ├── .claude.json.example     # Template for MCP servers
│   ├── plugins.txt              # List of installed plugins
│   └── zshrc-aliases.txt        # Shell aliases extracted from .zshrc
│
├── content/                     # User content synced from ~/.claude
│   ├── skills/                  # Custom skills (auto-detected)
│   ├── scripts/                 # Custom scripts (context-bar, etc.)
│   └── hooks/                   # Custom hooks
│
├── automation/                  # Automation and integration scripts
│   ├── auto-sync.sh             # Cron job for daily auto-sync
│   └── git-hooks/
│       └── pre-commit           # Pre-commit hook for auto-sync
│
├── logs/                        # Log files (gitignored)
│   ├── sync.log                 # General sync operations
│   └── auto-sync.log            # Daily auto-sync logs
│
├── docs/                        # Additional documentation
│   └── HANDOVER.md              # Project handover notes
│
├── README.md                    # Main documentation
├── FOLDER.md                    # This file - structure documentation
├── .gitignore                   # Git ignore rules
└── .slack-config                # Slack webhook config (optional, gitignored)
```

## Directory Purposes

### `bin/` - User-facing Commands

Contains executable scripts that users interact with directly:

- **`claude-sync`** - The main CLI tool that consolidates all functionality
  - Subcommands: `sync`, `quick`, `backup`, `status`, `auto-enable`, `auto-disable`
  - Replaces: `sync.sh`, `quick-sync.sh`, `backup.sh`, etc.

- **`install`** - Sets up symlinks on new machines
  - Links `config/*` to `~/.claude/`
  - Links `content/*` to appropriate `~/.claude/` subdirectories
  - Installs shell aliases

- **`setup`** - Initial setup for the first machine
  - Creates directory structure
  - Copies config from `~/.claude` to repo
  - Initializes git repo
  - Creates `.gitignore`

### `lib/` - Internal Library Code

Core functionality used by scripts in `bin/` and `automation/`:

- **`common.sh`** - Shared utilities
  - Logging functions (`cs_log`, `cs_info`, `cs_success`, etc.)
  - Slack notifications (`cs_slack_notify`)
  - Path management and validation
  - Color-coded output

- **`sync.sh`** - Incremental sync logic
  - Detects new/changed/deleted skills, scripts, hooks, config
  - Used by: `claude-sync sync`, `claude-sync quick`, automation scripts

- **`backup.sh`** - Force backup functions
  - Full copy of all files (not incremental)
  - Used by: `claude-sync backup`

### `config/` - Configuration Files

Files that define Claude Code behavior:

- **`settings.json`** - Main Claude Code settings
  - Environment variables (API tokens, base URLs)
  - Enabled plugins
  - Status line configuration
  - Permissions

- **`.claude.json`** - Global Claude configuration
  - MCP server definitions
  - Plugin installations
  - Project-specific settings

- **`plugins.txt`** - List of installed marketplace plugins

- **`*.example`** - Template files for reference only

### `content/` - Synced User Content

Content synced from `~/.claude/` to the repository:

- **`skills/`** - Custom Claude Code skills
  - Auto-detected on sync
  - Incremental updates only

- **`scripts/`** - Custom utility scripts
  - Example: `context-bar.sh` for custom status bar

- **`hooks/`** - Custom hooks
  - Pre/post hooks for Claude Code operations

### `automation/` - Automation Scripts

Scripts for automated operations:

- **`auto-sync.sh`** - Runs via cron for daily automatic sync
  - Calls `lib/sync.sh`
  - Commits and pushes changes
  - Sends Slack notifications
  - Logs to `logs/auto-sync.log`

- **`git-hooks/pre-commit`** - Git pre-commit hook
  - Runs sync before every commit
  - Prompts user to include synced changes

### `logs/` - Log Files

Runtime logs (gitignored):

- **`sync.log`** - Manual sync operations
- **`auto-sync.log`** - Cron job logs

### `docs/` - Documentation

Additional project documentation:

- **`HANDOVER.md`** - Project handover notes

## Key Design Decisions

### 1. Separation of Concerns

- **User-facing** (`bin/`) vs **internal** (`lib/`)
- **Content** (`content/`) vs **tooling** (`bin/`, `lib/`, `automation/`)
- **Config** (`config/`) vs **code** (`bin/`, `lib/`)

### 2. Consolidated CLI

Instead of multiple scripts:
- **Before**: `sync.sh`, `quick-sync.sh`, `backup.sh`, `auto-sync.sh`, etc.
- **After**: Single `claude-sync` with subcommands

Benefits:
- Single entry point
- Consistent interface
- Easier to discover features
- Easier to maintain

### 3. Content Isolation

User content (`skills/`, `scripts/`, `hooks/`) isolated in `content/`:
- Clear separation from tooling
- Easier to understand what's synced
- Simplifies backup/restore

### 4. Log Containment

All logs in `logs/` directory:
- Keeps root clean
- Easy to exclude from git
- Simple log rotation

## Migration from Old Structure

| Old Path | New Path |
|----------|----------|
| `sync.sh` | `bin/claude-sync sync` |
| `quick-sync.sh` | `bin/claude-sync quick` |
| `backup.sh` | `bin/claude-sync backup` |
| `auto-sync.sh` | `automation/auto-sync.sh` |
| `pre-commit-hook` | `automation/git-hooks/pre-commit` |
| `settings.json` | `config/settings.json` |
| `skills/` | `content/skills/` |
| `scripts/` | `content/scripts/` |
| `hooks/` | `content/hooks/` |
| `HANDOVER.md` | `docs/HANDOVER.md` |

## Shell Aliases

The new aliases are shorter and more consistent:

| Old Alias | New Alias |
|-----------|-----------|
| `cws` | `cs-quick` |
| `ccs` | `cs-sync` |
| N/A | `cs-status` |
| N/A | `cs` (help) |

## Future Extensions

The new structure makes it easy to add:

- **`bin/`** - New commands like `claude-sync doctor`, `claude-sync clean`
- **`lib/`** - New modules like `health.sh`, `migrate.sh`
- **`automation/`** - New integrations like GitHub Actions, webhooks
- **`config/`** - Additional config templates

## Benefits Summary

1. **Cleaner root** - No more 18+ script files
2. **Better discoverability** - Clear purpose for each directory
3. **Easier maintenance** - Separated concerns
4. **Scalability** - Easy to add new features
5. **Professional structure** - Follows common CLI project patterns
