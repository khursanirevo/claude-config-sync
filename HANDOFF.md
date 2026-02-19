# Claude Config Sync - Project Handoff

## Goal
Implement auto-handoff hook to replace Claude Code's auto-compact feature for better context preservation.

## Current Progress

### ✅ Most Recent Work (2026-02-15)

**Implementing Auto-Handoff Hook (Commit: 23127ae)**

Successfully created an automatic handoff system that triggers when context reaches threshold:

**What Works:**
- ✅ **UserPromptSubmit event** - Hook fires BEFORE message processing, allowing Claude to execute commands
- ✅ **Context detection** - Accurately calculates context usage from transcript
- ✅ **Automatic execution** - Hook successfully triggers `/handoff` skill when context ≥45%
- ✅ **Hook execution confirmed** - Just triggered at 49% context and invoked handoff skill

**What Didn't Work:**
- ❌ **PreCompact event** - Only fires when auto-compact is enabled (useless since we disable it)
- ❌ **Stop event** - Fires AFTER Claude responds, too late to execute commands
- ❌ **Initial threshold (65%)** - Too high for practical testing, lowered to 45%

**Current Configuration:**
- **Hook file**: `content/hooks/auto-handoff-context-check.sh`
- **Threshold**: 45% (for debugging, will raise to 65% after testing)
- **Event**: UserPromptSubmit (fires before message processing)
- **Registered in**: `~/.claude/settings.json`

**How It Works:**
1. User sends message when context ≥45%
2. UserPromptSubmit hook fires before message is processed
3. Hook outputs: "IMMEDIATE ACTION REQUIRED: /handoff"
4. Claude reads and executes `/handoff` skill
5. Handoff creates HANDOFF.md with conversation state
6. User then runs `/clear` and starts fresh with `@HANDOFF.md`

### Previously Completed (2025-02-14)

#### 1. Repository Restructure (Commit: 0867f82)
- Reorganized from flat structure to professional layout
- Reduced from 18+ scattered scripts at root to clean directory structure
- Created new directories: `bin/`, `lib/`, `config/`, `content/`, `automation/`, `logs/`, `docs/`

#### 2. Unified CLI Implementation
- Consolidated 8+ scripts into single `bin/claude-sync` command with subcommands
- New CLI commands: `sync`, `quick`, `backup`, `install`, `setup`, `reinstall`, `auto-enable`, `auto-disable`, `status`
- Added shell aliases: `cs`, `cs-sync`, `cs-quick`, `cs-reinstall`, `cs-status`

#### 3. Code Organization
- **lib/common.sh** - Shared utilities (logging, Slack notifications, shell detection, jq checks)
- **lib/sync.sh** - Core incremental sync logic
- **lib/backup.sh** - Force backup functions
- **bin/install** - Improved install with color-coded output and existence checks
- **bin/setup** - Enhanced setup with better UX
- **bin/reinstall** - Clean reinstall functionality

#### 4. UX Improvements (from ykdojo/claude-code-tips)
- Color-coded output (green/yellow/gray indicators)
- Fork session shortcut: `--fs` → `--fork-session`
- Auto-detect shell (zsh vs bash) for configuration
- jq dependency check with clear error messages

#### 5. Content Management
- Moved 57 old skills → all removed (clean slate)
- Added 6 new skills from ykdojo/claude-code-tips:
  - `clone` - Branch off and try different approach
  - `gha` - Analyze GitHub Actions failures
  - `half-clone` - Clone conversation half to reduce tokens
  - `handoff` - Write handoff documents
  - `reddit-fetch` - Fetch Reddit content via Gemini CLI
  - `review-claudemd` - Review conversations for CLAUDE.md improvements

#### 6. Cleanup
- Removed failed auto-handoff feature (Commit: f270677) - OLD version
- Removed all 57 old skills (Commit: 210baaa)
- Added 6 new skills from ykdojo (Commit: ee5502e)

