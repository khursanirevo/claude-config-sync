---
name: lora-embedding-merge
description: |
  Fix for LoRA on nn.Embedding layers not saving/loading properly in PyTorch/HuggingFace models.
  Use when: (1) LoRA-wrapped nn.Embedding fails to load with "were not initialized" warnings,
  (2) Custom LoRA adapter for embeddings causes weight shape mismatches, (3) Model rejects
  LoRA checkpoint despite successful training. Covers weight merging formula: merged = original +
  (A.T @ B.T * scaling) where A is (r, vocab_size) and B is (embed_dim, r).
author: Claude Code
version: 1.0.0
date: 2026-01-24
---

# LoRA for nn.Embedding: Weight Merging for Save/Load

## Problem

When applying LoRA (Low-Rank Adaptation) to `nn.Embedding` layers using a custom adapter wrapper,
the checkpoint saves successfully but **fails to load** with warnings like:

```
Some weights of the model checkpoint were not used when initializing:
['module.text_embedding.lora_A', 'module.text_embedding.lora_B', ...]
```

The model loads with **base weights**, NOT the fine-tuned LoRA weights.

## Context / Trigger Conditions

- Using LoRA on `nn.Embedding` layers (not Linear/Convolution layers)
- Custom LoRA adapter wraps the original `nn.Embedding`
- Training completes successfully, but checkpoint loading ignores LoRA weights
- Model expects standard `nn.Embedding` at load time, not a wrapper class
- Error occurs with both HuggingFace `from_pretrained()` and raw PyTorch `load_state_dict()`

## Root Cause

Standard LoRA implementations (like PEFT) work on Linear layers by replacing them with
LoRA-wrapped versions. However, `nn.Embedding` has different save/load expectations:

1. **During training**: You replace `embedding = LoRAAdapter(original_embedding)`
2. **During save**: State dict saves the wrapper structure: `text_embedding.lora_A`, `text_embedding.lora_B`
3. **During load**: Model expects `text_embedding.weight` (a standard embedding), finds wrapper structure
4. **Result**: Loading rejects the wrapper weights, falls back to initialization or base weights

## Solution

**Merge LoRA weights into the original embedding matrix BEFORE saving**:

```python
import torch
from safetensors.torch import save_file

def merge_lora_embedding(original_embedding, lora_A, lora_B, alpha, r):
    """
    Merge LoRA weights into nn.Embedding weight matrix.

    Args:
        original_embedding: nn.Embedding with weight (vocab_size, embed_dim)
        lora_A: LoRA A matrix, shape (r, vocab_size)
        lora_B: LoRA B matrix, shape (embed_dim, r)
        alpha: LoRA scaling factor
        r: LoRA rank

    Returns:
        merged_weight: torch.Tensor of shape (vocab_size, embed_dim)
    """
    scaling = alpha / r
    original_weight = original_embedding.weight.data

    # LoRA forward: embedding @ A.T @ B.T
    # Weight update: A.T @ B.T
    lora_weight = (lora_A.T @ lora_B.T) * scaling

    # Merge: original + lora
    merged_weight = original_weight + lora_weight

    return merged_weight

# Usage during checkpoint saving
text_embedding_adapter = model.talker.model.text_embedding  # Your LoRAAdapter instance

if hasattr(text_embedding_adapter, 'original_embedding'):
    # Extract LoRA parameters
    lora_A = text_embedding_adapter.lora_A      # (r, vocab_size)
    lora_B = text_embedding_adapter.lora_B      # (embed_dim, r)
    alpha = text_embedding_adapter.alpha
    r = text_embedding_adapter.r

    # Merge weights
    merged_weight = merge_lora_embedding(
        text_embedding_adapter.original_embedding,
        lora_A, lora_B, alpha, r
    )

    # Replace with standard nn.Embedding containing merged weights
    model.talker.model.text_embedding = torch.nn.Embedding.from_pretrained(
        merged_weight, freezing=False
    )
    model.talker.model.text_embedding.to(original_weight.device)
    model.talker.model.text_embedding.to(original_weight.dtype)
```

**Then save normally**:
```python
state_dict = model.state_dict()
save_file(state_dict, "checkpoint/model.safetensors")
```

