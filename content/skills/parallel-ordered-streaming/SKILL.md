---
name: parallel-ordered-streaming
description: |
  Process multiple work items in parallel using ThreadPoolExecutor while streaming
  results in strict sequential order. Use when: (1) processing is slow and would benefit
  from parallelization, (2) results must be delivered in order (not completion order),
  (3) you want to stream results as they become available rather than waiting for all
  to complete. Applies to TTS, video processing, batch API calls, file processing, and
  any embarrassingly parallel work with ordering requirements.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Parallel Processing with Ordered Streaming

## Problem

You need to process multiple items in parallel to speed up computation, but results must be delivered in strict sequential order (not the order they complete). Naive parallel processing returns results as they finish, which breaks ordering.

## Context / Trigger Conditions

Use this pattern when:
- **Embarrassingly parallel workload**: Each item can be processed independently
- **Slow processing**: Each item takes significant time (seconds to minutes)
- **Ordered output required**: Results must be delivered/indexed in input order
- **Streaming desired**: Want to yield results as available, not wait for all to complete
- **Memory considerations**: Can't buffer all results before yielding

**Examples**:
- TTS: Process text chunks in parallel, but stream audio in order
- Video: Encode video segments in parallel, deliver frames sequentially
- Batch API: Make parallel API calls, but process responses in order
- File processing: Process multiple files in parallel, output in filename order

## Solution

Use `ThreadPoolExecutor` with a "pending results" dictionary and a counter to track expected index:

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

def process_item(item_idx, item):
    """Worker function - process a single item"""
    result = do_expensive_processing(item)
    return (item_idx, result)

# Process items in parallel, yield in order
pending_results = {}  # item_idx -> result
next_expected_idx = 0

with ThreadPoolExecutor(max_workers=4) as executor:
    # Submit all items for parallel processing
    futures = {
        executor.submit(process_item, idx, item): idx
        for idx, item in enumerate(items)
    }

    # Process completed items as they finish
    for future in as_completed(futures):
        item_idx, result = future.result()

        # Store result
        pending_results[item_idx] = result

        # Yield any available results in order
        while next_expected_idx in pending_results:
            result = pending_results.pop(next_expected_idx)
            yield result  # or yield (next_expected_idx, result)
            next_expected_idx += 1
```

**Key Components**:

1. **Worker function**: Returns `(index, result)` tuple to track ordering
2. **`pending_results` dict**: Stores completed results until their turn
3. **`next_expected_idx` counter**: Tracks which index should be yielded next
4. **`as_completed()`**: Processes futures as they finish (not in submission order)
5. **Yield loop**: Emits results in order once consecutive indices are available

## Verification

**Test with varying completion times**:
```python
import time
import random

def slow_process(idx):
    time.sleep(random.uniform(0.1, 0.5))  # Random completion time
    return idx

# Use the pattern
results = []
for idx in parallel_ordered(slow_process, range(10)):
    results.append(idx)
    print(f"Got: {idx}")

assert results == list(range(10))  # Should be [0, 1, 2, ..., 9]
```

**Expected behavior**:
- Results arrive out-of-order internally (due to random completion times)
- But are yielded in strict sequential order
- Shorter waits for early items even if later items complete first

## Example: TTS with Text Splitting

Processing text chunks in parallel while streaming audio in order:

```python
def process_text_chunk(text_chunk_idx, text_chunk, model, audio_prompt):
    """Generate streaming audio for one text chunk"""
    audio_tokens = []
    for audio_tensor, metadata in model.generate_stream(
        text=text_chunk,
        audio_prompt_path=audio_prompt,
    ):
        audio_tokens.append((audio_tensor, metadata))
    return (text_chunk_idx, audio_tokens)

# Split text into chunks
text_chunks = normalize_text(long_text)

# Process in parallel, stream in order
pending_chunks = {}
next_expected_idx = 0

