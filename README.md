# Claude Code Config Sync

Sync your Claude Code configuration across machines via Git.

## What Gets Synced

- `settings.json` - Main Claude Code settings (permissions, status line, etc.)
- `scripts/` - Custom scripts (context-bar.sh, etc.)
- `skills/` - Custom skills (**incremental auto-detection**)
- `hooks/` - Custom hooks
- `plugins.txt` - Plugin list for Claude Code plugin marketplace

## What Doesn't Get Synced

- `settings.local.json` - Machine-specific settings (API tokens, etc.)
- `projects/` - Session history
- `history.jsonl` - Command history
- Session data, todos, tasks, etc.

**Note:** Claude Code plugins installed via marketplace (`claude plugin install`) are stored globally in `~/.claude.json` and don't need to be synced separately. MCP servers are also configured globally.

## Setup

### First Machine (Initial Setup)

```bash
./setup.sh          # Backup current config and create git repo
./push-to-github.sh # (Optional) Push to GitHub/GitLab
```

### New Machine (Restore)

```bash
git clone <your-repo-url> ~/claude-config-sync
cd ~/claude-config-sync
./install.sh        # Symlink config files to ~/.claude
./install-plugins.sh # Install plugins from plugins.txt
```

## Daily Workflow

### Quick Sync (Recommended)

```bash
cws     # Sync + commit + push in one command
```

### Manual Sync

```bash
cd ~/claude-config-sync
./sync.sh           # Detects new/changed skills automatically
git add . && git commit -m "Update config"
git push
```

### Auto-Sync on Commit

A **pre-commit hook** is installed that auto-runs `./sync.sh` before every commit.

### Pulling Changes (Other Machines)

```bash
cd ~/claude-config-sync
git pull
# Files update automatically (they're symlinks)
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sync.sh` | Incremental sync - detects new/changed skills |
| `quick-sync.sh` | One-command sync + commit + push |
| `backup.sh` | Full backup (force copy all files) |
| `install.sh` | Symlink config to ~/.claude |
| `install-plugins.sh` | Install plugins from plugins.txt (marketplace plugins) |
| `enable-auto-sync.sh` | Enable automatic daily sync (cron) |
| `disable-auto-sync.sh` | Disable automatic daily sync |

## Automatic Daily Sync

Set up automatic daily backups:

```bash
cd ~/claude-config-sync
./enable-auto-sync.sh
```

**Default schedule:** 9:00 PM daily

**To customize schedule:**
```bash
crontab -e
# Change the time: 0 21 * * * → 0 12 * * * (for noon)
```

**View logs:**
```bash
tail -f ~/claude-config-sync/auto-sync.log
```

**Disable:**
```bash
./disable-auto-sync.sh
```

## Shell Aliases

Add to `~/.zshrc` for quick access:

```bash
# Claude Config Sync
alias cws='~/claude-config-sync/quick-sync.sh'
alias ccs='cd ~/claude-config-sync && ./sync.sh'
```

## Skills Auto-Detection

The `sync.sh` script automatically:
- ✅ Detects **new skills** created by Claude/claudeception
- ✅ Detects **updated skills**
- ✅ Detects **deleted skills**
- ✅ Syncs all changes to the repo

No manual file management needed!

## Example Workflow

```bash
# You create a new skill in Claude
# Claude adds it to ~/.claude/skills/my-new-skill/

# Run quick sync
cws

# Output:
#   [NEW] skills/my-new-skill
#   Total skills: 58
# === Sync Complete! (1 change(s)) ===
# === Committing & Pushing ===
# === Done! ===
```
