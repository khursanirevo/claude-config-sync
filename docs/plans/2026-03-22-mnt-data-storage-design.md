# Design: `/mnt/data` Storage Migration

**Date:** 2026-03-22
**Author:** Claude Code
**Status:** Approved

## Overview

Add optional support for storing Claude Code configuration data at `/mnt/data/.claude` while maintaining a symlink at `~/.claude` for backward compatibility. This allows users to use alternative storage locations (e.g., separate mount point) without breaking existing tooling.

## Architecture

### Symlink Layer Design

The system uses a transparent symlink layer where `~/.claude` becomes a symlink to `/mnt/data/.claude`. All existing code continues to use `~/.claude` paths without modification - the symlink is resolved automatically by the filesystem.

**Before (current state):**
```
~/.claude/                          (real data)
  ├── settings.json
  ├── skills/
  ├── scripts/
  └── ...

~/claude-config-sync/config/settings.json → ~/.claude/settings.json
```

**After (with --use-mnt-data):**
```
~/.claude → /mnt/data/.claude       (symlink)
/mnt/data/.claude/                  (real data)
  ├── settings.json
  ├── skills/
  ├── scripts/
  └── ...

~/claude-config-sync/config/settings.json → ~/.claude/settings.json → /mnt/data/.claude/settings.json
```

### Key Design Principle

**Symlink transparency:** All existing scripts continue working without changes because symlinks are resolved automatically by the filesystem. The symlink chain `config/ → ~/.claude → /mnt/data/.claude` is completely transparent to file operations.

## Implementation

### Changes to `bin/setup`

**New flag:** `--use-mnt-data` (optional)

**New function:** `migrate_to_mnt_data()` implements the migration logic.

#### Migration Algorithm

```bash
migrate_to_mnt_data() {
    local mnt_claude="/mnt/data/.claude"

    # Check if /mnt/data exists
    if [[ ! -d "/mnt/data" ]]; then
        cs_warn "/mnt/data does not exist, falling back to default ~/.claude location"
        return 0
    fi

    # Handle existing ~/.claude
    if [[ -e "$HOME/.claude" && ! -L "$HOME/.claude" ]]; then
        cs_info "Migrating existing ~/.claude to /mnt/data/.claude..."

        # Check disk space
        local current_size=$(du -sk "$HOME/.claude" | cut -f1)
        local available_space=$(df -k "/mnt/data" | awk 'NR==2 {print $4}')

        if [[ $available_space -lt $((current_size * 2)) ]]; then
            cs_error "Insufficient space on /mnt/data"
            return 1
        fi

        # Create /mnt/data/.claude if needed
        if [[ ! -d "$mnt_claude" ]]; then
            mkdir -p "$mnt_claude" || {
                cs_error "Failed to create $mnt_claude"
                return 1
            }
        fi

        # Copy contents
        cp -a "$HOME/.claude/"* "$mnt_claude/" 2>/dev/null || true

        # Verify copy succeeded
        local src_count=$(find "$HOME/.claude" -type f | wc -l)
        local dst_count=$(find "$mnt_claude" -type f | wc -l)

        if [[ $src_count -ne $dst_count ]]; then
            cs_error "Migration failed: file count mismatch"
            return 1
        fi

        # Remove old directory
        rm -rf "$HOME/.claude"
    fi

    # Check if ~/.claude is already a symlink elsewhere
    if [[ -L "$HOME/.claude" ]]; then
        local current_target=$(readlink "$HOME/.claude")
        if [[ "$current_target" != "$mnt_claude" ]]; then
            cs_error "~/.claude is already a symlink to $current_target"
            return 1
        fi
        cs_info "Symlink already configured correctly"
        return 0
    fi

    # Create symlink
    ln -s "$mnt_claude" "$HOME/.claude" || {
        cs_error "Failed to create symlink"
        return 1
    }

    cs_success "Created symlink: ~/.claude → /mnt/data/.claude"
    return 0
}
```

#### Integration Point

Call `migrate_to_mnt_data()` at the **beginning** of setup, before any directory creation or backup operations:

```bash
# In bin/setup, after argument parsing
if [[ "$USE_MNT_DATA" == "true" ]]; then
    migrate_to_mnt_data || exit 1
fi

# Continue with normal setup...
```

## Error Handling

### Error Scenarios

| Scenario | Action | Exit Code |
|----------|--------|-----------|
| `/mnt/data` doesn't exist | Log warning, continue with `~/.claude` | 0 |
| `~/.claude` already symlinked to `/mnt/data/.claude` | Skip, already configured | 0 |
| `~/.claude` symlinked to different location | Error, exit | 1 |
| Insufficient disk space | Error, exit | 1 |
| Copy operation fails (file count mismatch) | Error, exit | 1 |
| Permission denied | Error, exit | 1 |
| Symlink creation fails | Error, exit | 1 |

### Safety Guarantees

1. **No data loss:** Copy happens before removal, original `~/.claude` preserved on failure
2. **Idempotent:** Can be run multiple times safely
3. **Rollback-safe:** If migration fails, original state is untouched
4. **Graceful degradation:** Falls back to default if `/mnt/data` unavailable

## Testing Strategy

### Test Scenarios

1. **Fresh install with `--use-mnt-data`:**
   - Run `./bin/setup --use-mnt-data` on machine with no existing config
   - Verify symlink created: `~/.claude → /mnt/data/.claude`
   - Verify data stored in `/mnt/data/.claude`
   - Run `./bin/install` - should work transparently

2. **Migration from existing config:**
   - Create test `~/.claude` with sample files
   - Run `./bin/setup --use-mnt-data`
   - Verify all files moved to `/mnt/data/.claude`
   - Verify symlink works: accessing `~/.claude/file` reaches `/mnt/data/.claude/file`

3. **Fallback when `/mnt/data` missing:**
   - Temporarily rename `/mnt/data`
   - Run `./bin/setup --use-mnt-data`
   - Verify warning message displayed
   - Verify falls back to `~/.claude` (no symlink created)

4. **Idempotency:**
   - Run `./bin/setup --use-mnt-data` twice
   - Second run should detect existing symlink and skip migration

5. **Conflicting symlink detection:**
   - Create `~/.claude` symlink pointing elsewhere
   - Run `./bin/setup --use-mnt-data`
   - Should error out and not proceed

6. **Disk space validation:**
   - Fill `/mnt/data` to near capacity
   - Run `./bin/setup --use-mnt-data`
   - Should detect insufficient space and error out

### Verification Commands

```bash
# Check symlink
ls -la ~/.claude
readlink ~/.claude

# Verify file access through symlink
stat ~/.claude/settings.json
cat ~/.claude/settings.json

# Check disk space
df -h /mnt/data

# Verify file counts match
find ~/.claude -type f | wc -l
find /mnt/data/.claude -type f | wc -l
```

## No Changes Required To

- `bin/install` - continues using `~/.claude` paths (now symlinked)
- `lib/common.sh` - path variables unchanged
- `lib/sync.sh` - sync operations work through symlink
- `lib/backup.sh` - backup operations work through symlink
- `automation/` - all automation works through symlink

## Success Criteria

- [ ] Users can run `./bin/setup --use-mnt-data` to migrate storage
- [ ] Symlink `~/.claude → /mnt/data/.claude` is created
- [ ] All existing operations (sync, backup, install) work transparently
- [ ] Graceful fallback when `/mnt/data` doesn't exist
- [ ] No data loss during migration
- [ ] Idempotent operation (safe to run multiple times)
- [ ] Clear error messages for all failure scenarios
