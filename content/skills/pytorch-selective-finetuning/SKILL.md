---
name: pytorch-selective-finetuning
description: |
  Fix for "ValueError: can't optimize a non-leaf Tensor" when fine-tuning specific
  layers from PyTorch checkpoints. Use when: (1) loading pretrained models and training
  only specific layers, (2) creating trainable parameters from checkpoint state_dict,
  (3) transfer learning with partial layer updates, (4) getting non-leaf tensor errors
  with optimizer. Covers nn.Parameter creation, leaf tensors, and selective fine-tuning.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# PyTorch Selective Fine-Tuning from Checkpoints

## Problem
When loading a pretrained checkpoint and trying to fine-tune only specific layers,
you encounter: `ValueError: can't optimize a non-leaf Tensor`. This happens when
you try to add tensors directly from a state_dict to an optimizer without properly
converting them to trainable parameters.

## Context / Trigger Conditions
- Loading a `.pth` or `.pt` checkpoint with `torch.load()`
- Wanting to fine-tune only certain layers (e.g., encoder output, classifier head)
- Using `state_dict[key].clone().requires_grad_(True)` on checkpoint tensors
- Error appears when calling `optimizer = torch.optim.Adam(trainable_params.values())`
- Common in transfer learning, model adaptation, and continual learning scenarios

## Solution

### The Error
```python
# ❌ WRONG - Creates non-leaf tensor
checkpoint = torch.load('model.pth', map_location='cpu')
trainable_params = {}
for key in ['layer1.weight', 'layer2.weight']:
    param = checkpoint[key].clone().requires_grad_(True)
    trainable_params[key] = param

optimizer = torch.optim.Adam(trainable_params.values())
# ValueError: can't optimize a non-leaf Tensor
```

### The Fix
```python
# ✅ CORRECT - Creates leaf tensor with nn.Parameter
checkpoint = torch.load('model.pth', map_location='cpu')
trainable_params = {}
for key in ['layer1.weight', 'layer2.weight']:
    # Extract data, clone it, wrap in nn.Parameter
    param_data = checkpoint[key].data.clone()
    param = torch.nn.Parameter(param_data)
    trainable_params[key] = param

optimizer = torch.optim.Adam(trainable_params.values())
# ✓ Works!
```

### Complete Pattern for Selective Fine-Tuning

```python
import torch
from torch.utils.data import DataLoader
from pathlib import Path

class SelectiveFinetuner:
    """Fine-tune specific layers from a checkpoint"""

    def __init__(self, checkpoint_path, trainable_keys, device='cpu'):
        # Load checkpoint
        self.checkpoint = torch.load(checkpoint_path, map_location='cpu', weights_only=False)
        self.device = device

        # Create trainable parameters from checkpoint
        self.trainable_params = {}
        for key in trainable_keys:
            if key in self.checkpoint:
                # Critical: Create leaf tensor properly
                param_data = self.checkpoint[key].data.clone().to(device)
                param = torch.nn.Parameter(param_data)
                self.trainable_params[key] = param

        # Create optimizer
        self.optimizer = torch.optim.Adam(
            self.trainable_params.values(),
            lr=2e-4,
            betas=(0.8, 0.99)
        )

    def train_step(self, batch):
        """Training step that only updates trainable layers"""
        # Forward pass
        loss = self.compute_loss(batch)

        # Backward
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        # Update checkpoint with new values
        for key in self.trainable_params:
            self.checkpoint[key] = self.trainable_params[key].detach().cpu()

        return loss.item()

    def save_checkpoint(self, save_path):
        """Save updated checkpoint"""
        torch.save({
            'state_dict': self.checkpoint,
            'trainable_keys': list(self.trainable_params.keys())
        }, save_path)
```

### Identifying Trainable Layers

```python
# Select which layers to fine-tune
checkpoint = torch.load('model.pth', map_location='cpu')

# Option 1: Fine-tune specific named layers
trainable_keys = [k for k in checkpoint.keys()
                  if any(x in k for x in ['encoder.proj', 'decoder.final', 'classifier'])]

# Option 2: Fine-tune layers matching pattern
import re
trainable_keys = [k for k in checkpoint.keys()
                  if re.match(r'enc_p\..*\.proj', k)]

# Option 3: All except frozen layers
frozen_patterns = ['encoder.embed', 'decoder.upsampling']
trainable_keys = [k for k in checkpoint.keys()
                  if not any(p in k for p in frozen_patterns)]

print(f"Training {len(trainable_keys)}/{len(checkpoint)} parameters")
```

