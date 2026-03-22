# `/mnt/data` Storage Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add optional `--use-mnt-data` flag to `bin/setup` that stores Claude Code data at `/mnt/data/.claude` with a symlink at `~/.claude` for backward compatibility.

**Architecture:** Extend `bin/setup` to add a migration function that:
1. Checks if `/mnt/data` exists (graceful fallback if not)
2. Migrates existing `~/.claude` data to `/mnt/data/.claude`
3. Creates symlink `~/.claude` → `/mnt/data/.claude`
4. Validates migration success before proceeding

All existing scripts continue using `~/.claude` paths - symlink transparency makes this work without changes elsewhere.

**Tech Stack:** Bash scripting, standard Unix utilities (cp, ln, readlink, find, df)

---

## Task 1: Read and Understand Current `bin/setup`

**Files:**
- Read: `bin/setup`

**Step 1: Read the setup script**

Read the entire `bin/setup` file to understand:
- Current argument parsing logic
- Directory structure creation flow
- Backup operations
- Where migration should be integrated

**Step 2: Identify integration point**

Find the exact location in the script where:
- Arguments are parsed
- Initial setup begins (before directory creation)

**No commit needed** - this is research only

---

## Task 2: Add Argument Parsing for `--use-mnt-data`

**Files:**
- Modify: `bin/setup` (add to argument parsing section)

**Step 1: Add variable declaration**

Find the variable declaration section and add:

```bash
USE_MNT_DATA="false"
```

**Step 2: Add argument parsing**

Find the argument parsing loop (likely a `while` loop) and add:

```bash
    --use-mnt-data)
        USE_MNT_DATA="true"
        ;;
```

**Step 3: Verify the change**

Run: `./bin/setup --help` or check that argument parsing doesn't break existing functionality

**Step 4: Commit**

```bash
git add bin/setup
git commit -m "feat: add --use-mnt-data flag argument parsing"
```

---

## Task 3: Create `migrate_to_mnt_data()` Function

**Files:**
- Modify: `bin/setup` (add new function before main setup logic)

**Step 1: Write the migration function**

Add this function before the main setup logic (after sourcing `lib/common.sh`):

```bash
migrate_to_mnt_data() {
    local mnt_claude="/mnt/data/.claude"

    # Check if /mnt/data exists
    if [[ ! -d "/mnt/data" ]]; then
        cs_warn "/mnt/data does not exist, falling back to default ~/.claude location"
        return 0
    fi

    # Handle existing ~/.claude directory
    if [[ -e "$HOME/.claude" && ! -L "$HOME/.claude" ]]; then
        cs_info "Migrating existing ~/.claude to /mnt/data/.claude..."

        # Check disk space (require 2x current size)
        local current_size=$(du -sk "$HOME/.claude" 2>/dev/null | cut -f1)
        local available_space=$(df -k "/mnt/data" 2>/dev/null | awk 'NR==2 {print $4}')

        if [[ -n "$current_size" && -n "$available_space" && $available_space -lt $((current_size * 2)) ]]; then
            cs_error "Insufficient space on /mnt/data (need ~$((current_size * 2)) KB, have $available_space KB)"
            return 1
        fi

        # Create /mnt/data/.claude if needed
        if [[ ! -d "$mnt_claude" ]]; then
            mkdir -p "$mnt_claude" || {
                cs_error "Failed to create $mnt_claude"
                return 1
            }
        fi

        # Copy contents preserving attributes
        cp -a "$HOME/.claude"/ "$mnt_claude/" 2>/dev/null || {
            cs_error "Failed to copy files to $mnt_claude"
            return 1
        }

        # Verify copy succeeded by comparing file counts
        local src_count=$(find "$HOME/.claude" -type f 2>/dev/null | wc -l)
        local dst_count=$(find "$mnt_claude" -type f 2>/dev/null | wc -l)

        if [[ $src_count -ne $dst_count ]]; then
            cs_error "Migration verification failed: source has $src_count files, destination has $dst_count files"
            return 1
        fi

        cs_success "Copied $src_count files to /mnt/data/.claude"

        # Remove old directory
        rm -rf "$HOME/.claude" || {
            cs_error "Failed to remove old ~/.claude directory"
            return 1
        }
    fi

    # Check if ~/.claude is already a symlink
    if [[ -L "$HOME/.claude" ]]; then
        local current_target=$(readlink "$HOME/.claude")
        if [[ "$current_target" == "$mnt_claude" ]]; then
            cs_info "Symlink already configured correctly: ~/.claude → /mnt/data/.claude"
            return 0
        else
            cs_error "~/.claude is already a symlink to '$current_target' (not '$mnt_claude')"
            cs_error "Please remove the existing symlink manually and try again"
            return 1
        fi
    fi

    # Create symlink
    ln -s "$mnt_claude" "$HOME/.claude" || {
        cs_error "Failed to create symlink ~/.claude → $mnt_claude"
        return 1
    }

    cs_success "Created symlink: ~/.claude → /mnt/data/.claude"
    return 0
}
```

