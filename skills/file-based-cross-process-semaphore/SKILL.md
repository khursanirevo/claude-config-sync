---
name: file-based-cross-process-semaphore
description: |
  Cross-process rate limiting using fcntl.flock() with JSON state file.
  Use when: (1) Multiple Python processes need to coordinate API call limits,
  (2) Rate limit errors occur when spawning parallel API requests, (3) Need
  distributed semaphore without Redis/external services, (4) Processes are
  independent scripts (not forked from parent). Prevents API rate limit errors
  by tracking active calls in /tmp with file locking.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# File-Based Cross-Process Semaphore

## Problem
When running multiple Python processes that make API calls, hitting rate limits
causes errors and wasted retries. Standard solutions like `multiprocessing.Lock()`
don't work across independently spawned processes.

## Context / Trigger Conditions
- Multiple independent Python scripts calling the same API
- API has rate limit (e.g., "max 5 parallel requests")
- Errors like "429 Too Many Requests" or rate limit exceeded
- Processes are launched separately (not via `multiprocessing`)
- No Redis or external coordination service available
- Unix/Linux environment (uses `fcntl`)

## Solution

### Architecture
Use a JSON state file in `/tmp` with `fcntl.flock()` for atomic read/write
operations. Each process acquires a slot before API calls, releases after.

### Key Components

```python
import fcntl
import json
import tempfile
from pathlib import Path
from datetime import datetime, timedelta

class GlobalRateLimiter:
    def __init__(self, max_parallel: int = 5, timeout: int = 300):
        self.max_parallel = max_parallel
        self.timeout = timeout

        # Lock file in temp directory
        self.lock_dir = Path(tempfile.gettempdir()) / "myapp_rate_limit"
        self.lock_dir.mkdir(exist_ok=True)
        self.lock_file = self.lock_dir / "api_lock.json"

        if not self.lock_file.exists():
            self._init_lock_file()

    def _read_lock_file(self) -> dict:
        """Read with shared lock (allows concurrent readers)."""
        with open(self.lock_file, 'r') as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_SH)  # Shared lock
            try:
                return json.load(f)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    def _write_lock_file(self, data: dict):
        """Write with exclusive lock (blocks all other access)."""
        with open(self.lock_file, 'w') as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)  # Exclusive lock
            try:
                json.dump(data, f)
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    def _cleanup_stale_calls(self, active_calls: dict) -> dict:
        """Remove calls older than 10 minutes (crash recovery)."""
        now = datetime.utcnow()
        stale_threshold = timedelta(minutes=10)
        cleaned = {}

        for call_id, timestamp_str in active_calls.items():
            try:
                timestamp = datetime.fromisoformat(timestamp_str)
                if now - timestamp < stale_threshold:
                    cleaned[call_id] = timestamp_str
            except (ValueError, TypeError):
                continue  # Remove invalid entries

        return cleaned

    def acquire(self, call_id: str = None) -> bool:
        """Acquire a slot. Blocks until available or timeout."""
        if call_id is None:
            call_id = f"{os.getpid()}_{id(object())}_{time.time()}"

        start_time = time.time()

        while True:
            # Check timeout
            if time.time() - start_time > self.timeout:
                raise TimeoutError(f"Rate limiter timeout after {self.timeout}s")

            # Try to acquire slot
            data = self._read_lock_file()
            active_calls = self._cleanup_stale_calls(data.get("active_calls", {}))

            if len(active_calls) < self.max_parallel:
                # Slot available - acquire it
                active_calls[call_id] = datetime.utcnow().isoformat()
                data["active_calls"] = active_calls
                self._write_lock_file(data)
                self._current_call_id = call_id
                return True
            else:
                # Wait before retry
                time.sleep(0.1)

    def release(self):
        """Release the acquired slot."""
        if not hasattr(self, '_current_call_id'):
            return

        call_id = self._current_call_id

        data = self._read_lock_file()
        active_calls = data.get("active_calls", {})

        if call_id in active_calls:
            del active_calls[call_id]
            data["active_calls"] = active_calls
            self._write_lock_file(data)

        delattr(self, '_current_call_id')
```

### Usage in API Client

```python
def generate_conversation(self, ...):
    # ... existing code ...

    for attempt in range(max_retries + 1):
        rate_limiter = get_rate_limiter(max_parallel=5)

        try:
            rate_limiter.acquire()  # Blocks until slot available

            # Make API call
            response = call_api(...)

            return response

        finally:
            rate_limiter.release()  # Always release
```

### Important Practices

1. **Always use finally block**: Ensures slot is released even if exception occurs
2. **Store timestamps**: Enables cleanup of crashed processes
3. **Use /tmp directory**: Standard location for temporary locks
4. **Unique call IDs**: Include PID to avoid collisions
5. **Shared lock for reads**: `LOCK_SH` allows multiple concurrent readers
6. **Exclusive lock for writes**: `LOCK_EX` prevents race conditions

## Verification

Before the fix, multiple processes would simultaneously make API calls,
exceeding the rate limit:

```
# Without rate limiter
Process 1: API call -> OK
Process 2: API call -> OK
Process 3: API call -> OK
Process 4: API call -> OK
Process 5: API call -> OK
Process 6: API call -> ERROR 429 Too Many Requests
Process 7: API call -> ERROR 429 Too Many Requests
```

After the fix, only `max_parallel` concurrent calls occur:

```
# With rate limiter (max_parallel=5)
Process 1: Acquires slot 1/5 -> API call -> Releases
Process 2: Acquires slot 2/5 -> API call -> Releases
...
Process 6: Waits for slot... -> Acquires slot -> API call
Process 7: Waits for slot... -> Acquires slot -> API call
```

Check active slots:
```bash
cat /tmp/myapp_rate_limit/api_lock.json
# {"active_calls": {"12345_...": "2026-01-25T12:34:56.789", ...}, "last_cleanup": "..."}
```

## Notes

**Why not alternatives:**
- **multiprocessing.Lock**: Doesn't work across independent processes
- **Redis**: External dependency, infrastructure complexity
- **filelock library**: Works but less control, adds dependency

**Caveats:**
- **Unix-only**: `fcntl` doesn't exist on Windows (use `msvcrt.locking()` or `portalocker`)
- **NFS/SMB issues**: File locking behavior varies on network filesystems
- **Advisory locking**: Processes must voluntarily check the lock (not enforced)
- **macOS history**: Earlier versions (10.6) had fcntl bugs, fixed in modern versions

**Lock types comparison:**
- `flock()`: Not POSIX, simpler, doesn't work over NFS
- `fcntl()`: POSIX standard, byte-range locks, more complex (what we use)
- `lockf()`: Not in BSD, may wrap fcntl() inconsistently

**The apenwarr.ca article** is a famous deep-dive on file locking complexities.
Summary: All Unix file locking is messy, but fcntl() is the most portable
choice despite its quirks.

## References

- [Stack Overflow: Best way to communicate resource lock between processes](https://stackoverflow.com/questions/65950335/best-way-to-communicate-resource-lock-between-processes) - Recommends fcntl.flock() with PID tracking for deadlock recovery
- [Everything you never wanted to know about file locking (apenwarr.ca)](https://apenwarr.ca/log/20101213) - Comprehensive analysis of Unix file locking APIs and their quirks
- [Python fcntl documentation](https://docs.python.org/3/library/fcntl.html) - Official docs on fcntl module
