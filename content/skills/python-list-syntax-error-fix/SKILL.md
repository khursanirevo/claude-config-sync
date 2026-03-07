---
name: python-list-syntax-error-fix
description: |
  Fix "SyntaxError: unterminated string literal" in Python phrase/training data files.
  Use when: (1) Importing phrase lists fails with syntax error, (2) Large Python files
  with string lists have dangling quotes like `',`, (3) TTS/training data files with
  thousands of entries need cleanup. Automates detection and removal of malformed list
  items that break Python imports.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# Python List Syntax Error Fix

## Problem
Python files containing large lists of strings (e.g., TTS training phrases, translation data)
can develop syntax errors from incomplete or malformed entries like `',` instead of actual
strings, causing `SyntaxError: unterminated string literal` on import.

## Context / Trigger Conditions
- **Exact error**: `SyntaxError: unterminated string literal (detected at line N)`
- **File type**: Python files with large string lists (100+ entries)
- **Symptom**: Line numbers point to entries like `',`, `''`, or `']:`
- **Common causes**: Manual editing, copy-paste errors, template placeholders not filled

## Solution

### Automated Fix (Recommended)
Use this Python script to detect and remove malformed entries:

```python
import re

# Read the file
with open('your_file.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Remove lines that contain only dangling quotes
cleaned_lines = []
for line in lines:
    stripped = line.strip()
    # Skip lines that are just a single quote and comma
    if stripped in ["',", "''", "']:"]:
        continue
    # Also skip lines that start with a single quote followed by comma only
    if re.match(r"^\s*'\s*,\s*$", line):
        continue
    cleaned_lines.append(line)

# Write back
with open('your_file.py', 'w', encoding='utf-8') as f:
    f.writelines(cleaned_lines)

print(f"Removed {len(lines) - len(cleaned_lines)} malformed lines")
```

### Manual Fix (Small Files)
For small files (under 50 entries), manually search and replace:
1. Open file in text editor
2. Search for: `^\s*'\s*,\s*$` (regex mode)
3. Replace each match with a valid string or remove the line entirely

## Verification
After fixing:
```bash
# Test import
python3 -c "from your_file import YOUR_LIST; print(f'Loaded {len(YOUR_LIST)} items')"

# Check syntax
python3 -m py_compile your_file.py
```

Expected output: No errors, correct number of items loaded.

## Example
**Before** (broken):
```python
PHRASES = [
    'Hello world',
    'Good morning',
    ',
    '',
    'How are you?',
    '],
]
```
**After** (fixed):
```python
PHRASES = [
    'Hello world',
    'Good morning',
    'How are you?',
]
```

## Notes
- **Backup first**: Always create a backup before running automated fixes
- **Encoding matters**: Use UTF-8 encoding for files with non-ASCII characters (Malay, Chinese, etc.)
- **List structure**: This fix preserves valid list structure while removing only malformed entries
- **Common in TTS datasets**: Files like `Phrases.py`, `prompts.txt`, or training data often have this issue

## Prevention
When working with large phrase lists:
1. **Use scripts to generate** lists instead of manual editing
2. **Validate after edits**: Run `python3 -m py_compile` immediately
3. **Use linters**: Configure your IDE to highlight syntax errors in real-time
4. **Version control**: Git can help identify when errors were introduced