## Key Formula

```
merged_weight = original_weight + (lora_A.T @ lora_B.T) * (alpha / r)
```

Where:
- `original_weight`: (vocab_size, embed_dim)
- `lora_A`: (r, vocab_size) - stored transposed
- `lora_B`: (embed_dim, r) - stored transposed
- `alpha`: Scaling hyperparameter (typically 16-32)
- `r`: Rank hyperparameter (typically 4-16)

## Verification

After merging and saving, loading should work WITHOUT "were not initialized" warnings:

```bash
# Before fix: Shows warnings about lora_A, lora_B not being used
# After fix: No warnings, weights load correctly

model = AutoModel.from_pretrained("checkpoint")
# Should load with merged weights
```

Check that the loaded model has the fine-tuned weights:
```python
loaded = AutoModel.from_pretrained("checkpoint")
original = AutoModel.from_pretrained("base_model")

# Weights should be different
assert not torch.allclose(
    loaded.talker.model.text_embedding.weight,
    original.talker.model.text_embedding.weight
)
```

## Example

Complete example for Qwen3-TTS text embedding LoRA:

```python
# During training: Create LoRA adapter
class LoRAEmbeddingAdapter(torch.nn.Module):
    def __init__(self, original_embedding, r=8, alpha=16, dropout=0.05):
        super().__init__()
        self.original_embedding = original_embedding
        self.r = r
        self.alpha = alpha
        self.scaling = alpha / r

        vocab_size, embed_dim = original_embedding.weight.shape
        device = original_embedding.weight.device

        # LoRA parameters (transposed for efficiency)
        self.lora_A = torch.nn.Parameter(torch.zeros(r, vocab_size, device=device))
        self.lora_B = torch.nn.Parameter(torch.zeros(embed_dim, r, device=device))

        torch.nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5))
        torch.nn.init.zeros_(self.lora_B)

    def forward(self, input_ids):
        original = self.original_embedding(input_ids)
        lora_result = (
            torch.nn.functional.embedding(input_ids, self.lora_A.t())
            @ self.lora_B.t()
        ) * self.scaling
        return original + lora_result.to(original.dtype)

# Apply during training
model.talker.model.text_embedding = LoRAEmbeddingAdapter(
    model.talker.model.text_embedding, r=8, alpha=16
)

# During checkpoint saving: MERGE weights
adapter = model.talker.model.text_embedding
merged_weight = adapter.original_embedding.weight.data + (
    adapter.lora_A.T @ adapter.lora_B.T
) * adapter.scaling

model.talker.model.text_embedding = torch.nn.Embedding.from_pretrained(
    merged_weight, freezing=False
)
torch.save(model.state_dict(), "checkpoint.pth")
```

## Notes

### Why This Happens

- **PEFT library** only supports LoRA on Linear/Conv layers, not Embedding layers
- **Custom LoRA adapters** on Embeddings create wrapper structures that don't match expected state dict keys
- **HuggingFace models** expect `module.weight` for Embeddings, not nested wrapper structures

### Alternative Approaches

1. **Use PEFT's embedding support** (if available in newer versions)
2. **Modify model architecture** to accept custom embedding layers (more invasive)
3. **Save/merge manually** as shown in this solution (recommended for Embedding LoRA)

### When to Merge

- **Before saving**: Merge during checkpoint save to ensure compatibility
- **After loading**: Can load adapter weights separately and merge in memory if needed
- **Trade-off**: Merged weights can't be removed (LoRA is "baked in"), but this is usually fine for deployment

### Dimension Reference

| Matrix | Shape | Description |
|--------|-------|-------------|
| `original_weight` | (V, D) | vocab_size × embed_dim |
| `lora_A` | (r, V) | LoRA rank A (transposed) |
| `lora_B` | (D, r) | LoRA rank B (transposed) |
| `merged` | (V, D) | Same as original |

## References

- [LoRA Paper: LoRA: Low-Rank Adaptation of Large Language Models](https://arxiv.org/abs/2106.09685)
- [PEFT Library Documentation](https://huggingface.co/docs/peft/)
- [PyTorch nn.Embedding Documentation](https://pytorch.org/docs/stable/generated/torch.nn.Embedding.html)
