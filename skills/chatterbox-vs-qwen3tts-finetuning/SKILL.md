---
name: chatterbox-vs-qwen3tts-finetuning
description: |
  Architectural differences between Chatterbox and Qwen3-TTS fine-tuning approaches.
  Use when: (1) Choosing between fine-tuning strategies, (2) Understanding GPU memory
  requirements, (3) Planning TTS fine-tuning workflow. Covers data preparation, audio
  tokenization differences, and training pipeline variations.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# Chatterbox vs Qwen3-TTS Fine-tuning Architectures

## Problem
Understanding the key differences between Chatterbox and Qwen3-TTS fine-tuning approaches
to choose the right strategy and set proper expectations for GPU memory and workflow.

## Context / Trigger Conditions
- Planning TTS fine-tuning for new language or speaker
- Deciding between Chatterbox-style vs other approaches
- Confused about why Qwen3-TTS needs audio code extraction
- Estimating GPU memory requirements for fine-tuning

## Key Architectural Differences

### Audio Processing Approach

| Aspect | Chatterbox | Qwen3-TTS |
|--------|-----------|-----------|
| **When audio is tokenized** | During training loop | Before training (offline) |
| **Tokenizer location** | In training script | Separate `prepare_data.py` |
| **Token storage** | Temporary (in-memory) | Permanent (in JSONL) |
| **Re-tokenization** | Every epoch | Once, then reused |

**Impact:** Qwen3-TTS requires more upfront GPU memory for tokenization but is more
efficient for multiple training runs.

### Data Format Requirements

**Chatterbox:**
```json
{
  "audio": "path/to/audio.wav",
  "text": "Transcript here",
  "ref_audio": "path/to/reference.wav"
}
```
- Audio files loaded during training
- Tokenization happens on-the-fly

**Qwen3-TTS:**
```json
{
  "audio": "path/to/audio.wav",
  "text": "Transcript here",
  "ref_audio": "path/to/reference.wav",
  "audio_codes": [[...], [...], ...]  // Pre-extracted!
}
```
- Audio codes must be pre-extracted
- Two-step process: extract → train

### Training Pipeline

**Chatterbox Pipeline:**
```
1. Prepare JSONL with {audio, text, ref_audio}
2. Run training (tokenization happens during training)
   - For each batch:
     a. Load audio files
     b. Extract speaker embeddings
     c. Tokenize speech with S3Tokenizer
     d. Train with teacher forcing
```

**Qwen3-TTS Pipeline:**
```
1. Prepare JSONL with {audio, text, ref_audio}
2. Extract audio codes (prepare_data.py)
   - Load ALL audio files
   - Tokenize with 12Hz tokenizer
   - Save codes to JSONL
3. Run training
   - Load pre-extracted codes
   - Train with teacher forcing
```

### Memory Usage Pattern

**Chatterbox:**
- Peak memory: ~30-40GB during training
- Tokenizer memory: Included in training memory
- Can start with lower GPU memory

**Qwen3-TTS:**
- Step 1 (extract): ~100GB+ for tokenization
- Step 2 (train): ~40-50GB for training
- Requires high GPU memory upfront

### Selective Freezing Support

Both support selective freezing, but implementation differs:

**Chatterbox:**
```python
freeze_voice_encoder = True  # Speaker encoder
freeze_s3gen = True          # Decoder/vocoder
# T3 model trains
```

**Qwen3-TTS:**
```bash
--freeze_speaker_encoder     # Equivalent to voice_encoder
--freeze_talker_llm          # LLM layers
--freeze_code_predictor      # Audio token predictor
--train_text_embedding_only   # Only text embedding
```

## When to Use Which Approach

### Use Chatterbox-Style (Qwen3-TTS) When:

✅ You have GPU with 100GB+ free memory
✅ You want to train multiple times (codes extracted once)
✅ You need proven quality (teacher forcing on real audio)
✅ You have limited training time

### Use Text-Embedding Only When:

✅ GPU memory is limited (~10GB available)
✅ You only have text data (no audio)
✅ Quick experimentation needed
✅ Quality requirements are flexible

## Workflow Comparison

### Chatterbox-Style (Qwen3-TTS) Complete Workflow

