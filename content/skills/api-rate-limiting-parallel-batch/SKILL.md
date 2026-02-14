---
name: api-rate-limiting-parallel-batch
description: |
  Manage API rate limits when running parallel batch processing jobs.
  Use when: (1) Getting HTTP 429 "Too Many Requests" errors, (2) API returns
  "High concurrency usage" or rate limit messages, (3) Need to process large
  batches with rate-limited APIs (LLM, REST, GraphQL). Covers batch size
  tuning, worker limits, staggered launches, and continuous monitoring.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# API Rate Limiting for Parallel Batch Processing

## Problem
When processing large datasets with parallel API calls, you hit rate limits (HTTP 429 errors, "High concurrency" messages) even though you're within documented limits. Large parallel batches overwhelm the API's rate limiter.

## Context / Trigger Conditions
- HTTP 429 "Too Many Requests" errors during batch processing
- Error message: "High concurrency usage of this API, please reduce concurrency"
- Using ThreadPoolExecutor, multiprocessing, or subprocess for parallel API calls
- Working with rate-limited LLM APIs (OpenAI, Anthropic, Zhipu, etc.)
- Processing thousands of records through REST/GraphQL APIs

## Solution

### 1. Reduce Batch Size
**Problem**: Large batches (50-100) hit API rate limits immediately
**Fix**: Use smaller batches (10-20) for rate-limited APIs

```python
# Wrong: Too large for rate-limited API
batch_size = 100

# Correct: Smaller batches avoid burst traffic
batch_size = 10
```

