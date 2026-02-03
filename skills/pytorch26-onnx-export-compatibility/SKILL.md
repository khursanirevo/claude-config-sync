---
name: pytorch26-onnx-export-compatibility
description: |
  Fix for PyTorch 2.6 breaking changes when exporting PyTorch Lightning checkpoints
  to ONNX format. Use when: (1) "WeightsUnpickler error: Unsupported global: GLOBAL pathlib.PosixPath"
  when loading checkpoints, (2) "GuardOnDataDependentSymNode: Could not guard on data-dependent expression"
  during ONNX export, (3) Using PyTorch 2.6+ with PyTorch Lightning, Piper TTS, or VITS models.
  Covers torch.load weights_only=True change and torch.onnx.export dynamo=True change.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# PyTorch 2.6 ONNX Export Compatibility

## Problem

PyTorch 2.6 introduced two breaking changes that affect checkpoint loading and ONNX export:

### Issue 1: Checkpoint Loading Failure
- **Error**: `WeightsUnpickler error: Unsupported global: GLOBAL pathlib.PosixPath was not an allowed global by default`
- **Cause**: PyTorch 2.6 changed `torch.load()` default to `weights_only=True`
- **Impact**: PyTorch Lightning checkpoints containing `pathlib.PosixPath` metadata fail to load

### Issue 2: ONNX Export Failure
- **Error**: `GuardOnDataDependentSymNode: Could not guard on data-dependent expression Eq(u14, 1)`
- **Cause**: PyTorch 2.6 ONNX export defaults to `dynamo=True`
- **Impact**: Models with data-dependent guards (VITS, transformers with dynamic operations) fail to export

## Context / Trigger Conditions

Use this skill when:
- Upgrading to PyTorch 2.6+ from earlier versions
- Using PyTorch Lightning (checkpoints contain custom metadata)
- Exporting models with dynamic operations to ONNX
- Using Piper TTS, VITS, or similar neural TTS models
- Seeing `pathlib.PosixPath` or `GuardOnDataDependentSymNode` errors

## Solution

### Step 1: Create sitecustomize.py

Create a `sitecustomize.py` file in your project root:

```python
"""Site customization for PyTorch 2.6+ compatibility."""

from __future__ import annotations

try:
    import os
    import pathlib
    import torch

    # Allowlist PosixPath for torch.load with weights_only=True
    try:
        add_safe_globals = torch.serialization.add_safe_globals
    except Exception:
        add_safe_globals = None

    if add_safe_globals is not None:
        add_safe_globals([pathlib.PosixPath])

    # Force weights_only=False when PIPER_TORCH_LOAD_WEIGHTS_ONLY=0
    if os.environ.get("PIPER_TORCH_LOAD_WEIGHTS_ONLY", "1") == "0":
        _orig_torch_load = torch.load

        def _torch_load_compat(*args, **kwargs):
            if "weights_only" not in kwargs:
                kwargs["weights_only"] = False
            return _orig_torch_load(*args, **kwargs)

        torch.load = _torch_load_compat

    # Force dynamo=False when PIPER_TORCH_ONNX_DYNAMO=0
    if os.environ.get("PIPER_TORCH_ONNX_DYNAMO", "0") == "0":
        try:
            _orig_torch_onnx_export = torch.onnx.export

            def _torch_onnx_export_compat(*args, **kwargs):
                kwargs.setdefault("dynamo", False)
                return _orig_torch_onnx_export(*args, **kwargs)

            torch.onnx.export = _torch_onnx_export_compat
        except Exception:
            pass
except Exception:
    pass  # Never fail import
```

### Step 2: Mount sitecustomize.py in Docker

When running Docker containers, mount the file to `/app/sitecustomize.py`:

```bash
docker run --rm \
  -v "/path/to/project:/app" \
  -v "/path/to/project/sitecustomize.py:/app/sitecustomize.py" \
  -w "/app" \
  -e "PYTHONPATH=/app" \
  ...
```

### Step 3: Set Required Environment Variables

Set these environment variables before running the container:

```bash
-e "PIPER_TORCH_ONNX_DYNAMO=0" \
-e "PIPER_TORCH_LOAD_WEIGHTS_ONLY=0"
```

### Complete Working Example (Piper TTS)

```bash
docker run --rm --gpus device=2 \
  -v "/path/to/repo:/app" \
  -v "/path/to/repo/sitecustomize.py:/app/sitecustomize.py" \
  -w "/app" \
  -e "PYTHONPATH=/app" \
  -e "PIPER_TORCH_ONNX_DYNAMO=0" \
  -e "PIPER_TORCH_LOAD_WEIGHTS_ONLY=0" \
  chatterbox-piper:nightly-cu128-sm120 \
  python3 -m piper_train.export_onnx checkpoint.ckpt model.onnx
```