### Current Repository Structure
```
claude-config-sync/
├── bin/                     # User-facing commands
│   ├── claude-sync          # Main CLI
│   ├── install              # Install symlinks
│   ├── setup                # Initial setup
│   └── reinstall            # Clean reinstall
├── lib/                     # Core logic
│   ├── common.sh            # Shared utilities
│   ├── sync.sh              # Sync functions
│   └── backup.sh            # Backup functions
├── config/                  # Configuration files
│   ├── settings.json        # Main settings (with hooks.Stop registration)
│   ├── .claude.json         # Global Claude config (MCP, plugins)
│   └── plugins.txt          # Plugin list
├── content/                 # User content to sync
│   ├── skills/              # 6 skills (from ykdojo)
│   ├── scripts/             # 1 script (context-bar.sh)
│   └── hooks/               # 2 hooks (auto-handoff + claudeception.disabled)
├── automation/              # Automation scripts
│   ├── auto-sync.sh         # Daily cron job
│   └── git-hooks/
│       └── pre-commit       # Pre-commit hook
├── logs/                    # Log files (gitignored)
├── docs/                    # Documentation
│   └── HANDOVER.md          # Old handover doc
├── README.md                # Main documentation
├── FOLDER.md                # Structure documentation
└── .gitignore               # Git ignore rules
```

## What Worked

### Auto-Handoff Implementation
- ✅ **UserPromptSubmit event** - Correct event for executing commands before processing
- ✅ **Symlink management** - Repo properly syncs hooks via `bin/install` and `lib/sync.sh`
- ✅ **Context calculation** - Accurate token counting from transcript using jq
- ✅ **Hook message format** - Direct imperative instructions work best

### Previous Successes
- ✅ **Modular design**: Separating `lib/` for core logic from `bin/` for user commands
- ✅ **Unified CLI**: Single `claude-sync` command with subcommands
- ✅ **Color-coded output**: Better UX with status indicators
- ✅ **Symlink strategy**: Content is symlinked from `content/` to `~/.claude/`

## What Didn't Work

### Auto-Handoff Attempts
- ❌ **PreCompact event** - Only fires with auto-compact enabled (commit 34477e8)
- ❌ **Stop event** - Fires after Claude responds (commit 10944d5)
- ❌ **Initial message format** - "Execute: /handoff" wasn't direct enough
- ❌ **Threshold at 65%** - Too high for easy testing

### Previous Failures
- ❌ **Old auto-handoff feature** - Different approach, failed (commit f270677)
- ❌ **57 old skills** - Bloated, not useful, removed (commit 210baaa)

## Next Steps

### Immediate
1. **Test auto-handoff thoroughly** - Verify it works consistently at 45%
2. **Raise threshold back to 65%** - After confirming it works
3. **Update documentation** - Add auto-handoff section to README.md and FOLDER.md

### Documentation Updates Needed
- README.md: Add section explaining auto-handoff feature
- FOLDER.md: Document hooks/ directory and Stop event usage
- Explain relationship between auto-compact and auto-handoff

### Potential Future Enhancements
1. **Configurable threshold** - Make THRESHOLD variable configurable via settings
2. **Smart threshold** - Adjust based on model context window size
3. **Auto-clear after handoff** - Explore if we can automate /clear step
4. **Multiple handoff files** - Rotate HANDOFF.md.1, HANDOFF.md.2 for history

### Commands Reference
```bash
# Daily workflow
cs-sync              # Sync changes from ~/.claude
cs-quick             # Sync + commit + push
cs-status            # Check status

# Maintenance
cs-reinstall         # Clean reinstall symlinks
claude-sync backup   # Force full backup

# Automation
claude-sync auto-enable   # Enable daily auto-sync (9 PM)
claude-sync auto-disable  # Disable daily auto-sync

# Auto-handoff workflow (when context ≥45%)
/handoff             # Creates HANDOFF.md (auto-triggered by hook)
/clear               # Clear context
@HANDOFF.md          # Start fresh conversation
```

### Recent Commits (for context)
```
23127ae Fix auto-handoff: switch to UserPromptSubmit event
f89f735 Lower auto-handoff threshold to 45% for debugging
81a7c42 Switch to UserPromptSubmit hook for auto-handoff
63a79b6 Auto-sync: 2026-02-15 07:17
34477e8 Add auto-handoff PreCompact hook to replace auto-compact
```

## Repository Info
- **Path**: `/home/sani/claude-config-sync`
- **Remote**: https://github.com/khursanirevo/claude-config-sync.git
- **Branch**: main
- **Last handoff**: 2026-02-15 (context at 49%, auto-handoff successfully triggered)
