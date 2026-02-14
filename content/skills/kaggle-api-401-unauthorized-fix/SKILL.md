---
name: kaggle-api-401-unauthorized-fix
description: |
  Fix Kaggle Python API 401 Unauthorized errors when KAGGLE_API_TOKEN environment
  variable is set. Use when: (1) api.competition_submissions() returns 401,
  (2) api.competition_leaderboard_view() returns 401, (3) valid ~/.kaggle/kaggle.json
  exists but API still unauthorized, (4) competition rules already accepted.
  Works by forcing API key authentication instead of token-based auth.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Kaggle API 401 Unauthorized Fix

## Problem
The Kaggle Python API returns `401 Unauthorized` errors even when:
- Valid `~/.kaggle/kaggle.json` file exists with correct credentials
- Competition rules have been accepted
- Credentials work in Kaggle CLI but not in Python API

## Context / Trigger Conditions
- Using `kaggle` Python package with `KAGGLE_API_TOKEN` environment variable set
- Calling methods like `api.competition_submissions()`, `api.competition_leaderboard_view()`
- Error message: `401 Client Error: Unauthorized for url: https://api.kaggle.com/...`
- File format: `KAGGLE_API_TOKEN=KGAT_xxxxxxxxxxxxxxxxxxxxxxxxx`

## Root Cause
When `KAGGLE_API_TOKEN` environment variable is set, the Kaggle API prioritizes token-based
authentication (newer method) which has different permission scopes than the traditional
API key authentication. The token method may return 401 for endpoints that work fine with
API key authentication.

## Solution
Remove the `KAGGLE_API_TOKEN` from environment and force API key authentication:

```python
from kaggle import KaggleApi
import os

# Remove token from environment to force API key method
if 'KAGGLE_API_TOKEN' in os.environ:
    del os.environ['KAGGLE_API_TOKEN']

api = KaggleApi()

# Force API key configuration
api.config_values = {
    'username': 'your_kaggle_username',
    'key': 'your_kaggle_api_key'
}

# Now authenticate and use API
api.authenticate()

# This will now work:
submissions = api.competition_submissions("competition-name")
leaderboard = api.competition_leaderboard_view("competition-name")
```

For `kaggle.json` format:
```json
{
  "username": "your_username",
  "key": "your_api_key_here"
}
```

## Verification
After applying the fix, these commands should work:

```python
# Test authentication
api.competitions_list(page=1)  # Should return list, not 401

# Test specific endpoints
submissions = api.competition_submissions("competition-name")  # Should return list
leaderboard = api.competition_leaderboard_view("competition-name")  # Should return list
```

## Example
```python
from kaggle import KaggleApi
import os

# Before fix (returns 401):
export KAGGLE_API_TOKEN=KGAT_abcdef123456
api = KaggleApi()
api.authenticate()
submissions = api.competition_submissions("santa-2025")  # 401 Unauthorized!

# After fix (works):
if 'KAGGLE_API_TOKEN' in os.environ:
    del os.environ['KAGGLE_API_TOKEN']

api = KaggleApi()
api.config_values = {
    'username': 'khursani8',
    'key': '50f8777f3a66d44c33b1e2a8814b88d3'
}
api.authenticate()
submissions = api.competition_submissions("santa-2025")  # Success!
```

## Notes
- The `KAGGLE_API_TOKEN` format (`KGAT_...`) appears to be a newer authentication method
  with different permission scopes
- Traditional API key authentication (from `~/.kaggle/kaggle.json`) has broader permissions
  for competition operations
- This is a known issue discussed in [Kaggle/kaggle-api #550](https://github.com/Kaggle/kaggle-api/issues/550)
- Token-based auth may work for dataset downloads but fail for competition submissions/leaderboard
- If you don't have a `kaggle.json` file, create one at `~/.kaggle/kaggle.json` with credentials
  from https://www.kaggle.com/settings

## Workarounds That DON'T Work
- ❌ Re-generating the API token
- ❌ Re-creating `kaggle.json` file
- ❌ Accepting competition rules again
- ❌ Using `KAGGLE_USERNAME` and `KAGGLE_KEY` environment variables
- ❌ Setting `KAGGLE_API_TOKEN` to different format

## Related Issues
- Environment variable loading timing: `kaggle` package reads env vars on import, before
  `.env` files are loaded with `python-dotenv`
- Solution: Set environment variables in shell before running Python, or use the
  `api.config_values` override method shown above

## References
- [Kaggle Public API Documentation](https://www.kaggle.com/docs/api)
- [Environment Method Issue #550](https://github.com/Kaggle/kaggle-api/issues/550)
- [Kaggle API GitHub Repository](https://github.com/Kaggle/kaggle-api)