## Verification

### Check if tensors are leaf tensors
```python
# Verify fix worked
for key, param in trainable_params.items():
    assert param.is_leaf, f"{key} is not a leaf tensor!"
    assert param.requires_grad, f"{key} doesn't require grad!"
    print(f"✓ {key}: leaf={param.is_leaf}, requires_grad={param.requires_grad}")
```

### Training loop test
```python
# Should run without errors
for batch in dataloader:
    loss = train_step(batch)
    print(f"Loss: {loss:.4f}")
    break  # Test one batch
```

## Example: Fine-Tuning VITS Model

```python
# Real example from VITS-osman fine-tuning
import torch

# Load VITS checkpoint
checkpoint = torch.load('vits_osman.pth', map_location='cpu')

# Select layers to fine-tune (encoder output, flow model, decoder output)
trainable_keys = [k for k in checkpoint.keys()
                  if any(x in k for x in ['enc_p.proj', 'flow.flows', 'dec.conv_post'])]

print(f"Fine-tuning {len(trainable_keys)} parameters")

# Create trainable parameters
trainable_params = {}
for key in trainable_keys:
    param_data = checkpoint[key].data.clone().to('cuda')
    param = torch.nn.Parameter(param_data)
    trainable_params[key] = param

# Optimizer
optimizer = torch.optim.Adam(trainable_params.values(), lr=2e-4)

# Training loop
for epoch in range(10):
    for batch in dataloader:
        loss = compute_loss(batch)  # Your loss function

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        # Update checkpoint
        for key in trainable_params:
            checkpoint[key] = trainable_params[key].detach().cpu()
```

## Notes

### Why This Happens
- PyTorch optimizers can only optimize **leaf tensors** (tensors created by users, not results of operations)
- `checkpoint[key].clone().requires_grad_(True)` creates a tensor, but it's not a leaf because it came from another tensor
- `nn.Parameter()` explicitly creates a leaf tensor that tracks gradients

### When to Use This Pattern
- **Transfer learning**: Load pretrained model, train only the classifier head
- **Model adaptation**: Fine-tune specific layers for new domain
- **Continual learning**: Update parts of model without catastrophic forgetting
- **Layer freezing**: Keep most layers frozen, train only a few

### Alternative Approach: requires_grad=False
```python
# Another pattern: Load entire model, freeze most layers
model = load_model('checkpoint.pth')

# Freeze all layers
for param in model.parameters():
    param.requires_grad = False

# Unfreeze specific layers
for name, param in model.named_parameters():
    if 'encoder.output' in name or 'classifier' in name:
        param.requires_grad = True

# Optimizer will only update unfrozen layers
optimizer = torch.optim.Adam(
    [p for p in model.parameters() if p.requires_grad],
    lr=1e-4
)
```

### Memory Considerations
- Only trainable parameters need gradients (saves memory)
- Frozen parameters can be moved to CPU if needed
- Use `torch.cuda.empty_cache()` after freezing layers

### Performance Tips
- Use smaller learning rates for pretrained layers (1e-4 to 1e-5)
- Consider discriminative learning rates (different lr for different layer groups)
- Monitor overfitting when training on small datasets

## References

- [PyTorch Discussion: ValueError: can't optimize a non-leaf Tensor](https://discuss.pytorch.org/t/valueerror-cant-optimize-a-non-leaf-tensor/21751)
- [StackOverflow: "can't optimize a non-leaf Tensor" on torch Parameter](https://stackoverflow.com/questions/72679858/cant-optimize-a-non-leaf-tensor-on-torch-parameter)
- [PyTorch Tutorial: Understanding Leaf vs Non-leaf Tensors](https://docs.pytorch.org/tutorials/beginner/understanding_leaf_vs_nonleaf_tutorial.html)
- [PyTorch Docs: torch.Tensor.is_leaf](https://docs.pytorch.org/docs/stable/generated/torch.Tensor.is_leaf.html)
- [PyTorch Discussion: Loading a specific layer from checkpoint](https://discuss.pytorch.org/t/loading-a-specific-layer-from-checkpoint/52725)
- [PyTorch Blog: torchtune for fine-tuning LLMs](https://pytorch.org/blog/torchtune-fine-tune-llms/)