## Verification

### Check 1: Checkpoint Loads Successfully
After applying the fix, checkpoint loading should succeed without `WeightsUnpickler` errors:
```bash
# Should load without errors
python -c "import torch; torch.load('checkpoint.ckpt')"
```

### Check 2: ONNX Export Completes
After applying the fix, ONNX export should complete without `GuardOnDataDependentSymNode` errors:
```bash
# Should export successfully
python3 -m piper_train.export_onnx checkpoint.ckpt model.onnx
```

### Check 3: ONNX File is Valid
```bash
# Verify the ONNX file exists and is valid
ls -lh model.onnx
python -c "import onnx; onnx.load('model.onnx')"
```

## Example: Piper TTS Malay Model Export

**Before the fix**:
```
_pickle.UnpicklingError: Weights only load failed. This file can still be loaded...
WeightsUnpickler error: Unsupported global: GLOBAL pathlib.PosixPath
```

**After applying the fix**:
```bash
# Export succeeds
INFO:piper_train.export_onnx:Exported model to /app/model.onnx

# Verify
$ ls -lh model.onnx
-rw-r--r-- 1 root root 61M Jan 28 15:32 model.onnx
```

## Notes

### Security Considerations
- **CVE-2025-32434**: PyTorch 2.6's `weights_only=True` is a security feature addressing RCE vulnerabilities
- Setting `PIPER_TORCH_LOAD_WEIGHTS_ONLY=0` disables this protection
- **Only use** with trusted checkpoints from known sources
- This is appropriate for development/training environments, not production inference on untrusted models

### Why Two Separate Environment Variables?
- `PIPER_TORCH_LOAD_WEIGHTS_ONLY=0`: Controls checkpoint loading (weights_only parameter)
- `PIPER_TORCH_ONNX_DYNAMO=0`: Controls ONNX export method (dynamo parameter)
- They address different PyTorch 2.6 changes and can be set independently

### Alternative Solutions
1. **Downgrade PyTorch**: Use PyTorch 2.5.x if you don't need 2.6 features
2. **Recreate Checkpoints**: Save checkpoints without `pathlib.PosixPath` metadata (requires code changes)
3. **Model Refactoring**: Rewrite model to avoid data-dependent guards (complex for VITS/transformers)

### When to Use sitecustomize.py
- **Use**: When you don't control the code calling `torch.load` or `torch.onnx.export`
- **Don't need**: If you can modify the code directly to pass `weights_only=False` and `dynamo=False`

### Python Environment Loading
- `sitecustomize.py` is automatically imported by Python when on `sys.path`
- This is the standard Python mechanism for site-wide customization
- Mounting it to `/app/sitecustomize.py` in Docker ensures it's always loaded

## References

### Official PyTorch Documentation
- [PyTorch 2.6 Release Blog](https://pytorch.org/blog/pytorch2-6/) - Announces weights_only security change
- [torch.load Documentation](https://docs.pytorch.org/docs/stable/generated/torch.load.html) - Official torch.load API reference
- [Serialization Semantics](https://docs.pytorch.org/docs/stable/notes/serialization.html) - Detailed serialization behavior
- [torch.onnx Documentation](https://docs.pytorch.org/docs/stable/onnx.html) - ONNX export API reference

### PyTorch Issues & Discussions
- [GitHub Issue #718 - Cufft resolved but now torch.load error (rhassdy/piper)](https://github.com/rhassdy/piper/issues/718) - Piper TTS specific issue
- [GitHub Issue #134616 - Could not guard on data-dependent expression](https://github.com/pytorch/pytorch/issues/134616) - Dynamo guard issue
- [GitHub Issue #136083 - ONNX Export Fails with Dynamic Slicing](https://github.com/pytorch/pytorch/issues/136083) - Ongoing dynamo export issues (2026)
- [GitHub Issue #172652 - ONNX export of linspace doesn't work with dynamo=True](https://github.com/pytorch/pytorch/issues/172652) - January 2026 confirmation

### Security Context
- [CVE-2025-32434 Detail](https://nvd.nist.gov/vuln/detail/CVE-2025-32434) - PyTorch torch.load RCE vulnerability
- [PyTorch Discussion: torch.load with weights_only=True RCE](https://discuss.pytorch.org/t/torch-load-with-weights-only-true-rce/219375) - Security discussion
