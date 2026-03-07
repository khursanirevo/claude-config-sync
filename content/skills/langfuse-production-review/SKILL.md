---
name: langfuse-production-review
description: |
  Review Langfuse observability integration for production readiness. Use when:
  (1) Auditing Langfuse Python SDK integration for deployment, (2) Investigating
  thread leaks or resource issues with observability, (3) Reviewing async
  background flush implementations, (4) Diagnosing why traces aren't appearing
  in Langfuse dashboard. Covers ThreadPoolExecutor lifecycle, background flush
  patterns, graceful degradation, timeout protection, and logging visibility.
author: Claude Code
version: 1.0.0
date: 2026-02-07
---

# Langfuse Production Review Checklist

## Problem

Langfuse observability integrations often have subtle production issues that don't appear in development:
- Thread leaks from improper executor shutdown
- Race conditions during application shutdown
- Silent failures from inadequate logging
- Bottlenecks under high load
- Hanging threads from unresponsive API calls

These issues cause resource leaks, lost traces, and difficult-to-diagnose production problems.

## Context / Trigger Conditions

Review Langfuse integration when:
- **Pre-deployment audit**: Checking observability before production release
- **Resource issues**: Thread leaks, memory growth, or slow shutdowns
- **Missing traces**: Data not appearing in Langfuse dashboard
- **After adding Langfuse**: To any Python service using background flush
- **Performance review**: Investigating slow request handling or high TPS issues

**Key files to review:**
- `langfuse_tracer.py` or similar observability wrapper
- Application lifecycle management (startup/shutdown handlers)
- Background task / thread pool initialization

## Solution

### 1. ThreadPoolExecutor Lifecycle (CRITICAL)

**Problem:** Executor never shut down → thread leaks on restart

**Check:**
```python
# ✅ CORRECT - Executor shut down during application shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    langfuse = get_langfuse_client()
    # ... startup code ...
    yield

    # Shutdown
    if langfuse:
        langfuse.flush()
        join_background_flushes(timeout=5.0)  # ← MUST HAVE THIS

# ❌ WRONG - Executor never cleaned up
@asynccontextmanager
async def lifespan(app: FastAPI):
    langfuse = get_langfuse_client()
    # ... startup code ...
    yield

    # Shutdown
    if langfuse:
        langfuse.flush()
        # ❌ Missing join_background_flushes() - threads leak!
```

**Implementation:**
```python
def join_background_flushes(timeout: float = 1.0):
    """Wait for pending background flushes to complete."""
    global _flush_executor
    if _flush_executor is not None:
        try:
            _flush_executor.shutdown(wait=True, timeout=timeout)
        except Exception as e:
            logger.warning(f"Failed to shutdown flush executor: {e}")
        _flush_executor = None
```

### 2. Shutdown State Handling (MEDIUM)

**Problem:** `flush_in_background()` called during shutdown → RuntimeError

**Check:**
```python
# ✅ CORRECT - Checks shutdown state
def flush_in_background():
    client = get_langfuse_client()
    if client is None:
        return

    global _flush_executor
    if _flush_executor is None:
        return  # Silently skip

    # Check if executor is shutting down
    if getattr(_flush_executor, "_shutdown", False):
        return  # Silently skip during shutdown

    def do_flush():
        try:
            client.flush()
        except Exception as e:
            logger.warning(f"Background flush failed: {e}")

    try:
        _flush_executor.submit(do_flush)
    except RuntimeError:
        # Executor shut down between check and submit
        logger.debug("Flush executor shut down, skipping trace flush")

# ❌ WRONG - No shutdown check
def flush_in_background():
    client = get_langfuse_client()
    if client is None:
        return

    if _flush_executor is None:
        logger.warning("Flush executor not initialized")  # ❌ Unnecessary warning
        return

    def do_flush():
        client.flush()

    _flush_executor.submit(do_flush)  # ❌ RuntimeError during shutdown
```

