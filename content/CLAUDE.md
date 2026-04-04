# CLAUDE.md — Global Operating Instructions

This file defines **how Claude should work by default** across tasks.
If a direct user instruction conflicts with this file, follow this order:

1. System rules
2. Direct user instruction
3. This CLAUDE.md

---

## 1) Primary Mission

- Execute the user's requested goal exactly.
- Stay within the user's constraints (stack, architecture, infra, scale, parameters).
- Do not downgrade scope, change approach, or "simplify" unless the user explicitly asks.
- Maintain momentum: if blocked, identify the blocker and ask one focused unblock question.

---

## 1.5) Mandatory Plan-First Protocol (No Missing Steps)

Before taking action, always create an explicit task plan/checklist.

Requirements:

1. List all major steps before implementation.
2. Map each applicable instruction in this file to at least one checklist item.
3. Ensure no instruction-relevant work is left out.
4. Mark progress as you execute (`[ ]` -> `[x]`).
5. Before final output, run a final checklist pass to confirm nothing is missing.

If any instruction point is not represented in the plan, revise the plan first, then execute.

---

## 2) Non-Negotiable Implementation Rules

1. **No fake implementations**
   - Never use mocks, placeholders, stub logic, TODO behavior, or fabricated API responses.
   - Never use mock data unless the user explicitly asks for it.

2. **No silent failure**
   - Never swallow exceptions (`except: pass`).
   - Always surface full error context with traceback (`logging.exception(...)` or equivalent).

3. **Real execution over paper correctness**
   - Validate by actually running code when feasible.
   - If execution is blocked, state exactly why.

4. **No repeated dead-end loops**
   - Do not keep retrying the same failed approach without a new hypothesis.
   - Use evidence-driven debugging.

---

## 3) Missing Information Protocol

When details are missing:

- State exactly what is missing.
- Explain why it blocks a real implementation.
- Ask the **minimum single question** needed to proceed.

Preferred failure mode:

> "I cannot implement this yet because [specific missing detail]."

Never fake behavior to hide missing inputs.

---

## 4) Persistence & Problem-Solving Standard

- Treat obstacles as solvable engineering problems.
- Investigate root cause, not just symptoms.
- Use a disciplined loop: observe -> hypothesize -> test -> analyze -> iterate.
- Never suggest quitting or abandoning the goal.
- Only propose alternatives/workarounds if the user explicitly requests alternatives.

---

## 5) Planning Before Coding

Before editing:

- Confirm architecture assumptions are explicit.
- Mentally trace runtime flow end-to-end.
- Check imports, dependency compatibility, failure points, and environment constraints.
- Choose the smallest set of changes that solves the real problem.

If a key design decision is ambiguous, pause and ask one focused question.

---

## 6) Code Quality Standards

### 6.1 Linting (Required)

- Run `ruff check` before considering Python code complete.
- Fix all errors and warnings relevant to changed code.
- Treat lint failures as blocking.

### 6.2 Logging (Required)

- Use `logging`, not `print`, for persistent runtime output.
- Use appropriate levels: DEBUG / INFO / WARNING / ERROR / CRITICAL.
- Include exception context with traceback for failures.