**Step 2: Verify syntax**

Run: `bash -n bin/setup`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add bin/setup
git commit -m "feat: add migrate_to_mnt_data() function"
```

---

## Task 4: Integrate Migration into Setup Flow

**Files:**
- Modify: `bin/setup` (call migration function at appropriate point)

**Step 1: Add migration call**

Find the location after argument parsing and after sourcing `lib/common.sh`, but BEFORE any directory creation or backup operations. Add:

```bash
# Handle optional /mnt/data migration
if [[ "$USE_MNT_DATA" == "true" ]]; then
    migrate_to_mnt_data || exit 1
fi
```

**Step 2: Verify the placement**

Ensure the migration call is:
- After `CS_ROOT` and other variables are set
- After `lib/common.sh` is sourced (for `cs_info`, `cs_error`, etc.)
- Before any operations that use `~/.claude`

**Step 3: Verify syntax**

Run: `bash -n bin/setup`
Expected: No syntax errors

**Step 4: Commit**

```bash
git add bin/setup
git commit -m "feat: integrate migrate_to_mnt_data into setup flow"
```

---

## Task 5: Test - Fallback When `/mnt/data` Missing

**Files:**
- Test: Manual testing of `bin/setup`

**Step 1: Test fallback behavior**

Ensure `/mnt/data` doesn't exist (or temporarily rename it):

```bash
# If /mnt/data exists, temporarily rename it
sudo mv /mnt/data /mnt/data.backup 2>/dev/null || true

# Run setup with flag
./bin/setup --use-mnt-data

# Verify warning was shown
# Verify ~/.claude is NOT a symlink (normal setup occurred)
ls -la ~/.claude | grep -v "^l"

# Restore /mnt/data if we renamed it
sudo mv /mnt/data.backup /mnt/data 2>/dev/null || true
```

Expected: Warning message about `/mnt/data` not existing, normal setup proceeds

**Step 2: Clean up test artifacts**

Remove test setup if created

**No commit needed** - testing only

---

## Task 6: Test - Fresh Install with `--use-mnt-data`

**Files:**
- Test: Manual testing of `bin/setup`

**Step 1: Create test environment**

```bash
# Create temporary test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Clone or copy the repo
cp -r /home/sani/claude-config-sync "$TEST_DIR/"
cd "$TEST_DIR/claude-config-sync"

# Ensure /mnt/data exists and is empty
sudo rm -rf /mnt/data/.claude
sudo mkdir -p /mnt/data

# Remove existing ~/.claude if it exists
rm -rf ~/.claude
```

**Step 2: Run setup with flag**

```bash
./bin/setup --use-mnt-data
```

**Step 3: Verify symlink was created**

```bash
# Check it's a symlink
ls -la ~/.claude
# Expected: lrwxrwxrwx ... ~/.claude -> /mnt/data/.claude

# Verify symlink target
readlink ~/.claude
# Expected: /mnt/data/.claude

# Verify real data exists at target
ls -la /mnt/data/.claude
# Expected: Directory with config files
```

**Step 4: Verify symlink transparency**

```bash
# Access files through symlink
stat ~/.claude/settings.json
# Expected: File exists and is accessible

# Verify it's actually at /mnt/data
ls -la /mnt/data/.claude/settings.json
# Expected: Same file
```

**Step 5: Clean up**

```bash
# Remove test setup
rm -rf "$TEST_DIR"
```

**No commit needed** - testing only

---

## Task 7: Test - Migration from Existing Config

**Files:**
- Test: Manual testing of `bin/setup`

**Step 1: Create test environment with existing config**

```bash
# Create test ~/.claude with sample data
TEST_CLAUDE=$(mktemp -d)
mkdir -p "$TEST_CLAUDE/skills"
mkdir -p "$TEST_CLAUDE/scripts"
echo '{"test": "data"}' > "$TEST_CLAUDE/settings.json"
echo "# test skill" > "$TEST_CLAUDE/skills/test.md"
echo "# test script" > "$TEST_CLAUDE/scripts/test.sh"

# Ensure /mnt/data exists and is empty
sudo rm -rf /mnt/data/.claude
sudo mkdir -p /mnt/data

# Replace ~/.claude with test data
rm -rf ~/.claude
cp -r "$TEST_CLAUude" ~/.claude
```

**Step 2: Run setup with flag**

```bash
./bin/setup --use-mnt-data
```

**Step 3: Verify migration succeeded**

```bash
# Check symlink was created
readlink ~/.claude
# Expected: /mnt/data/.claude

# Verify all files were migrated
ls /mnt/data/.claude/settings.json
# Expected: File exists

ls /mnt/data/.claude/skills/test.md
# Expected: File exists

ls /mnt/data/.claude/scripts/test.sh
# Expected: File exists