### 3. Logging Visibility (LOW-MEDIUM)

**Problem:** Failures logged at DEBUG level → invisible in production

**Check:**
```python
# ✅ CORRECT - WARNING level for production visibility
def update_current_observation(**kwargs):
    try:
        client.update_current_generation(**kwargs)
    except Exception:
        try:
            client.update_current_span(**kwargs)
        except Exception as e2:
            logger.warning(f"Could not update current observation: {e2}")  # ✅ WARNING

# ❌ WRONG - DEBUG level (invisible in production)
def update_current_observation(**kwargs):
    try:
        client.update_current_generation(**kwargs)
    except Exception:
        try:
            client.update_current_span(**kwargs)
        except Exception as e2:
            logger.debug(f"Could not update current observation: {e2}")  # ❌ DEBUG
```

**Rule of thumb:**
- **DEBUG**: Detailed diagnostics for development
- **INFO**: Normal operational messages
- **WARNING**: Failures that don't break functionality (like observability failures)
- **ERROR**: Failures that break functionality

### 4. Throughput Bottlenecks (LOW)

**Problem:** Single worker → flushes queue under high load

**Check:**
```python
# ✅ RECOMMENDED - 3 workers for better throughput
_flush_executor = ThreadPoolExecutor(
    max_workers=3,  # ✅ Allows concurrent flush uploads
    thread_name_prefix="langfuse_flush"
)

# ⚠️ OK for low traffic - Single worker
_flush_executor = ThreadPoolExecutor(
    max_workers=1,  # Single worker may bottleneck under high TPS
    thread_name_prefix="langfuse_flush"
)
```

**Trade-offs:**
- **1 worker**: Simple, minimal resources, may bottleneck at high TPS
- **3-5 workers**: Better throughput, more resources, recommended for production
- **10+ workers**: Diminishing returns, higher resource usage

### 5. Timeout Protection (LOW)

**Problem:** `flush()` hangs indefinitely if API unresponsive

**Check:**
```python
# ✅ CORRECT - Timeout protection
def do_flush():
    import threading

    flush_error = [None]
    flush_complete = threading.Event()

    def flush_worker():
        try:
            client.flush()
        except Exception as e:
            flush_error[0] = e
        finally:
            flush_complete.set()

    flush_thread = threading.Thread(target=flush_worker, daemon=True)
    flush_thread.start()

    # Wait with timeout
    if not flush_complete.wait(timeout=10):
        logger.warning("Langfuse flush timeout after 10 seconds")
        return  # Daemon thread will be cleaned up

    if flush_error[0] is not None:
        logger.warning(f"Background flush failed: {flush_error[0]}")

# ❌ WRONG - No timeout
def do_flush():
    try:
        client.flush()  # ❌ Could hang forever
    except Exception as e:
        logger.warning(f"Background flush failed: {e}")
```

**Timeout guidelines:**
- **10 seconds**: Good balance for API timeouts
- **5 seconds**: Aggressive, may timeout on slow networks
- **30+ seconds**: Too long, defeats the purpose

### 6. Graceful Degradation (BEST PRACTICE)

**Check that app works without Langfuse:**
```python
# ✅ CORRECT - Returns None if not configured
def get_langfuse_client():
    global _langfuse_client, _langfuse_enabled

    if _langfuse_enabled is not None:
        return _langfuse_client if _langfuse_enabled else None

    public_key = os.getenv("LANGFUSE_PUBLIC_KEY")
    secret_key = os.getenv("LANGFUSE_SECRET_KEY")

    if not public_key or not secret_key:
        _langfuse_enabled = False
        logger.info("Langfuse not configured")
        return None  # ✅ App continues without observability

    try:
        _langfuse_client = Langfuse(public_key=public_key, secret_key=secret_key)
        _langfuse_enabled = True
        return _langfuse_client
    except Exception as e:
        _langfuse_enabled = False
        logger.warning(f"Failed to initialize Langfuse: {e}")
        return None  # ✅ App continues despite failure
```