Minimal baseline:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)
```

### 6.3 Data/DB Preference

- Prefer PostgreSQL over SQLite unless the user requests otherwise.

  ### 6.4 Style Preference

- Prefer functional patterns when practical and readable.

### 6.5 Python Execution Standard (Strict - Non-Negotiable)

**NEVER execute Python code inline.** All Python code must be written to physical script files.

#### Required Behavior:

1. **No Inline Execution**
   - Do NOT use Jupyter notebook cells for production code
   - Do NOT use `python -c "..."` commands
   - Do NOT execute Python code snippets in any REPL or inline context
   - Do NOT suggest or demonstrate inline execution patterns

2. **Always Write Physical Scripts**
   - All Python code MUST be written to `.py` files
   - Scripts must be complete, runnable, and standalone
   - Include proper imports, logging setup, error handling
   - Use meaningful filenames that reflect their purpose

3. **Experimentation Protocol (tmp.py Pattern)**
   - When exploring ideas or testing code, create `tmp.py` in the working directory
   - Use `tmp.py` for playaround, prototyping, and experimentation
   - Test, iterate, and refine code in `tmp.py`
   - Once code is finalized, move it to the appropriate final script file
   - **Remove `tmp.py` after finalization** (add to .gitignore if needed)

4. **File Management**
   - Production code belongs in properly named, versioned files
   - `tmp.py` is explicitly for temporary exploration only
   - Never commit `tmp.py` to version control
   - Always clean up temporary files before finalizing work

5. **Execution Pattern**
   ```bash
   # CORRECT:
   # Write to script_file.py first
   python script_file.py

   # WRONG:
   # python -c "print('hello')"  # NEVER do this
   ```

6. **Verification**
   - Always verify code by running the physical script file
   - Check script output, errors, and behavior
   - Ensure scripts can be reproduced by running the file

**Rationale**: Physical scripts ensure traceability, reproducibility, proper error handling, logging, and maintainability. Inline execution makes debugging, version control, and long-term maintenance impossible.

---

## 6.6 Data Persistence & Resumability (Strict - Non-Negotiable)

**NEVER store results in memory when working with large datasets or long-running processes.** Always write results directly to physical files incrementally. Code MUST be resumable and continuable.

#### Core Principles:

1. **Write Directly to Files**
   - Do NOT accumulate results in memory lists/dictionaries/arrays
   - Do NOT process entire datasets before writing output
   - Write each result immediately after processing to ensure persistence
   - Use atomic writes or append mode to prevent data loss

2. **Resumable & Continuable**
   - Code can be stopped at any time and restarted
   - Already-processed items are automatically skipped
   - Progress state is preserved across runs
   - No manual intervention needed for continuation

3. **Structured Checkpointing**
   - Maintain separate checkpoint files for state management
   - Store processing metadata (timestamps, counts, status)
   - Enable easy inspection of progress state
   - Support rollback if needed

---

### Pattern 1: Simple Line-Based Output (Basic Resumability)

Use for simple text-based outputs where each line is independent.

```python
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

output_file = "results.txt"

def process_simple_dataset(items):
    """
    Process items with simple line-based output.
    Resumable: checks output file for existing lines.
    """
    # Load already processed item IDs
    processed_ids = set()
    if os.path.exists(output_file):
        with open(output_file, "r") as f:
            for line in f:
                # Assumes format: "item_id\tresult"
                if line.strip():
                    item_id = line.split("\t")[0]
                    processed_ids.add(item_id)
    
    logger.info(f"Found {len(processed_ids)} already processed items")
    
    # Process only unprocessed items
    with open(output_file, "a") as f:
        for item_id, data in items:
            if item_id in processed_ids:
                logger.info(f"Skipping {item_id} - already processed")
                continue
            
            try:
                result = process_item(data)
                f.write(f"{item_id}\t{result}\n")
                f.flush()  # Ensure immediate write
                processed_ids.add(item_id)
                logger.info(f"Processed {item_id}")
            except Exception as e:
                logger.error(f"Failed to process {item_id}: {e}")
                # Continue with next item - data is already safe
```

---

### Pattern 2: Structured JSON Output (Full State Tracking)

Use for complex outputs requiring rich metadata and precise progress tracking.

```python
import json
import os
from datetime import datetime

output_file = "results.jsonl"
checkpoint_file = "checkpoint.json"