# Verify content is preserved
cat /mnt/data/.claude/settings.json
# Expected: {"test": "data"}
```

**Step 4: Verify file counts match**

```bash
# Count files in migrated location
find /mnt/data/.claude -type f | wc -l
# Expected: 3 (settings.json, test.md, test.sh)
```

**Step 5: Clean up**

```bash
# Clean up test data
rm -rf /mnt/data/.claude
rm -rf "$TEST_CLAUDE"
```

**No commit needed** - testing only

---

## Task 8: Test - Idempotency (Run Multiple Times)

**Files:**
- Test: Manual testing of `bin/setup`

**Step 1: Run setup twice**

```bash
# First run
./bin/setup --use-mnt-data

# Second run (should detect existing symlink)
./bin/setup --use-mnt-data
```

**Step 2: Verify no errors**

Expected: Second run shows "Symlink already configured correctly" message and exits successfully

**Step 3: Verify symlink is correct**

```bash
readlink ~/.claude
# Expected: /mnt/data/.claude (unchanged)
```

**No commit needed** - testing only

---

## Task 9: Test - Conflicting Symlink Detection

**Files:**
- Test: Manual testing of `bin/setup`

**Step 1: Create conflicting symlink**

```bash
# Remove existing setup
rm -rf ~/.claude /mnt/data/.claude

# Create ~/.claude symlink pointing elsewhere
mkdir -p /tmp/fake-claude
ln -s /tmp/fake-claude ~/.claude
```

**Step 2: Run setup with flag**

```bash
./bin/setup --use-mnt-data
```

**Step 3: Verify error message**

Expected: Error message about existing symlink pointing to different location

**Step 4: Verify setup didn't proceed**

```bash
readlink ~/.claude
# Expected: Still points to /tmp/fake-claude (unchanged)
```

**Step 5: Clean up**

```bash
rm -rf ~/.claude /tmp/fake-claude
```

**No commit needed** - testing only

---

## Task 10: Test - Disk Space Validation

**Files:**
- Test: Manual testing of `bin/setup`

**Step 1: Create large test config**

```bash
# Create test ~/.claude with large file
TEST_CLAUDE=$(mktemp -d)
mkdir -p "$TEST_CLAUDE"
dd if=/dev/zero of="$TEST_CLAUDE/largefile" bs=1M count=100

# Ensure /mnt/data has limited space (if possible)
# Note: This test may not be feasible on all systems
# Skip if /mnt/data has sufficient space

rm -rf ~/.claude
cp -r "$TEST_CLAUDE" ~/.claude
```

**Step 2: Check if validation works**

```bash
# Run setup with flag
./bin/setup --use-mnt-data

# If /mnt/data has < 200MB free, should error
# If /mnt/data has >= 200MB free, should succeed
```

**Step 3: Clean up**

```bash
rm -rf ~/.claude /mnt/data/.claude "$TEST_CLAUDE"
```

**No commit needed** - testing only (may be skipped depending on system)

---

## Task 11: Update Documentation

**Files:**
- Modify: `README.md` (add usage documentation)
- Modify: `CLAUDE.md` (if needed, add architecture note)

**Step 1: Add usage to README**

Find the usage section in README.md and add:

```markdown
### Using Alternative Storage Location

To store Claude Code data on a separate mount point (e.g., `/mnt/data`), use the `--use-mnt-data` flag during setup:

```bash
./bin/setup --use-mnt-data
```

This will:
- Move existing `~/.claude` data to `/mnt/data/.claude`
- Create a symlink `~/.claude` → `/mnt/data/.claude`
- All operations continue working transparently

If `/mnt/data` doesn't exist, the script will fall back to the default `~/.claude` location with a warning.
```

**Step 2: Commit documentation**

```bash
git add README.md
git commit -m "docs: add --use-mnt-data usage documentation"
```

---

## Task 12: Final Integration Test

**Files:**
- Test: Full end-to-end workflow

**Step 1: Test complete workflow**

```bash
# Clean slate
rm -rf ~/.claude /mnt/data/.claude

# Run setup with flag
./bin/setup --use-mnt-data

# Verify symlink
readlink ~/.claude

# Run sync operation
./bin/claude-sync sync

# Run status
./bin/claude-sync status

# Verify all operations work through symlink
```

**Step 2: Verify all existing operations work**

```bash
# Test that sync still works
./bin/claude-sync sync

# Test that quick sync works
./bin/claude-sync quick

# Verify data is actually at /mnt/data
ls -la /mnt/data/.claude/
```

**No commit needed** - final validation only

---

## Success Criteria

- [ ] `--use-mnt-data` flag is recognized by `bin/setup`
- [ ] Symlink `~/.claude` → `/mnt/data/.claude` is created when flag is used
- [ ] Existing data is migrated successfully
- [ ] Graceful fallback when `/mnt/data` doesn't exist
- [ ] Error when conflicting symlink exists
- [ ] Disk space validation prevents insufficient space scenarios
- [ ] All existing operations (sync, backup, status) work transparently through symlink
- [ ] Documentation updated with usage instructions
- [ ] Idempotent - can be run multiple times safely
