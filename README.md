# Claude Code Config Sync

Sync your Claude Code configuration across machines via Git.

## What Gets Synced

- `settings.json` - Main Claude Code settings (permissions, status line, etc.)
- `scripts/` - Custom scripts (context-bar.sh, etc.)
- `skills/` - Custom skills (not built-in plugins)
- `hooks/` - Custom hooks
- `.zshrc` additions - Shell aliases (c, ch, cs, --fs)

## What Doesn't Get Synced

- `settings.local.json` - Machine-specific settings (API tokens, etc.)
- `projects/` - Session history
- `history.jsonl` - Command history
- `plugins/` - NPM-installed plugins (use install script)
- Session data, todos, tasks, etc.

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
```

## Updating

```bash
cd ~/claude-config-sync
./backup.sh         # Pull latest changes from ~/.claude
git commit -am "Update config"
git push
```

On other machines:
```bash
cd ~/claude-config-sync
git pull
./install.sh        # Re-symlink (or files update automatically)
```
