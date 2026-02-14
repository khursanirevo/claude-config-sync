---
name: pytorch-dataloader-padding-3d-tensors
description: |
  Fix "RuntimeError: stack expects each tensor to be equal size" in PyTorch
  DataLoader when batching variable-length 3D sequences. Use when: (1) batching
  tensors with shape [batch, time, features] where time dimension varies,
  (2) implementing custom collate_fn for audio/video/sequence data,
  (3) F.pad not working as expected with multi-dimensional tensors. Covers
  torch.nn.functional.pad tuple semantics for n-D tensors.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# PyTorch DataLoader: Padding Variable-Length 3D Tensors

## Problem

When batching variable-length sequences (audio, video, time-series) in PyTorch DataLoader,
you encounter:

```
RuntimeError: stack expects each tensor to be equal size, but got
  [1, 942, 128] at entry 0 and [1, 1257, 128] at entry 1
```

The `collate_fn` fails because samples have different time dimensions and cannot be
stacked directly.

## Context / Trigger Conditions

- **Error message**: `RuntimeError: stack expects each tensor to be equal size`
- **Data shape**: 3D tensors with format `[batch, time, features]` where time varies
- **Use cases**: Audio spectrograms, video frames, time-series features, sequences
- **Location**: Custom `collate_fn` in PyTorch Dataset/DataLoader

## Solution

### Understanding F.pad Tuple Semantics

For `torch.nn.functional.pad`, the padding tuple is specified in **reverse order of dimensions**:

```python
# For 3D tensor [batch, time, features]:
# F.pad(tensor, (left, right, top, bottom, front, back))
#                ^^^^^^^^  ^^^^^^^^^  ^^^^^^^^^^^^
#                dim 2      dim 1       dim 0

# To pad on dimension 1 (time):
F.pad(tensor, (0, 0, 0, padding_needed))
#              ^^^^^  ^^^^^^^^^^^^^^^^^^^
#              dim 2  dim 1
```

### Correct collate_fn Pattern

```python
def collate_fn(self, batch):
    # Extract variable-length tensors
    tensors = [item['tensor'] for item in batch]

    # Find max time dimension in this batch
    max_time = max(t.shape[1] for t in tensors)  # Shape is [batch, time, features]

    # Pad each tensor to max_time
    # For [batch, time, features], use: (left, right, top, bottom)
    tensors_padded = [
        F.pad(t, (0, 0, 0, max_time - t.shape[1]))  # Pad on time dimension only
        for t in tensors
    ]

    # Stack into batch
    batch_tensor = torch.stack(tensors_padded, dim=0)  # [batch_size, max_time, features]

    return batch_tensor
```

### Common Mistakes

❌ **Wrong dimension index**:
```python
max_time = max(mel.shape[2] for mel in ref_mels)  # WRONG if shape is [batch, time, features]
```

❌ **Wrong padding tuple length** (common error):
```python
F.pad(mel, (0, 0, max_time - mel.shape[2]))  # WRONG - 3 elements for 3D tensor
```

❌ **Using torch.cat instead of torch.stack**:
```python
torch.cat(ref_mels_padded, dim=0)  # Works but less safe - concatenates along existing dim
torch.stack(ref_mels_padded, dim=0)  # BETTER - creates new batch dimension
```

## Verification

After fixing, the DataLoader should:
1. Successfully batch samples without size mismatch errors
2. Return tensors with shape `[batch_size, max_time, num_features]`
3. Preserve all original data (padded with zeros)

Check output:
```python
for batch in dataloader:
    print(batch.shape)  # Should be [batch_size, fixed_time, features]
    assert batch.shape[1] == max_time  # All batches have consistent time dim
```

## Example

### Mel Spectrogram Padding (Audio TTS)

```python
import torch
import torch.nn.functional as F

class TTSDataset(Dataset):
    def extract_mels(self, audio, sr):
        """Extract mel spectrogram - returns [1, time, 128] after transpose"""
        mels = mel_spectrogram(
            torch.from_numpy(audio).unsqueeze(0),
            n_fft=1024, num_mels=128, sampling_rate=24000,
            hop_size=256, win_size=1024, fmin=0, fmax=12000
        ).transpose(1, 2)  # [1, 128, time] -> [1, time, 128]
        return mels

    def collate_fn(self, batch):
        # Collect mel specs from batch
        ref_mels = [data['ref_mel'] for data in batch]

        # Shape is [1, time, 128] - find max time dimension
        max_time = max(mel.shape[1] for mel in ref_mels)

        # Pad each mel to max_time on the time dimension (dim 1)
        # F.pad tuple for 3D: (left, right, top, bottom, front, back)
        ref_mels_padded = [
            F.pad(mel, (0, 0, 0, max_time - mel.shape[1]))  # Pad time dim only
            for mel in ref_mels
        ]

        # Stack into batch: [batch_size, max_time, 128]
        ref_mels = torch.stack(ref_mels_padded, dim=0)

        return {'ref_mels': ref_mels, **other_data}
```

## Notes

### F.pad Tuple Semantics by Dimensionality

| Tensor Dim | Padding Tuple | Meaning |
|------------|---------------|---------|
| 1D `[time]` | `(left, right)` | Pad last dim (time) |
| 2D `[time, features]` | `(left, right, top, bottom)` | Pad dim 1 then dim 0 |
| 3D `[batch, time, features]` | `(left, right, top, bottom, front, back)` | Pad dim 2, 1, 0 |
| 4D `[batch, channels, H, W]` | `(left, right, top, bottom, front, back, ...)` | Pad dim 3, 2, 1, 0 |

**Key insight**: Padding tuple applies from **last dimension backward**.

### Alternative: torch.nn.utils.rnn.pad_sequence

For RNN/LSTM/Transformer inputs, PyTorch provides a helper:

```python
from torch.nn.utils.rnn import pad_sequence

sequences = [torch.randn(t, 128) for t in [942, 1257, 876]]  # Variable length
padded = pad_sequence(sequences, batch_first=True)  # [3, 1257, 128]
```

This is cleaner but requires specific tensor layouts (sequence-first or batch-first).

### Performance Considerations

- **Dynamic padding per batch** (shown above): More efficient, but batches have varying sizes
- **Global padding to max length**: Simpler, wastes computation on padding
- **Bucketing by length**: Middle ground - group similar-length sequences together

## References

- [PyTorch torch.nn.functional.pad Documentation](https://docs.pytorch.org/docs/stable/generated/torch.nn.functional.pad.html)
- [PyTorch Discussion: DataLoader for various length of data](https://discuss.pytorch.org/t/dataloader-for-various-length-of-data/6418)
- [PyTorch Discussion: How to use collate_fn()](https://discuss.pytorch.org/t/how-to-use-collate-fn/27181)
- [Stack Overflow: Create padded tensor from variable length sequences](https://stackoverflow.com/questions/52235928/pytorch-create-padded-tensor-from-sequences-of-variable-length)
- [Use PyTorch's DataLoader with Variable Length Sequences](https://www.codefull.net/2018/11/use-pytorchs-dataloader-with-variable-length-sequences-for-lstm-gru/)
- [PyTorch torch.nn.utils.rnn.pad_sequence Documentation](https://docs.pytorch.org/docs/stable/generated/torch.nn.utils.rnn.pad_sequence.html)
