---
name: pytorch-weight-norm-checkpoint-compatibility
description: |
  Fix for PyTorch checkpoint loading when source has plain .weight tensors but
  target model uses weight_norm (weight_g, weight_v). Use when: (1) Loading
  checkpoints where weights appear to load but model outputs garbage, (2) State
  dict has .weight but model expects .weight_g and .weight_v, (3) Model
  parameters have mean ≈ 0 after loading checkpoint. Covers VITS, WaveNet,
  and other models using torch.nn.utils.weight_norm.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# PyTorch Weight Norm Checkpoint Compatibility

## Problem
When loading PyTorch checkpoints, the source may have plain convolutional/linear
weights (`.weight`) while your model uses `torch.nn.utils.weight_norm` which
decomposes weights into `.weight_g` (norms) and `.weight_v` (directions). This
causes silent failures where:
- Loading reports "success" but weights don't actually transfer
- Model outputs are garbage because weights are randomly initialized
- Mean of loaded weights ≈ 0 (random init) instead of trained values

## Context / Trigger Conditions
- **Symptom**: After loading checkpoint, `model.layer.weight.mean().item() ≈ 0` (e.g., 2e-5)
- **Error pattern**: Checkpoint has `dec.conv_pre.weight` but model has
  `dec.conv_pre.weight_g` and `dec.conv_pre.weight_v`
- **Common in**: VITS, WaveNet, and other speech synthesis models
- **Cause**: Checkpoint was saved after calling `remove_weight_norm()` or from
  a framework that doesn't use weight_norm

## Solution

### Understanding weight_norm Decomposition

`weight_norm` decomposes a weight matrix `W` into:
- `weight_g`: The norm of W along a dimension (default dim=0)
- `weight_v`: The direction vector W / ||W||

The reconstructed weight is: `W = weight_g * weight_v / ||weight_v||`

### Loading with Conversion

```python
def load_with_weight_norm_conversion(model, checkpoint_state_dict):
    """Load checkpoint with weight -> weight_g/weight_v conversion"""
    model_state = model.state_dict()

    for ckpt_key, ckpt_value in checkpoint_state_dict.items():
        # Direct match
        if ckpt_key in model_state:
            if model_state[ckpt_key].shape == ckpt_value.shape:
                model_state[ckpt_key] = ckpt_value
                continue

        # Check if this is a .weight that needs conversion to weight_norm format
        if ckpt_key.endswith('.weight'):
            base_key = ckpt_key[:-6]  # Remove '.weight'
            weight_g_key = f"{base_key}.weight_g"
            weight_v_key = f"{base_key}.weight_v"

            # Only convert if model has weight_norm parameters
            if weight_g_key in model_state and weight_v_key in model_state:
                # Convert plain weight to weight_norm format
                weight = ckpt_value

                # For Conv1d/ConvTranspose1d: dim=0 is output channels
                # Calculate norm: reduce over all dims except dim=0
                weight_g = weight.norm(dim=tuple(range(1, weight.dim())), keepdim=True)
                weight_v = weight / (weight_g + 1e-10)

                # Verify shapes match before assigning
                if (weight_g.shape == model_state[weight_g_key].shape and
                    weight_v.shape == model_state[weight_v_key].shape):
                    model_state[weight_g_key] = weight_g.squeeze()
                    model_state[weight_v_key] = weight_v
                    print(f"  Converted {ckpt_key} to weight_norm format")
                else:
                    print(f"  Shape mismatch after conversion for {ckpt_key}")
                    print(f"    Expected weight_g: {model_state[weight_g_key].shape}, got: {weight_g.shape}")
                    print(f"    Expected weight_v: {model_state[weight_v_key].shape}, got: {weight_v.shape}")

    model.load_state_dict(model_state)
    return model
```

### Alternative: Remove weight_norm Before Loading

If you don't need weight_norm during training:

```python
# Remove weight_norm from model (makes it use plain weights)
def remove_weight_norm(model):
    for module in model.modules():
        try:
            nn.utils.remove_weight_norm(module)
        except:
            pass  # Module doesn't have weight_norm

# Then load checkpoint normally
remove_weight_norm(model)
model.load_state_dict(checkpoint_state_dict)
```

### Alternative: Add weight_norm After Loading

If checkpoint has plain weights but you want weight_norm:

```python
# Load checkpoint first
model.load_state_dict(checkpoint_state_dict)

# Then apply weight_norm
for module in model.modules():
    if isinstance(module, (nn.Conv1d, nn.ConvTranspose1d, nn.Linear)):
        nn.utils.weight_norm(module, name='weight')
```

## Verification

```python
# After loading, verify weights are actually loaded:
param = model.dec.conv_pre.weight_v  # or any weight_g/weight_v
print(f"Mean: {param.mean().item():.6f}")
print(f"Std: {param.std().item():.6f}")

# If loaded from checkpoint:
# - Mean should be significantly non-zero (e.g., 0.01 or higher)
# - Std should be non-zero (e.g., 0.1 or higher)

# If randomly initialized:
# - Mean ≈ 0 (e.g., 2e-5)
# - Std ≈ 0 (e.g., 1e-5)
```

## Example

**Scenario**: Loading VITS-osman checkpoint into custom VITS model

```python
import torch
from vits_model import Generator

# Load checkpoint
checkpoint = torch.load('vits_osman.pth', map_location='cpu')

# Create model
model = Generator(config)

# Load with conversion
model = load_with_weight_norm_conversion(model, checkpoint)

# Verify
print(f"conv_pre weight_v mean: {model.dec.conv_pre.weight_v.mean().item():.6f}")
# Output: 0.023451 (loaded) vs 2.47e-05 (random)
```

## Notes

### Dimension Considerations
- **Conv1d/Linear**: Use `dim=0` for norm calculation
- **ConvTranspose1d**: Also uses `dim=0` (output channels)
- **Other layers**: Check the original weight_norm call's `dim` parameter

### Gotchas
1. **Silent failure**: PyTorch's `load_state_dict()` doesn't error when keys don't
   match - it just silently skips them
2. **Partial loading**: Only matched keys load; always verify the count
3. **Shape mismatches**: Even with correct keys, shape mismatches prevent loading
4. **Order matters**: Apply conversion BEFORE calling `model.load_state_dict()`

### When to Use Each Approach
- **Convert during load**: When checkpoint has mixed formats (some weight_norm, some not)
- **Remove weight_norm**: When you don't need weight normalization benefits
- **Add weight_norm after**: When checkpoint is clean but you want weight_norm training

### Common Error Messages
- `RuntimeError: Error(s) in loading state_dict`: Usually shape mismatch
- `KeyError: 'unexpected key'`: Missing conversion logic
- Model produces silence/garbage: Weights didn't load (verify with mean check)

## References

- [PyTorch weight_norm documentation](https://pytorch.org/docs/stable/generated/torch.nn.utils.weight_norm.html)
- [PyTorch weight_norm removal](https://pytorch.org/docs/stable/generated/torch.nn.utils.remove_weight_norm.html)
- VITS paper: Conditional Variational Autoencoder with Adversarial Learning for End-to-End Text-to-Speech
