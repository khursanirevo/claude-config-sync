# Claude Code Config Sync - Handover Document

**Location:** `~/claude-config-sync`
**Created:** 2026-02-03
**Purpose:** Sync Claude Code config across machines via Git

---

## Quick Reference

### Daily Commands
```bash
cd ~/claude-config-sync

# Quick sync (sync + commit + push)
cws    # or: ./quick-sync.sh

# Check sync status
ccs    # or: ./sync.sh

# Enable auto-sync (daily at 9 PM)
./enable-auto-sync.sh

# Disable auto-sync
./disable-auto-sync.sh
```

### Push to GitHub (First Time Setup)
```bash
cd ~/claude-config-sync

# Create repo on GitHub/GitLab first, then:
git remote add origin <your-repo-url>
git push -u origin main

# Or use helper:
./push-to-github.sh
```

---

## What's Synced

| Item | Count | Status |
|------|-------|--------|
| `settings.json` | 1 | ✅ Includes status line fix |
| `scripts/` | 1 | ✅ context-bar.sh (fixed for non-zero tokens) |
| `skills/` | 57 | ✅ Auto-detects new/changed |
| `hooks/` | 1 | ✅ claudeception hook |
| `plugins.txt` | 1 | ✅ Auto-updated |
| Shell aliases | 3 | ✅ c, ch, cs, --fs |

---

## Recent Changes

### 2026-02-03: Fixed Context Bar
**Issue:** Status line showed `~10%` instead of actual usage
**Cause:** Script picked last entry with `.message.usage`, but had 0 tokens
**Fix:** Filter for `.message.usage.input_tokens > 0` before selecting last
**File:** `scripts/context-bar.sh` line 108-116

### 2026-02-03: Added Auto-Sync
- **Cron job:** Runs daily at 9:00 PM
- **Log:** `~/claude-config-sync/auto-sync.log`
- **Skip:** Use `SKIP_SYNC=1 git commit` to bypass pre-commit hook

---

## New Machine Setup

```bash
# Clone repo
git clone <your-repo-url> ~/claude-config-sync
cd ~/claude-config-sync

# Install symlinks
./install.sh

# Install NPM plugins
./install-plugins.sh

# Apply shell aliases
source ~/.zshrc

# Enable auto-sync (optional)
./enable-auto-sync.sh
```

---

## File Structure

```
~/claude-config-sync/
├── settings.json           # Claude settings (symlinked to ~/.claude/)
├── scripts/                # Custom scripts
│   └── context-bar.sh     # Status line (FIXED)
├── skills/                 # 57 skills (symlinked)
├── hooks/                  # Custom hooks
├── plugins.txt             # Plugin list
├── zshrc-aliases.txt       # Shell aliases
├── sync.sh                 # Incremental sync (auto-detects changes)
├── quick-sync.sh           # One-command sync+commit+push
├── enable-auto-sync.sh     # Enable cron job
├── disable-auto-sync.sh    # Disable cron job
├── auto-sync.sh            # Internal (cron runs this)
├── install.sh              # Restore on new machine
├── install-plugins.sh      # Install NPM plugins
├── backup.sh               # Full backup
├── setup.sh                # Initial setup
├── push-to-github.sh       # Push helper
├── pre-commit-hook         # Git hook (auto-runs sync before commit)
├── README.md               # Full documentation
└── HANDOVER.md             # This file
```

---

## Shell Aliases Installed

```bash
# Claude Code main aliases
c='claude'
ch='claude --chrome'
cs='claude --dangerously-skip-permissions'

# Fork shortcut
claude() { ... }  # Handles --fs → --fork-session

# Claude Config Sync (added 2026-02-03)
cws='~/claude-config-sync/quick-sync.sh'
ccs='cd ~/claude-config-sync && ./sync.sh'
```

---

## Git Remote Setup Needed

**Current status:** Local repo only, no remote configured

**To add remote:**
```bash
cd ~/claude-config-sync
git remote add origin <your-repo-url>
git push -u origin main
```

**After pushing, other machines can:**
```bash
git clone <your-repo-url> ~/claude-config-sync
cd ~/claude-config-sync
./install.sh
```

---

## Auto-Sync Details

**Schedule:** Daily at 9:00 PM (editable via `crontab -e`)
**Log file:** `~/claude-config-sync/auto-sync.log`
**What it does:**
1. Runs `./sync.sh` (detects changes)
2. Commits if changes found
3. Pushes to remote
4. Logs everything

**Enable:**
```bash
cd ~/claude-config-sync
./enable-auto-sync.sh
```

**Disable:**
```bash
cd ~/claude-config-sync
./disable-auto-sync.sh
```

**View logs:**
```bash
tail -f ~/claude-config-sync/auto-sync.log
```

---

## Troubleshooting

### Pre-commit hook runs unexpectedly
**Fix:** Use `SKIP_SYNC=1 git commit` to bypass

### Symlinks not working
**Check:** `ls -la ~/.claude/settings.json` should show `-> ~/claude-config-sync/...`
**Fix:** Run `./install.sh` again

### Auto-sync not running
**Check:** `crontab -l` should show `claude-config-sync-auto`
**Check:** `tail ~/claude-config-sync/auto-sync.log`
**Fix:** Run `./enable-auto-sync.sh` again

### Context bar showing wrong percentage
**Fixed:** This was fixed on 2026-02-03
**If still wrong:** Check `scripts/context-bar.sh` line 113 for `input_tokens > 0` filter

---

## Next Steps

1. **Push to GitHub:** `./push-to-github.sh` or manually add remote
2. **Enable auto-sync:** `./enable-auto-sync.sh` (optional)
3. **Test on another machine:** Clone and run `./install.sh`

---

## Contact

For issues or questions, check `README.md` or inspect the scripts directly.
