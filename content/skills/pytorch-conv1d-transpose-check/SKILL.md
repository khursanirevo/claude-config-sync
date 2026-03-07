---
name: pytorch-conv1d-transpose-check
description: |
  Debug Conv1d input shape mismatches in PyTorch. Use when: (1) Runtime error
  "Expected 3D input but got XD tensor" or shape mismatch, (2) mel-spectrogram
  or audio feature tensors causing Conv1d failures, (3) Error messages show
  unexpected dimension order like [batch, time, channels] vs [batch, channels, time].
  Check model code for internal transpose operations before fixing dataset shapes.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# PyTorch Conv1d Input Shape Debugging

## Problem
When debugging Conv1d input shape errors in PyTorch, it's tempting to fix the shape in your dataset/collate function. However, many models perform transpose operations internally, so the "fix" may actually break the model's expected input format.

## Context / Trigger Conditions
- **Error messages**: "RuntimeError: Expected 3D (unbatched) or 4D (batched) input", "Given groups=1, weight of size [X, Y, Z], expected input[B, C, L] to have Y channels"
- **Tensors involved**: mel-spectrograms, audio features, or any sequential data with shape [batch, time, features]
- **Common scenario**: You transpose your tensor to `[batch, channels, time]` format but still get shape errors
- **Model types**: Speaker encoders, audio models, any architecture using Conv1d layers

## Solution

### Step 1: Check Model Code for Internal Transpose
Before modifying your dataset, grep the model code for transpose operations:

```bash
# Search for transpose near the Conv1d layer
grep -n "transpose" model_file.py
# Or check the forward method specifically
grep -A 20 "def forward" model_file.py | grep -i transpose
```

**Key pattern**: Look for `x = x.transpose(1, 2)` or `x = x.permute(...)` right before Conv1d calls.

### Step 2: Understand the Expected Input Format

**Conv1d standard format**: `(batch_size, channels, length)`
- `batch_size`: Number of samples
- `channels`: Feature dimension (e.g., mel_bands=128)
- `length`: Temporal dimension (variable)

**Common formats in speech models**:
- `[batch, time, mel_bands]` → Model internally transposes to Conv1d format
- `[batch, mel_bands, time]` → Direct Conv1d input

### Step 3: Match Dataset Output to Model Expectations

**If model has internal transpose**:
```python
# Keep your data in [batch, time, channels] format
ref_mels = torch.cat(ref_mels_padded, dim=0)  # [batch, max_time, 128]
# Model will handle: x = x.transpose(1, 2) internally
```

**If model has NO internal transpose**:
```python
# Pre-transpose to [batch, channels, time] format
ref_mels = ref_mels.transpose(1, 2)  # [batch, time, channels] -> [batch, channels, time]
```

### Step 4: Verify at Multiple Points

Add debug prints to trace shape transformations:
```python
# In dataset __getitem__
print(f"After extract_mels: {ref_mel.shape}")

# In collate_fn
print(f"After padding: {ref_mels_padded[0].shape}")
print(f"After cat: {ref_mels.shape}")

# In model forward (if accessible)
print(f"Before Conv1d: {x.shape}")
```

## Example

**Scenario**: Qwen3-TTS fine-tuning with speaker encoder Conv1d error

**Initial approach (WRONG)**:
```python
# In dataset.py
ref_mel = self.extract_mels(audio=wav, sr=sr)
ref_mel = ref_mel.transpose(1, 2)  # [1, time, 128] -> [1, 128, time]
```

**Error received**:
```
RuntimeError: Given groups=1, weight of size [512, 128, 3], expected input[4, 883, 132] to have 128 channels
```
Wait—the model received `[4, 883, 132]` not `[4, 128, time]`? Something transformed it.

**Root cause found** (modeling_qwen3_tts.py:338):
```python
# In speaker_encoder forward method
x = x.transpose(1, 2)  # Converts [batch, time, mel_bands] to [batch, mel_bands, time]
```

**Correct fix**:
```python
# Remove the transpose from dataset.py
ref_mel = self.extract_mels(audio=wav, sr=sr)
# Keep as [1, time, 128] - model will transpose internally

# In collate_fn, pad on time dimension (dim 1)
ref_mels_padded = [F.pad(mel, (0, 0, 0, max_time - mel.shape[1])) for mel in ref_mels]
ref_mels = torch.cat(ref_mels_padded, dim=0)  # [batch, max_time, 128]
```

## Verification

After applying the fix:
1. Add debug print at first model forward call
2. Verify tensor shape matches what Conv1d expects
3. Training should proceed without shape errors
4. Check that loss values are reasonable (not NaN/Inf)

## Notes

- **Channels-first vs channels-last**: PyTorch uses channels-first `[B, C, L]` unlike Keras/TensorFlow's channels-last convention
- **contiguous() after transpose**: When transposing for Conv1d input, use `.transpose(1, 2).contiguous()` to ensure memory layout is correct
- **Batch dimensions**: Collate functions often introduce shape changes—trace through both dataset output AND collate output
- **Layer-specific**: This applies to Conv1d, ConvTranspose1d, and any channel-based convolution
- **Model type inconsistency**: Different model architectures (Base vs CustomVoice vs VoiceDesign) may handle shapes differently

## References

- [Conv1d — PyTorch 2.10 documentation](https://docs.pytorch.org/docs/stable/generated/torch.nn.Conv1d.html) - Official Conv1d input format requirements
- [Understanding input shape to PyTorch conv1D? - StackOverflow](https://stackoverflow.com/questions/62372938/understanding-input-shape-to-pytorch-conv1d) - Discussion on transpose pattern: `input = input.transpose(1, 2).contiguous()`
- [Understanding input shape to PyTorch conv1D? - PyTorch Forums](https://discuss.pytorch.org/t/understanding-input-shape-to-pytorch-conv1d/85429) - Community thread on handling text sequences with Conv1d
- [How To Debug PyTorch Shape Mismatch Errors](https://apxml.com/posts/pytorch-shape-mismatch-error-debug-fix) - Practical debugging methods (April 2025)
