---
name: vllm-bleeding-edge-model-setup
description: |
  Fix "model type not recognized" errors when running new/bleeding-edge models with vLLM.
  Use when: (1) vLLM fails with "Transformers does not recognize this architecture",
  (2) Error mentions unknown model type like "glm4_moe_lite", (3) Model was released
  in the last few months and requires latest Transformers. Covers installing vLLM
  and Transformers from git source, NumPy version constraints for Numba compatibility,
  and dependency resolution order.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# vLLM Bleeding-Edge Model Setup

## Problem
When trying to run newly released models with vLLM, you encounter errors about
unrecognized model architectures even with the latest vLLM version installed.

## Context / Trigger Conditions

### Error Messages
```
Value error, The checkpoint you are trying to load has model type `glm4_moe_lite`
but Transformers does not recognize this architecture.
```

Or:
```
pydantic_core._pydantic_core.ValidationError: 1 validation error for ModelConfig
```

### When This Happens
- Model was released within the last 1-3 months
- Model uses a new architecture not yet in stable Transformers releases
- You're using PyPI-installed versions of vLLM and Transformers
- Model is from HuggingFace with very recent commit dates

## Solution

### Step 1: Install Transformers from Source

Bleeding-edge model architectures are often only available in the Transformers
development branch, not in PyPI releases.

```bash
# Using uv (recommended for speed)
uv pip install git+https://github.com/huggingface/transformers.git --python /path/to/venv/bin/python

# Using traditional pip
/path/to/venv/bin/pip install git+https://github.com/huggingface/transformers.git
```

This installs Transformers 5.0.0.dev0 or later with the newest architectures.

### Step 2: Install vLLM from Source

Ensure vLLM has the latest model implementations:

```bash
# Using uv
uv pip install --upgrade git+https://github.com/vllm-project/vllm.git --python /path/to/venv/bin/python

# Using traditional pip
/path/to/venv/bin/pip install --upgrade git+https://github.com/vllm-project/vllm.git
```

### Step 3: Fix NumPy Version for Numba Compatibility

vLLM's Numba dependency has strict NumPy version requirements. If you see:

```
ImportError: Numba needs NumPy 2.2 or less. Got NumPy 2.4.
```

Downgrade NumPy to 2.2.x:

```bash
uv pip install "numpy<2.3" --python /path/to/venv/bin/python
```

**Important**: Do this AFTER installing vLLM from source, as vLLM may upgrade
NumPy during installation.

### Step 4: Verify Installation

```bash
python -c "import transformers; print('Transformers:', transformers.__version__)"
python -c "import vllm; print('vLLM:', vllm.__version__)"
python -c "import numpy; print('NumPy:', numpy.__version__)"
```

Expected output:
- Transformers: 5.0.0.dev0 or higher
- vLLM: 0.14.0rc2.dev or higher
- NumPy: 2.2.x (not 2.3+ or 2.4+)

### Step 5: Start vLLM Server

Now the model should load correctly:

```bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
python -m vllm.entrypoints.openai.api_server \
  --model "org/model-name" \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.85 \
  --max-model-len 131072 \
  --port 8002
```

## Verification

**Before fix**: Server fails during initialization with model architecture error

**After fix**: Server initializes successfully with output like:
```
INFO Resolved architecture: Glm4MoeLiteForCausalLM
INFO Model loading took XX GiB memory
INFO Starting vLLM API server on http://0.0.0.0:8002
```

Test with a simple request:
```bash
curl http://localhost:8002/v1/models
```

Should return your model in the list.

## Example

Running GLM-4.7-Flash (released January 2026):

```bash
# Initial attempt fails with:
# "The checkpoint you are trying to load has model type `glm4_moe_lite`"

# Fix: Install from source
uv pip install git+https://github.com/huggingface/transformers.git --python .venv/bin/python
uv pip install --upgrade git+https://github.com/vllm-project/vllm.git --python .venv/bin/python
uv pip install "numpy<2.3" --python .venv/bin/python

# Now it works
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True CUDA_VISIBLE_DEVICES=2 \
.venv/bin/python -m vllm.entrypoints.openai.api_server \
  --model "zai-org/GLM-4.7-Flash" \
  --tensor-parallel-size 1 \
  --port 8002
```

## Notes

### Installation Order Matters
1. Install Transformers from source FIRST
2. Install vLLM from source SECOND
3. Downgrade NumPy LAST (vLLM installation may upgrade it)

### Dependency Triangle
There's a compatibility triangle between:
- **vLLM**: Moving toward NumPy 2.x support but not fully there
- **Numba**: vLLM dependency with NumPy <2.3 requirement (as of 2025)
- **NumPy**: 2.3+ and 2.4 released but breaks Numba compatibility

This is tracked in [vLLM Issue #6570](https://github.com/vllm-project/vllm/issues/6570)
and [vLLM Issue #11991](https://github.com/vllm-project/vllm/issues/11991).

### When to Use PyPI vs Source
- **Stable models** (Llama 3, Mixtral, etc.): PyPI installations work fine
- **New models** (last 1-3 months): Install from source
- **Experimental architectures**: Always check if Transformers main branch has it

### Alternative: Use Docker
For production, consider using vLLM's official Docker images which may have
preconfigured dependencies:

```bash
docker pull vllm/vllm-openai:latest
```

However, even Docker images may lag behind the very latest model architectures.

## References

- [vLLM Supported Models Documentation](https://docs.vllm.ai/en/latest/models/supported_models/)
- [vLLM Forum: GLM-4.7-Flash Discussion](https://discuss.vllm.ai/t/glm-4-7-flash-with-nvidia/2256)
- [vLLM GitHub Issue #6570: NumPy 2.0 Compatibility](https://github.com/vllm-project/vllm/issues/6570)
- [Numba 0.63.0 Release Notes (NumPy 2.x improvements)](https://numba.readthedocs.io/en/stable/release/0.63.0-notes.html)
- [NumPy 2.3.4 Release Notes](https://numpy.org/devdocs/release/2.3.4-notes.html)