**Pattern:**
1. Return `None` if Langfuse unavailable
2. Check for `None` before all operations
3. Log warnings (not errors) for observability failures
4. Never let Langfuse failure break the application

## Verification Checklist

- [ ] **Executor shutdown**: `join_background_flushes()` called in lifespan shutdown
- [ ] **Shutdown state check**: `_flush_executor._shutdown` checked before submit
- [ ] **Logging levels**: Failures use `logger.warning()` not `logger.debug()`
- [ ] **Worker count**: `max_workers >= 3` for production (or justified if =1)
- [ ] **Timeout protection**: `client.flush()` has 10-second timeout wrapper
- [ ] **Graceful degradation**: App works if Langfuse is down
- [ ] **No blocking flushes**: All flushes are background (non-blocking)
- [ ] **Singleton pattern**: Single client instance, not recreated per request
- [ ] **Environment-specific**: Different configs for dev/staging/prod

## Example: Complete Implementation

```python
# langfuse_tracer.py
import logging
import os
import threading
from concurrent.futures import ThreadPoolExecutor

from langfuse import Langfuse

logger = logging.getLogger(__name__)

MAX_AUDIO_SIZE_BYTES = 10 * 1024 * 1024  # 10MB

_langfuse_client = None
_langfuse_enabled = None
_flush_executor = None


def get_langfuse_client():
    """Get or create Langfuse client singleton. Returns None if not configured."""
    global _langfuse_client, _langfuse_enabled, _flush_executor

    if _langfuse_enabled is not None:
        return _langfuse_client if _langfuse_enabled else None

    public_key = os.getenv("LANGFUSE_PUBLIC_KEY")
    secret_key = os.getenv("LANGFUSE_SECRET_KEY")

    if not public_key or not secret_key:
        _langfuse_enabled = False
        logger.info("Langfuse not configured")
        return None

    try:
        _langfuse_client = Langfuse(
            public_key=public_key,
            secret_key=secret_key,
            host=os.getenv("LANGFUSE_HOST", "https://cloud.langfuse.com"),
        )
        _langfuse_enabled = True
        # 3 workers for production throughput
        _flush_executor = ThreadPoolExecutor(
            max_workers=3, thread_name_prefix="langfuse_flush"
        )
        logger.info("Langfuse client initialized")
        return _langfuse_client
    except Exception as e:
        _langfuse_enabled = False
        logger.warning(f"Failed to initialize Langfuse: {e}")
        return None


def flush_in_background():
    """Flush Langfuse traces in background thread."""
    client = get_langfuse_client()
    if client is None:
        return

    global _flush_executor
    if _flush_executor is None:
        return

    # Check if executor is shutting down
    if getattr(_flush_executor, "_shutdown", False):
        return

    def do_flush():
        import threading

        flush_error = [None]
        flush_complete = threading.Event()

        def flush_worker():
            try:
                client.flush()
            except Exception as e:
                flush_error[0] = e
            finally:
                flush_complete.set()

        flush_thread = threading.Thread(target=flush_worker, daemon=True)
        flush_thread.start()

        if not flush_complete.wait(timeout=10):
            logger.warning("Langfuse flush timeout after 10 seconds")
            return

        if flush_error[0] is not None:
            logger.warning(f"Background flush failed: {flush_error[0]}")

    try:
        _flush_executor.submit(do_flush)
    except RuntimeError:
        logger.debug("Flush executor shut down, skipping trace flush")


def join_background_flushes(timeout: float = 5.0):
    """Wait for pending background flushes to complete."""
    global _flush_executor

    if _flush_executor is not None:
        try:
            _flush_executor.shutdown(wait=True, timeout=timeout)
        except Exception as e:
            logger.warning(f"Failed to shutdown flush executor: {e}")
        _flush_executor = None


# main.py
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    langfuse = get_langfuse_client()
    if langfuse:
        try:
            langfuse.auth_check()
            logger.info("✅ Langfuse connected")
        except Exception as e:
            logger.warning(f"⚠️ Langfuse auth failed: {e}")

    yield

    # Shutdown
    if langfuse:
        logger.info("Flushing Langfuse traces...")
        langfuse.flush()
        join_background_flushes(timeout=5.0)  # ← CRITICAL
        logger.info("Langfuse shutdown complete")
```

