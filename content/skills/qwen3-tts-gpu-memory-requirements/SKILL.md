---
name: qwen3-tts-gpu-memory-requirements
description: |
  GPU memory requirements for Qwen3-TTS audio code extraction during Chatterbox-style
  fine-tuning. Use when: (1) torch.OutOfMemoryError during prepare_data.py, (2) planning
  Chatterbox-style fine-tuning with Qwen3-TTS, (3) GPU has less than 100GB free memory.
  Covers tokenizer memory requirements, batch size limitations, and workaround strategies.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# Qwen3-TTS GPU Memory Requirements for Audio Code Extraction

## Problem
When attempting Chatterbox-style fine-tuning with Qwen3-TTS, the audio code extraction
step (`prepare_data.py`) fails with `torch.OutOfMemoryError` even with minimal batch sizes.

## Context / Trigger Conditions
- Running `finetuning/prepare_data.py` to extract audio codes
- GPU has 50-80GB free memory (seems sufficient but isn't)
- Error occurs even with `BATCH_INFER_NUM = 1`
- Another process may be using 30-70GB on the same GPU

**Error message:**
```
torch.OutOfMemoryError: CUDA out of memory. Tried to allocate 9.32 GiB.
GPU 0 has a total capacity of 139.80 GiB of which 1.49 GiB is free.
```

## Root Cause
The Qwen3-TTS tokenizer (Qwen/Qwen3-TTS-Tokenizer-12Hz) has significant memory requirements:

| Component | Memory Required |
|-----------|-----------------|
| Tokenizer model load | ~60-70GB |
| Batch processing (even batch=1) | ~9-10GB |
| PyTorch overhead | ~2-5GB |
| **Total minimum** | **~100GB** |

**Key insight:** Reducing batch size doesn't help because the tokenizer itself needs 60-70GB
just to load into memory. The bottleneck is model size, not batch size.

## Solution

### Option 1: Wait for GPU with 100GB+ Free Memory (Recommended)

Monitor GPU availability:
```bash
# Check all GPUs
nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits

# Monitor continuously
watch -n 10 nvidia-smi

# Find GPU with most free memory
BEST_GPU=$(nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits | sort -t',' -k2 -rn | head -1 | cut -d',' -f1)
```

**Required:** GPU with 100GB+ free memory

### Option 2: Use Text-Embedding Only Approach (Fallback)

If GPU memory is limited, use the text-embedding approach which doesn't require audio code extraction:

```bash
cd finetuning

CUDA_VISIBLE_DEVICES=1 ../.venv/bin/python ft_text_embedding.py \
  --init_model_path Qwen/Qwen3-TTS-12Hz-1.7B-Base \
  --train_jsonl ../malay_text_only.jsonl \
  --output_model_path ../output_malay_text_ft \
  --language Malay \
  --batch_size 2 \
  --gradient_accumulation_steps 4 \
  --lr 1e-4 \
  --num_epochs 3
```

**Memory required:** ~10GB
**Trade-off:** Trains on synthetic loss instead of real audio, quality unknown

### Option 3: Selective Freezing During Training

While this doesn't solve the audio code extraction issue, it helps during the training phase:

```bash
python sft_12hz_chatterbox.py \
  --freeze_speaker_encoder \      # Saves ~8GB
  --freeze_talker_llm \            # Saves ~30GB
  --train_text_embedding_only \    # Only uses ~10GB total
  ...
```

## What Doesn't Work

These approaches will NOT solve the OOM during audio code extraction:

❌ Reducing batch size (already at minimum 1)
❌ Gradient accumulation (doesn't affect tokenizer memory)
❌ Mixed precision (already using BF16)
❌ Killing other processes (unless you have permission)

## Verification

After finding suitable GPU:

```bash
# Verify GPU has enough memory
nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits | grep $BEST_GPU

# Should show 100GB+ free, e.g.:
# 1, 102400

# Run extraction
CUDA_VISIBLE_DEVICES=$BEST_GPU ../.venv/bin/python prepare_data.py \
  --device cuda:0 \
  --tokenizer_model_path Qwen/Qwen3-TTS-Tokenizer-12Hz \
  --input_jsonl ../malay_train_raw.jsonl \
  --output_jsonl ../malay_train_with_codes.jsonl

# Should complete without OOM
```

## Example

**Scenario:** You want to fine-tune Qwen3-TTS for Malay language using Chatterbox-style approach.
GPU 0 has 70GB free, GPU 1 has 71GB free.

**Wrong approach:**
```bash
# Try reducing batch size
BATCH_INFER_NUM = 1  # Still OOM!
```

**Correct approach:**
```bash
# Check if any GPU has 100GB+ free
nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits

# Output:
# 0, 71680  # Only 70GB - not enough!
# 1, 73216  # Only 71GB - not enough!
# 2, 4226   # Way too little
# 3, 4656   # Way too little

# Result: Need to wait for GPU availability or use text-embedding fallback
```

## Notes

### Architecture Difference: Chatterbox vs Qwen3-TTS

**Chatterbox:**
- Processes audio on-the-fly during training loop
- S3Tokenizer runs in the same process as training
- Memory usage is spread across training

**Qwen3-TTS:**
- Requires offline audio code extraction BEFORE training
- Tokenizer is a separate step (`prepare_data.py`)
- Needs full model in memory upfront

This is why Qwen3-TTS has higher upfront memory requirements.

### Batch Size Tuning

Once audio codes are extracted, batch size for the actual training can be adjusted:

| Training batch size | GPU memory needed |
|---------------------|-------------------|
| 2 | ~40-50GB |
| 1 | ~30-40GB |
| With `--freeze_talker_llm` | ~10-15GB |

The training phase is more flexible than the audio code extraction phase.

### Memory Profiling

To see exactly how much memory the tokenizer needs:

```python
import torch
from qwen_tts import Qwen3TTSTokenizer

tokenizer = Qwen3TTSTokenizer.from_pretrained(
    "Qwen/Qwen3-TTS-Tokenizer-12Hz",
    device_map="cuda:0"
)

# Check memory before and after
print(torch.cuda.memory_allocated() / 1024**3)  # Should show ~60-70GB
```

## References

- Qwen3-TTS Documentation: https://github.com/QwenLM/Qwen3-TTS
- Chatterbox Fine-tuning: https://github.com/stlohrey/chatterbox-finetuning