**Rationale**: Smaller batches spread requests over time, preventing burst traffic that triggers rate limiters. [Celigo recommends 50-100 for high-latency APIs](https://www.celigo.com/blog/concurrency-best-practices-for-large-data-volumes/).

### 2. Stagger Job Launches
**Problem**: Launching 50 parallel processes simultaneously creates request spikes
**Fix**: Add delays between job launches

```python
# Wrong: All jobs start immediately
for i in range(50):
    subprocess.Popen(cmd)

# Correct: Stagger launches to smooth traffic
for i in range(50):
    subprocess.Popen(cmd)
    time.sleep(0.5)  # 500ms delay between launches
```

**Rationale**: Staggering prevents "thundering herd" problem. Requests are spread over time rather than hitting all at once.

### 3. Monitor Active Process Count
**Problem**: Don't know when to launch more jobs
**Fix**: Check active processes and launch when count drops

```python
import subprocess

def count_active_jobs():
    """Count running processes by name"""
    result = subprocess.run(
        ["ps", "aux"],
        capture_output=True,
        text=True
    )
    return result.stdout.count("process_name_pattern")

def launch_when_needed(threshold=20):
    """Launch new jobs when active count drops below threshold"""
    active = count_active_jobs()
    if active < threshold:
        # Launch new batch
        launch_batch_jobs()
```

**Pattern**:
- Check active job count every 1-2 minutes
- Launch new batch when count drops below threshold
- Keep steady flow instead of bursts

### 4. Use Exponential Backoff for Retries
**Problem**: Immediate retries after 429 just trigger more rate limits
**Fix**: Implement exponential backoff

```python
import time

def api_call_with_retry(func, max_retries=3):
    """API call with exponential backoff"""
    for attempt in range(max_retries):
        try:
            return func()
        except RateLimitError as e:
            if attempt == max_retries - 1:
                raise
            wait_time = 2 ** attempt  # 1s, 2s, 4s
            time.sleep(wait_time)
```

### 5. Detach Long-Running Processes
**Problem**: Subprocesses block parent or get killed when parent exits
**Fix**: Use `start_new_session=True` to detach

```python
# Wrong: Process tied to parent
subprocess.Popen(cmd)

# Correct: Process runs independently
subprocess.Popen(
    cmd,
    start_new_session=True,  # Detach from parent process group
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
```

**Rationale**: Detached processes continue running even if parent script exits, enabling truly continuous batch processing.

### 6. Redirect Output to Avoid Clutter
**Problem**: Hundreds of processes spam terminal with logs
**Fix**: Redirect stdout/stderr

```python
with open('/tmp/job.log', 'a') as f:
    subprocess.Popen(
        cmd,
        stdout=f,
        stderr=subprocess.STDOUT,  # Combine stderr into stdout
    )
```

## Recommended Settings by API Type

| API Type | Batch Size | Max Workers | Throttle Delay |
|----------|-----------|-------------|----------------|
| Rate-limited LLM APIs | 10 | 5-10 | 0.5-1s |
| High-latency APIs | 50-100 | 2-3 | 1s |
| Low-latency, high-capacity | 1000+ | 5-10 | 0s |
| Strict rate limits | 5 | 2-5 | 1-2s |

*Source: Adapted from [Celigo's concurrency best practices](https://www.celigo.com/blog/concurrency-best-practices-for-large-data-volumes/)*

## Verification

After implementing these changes:

1. **Monitor error logs**: 429 errors should decrease significantly
2. **Check throughput**: Total processing should be 3-5x faster than sequential (though slower than naive parallel)
3. **Verify API compliance**: No warnings from API provider about rate limits

## Example: Continuous Batch Processing System

```python
#!/usr/bin/env python3
"""Auto-launcher - keeps generation jobs running until target time"""
import subprocess
import time
from pathlib import Path

def count_active_jobs():
    result = subprocess.run(["ps", "aux"], capture_output=True, text=True)
    return result.stdout.count("uv run python main.py generate")

def launch_batch(size=10):
    """Launch batch with staggered delays"""
    for job_type in JOB_TYPES:
        subprocess.Popen([
            "uv", "run", "python", "main.py", "generate",
            "--count", str(size),
            "--type", job_type,
        ],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        )
        time.sleep(0.5)  # Stagger launches

def main():
    while not is_past_target_time():
        active = count_active_jobs()
        print(f"Active jobs: {active}")

        # Launch more when count drops
        if active < 20:
            launch_batch(size=10)

        time.sleep(120)  # Check every 2 minutes
```

**File**: `/tmp/auto_launcher.py` - Working example that runs until 6 AM

## Notes

### Why Smaller Batches Work Better
- **Prevents burst traffic**: Large batches send 100+ requests simultaneously
- **Spreads load**: Smaller batches distribute requests over time
- **Natural rate limiting**: Processing time between batches acts as throttle

### Parallel vs Sequential Performance
According to [Medium analysis](https://medium.com/@avinash.narala6814/api-calls-with-parallel-processing-scaling-api-performance-without-breaking-rate-limits-c72e206da3a2):
- Sequential: 1x speed (reference baseline)
- Naive parallel: 5x speed but hits rate limits
- **Managed parallel**: 3-4x speed while respecting limits ← **Target this**

### Dynamic Scaling
For production systems, consider:
- Monitor API response times
- Reduce concurrency when response times increase
- Increase concurrency during off-peak hours
- Use AI-powered optimization when available ([Celigo feature](https://www.celigo.com/blog/concurrency-best-practices-for-large-data-volumes/))

## References

- [Celigo - Concurrency Best Practices for Large Data Volumes (Feb 2025)](https://www.celigo.com/blog/concurrency-best-practices-for-large-data-volumes/) - Comprehensive guide on concurrency management, throttling strategies, and recommended settings for different API types
- [Medium - API Calls with Parallel Processing (Sep 2025)](https://medium.com/@avinash.narala6814/api-calls-with-parallel-processing-scaling-api-performance-without-breaking-rate-limits-c72e206da3a2) - ThreadPoolExecutor pattern for parallel API calls with 5x speedup
- [Gcore - API Rate Limiting Guide (Nov 2025)](https://gcore.com/learning/api-rate-limiting) - Rate limiting algorithms and implementation patterns
- [Merge.dev - 7 API Rate Limit Best Practices](https://www.merge.dev/blog/api-rate-limit-best-practices) - Tracking usage, exponential backoff, webhook alternatives
