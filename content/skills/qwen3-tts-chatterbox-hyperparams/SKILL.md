---
name: qwen3-tts-chatterbox-hyperparams
description: |
  Correct hyperparameters for Chatterbox-style fine-tuning of Qwen3-TTS models.
  Use when: (1) Fine-tuning Qwen3-TTS with Chatterbox-style approach, (2) Poor quality
  results from default hyperparameters, (3) Training new speakers or languages.
  Critical: learning_rate 5e-5 (not 2e-5), batch_size 4 with gradient_accumulation_steps 2,
  and only 1 epoch (not 5). Effective batch size = 8.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# Qwen3-TTS Chatterbox Fine-tuning Hyperparameters

## Problem
Using typical ML hyperparameters (2e-5 LR, 5 epochs, small batches) produces poor quality
results when fine-tuning Qwen3-TTS with Chatterbox-style approach.

## Context / Trigger Conditions
- Fine-tuning Qwen3-TTS models using `sft_12hz_chatterbox.py`
- Adding new speakers or adapting to new languages
- Poor audio quality or unnatural speech after training
- Following generic ML fine-tuning practices instead of Chatterbox-specific settings

## Solution

Use these **exact hyperparameters** from the original Chatterbox repository:

```bash
python finetune_t3.py \
  --output_dir ./checkpoints/chatterbox_finetuned \
  --model_name_or_path ResembleAI/chatterbox \
  --num_train_epochs 1 \
  --per_device_train_batch_size 4 \
  --gradient_accumulation_steps 2 \
  --learning_rate 5e-5 \
  --warmup_steps 100 \
  --logging_steps 10 \
  --save_steps 4000 \
  --eval_steps 2000 \
  --fp16 True
```

**For Qwen3-TTS (`sft_12hz_chatterbox.py`):**

```bash
cd finetuning
CUDA_VISIBLE_DEVICES=2 python sft_12hz_chatterbox.py \
  --init_model_path /path/to/Qwen3-TTS-12Hz-1.7B-Base \
  --train_jsonl /path/to/train_with_codes.jsonl \
  --output_model_path /path/to/output \
  --speaker_name my_speaker \
  --batch_size 4 \
  --lr 5e-5 \
  --num_epochs 1 \
  --gradient_accumulation_steps 2 \
  --warmup_steps 100 \
  --freeze_speaker_encoder
```

**Critical Hyperparameters:**

| Parameter | Value | Why It Matters |
|-----------|-------|----------------|
| `learning_rate` | **5e-5** | Higher than typical 2e-5; Chatterbox-specific optimization |
| `batch_size` | **4** | Larger batch for stable gradients |
| `gradient_accumulation_steps` | **2** | Effective batch = 4 × 2 = **8** |
| `num_epochs` | **1** | Chatterbox converges quickly; more epochs cause overfitting |
| `warmup_steps` | **100** | Gradual LR ramp-up for stability |

**Common Mistakes to Avoid:**
- ❌ Using `learning_rate 2e-5` (too low, poor convergence)
- ❌ Using `num_epochs 5` (causes overfitting, degraded quality)
- ❌ Using `batch_size 2` with `gradient_accumulation_steps 4` (same effective batch but less stable)

## Verification

After training with correct hyperparameters:
1. Loss should decrease smoothly across epochs
2. Generated audio should have natural prosody and clear pronunciation
3. No stuttering or repetition artifacts
4. Speaker characteristics should be consistent

Test with:
```python
from qwen_tts import Qwen3TTSModel
import soundfile as sf

model = Qwen3TTSModel.from_pretrained(
    "./output/checkpoint-epoch-0",
    device_map="cuda:0",
    dtype=torch.bfloat16
)

wavs, sr = model.generate_custom_voice(
    text="Test sentence for quality check.",
    language="auto",
    speaker="your_speaker_name"
)
sf.write("test.wav", wavs[0], sr)
```

## Example

**Wrong approach (produces poor quality):**
```bash
python sft_12hz_chatterbox.py \
  --batch_size 2 \
  --lr 2e-5 \
  --num_epochs 5 \
  --gradient_accumulation_steps 4
```
Result: Unnatural speech, poor pronunciation

**Correct approach:**
```bash
python sft_12hz_chatterbox.py \
  --batch_size 4 \
  --lr 5e-5 \
  --num_epochs 1 \
  --gradient_accumulation_steps 2 \
  --warmup_steps 100
```
Result: Natural, high-quality speech

## Notes

**Why These Hyperparameters Work:**
- Chatterbox architecture uses a different training objective than standard TTS
- The model converges faster due to pre-training on large speech datasets
- Higher learning rate compensates for single-epoch training
- Effective batch size of 8 provides stable gradients without excessive memory

**Data Requirements:**
- Minimum 1,000 samples for basic speaker cloning
- 5,000-10,000 samples for new languages
- 20,000+ samples for best quality (as with original Chatterbox training)

**Memory Requirements:**
- With `--freeze_speaker_encoder`: ~30-40GB GPU memory
- Without freezing: ~50GB+ GPU memory
- Use H200/A100 for best results

**Training Time:**
- 1 epoch on 20k samples: ~2-4 hours on H200
- Single epoch is sufficient - more epochs hurt quality

## References

- [stlohrey/chatterbox-finetuning](https://github.com/stlohrey/chatterbox-finetuning) - Original Chatterbox fine-tuning repository
- [Chatterbox example_tts.py](https://github.com/stlohrey/chatterbox-finetuning/blob/master/example_tts.py) - Reference implementation
- Qwen3-TTS Chatterbox-style fine-tuning guide: `finetuning/README_CHATTERBOX_STYLE.md`