```bash
# Step 1: Prepare data with audio paths
python prepare_malay_audio_text_data.py \
  --audio_dir Malay_spoken \
  --output_jsonl malay_train_raw.jsonl

# Step 2: Extract audio codes (REQUIRES 100GB+ GPU)
cd finetuning
CUDA_VISIBLE_DEVICES=0 ../.venv/bin/python prepare_data.py \
  --device cuda:0 \
  --tokenizer_model_path Qwen/Qwen3-TTS-Tokenizer-12Hz \
  --input_jsonl ../malay_train_raw.jsonl \
  --output_jsonl ../malay_train_with_codes.jsonl

# Step 3: Train model (50GB GPU sufficient)
CUDA_VISIBLE_DEVICES=0 ../.venv/bin/python sft_12hz_chatterbox.py \
  --init_model_path Qwen/Qwen3-TTS-12Hz-1.7B-Base \
  --train_jsonl ../malay_train_with_codes.jsonl \
  --output_model_path ../output \
  --speaker_name malay_speaker \
  --batch_size 2 \
  --lr 2e-5 \
  --num_epochs 5 \
  --freeze_speaker_encoder
```

### Text-Embedding Only Workflow (Simpler)

```bash
# Step 1: Prepare text-only data
python prepare_malay_text_data.py

# Step 2: Train directly (10GB GPU sufficient)
cd finetuning
CUDA_VISIBLE_DEVICES=0 ../.venv/bin/python ft_text_embedding.py \
  --init_model_path Qwen/Qwen3-TTS-12Hz-1.7B-Base \
  --train_jsonl ../malay_text_only.jsonl \
  --output_model_path ../output \
  --language Malay \
  --batch_size 2 \
  --lr 1e-4 \
  --num_epochs 3
```

## Decision Tree

```
Need GPU with how much free memory?

├─ 100GB+: Use Chatterbox-style (best quality)
│   ├─ Extract audio codes first
│   └─ Then train with selective freezing
│
├─ 50-100GB: May work with aggressive freezing
│   ├─ Try Chatterbox-style with --train_text_embedding_only
│   └─ Or use smaller dataset
│
└─ <50GB: Use text-embedding only
    ├─ Doesn't need audio code extraction
    ├─ Faster to start
    └─ Quality unknown (synthetic loss)
```

## Quality Trade-offs

| Approach | Training Data | Loss Function | Quality | Proven |
|----------|--------------|---------------|---------|--------|
| Chatterbox-style | Real audio + text | Teacher forcing | High | ✓ |
| Text-embedding only | Text only | Synthetic variance | Unknown | ✗ |

## Notes

### Reusability of Audio Codes

Once extracted, audio codes can be reused:

```bash
# Extract once (painful, 100GB GPU)
python prepare_data.py ... --output_jsonl malay_with_codes.jsonl

# Train multiple times (easy, 50GB GPU)
python sft_12hz_chatterbox.py ... --train_jsonl malay_with_codes.jsonl --lr 2e-5
python sft_12hz_chatterbox.py ... --train_jsonl malay_with_codes.jsonl --lr 3e-5
python sft_12hz_chatterbox.py ... --train_jsonl malay_with_codes.jsonl --lr 1e-5
```

This is the key advantage of Qwen3-TTS's approach.

### Storage Considerations

Audio codes increase file size significantly:

| Format | Size (1000 samples) |
|--------|---------------------|
| Raw JSONL (text only) | ~500KB |
| With audio codes | ~50-100MB |
| Ratio | ~100-200x larger |

Plan storage accordingly for large datasets.

### Hybrid Approach

You can combine both strategies:

1. Start with text-embedding only (quick test)
2. If quality insufficient, extract codes for subset
3. Train Chatterbox-style on subset
4. Evaluate and scale up if needed

## Example

**Scenario:** Fine-tuning for Malay language with 29K audio files, GPU has 70GB free

**Wrong approach:**
```bash
# Try Chatterbox-style directly
python prepare_data.py ...
# ERROR: Out of memory (needs 100GB+)
```

**Right approach:**
```bash
# Option A: Wait for 100GB+ GPU
watch -n 60 nvidia-smi  # Monitor until GPU available

# Option B: Start with text-embedding (70GB is plenty)
python ft_text_embedding.py --train_jsonl malay_text_only.jsonl ...

# Option C: Use smaller subset for Chatterbox-style
python prepare_malay_audio_text_data.py --max_samples 1000 ...
# Try extraction with 1000 samples first
```

## References

- Chatterbox Fine-tuning: https://github.com/stlohrey/chatterbox-finetuning
- Qwen3-TTS Documentation: https://github.com/QwenLM/Qwen3-TTS
- Related Skill: qwen3-tts-gpu-memory-requirements