def process_structured_dataset(items):
    """
    Process items with JSON output and comprehensive checkpointing.
    Fully resumable and continuable with rich state tracking.
    """
    # Load checkpoint if exists
    checkpoint = {
        "start_time": datetime.now().isoformat(),
        "processed_ids": [],
        "failed_ids": [],
        "total_count": 0,
        "success_count": 0,
        "error_count": 0,
        "last_processed_id": None,
    }
    
    if os.path.exists(checkpoint_file):
        with open(checkpoint_file, "r") as f:
            checkpoint = json.load(f)
        logger.info(f"Resuming from checkpoint: {len(checkpoint['processed_ids'])} items done")
    
    processed_ids = set(checkpoint["processed_ids"])
    
    # Process only unprocessed items
    with open(output_file, "a") as out_f:
        for item_id, data in items:
            if item_id in processed_ids:
                logger.debug(f"Skipping {item_id} - already processed")
                continue
            
            try:
                result = process_item(data)
                
                # Write result immediately
                output_entry = {
                    "item_id": item_id,
                    "result": result,
                    "timestamp": datetime.now().isoformat(),
                    "status": "success"
                }
                out_f.write(json.dumps(output_entry) + "\n")
                out_f.flush()
                
                # Update checkpoint
                checkpoint["processed_ids"].append(item_id)
                checkpoint["success_count"] += 1
                checkpoint["last_processed_id"] = item_id
                
                # Save checkpoint periodically
                if checkpoint["success_count"] % 10 == 0:
                    save_checkpoint(checkpoint, checkpoint_file)
                    logger.info(f"Progress: {checkpoint['success_count']} items completed")
                
                logger.info(f"Processed {item_id}")
                
            except Exception as e:
                logger.error(f"Failed to process {item_id}: {e}")
                checkpoint["failed_ids"].append({
                    "item_id": item_id,
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                })
                checkpoint["error_count"] += 1
    
    # Final checkpoint save
    checkpoint["end_time"] = datetime.now().isoformat()
    checkpoint["total_count"] = len(items)
    save_checkpoint(checkpoint, checkpoint_file)
    logger.info(f"Completed: {checkpoint['success_count']} success, {checkpoint['error_count']} failed")

def save_checkpoint(checkpoint, filepath):
    """Atomically save checkpoint file."""
    temp_path = f"{filepath}.tmp"
    with open(temp_path, "w") as f:
        json.dump(checkpoint, f, indent=2)
    os.rename(temp_path, filepath)
```

---

### Pattern 3: Multi-Stage Pipeline with State Management

Use for complex workflows with multiple processing stages.

```python
import json
import os
from pathlib import Path

class PipelineState:
    """
    Manage state for multi-stage resumable pipelines.
    Each stage can be resumed independently.
    """
    
    def __init__(self, state_file="pipeline_state.json"):
        self.state_file = state_file
        self.state = self._load_state()
    
    def _load_state(self):
        """Load existing state or create new."""
        if os.path.exists(self.state_file):
            with open(self.state_file, "r") as f:
                return json.load(f)
        
        return {
            "stages": {
                "stage1": {"completed": [], "failed": []},
                "stage2": {"completed": [], "failed": []},
                "stage3": {"completed": [], "failed": []},
            },
            "global_status": "initialized"
        }
    
    def save_state(self):
        """Atomically save current state."""
        temp_path = f"{self.state_file}.tmp"
        with open(temp_path, "w") as f:
            json.dump(self.state, f, indent=2)
        os.rename(temp_path, self.state_file)
    
    def is_completed(self, stage, item_id):
        """Check if item completed in given stage."""
        return item_id in self.state["stages"][stage]["completed"]
    
    def mark_completed(self, stage, item_id):
        """Mark item as completed in stage."""
        self.state["stages"][stage]["completed"].append(item_id)
        self.save_state()
    
    def mark_failed(self, stage, item_id, error):
        """Mark item as failed in stage."""
        self.state["stages"][stage]["failed"].append({
            "item_id": item_id,
            "error": error,
            "timestamp": datetime.now().isoformat()
        })
        self.save_state()

def run_resumable_pipeline(items):
    """
    Multi-stage pipeline with full resumability.
    Each stage can be resumed independently.
    """
    state = PipelineState()
    
    for item_id, data in items:
        # Stage 1: Data preprocessing
        if not state.is_completed("stage1", item_id):
            try:
                preprocessed = preprocess(data)
                save_stage_output("stage1_output.jsonl", item_id, preprocessed)
                state.mark_completed("stage1", item_id)
                logger.info(f"Stage 1 completed for {item_id}")
            except Exception as e:
                state.mark_failed("stage1", item_id, str(e))
                logger.error(f"Stage 1 failed for {item_id}: {e}")
                continue
        
        # Stage 2: Processing (only runs if stage1 succeeded)
        if not state.is_completed("stage2", item_id):
            try:
                processed = process(preprocessed)
                save_stage_output("stage2_output.jsonl", item_id, processed)
                state.mark_completed("stage2", item_id)
                logger.info(f"Stage 2 completed for {item_id}")
            except Exception as e:
                state.mark_failed("stage2", item_id, str(e))
                logger.error(f"Stage 2 failed for {item_id}: {e}")
                continue
        
        # Stage 3: Post-processing
        if not state.is_completed("stage3", item_id):
            try:
                final = postprocess(processed)
                save_stage_output("stage3_output.jsonl", item_id, final)
                state.mark_completed("stage3", item_id)
                logger.info(f"Stage 3 completed for {item_id}")
            except Exception as e:
                state.mark_failed("stage3", item_id, str(e))
                logger.error(f"Stage 3 failed for {item_id}: {e}")
    
    logger.info("Pipeline completed - check pipeline_state.json for details")