with ThreadPoolExecutor(max_workers=4) as executor:
    futures = {
        executor.submit(process_text_chunk, idx, chunk, model, prompt): idx
        for idx, chunk in enumerate(text_chunks)
    }

    for future in as_completed(futures):
        chunk_idx, audio_tokens = future.result()
        pending_chunks[chunk_idx] = audio_tokens

        # Yield audio tokens in order
        while next_expected_idx in pending_chunks:
            for audio_tensor, metadata in pending_chunks.pop(next_expected_idx):
                yield audio_tensor, metadata
            next_expected_idx += 1
```

## Variations

**With timeout**:
```python
for future in as_completed(futures, timeout=300):  # 5 minute timeout
    item_idx, result = future.result(timeout=10)  # Per-item timeout
    # ... rest of pattern
```

**With error handling**:
```python
for future in as_completed(futures):
    try:
        item_idx, result = future.result()
        pending_results[item_idx] = result
    except Exception as e:
        pending_results[item_idx] = None  # Mark as failed
        logger.error(f"Item {item_idx} failed: {e}")
```

**Bounded buffer** (limit memory):
```python
MAX_BUFFER_SIZE = 100
while next_expected_idx in pending_results:
    if len(pending_results) > MAX_BUFFER_SIZE:
        logger.warning("Buffer full, waiting...")
        time.sleep(0.1)
        continue
    result = pending_results.pop(next_expected_idx)
    yield result
    next_expected_idx += 1
```

## Notes

**When to use this pattern**:
- Processing time per item > 100ms (parallel overhead is worth it)
- Number of items > number of workers (enough work to parallelize)
- Ordered output is a hard requirement
- Streaming/yielding is better than waiting for all results

**When NOT to use**:
- Small number of items (< workers): Overhead not worth it
- Very fast processing (< 10ms per item): Thread creation overhead dominates
- Order doesn't matter: Use `as_completed()` directly without pending dict
- Can buffer all results: Use `executor.map()` or list comprehension

**Thread safety**:
- The pattern is thread-safe because:
  - Each worker writes to a unique dict key (item_idx)
  - Main thread is only reader/writer of `pending_results`
  - No shared mutable state between workers

**Memory considerations**:
- Worst case: All items complete before yielding (if last item finishes first)
- Buffer size = number of pending completed items
- For very large workloads, add bounded buffer or reduce worker count

**Alternatives**:
- **AsyncIO**: Use `asyncio.gather()` + `asyncio.Queue()` for I/O-bound work
- **Multiprocessing**: Use `ProcessPoolExecutor` for CPU-bound work (same pattern)
- **Ray/Dask**: For distributed computing, use these frameworks instead

**Performance tuning**:
- Worker count = `min(CPU_COUNT * 2, item_count)` for I/O-bound
- Worker count = `CPU_COUNT` for CPU-bound
- Monitor buffer size: if growing large, reduce workers
- Profile: if workers often idle, reduce workers; if queue builds, increase

## Common Pitfalls

**Pitfall 1**: Forgetting to increment `next_expected_idx`
- **Symptom**: Infinite loop yielding same result
- **Fix**: Always increment in the yield loop

**Pitfall 2**: Worker function returns only result (no index)
- **Symptom**: Can't match results to input order
- **Fix**: Return `(index, result)` tuple from worker

**Pitfall 3**: Using `executor.map()` instead of futures
- **Symptom**: Loses parallelism (blocks on each item in order)
- **Fix**: Use `executor.submit()` + `as_completed()` for true parallelism

**Pitfall 4**: Not handling exceptions in workers
- **Symptom**: One failed worker hangs entire process
- **Fix**: Wrap `future.result()` in try/except or use `future.exception()`

## References

- [Python concurrent.futures documentation](https://docs.python.org/3/library/concurrent.futures.html)
- [ThreadPoolExecutor Best Practices](https://docs.python.org/3/library/concurrent.futures.html#threadpoolexecutor)
- [as_completed() vs map()](https://stackoverflow.com/questions/52086700/what-is-the-difference-between-concurrent-futures-as-completed-and-executor)
