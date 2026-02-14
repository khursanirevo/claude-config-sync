---
name: multiprocess-pytorch-gpu-model-isolation
description: |
  Fix CUDA device mismatch errors when using PyTorch models with multiprocessing.
  Use when: (1) "Expected all tensors to be on the same device, but found at least
  two devices, cuda:0 and cuda:1!", (2) global PyTorch model singleton causing
  device conflicts in worker processes, (3) multiprocessing with model inference on
  multiple GPUs. Applies to ProcessPoolExecutor, multiprocessing.Pool, and
  Process.start() scenarios.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# Multiprocessing PyTorch GPU Model Isolation

## Problem
When using PyTorch models with multiprocessing, all worker processes share the same
global model instance loaded on a single GPU (usually cuda:0). When workers try to use
different GPUs, this causes device mismatch errors.

## Context / Trigger Conditions
- Using `multiprocessing.Pool`, `ProcessPoolExecutor`, or `Process.start()`
- PyTorch models loaded as global singletons (e.g., `MODEL = None` pattern)
- Workers need to use different CUDA devices
- Error: `Expected all tensors to be on the same device, but found at least two devices, cuda:0 and cuda:1!`
- Error: `RuntimeError: CUDA error: invalid device ordinal` or similar
- Model inference works in main process but fails in workers

## Root Cause
PyTorch models with global singletons are loaded once before forking workers. All
workers inherit the same model object pointing to the original device. When workers
call `torch.cuda.set_device(N)`, it changes their current device context but the model
tensors remain on the original GPU.

## Solution

### Option 1: Load Model Per Worker Process (Recommended)

```python
import torch
import multiprocessing as mp

def worker_process(gpu_id: int, task_queue: mp.Queue, result_queue: mp.Queue):
    """Worker that loads its own model instance"""

    # Set device for this process FIRST
    device = f"cuda:{gpu_id}"
    torch.cuda.set_device(device)

    # Reset global model singleton to force reload on correct GPU
    import my_model_module
    my_model_module.MODEL = None
    my_model_module.DEVICE = device

    # Now when model is loaded, it will use the correct GPU
    from my_model_module import get_model
    model = get_model()  # Loads on cuda:{gpu_id}

    while True:
        task = task_queue.get()
        if task is None:
            break
        result = model(task)
        result_queue.put(result)
```

### Option 2: Pass Model via Process Initializer (Cleaner)

```python
import torch
from functools import partial

def init_worker(gpu_id, model_class, model_path):
    """Initialize each worker with its own model"""
    device = f"cuda:{gpu_id}"
    torch.cuda.set_device(device)

    # Load model on this GPU
    global worker_model
    worker_model = model_class.load(model_path)
    worker_model = worker_model.to(device)
    worker_model.eval()

def worker(task):
    """Use the global worker_model"""
    return worker_model(task)

# Start pool with initializer
with multiprocessing.Pool(
    processes=4,
    initializer=partial(init_worker, model_class=MyModel, model_path="model.pt"),
    initargs=([0, 1, 2, 3],)  # GPU IDs for each worker
) as pool:
    results = pool.map(worker, tasks)
```

### Option 3: Re-create Model After Fork (Quick Fix)

```python
import os
import torch

def worker(gpu_id):
    # Force re-import to get fresh module state
    import importlib
    import my_model
    importlib.reload(my_model)

    # Set device before loading
    torch.cuda.set_device(gpu_id)
    device = torch.device(f"cuda:{gpu_id}")

    # Load model on correct device
    model = my_model.MyModel()
    model = model.to(device)

    return model(data)
```

### Option 4: Use Spawn Instead of Fork (For Linux)

```python
import multiprocessing

# Use 'spawn' start method instead of default 'fork'
mp.set_start_method('spawn', force=True)

# Each process gets fresh Python interpreter
# Models don't need to be reset, but each worker loads its own copy
with multiprocessing.Pool(processes=4) as pool:
    results = pool.map(worker, tasks)
```

## Verification
After fixing, each worker should:
1. Run on its assigned GPU (check with `torch.cuda.current_device()`)
2. Have model on correct device (check with `model.device.index`)
3. No device mismatch errors
4. Different workers use different GPUs simultaneously

```python
# In worker process
print(f"Current device: {torch.cuda.current_device()}")  # Should match gpu_id
print(f"Model device: {model.device}")  # Should be cuda:{gpu_id}
```

## Example: Multi-GPU Conversation Generation

**Before (Broken):**
```python
# Global model loaded once on cuda:0
TTS_MODEL = ChatterboxTTS.from_local(MODEL_PATH, device="cuda:0")

def worker(gpu_id, task):
    # Tries to use cuda:1 but model is on cuda:0
    torch.cuda.set_device(gpu_id)
    return TTS_MODEL.generate(task)  # ERROR: Device mismatch!
```

**After (Fixed):**
```python
def worker(gpu_id, task):
    # Each worker loads fresh model on its GPU
    device = f"cuda:{gpu_id}"
    torch.cuda.set_device(device)

    # Reset global singleton
    import backend.chatter_service as cs
    cs.TTS_MODEL = None
    cs.DEVICE = device

    # Load model on correct GPU
    model = cs.get_or_load_tts_model()  # Loads on cuda:{gpu_id}
    return model.generate(task)
```

## Notes
- **Default start method on Linux**: 'fork' inherits parent's memory (including model)
- **'spawn' method**: Fresh interpreter, no inherited state, but slower startup
- **CUDA_VISIBLE_DEVICES**: Alternative approach to restrict GPU visibility per worker:
  ```bash
  export CUDA_VISIBLE_DEVICES=0 python worker.py &
  export CUDA_VISIBLE_DEVICES=1 python worker.py &
  ```
- **Memory considerations**: Loading model per-worker consumes more GPU memory
- **Model compilation**: `torch.compile()` models may have device-specific optimizations
- **NCCL/Distributed**: For multi-GPU training, use `torch.distributed` instead of multiprocessing
- Best for inference: Use option 1 (load per worker) for cleanest separation

## Common Pitfalls

### Don't do this:
```python
# Model loaded before forking
model = load_model().to("cuda:0")

def worker(task):
    # Changing device doesn't move the model
    torch.cuda.set_device(1)
    return model(task)  # Model still on cuda:0!
```

### Do this instead:
```python
def worker(gpu_id):
    # Load model in the worker
    model = load_model().to(f"cuda:{gpu_id}")
    return model(task)
```

## Related Issues
- "RuntimeError: CUDA error: invalid device ordinal" - Wrong GPU ID for system
- "out of memory" - Loading too many model copies across GPUs
- "tuple appears and disappears" - Inconsistency from fork vs spawn differences

## References
- [PyTorch Multiprocessing Best Practices](https://pytorch.org/docs/stable/notes/multiprocessing.html)
- [PyTorch CUDA Semantics](https://pytorch.org/docs/stable/cuda.html#multiprocessing-cuda)
- [Python multiprocessing start methods](https://docs.python.org/3/library/multiprocessing.html#contexts-and-start-methods)