```

---

### Pattern 4: Batch Processing with Progress Reporting

Use for large batches where progress visibility is critical.

```python
import time

def process_large_batch(items, output_file="batch_results.jsonl"):
    """
    Batch processing with progress reporting and resumability.
    """
    checkpoint_file = f"{output_file}.checkpoint"
    
    # Load checkpoint
    checkpoint = load_checkpoint(checkpoint_file)
    processed_ids = set(checkpoint["processed_ids"])
    
    total_items = len(items)
    start_time = checkpoint.get("start_time", time.time())
    last_log_time = time.time()
    
    with open(output_file, "a") as f:
        for idx, (item_id, data) in enumerate(items, 1):
            if item_id in processed_ids:
                continue
            
            try:
                result = process_item(data)
                f.write(json.dumps({"id": item_id, "result": result}) + "\n")
                f.flush()
                
                processed_ids.add(item_id)
                
                # Update checkpoint periodically
                checkpoint["processed_ids"] = list(processed_ids)
                checkpoint["last_processed"] = item_id
                
                # Log progress every 10 items or every 60 seconds
                current_time = time.time()
                if idx % 10 == 0 or (current_time - last_log_time) > 60:
                    progress_pct = (len(processed_ids) / total_items) * 100
                    elapsed = current_time - start_time
                    rate = len(processed_ids) / elapsed if elapsed > 0 else 0
                    eta = (total_items - len(processed_ids)) / rate if rate > 0 else 0
                    
                    logger.info(
                        f"Progress: {len(processed_ids)}/{total_items} "
                        f"({progress_pct:.1f}%) | "
                        f"Rate: {rate:.2f} items/sec | "
                        f"ETA: {eta/60:.1f} min"
                    )
                    save_checkpoint(checkpoint, checkpoint_file)
                    last_log_time = current_time
                
            except Exception as e:
                logger.error(f"Error processing {item_id}: {e}")
                continue
    
    # Final summary
    elapsed = time.time() - start_time
    logger.info(
        f"Batch complete: {len(processed_ids)}/{total_items} items "
        f"in {elapsed/60:.1f} minutes"
    )
    save_checkpoint(checkpoint, checkpoint_file)
