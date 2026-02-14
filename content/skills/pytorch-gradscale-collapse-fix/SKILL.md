---
name: pytorch-gradscale-collapse-fix
description: |
  Fix "grad_scale is too small" error in PyTorch mixed precision fine-tuning.
  Use when: (1) Training fails with "grad_scale is too small, exiting: Xe-XX",
  (2) Gradients collapse after first epoch during fine-tuning, (3) RuntimeError
  from GradScaler in mixed precision (FP16) training. Covers learning rate
  adjustment, batch size reduction, and gradient stability in fine-tuning scenarios.
author: Claude Code
version: 1.0.0
date: 2025-01-22
---

# PyTorch Gradient Scale Collapse Fix

## Problem
During fine-tuning with mixed precision (FP16), training fails after the first epoch
with gradient scale collapsing to extremely small values (~1e-20 to 1e-30), causing
the training to abort with "grad_scale is too small" error.

## Context / Trigger Conditions

**Exact Error Message:**
```
RuntimeError: grad_scale is too small, exiting: 5.169878828456423e-26
```

**When This Occurs:**
- Fine-tuning pre-trained models with `--use-fp16 1` or `torch.cuda.amp`
- First epoch completes successfully, second epoch fails
- Gradient scale drops from ~1e-10 to ~1e-26 between epochs
- Using custom or small datasets (< 20 hours of data)
- Default learning rates from pre-training scripts are too aggressive

**Root Cause:**
In mixed precision (FP16) training, the `GradScaler` maintains a scale factor to prevent
gradient underflow. When learning rates are too high for fine-tuning, gradients become
unstable, causing the scaler to rapidly decrease its scale factor until it becomes so
small that training cannot continue ([PyTorch AMP Recipe](https://docs.pytorch.org/tutorials/recipes/recipes/amp_recipe.html)).

## Solution

### Primary Fix: Reduce Learning Rate

**Default fine-tuning LR too high:** `0.0001`
**Recommended starting LR:** `0.00001` to `0.00003` (3-10x lower)

```python
# Before (fails):
--base-lr 0.0001

# After (works):
--base-lr 0.00003  # or 0.00001 for more conservative
```

### Secondary Fix: Reduce Batch Size

**Large batches can amplify gradient instability:**

```python
# Before:
--max-duration 500  # seconds per batch

# After:
--max-duration 300  # or 200 for very small datasets
```

### Additional Stabilization Techniques

1. **Gradient Clipping** (if supported by your framework):
   ```python
   --grad-clip 1.0  # Clip gradients to prevent explosion
   ```

2. **Warmup Period**:
   ```python
   --warmup-steps 1000  # Gradually increase LR at start
   ```

3. **Learning Rate Schedule**:
   ```python
   --lr-scheduler cosine  # Use LR decay instead of constant
   ```

### Diagnostic Commands

**Monitor gradient scale during training:**
```python
# Add to training loop to log grad_scale
if iteration % 50 == 0:
    print(f"Grad scale: {scaler.get_scale()}")
```

**Warning signs:**
- Grad scale drops below 1e-10: LR too high, reduce immediately
- Grad scale increases rapidly: LR too low, can increase
- Grad scale stable around 1e-4 to 1e-8: Good range

## Verification

**Expected behavior after fix:**
1. Training completes epoch 2 without gradient collapse
2. Grad scale remains in range 1e-6 to 1e-3
3. Loss decreases steadily (not NaN or infinity)

**Check training logs:**
```
# Before (failing):
Epoch 1, batch 50, grad_scale: 1.5e-10
Epoch 2, batch 10, grad_scale: 5.2e-26  # FAIL

# After (success):
Epoch 1, batch 50, grad_scale: 2.3e-6
Epoch 2, batch 50, grad_scale: 1.8e-6  # STABLE
```

## Example

**Scenario:** Fine-tuning ZipVoice TTS model for Malay language

**Initial Configuration (Failed):**
```bash
python3 -m zipvoice.bin.train_zipvoice \
    --finetune 1 \
    --base-lr 0.0001 \
    --max-duration 500 \
    --use-fp16 1
    # Fails at epoch 2 with grad_scale=5.2e-26
```

**Fixed Configuration:**
```bash
python3 -m zipvoice.bin.train_zipvoice \
    --finetune 1 \
    --base-lr 0.00003 \    # Reduced 3x
    --max-duration 300 \    # Smaller batches
    --use-fp16 1
    # Succeeds through all epochs
```

## Notes

**Why Fine-tuning is More Sensitive:**
- Pre-trained models already have optimized weights
- Large updates (high LR) disturb pre-learned features
- Small datasets provide fewer gradient samples → more variance
- FP16 has limited dynamic range (1e-5 to 6e4) vs FP32 (1e-38 to 1e38)

**Learning Rate Guidelines by Dataset Size:**

| Dataset Size | Recommended LR | Relative to Pre-training |
|--------------|----------------|-------------------------|
| < 5 hours | 1e-5 to 3e-5 | 10-30x lower |
| 5-20 hours | 3e-5 to 1e-4 | 3-10x lower |
| 20-100 hours | 5e-5 to 1e-4 | 2-5x lower |
| > 100 hours | 1e-4 to 2e-4 | 1-2x lower |

**If Reducing LR Doesn't Work:**
1. Check data quality (corrupt labels, audio issues)
2. Verify tokenization correct for your language
3. Ensure batch_size >= 4 (too small = unstable gradients)
4. Try disabling FP16 (`--use-fp16 0`) to debug
5. Check for NaN/Inf in input features

**Related Issues:**
- "Loss becomes NaN": Usually LR too high, drop more
- "Loss stays constant": LR too low, can increase slightly
- "Out of memory": Reduce batch size or model size

**Framework-Specific Notes:**

**PyTorch Native:**
```python
scaler = torch.cuda.amp.GradScaler()
# Monitor: scaler.get_scale()
```

**HuggingFace Transformers:**
```python
TrainingArguments(
    fp16=True,
    learning_rate=3e-5,  # Start conservative
    gradient_accumulation_steps=4,  # Simulates larger batch
)
```

**FastAI:**
```python
learn.to_fp16()
learn.fit_one_cycle(10, lr_max=3e-5)  # Lower max LR
```

## References

- [PyTorch Automatic Mixed Precision Recipe](https://docs.pytorch.org/tutorials/recipes/recipes/amp_recipe.html) - Official gradient scaling documentation
- [PyTorch Forum - Adam Stability in AMP](https://discuss.pytorch.org/t/the-problematic-adam-stability-in-automatic-mixed-precision-training/137434) - Community discussion on AMP stability
- [Medium - Mixed Precision Training Guide](https://medium.com/data-scientists-diary/what-every-user-should-know-about-mixed-precision-training-in-pytorch-63c6544e5a05) - Gradient underflow explanation
- [StackExchange - Mixed Precision Stability Tricks](https://datascience.stackexchange.com/questions/116679/training-tricks-for-increasing-stability-in-mixed-precision) - Practical tips