## Common Pitfalls

### 1. **Forgetting to join background flushes**
```python
# ❌ WRONG
langfuse.flush()  # Doesn't wait for background threads

# ✅ CORRECT
langfuse.flush()
join_background_flushes(timeout=5.0)  # Wait for background threads
```

### 2. **Blocking user response with flush**
```python
# ❌ WRONG - Blocks user response
audio_path = generate_audio(...)
flush_blocking(timeout=10)  # User waits!
return {"audio_url": audio_path}

# ✅ CORRECT - Non-blocking
audio_path = generate_audio(...)
flush_in_background()  # Background thread
return {"audio_url": audio_path}  # Immediate response
```

### 3. **Creating multiple clients**
```python
# ❌ WRONG - New client per request
def handle_request():
    client = Langfuse(public_key=..., secret_key=...)  # Connection leak!
    client.flush()

# ✅ CORRECT - Singleton client
client = get_langfuse_client()  # Reused across requests
```

### 4. **Silent failures at DEBUG level**
```python
# ❌ WRONG - Invisible in production
logger.debug(f"Trace update failed: {e}")

# ✅ CORRECT - Visible in production
logger.warning(f"Trace update failed: {e}")
```

## Notes

### Thread Safety
- Langfuse Python SDK is thread-safe for flush operations
- Multiple threads can call `flush()` concurrently
- Use `langfuse_parent_trace_id` to maintain trace context across threads (see [Observability with concurrent threads](https://github.com/orgs/langfuse/discussions/4438))

### Known Issues
- **Daemon threads cannot be cleaned up**: Langfuse SDK creates daemon threads that cannot be stopped through any API (see [issue #4163](https://github.com/langfuse/langfuse/issues/4163))
- **Flush hangs in serverless**: `langfuse.flush()` can hang indefinitely in Google Cloud Functions and similar environments (see [issue #11104](https://github.com/langfuse/langfuse/issues/11104))
- **Workaround**: Use timeout protection (shown above) or implement deadline-based cancellation

### Performance Impact
- **Memory**: Each worker thread ~1-2MB stack size
- **Network**: Flush payload ~1-10KB per trace (depends on metadata)
- **CPU**: Minimal (JSON serialization + HTTP POST)
- **Recommendation**: 3 workers adds ~3-6MB memory, negligible for most services

### Environment Management
Use Langfuse's built-in Environments feature for multi-stage deployments:
- **Development**: Separate traces from production
- **Staging**: Pre-production testing environment
- **Production**: Live production traces
- Set via `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` per environment

## References

- [Langfuse Python SDK Documentation](https://langfuse.com/docs/observability/sdk/overview)
- [Langfuse Advanced Features](https://langfuse.com/docs/observability/sdk/advanced-features)
- [Langfuse Python Decorators](https://langfuse.com/docs/sdk/python/decorators)
- [Managing Different Environments in Langfuse](https://langfuse.com/faq/all/managing-different-environments)
- [Help with flushing behavior (Discussion #5093)](https://github.com/orgs/langfuse/discussions/5093)
- [Observability with concurrent threads (Discussion #4438)](https://github.com/orgs/langfuse/discussions/4438)
- [Regarding Traces Being Flushed (Discussion #5331)](https://github.com/orgs/langfuse/discussions/5331)
- [Prompt cache thread not reliably exited (Issue #4163)](https://github.com/langfuse/langfuse/issues/4163)
- [flush() hangs indefinitely in Google Cloud (Issue #11104)](https://github.com/langfuse/langfuse/issues/11104)