```

---

### Best Practices Summary

1. **Always write incrementally**: Never accumulate in memory
2. **Use atomic writes**: Write to temp file, then rename
3. **Maintain checkpoints**: Track what's been done
4. **Log progress**: Regular updates on processing status
5. **Handle failures gracefully**: Continue processing next item
6. **Enable resumption**: Check existing state before processing
7. **Flush frequently**: Ensure data is written to disk
8. **Structure output**: Use JSON/JSONL for rich metadata
9. **Save state often**: Update checkpoint files periodically
10. **Provide summaries**: Include timing, counts, and status in logs

**Rationale**: These patterns ensure data is never lost, processes can be stopped and resumed without manual intervention, progress is transparent, and failures don't require restarting from the beginning. This is critical for large-scale data processing and long-running tasks.

---

## 7) File Change Discipline

Default behavior: **edit existing files**.

Create new files only when:

- Introducing truly new functionality,
- The structure clearly requires a new module,
- Or the user explicitly asks for a new file.

Avoid:

- `*_v2`, `*_new`, `*_fixed`, `backup_*`, and duplicate variant files.
- Creating a new script file for each iteration instead of updating the existing script.

Guidelines:

- Make minimal, targeted edits.
- Preserve project style and structure.
- Avoid unnecessary file proliferation.

### 7.1 Script Iteration Rule (Strict)

When improving/debugging an existing script:

- **Always update the same script file incrementally**.
- **Do not create replacement script variants** (for example: `script_v2.py`, `script_new.py`, `script_fixed.py`).
- Create a new script only if:
  1. The original script does not exist, or
  2. The user explicitly asks for a separate new script.

Before creating any new script, run this decision check:

1. "Does an existing script already cover this purpose?"
2. If yes -> edit that existing script.
3. If no -> create one new script with a clear canonical name.

If unsure, default to editing the existing file and ask one focused clarification question.

---

## 8) Response Contract

Keep responses concise and operational.

When making changes, include:

1. What changed.
2. Why it changed.
3. Files touched.
4. Validation performed (commands/run results).
5. Next action (only if needed).

Do not ask unnecessary questions.
Ask questions only when required to unblock real implementation.

---

## 9) Testing Philosophy for This Environment

- Prioritize real runtime verification over writing dedicated unit tests.
- Do not create test files unless the user asks.
- Validate behavior by executing actual code paths.

### 9.1 Critical Measurement & Benchmark Skepticism (Required)

When performance results look surprisingly good, assume they may be incomplete until proven otherwise.

Rules:

- Be explicitly skeptical of "too-good-to-be-true" speedups.
- Verify **what is actually being timed** and **where timing starts/stops**.
- Prefer true **end-to-end (E2E)** measurement for user-visible performance claims.
- Do not benchmark only an internal sub-step if the claim is about full pipeline latency.
- Ensure benchmark instrumentation is placed at the correct boundaries (real input -> full processing -> real output).
- Report what is included/excluded in timing (I/O, serialization, warmup, model load, network, post-processing).
- Cross-check with at least one independent timing method when possible.

Required benchmark report fields:

1. Exact timed scope (E2E or component-only)
2. Timer boundary locations in code
3. Warmup policy
4. Number of runs + aggregation (mean/p50/p95)
5. Environment details (hardware, software versions)
6. Known exclusions/limitations

Never present partial timing as full-system performance.

---

### 9.2 Benchmarking Implementation Patterns (Required)

All performance measurements MUST follow these patterns to ensure accuracy and reproducibility.

#### Core Principles

1. **Always warm up** (3+ runs before timing) - eliminates cold-start bias, JIT overhead, cache effects
2. **Multiple runs** (10+ timed iterations) - ensures statistical significance
3. **E2E timing** - time full flow for performance claims
4. **Timer placement** - start immediately before operation, stop immediately after completion
5. **Async handling** - always `await` to get actual execution time, not coroutine creation
6. **Statistics** - report mean, median, stdev, min, max, P50, P95, P99
7. **Context** - report what's included/excluded, warmup policy, runs, environment

#### Pattern 1: Synchronous Benchmarking

```python
import time, statistics

def benchmark_sync(func, *args, warmup_runs=3, benchmark_runs=10, **kwargs):
    # Warmup - NOT timed
    for _ in range(warmup_runs):
        func(*args, **kwargs)
    
    # Benchmark - full E2E timing
    timings = []
    for _ in range(benchmark_runs):
        start = time.perf_counter()
        result = func(*args, **kwargs)  # CRITICAL: timer around actual work
        end = time.perf_counter()
        timings.append(end - start)
    
    return {
        "mean": statistics.mean(timings),
        "median": statistics.median(timings),
        "stdev": statistics.stdev(timings) if len(timings) > 1 else 0,
        "min": min(timings),
        "max": max(timings),
        "p95": timings[int(len(timings) * 0.95)],
    }
```

#### Pattern 2: Asynchronous Benchmarking

```python
import time, statistics, asyncio

async def benchmark_async(func, *args, warmup_runs=3, benchmark_runs=10, **kwargs):
    # Warmup - NOT timed
    for _ in range(warmup_runs):
        await func(*args, **kwargs)  # CRITICAL: await in warmup too
    
    # Benchmark - full E2E timing
    timings = []
    for _ in range(benchmark_runs):
        start = time.perf_counter()
        result = await func(*args, **kwargs)  # CRITICAL: await, not just coroutine creation
        end = time.perf_counter()
        timings.append(end - start)
    
    return {
        "mean": statistics.mean(timings),
        "median": statistics.median(timings),
        "stdev": statistics.stdev(timings) if len(timings) > 1 else 0,
    }
```

#### Pattern 3: E2E Pipeline Benchmarking

```python
import time, statistics

def benchmark_e2e(setup_func, process_func, teardown_func, 
                  warmup_runs=2, benchmark_runs=5, **setup_kwargs):
    # Warmup - NOT timed
    for _ in range(warmup_runs):
        ctx = setup_func(**setup_kwargs)
        result = process_func(ctx)
        teardown_func(ctx, result)
    
    # Benchmark - full pipeline timing
    timings = []
    for _ in range(benchmark_runs):
        start = time.perf_counter()  # CRITICAL: before setup
        ctx = setup_func(**setup_kwargs)
        result = process_func(ctx)
        teardown_func(ctx, result)
        end = time.perf_counter()  # CRITICAL: after teardown
        timings.append(end - start)
    
    return {"mean": statistics.mean(timings), "timed_scope": "E2E (setup+process+teardown)"}
```

#### Pattern 4: Memory Tracking Benchmarking

```python
import time, statistics, tracemalloc, psutil, os

def benchmark_with_memory(func, *args, warmup_runs=3, benchmark_runs=10, **kwargs):
    process = psutil.Process(os.getpid())
    
    # Warmup - NOT timed
    for _ in range(warmup_runs):
        func(*args, **kwargs)
    
    # Benchmark with memory tracking
    timings, memory_usage, peak_memory = [], [], []
    for _ in range(benchmark_runs):
        start = time.perf_counter()
        tracemalloc.start()
        mem_before = process.memory_info().rss / 1024 / 1024
        
        result = func(*args, **kwargs)
        
        mem_after = process.memory_info().rss / 1024 / 1024
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        end = time.perf_counter()
        
        timings.append(end - start)
        memory_usage.append(mem_after - mem_before)
        peak_memory.append(peak / 1024 / 1024)
    
    return {
        "mean_seconds": statistics.mean(timings),
        "mean_memory_mb": statistics.mean(memory_usage),
        "mean_peak_memory_mb": statistics.mean(peak_memory),
    }
```

#### Common Pitfalls (Avoid These)

- ❌ No warmup (cold-start bias)
- ❌ Timing only inner loop, not full pipeline
- ❌ Not awaiting async functions (measures coroutine creation, not execution)
- ❌ Including unrelated setup/teardown in timing
- ❌ Running only 1-2 iterations (insufficient statistics)
- ❌ Using `time.time()` instead of `time.perf_counter()`
- ❌ Measuring mock data instead of real workloads
- ❌ Not reporting what's included/excluded in timing

---

## 10) Visualization Preference

- If visualization is needed, use Seaborn.
- If no visualization is needed, do not add one.

---

## 11) ML / Training Experiment Protocol (When Applicable)

Use a reproducible, hypothesis-driven loop.

### Required per experiment

- Objective and hypothesis
- Baseline reference
- Primary/secondary metrics and acceptance criteria
- Exact command + resolved config
- Seed(s)
- Dataset/split version
- Code commit hash
- Artifacts (logs, checkpoints, reports)
- Result classification: WIN / LOSS / NEUTRAL / INVALID
- Next action

### Operating principles

- Compare against a real baseline.
- Change one meaningful variable at a time unless running designed multi-factor studies.
- Do not leak validation/test data.
- Prefer multiple seeds for important claims; report mean ± std.
- Report absolute and relative deltas.
- Include negative outcomes; no cherry-picking.

### Recommended transfer-learning order

1. Fast, complete baseline
2. Tune LR/epochs/freeze strategy
3. Add augmentations/regularization
4. Scale model or resolution
5. Ensemble diverse strong models

---

## 12) Personalization

When useful, connect explanations to the user's known interests and preferred terminology to improve learning and retention.

---

## 13) Quick Compliance Checklist (Self-check before finalizing)

- Did I create an explicit upfront plan/checklist and cover all applicable instruction points?
- Did I follow the user's exact request and constraints?
- Did I avoid fake logic/mock data?
- Did I avoid silent exception handling?
- Did I ask only necessary unblock questions?
- Did I make minimal, targeted edits to existing files?
- **Did I write all Python code to physical script files (no inline execution)?**
- **Did I write results directly to files incrementally (not stored in memory)?**
- **Did I implement file existence checking for resumability?**
- Did I run appropriate real validation (and ruff for Python)?
- Did I critically validate any benchmark/performance claims with correct E2E measurement boundaries?
- Did I report what changed and evidence it works?
