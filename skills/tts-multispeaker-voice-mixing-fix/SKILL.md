---
name: tts-multispeaker-voice-mixing-fix
description: |
  Fix voice mixing when training multi-speaker TTS models. Use when: (1) training
  codec-based TTS (Qwen3-TTS, VITS, etc.) on multi-speaker data, (2) each sample has
  its own reference audio and speaker embedding, but voice characteristics still get
  mixed or averaged, (3) inference produces inconsistent voice even with same reference
  audio. Root cause: single-position speaker embedding injection is insufficient.
author: Claude Code
version: 1.0.0
date: 2025-01-24
---

# Multi-Speaker TTS Training: Voice Mixing Fix

## Problem

When training codec-based TTS models (like Qwen3-TTS, VITS, or similar transformer-based
models) on multi-speaker data, voice characteristics get mixed or averaged even when:
- Each training sample has its own reference audio for speaker embedding extraction
- Speaker embeddings are correctly extracted per-sample
- The architecture appears to support per-sample speaker conditioning

**Symptoms:**
- Inference with the same reference audio produces inconsistent voice characteristics
- Model outputs sound "averaged" across speakers in the training set
- Prosody, rhythm, or emphasis patterns don't match the reference speaker

## Context / Trigger Conditions

**When this occurs:**
- Training TTS models on data from multiple speakers (parliament members, different
  voice actors, crowdsourced datasets)
- Each sample has `ref_audio` field used for speaker embedding extraction
- Speaker embedding is injected into the model (usually at a specific position)
- Model uses discrete audio codec tokens + transformer architecture

**Example scenario:**
```
Training data: 20K samples from 50 different parliament members
Each sample: {
  "audio": "target.wav",
  "text": "transcript",
  "ref_audio": "reference.wav"  # Different speaker per sample
}
```

After training, using Speaker A's reference audio produces speech that doesn't sound
like Speaker A - instead, it has averaged characteristics from all 50 speakers.

## Root Cause

The issue is **insufficient speaker conditioning** in the transformer, not missing
speaker embeddings. Common problematic pattern:

```python
# Speaker embedding extracted correctly per-sample
speaker_embedding = speaker_encoder(ref_mels)  # [batch, hidden_size]

# BUT: Only injected at ONE position in the sequence
input_codec_embedding[:, position_6, :] = speaker_embedding  # ❌ Too sparse!
```

With single-position injection, the transformer cannot effectively isolate speaker
characteristics, so the **text embedding layer** absorbs speaker-specific prosody
patterns during training. When multi-speaker data is used, `text_embedding` learns
to work with **mixed prosodic patterns** from all speakers simultaneously.

At inference time, even with the correct speaker embedding, `text_embedding` has
already learned to be "prosody-agnostic" and doesn't properly reproduce the reference
speaker's characteristics.

## Solution

**Broadcast speaker embedding throughout the codec sequence** instead of injecting at
a single position. This makes speaker information pervasive and reduces the burden on
text_embedding to encode prosody.

### Implementation

**Before (single-position injection):**
```python
speaker_embedding = speaker_encoder(ref_mels).detach()
input_codec_embedding[:, 6, :] = speaker_embedding  # Only position 6
```

**After (broadcast injection):**
```python
speaker_embedding = speaker_encoder(ref_mels).detach()

# Broadcast to ALL codec positions
codec_mask_expanded = codec_mask.unsqueeze(-1).expand_as(input_codec_embedding)
input_codec_embedding = input_codec_embedding * (~codec_mask_expanded)
input_codec_embedding = input_codec_embedding + speaker_embedding.unsqueeze(1) * codec_mask_expanded
```

### Alternative: Multi-Position Injection

If full broadcast is too aggressive, inject at multiple strategic positions:
```python
# Inject at exponential spacing: 6, 16, 32, 64, 128, 256
positions = [6, 16, 32, 64, 128, 256]
for pos in positions:
    if pos < input_codec_embedding.shape[1]:
        input_codec_embedding[:, pos, :] = speaker_embedding
```

### Why This Works

| Injection Strategy | Speaker Coverage | Voice Mixing Risk |
|--------------------|------------------|-------------------|
| **Broadcast** | Every codec position | **Low** |
| Multi-position | 6-8 strategic positions | Medium |
| Single-position (typical) | Only 1 position | **High** |

By providing speaker information throughout the sequence:
1. Transformer attention can attend to speaker conditioning at any position
2. `text_embedding` is less pressured to encode prosody
3. Speaker characteristics are better preserved at inference

## Verification

After implementing broadcast injection:
1. Train on multi-speaker data with distinct voice characteristics
2. At inference, test with the same reference audio multiple times
3. Verify: Voice characteristics are consistent and match the reference speaker
4. Compare outputs from different speakers - they should sound distinct

## Additional Strategies

If broadcast injection alone doesn't fully resolve the issue:

### 1. Reduce Learning Rate
```python
optimizer = AdamW(model.parameters(), lr=1e-5)  # Lower than typical 2e-5
```

### 2. Freeze text_embedding for Speaker Adaptation
```python
# When adding NEW speakers to existing language model
for param in model.talker.model.text_embedding.parameters():
    param.requires_grad = False

# Only train speaker-specific components
for param in model.speaker_encoder.parameters():
    param.requires_grad = True
```

### 3. Use LoRA for More Minimal Adaptation
```python
# Instead of full text_embedding fine-tuning
from peft import LoraConfig, get_peft_model

lora_config = LoraConfig(
    target_modules=["text_embedding"],
    r=8,
    alpha=16,
    dropout=0.05
)
model = get_peft_model(model, lora_config)
```

## Notes

- **Applicability**: This applies to any TTS model using codec tokens + transformer
  architecture with speaker embeddings (Qwen3-TTS, VITS variants, YourTTS, etc.)

- **Performance impact**: Broadcast injection adds minimal computational overhead
  (just a tensor expansion and multiplication)

- **Compatibility**: This doesn't change the model architecture, only how speaker
  embeddings are injected during training

- **Detaching speaker embeddings**: Keep `.detach()` on speaker encoder output unless
  you explicitly want to train the speaker encoder itself

- **Per-sample vs per-batch**: The critical insight is that each SAMPLE has its own
  speaker embedding (which is correct), but the INJECTION METHOD determines whether
  voice mixing occurs

## References

- [Enhancing Zero-Shot Multi-Speaker TTS with Negated...](https://arxiv.org/html/2401.02014v1) - Discusses speaker embedding strategies in TTS
- [YourTTS: Towards Zero-Shot Multi-Speaker TTS](https://proceedings.mlr.press/v162/casanova22a/casanova22a.pdf) - Multi-speaker TTS architecture analysis
- [MultiSpeech: Multi-Speaker Text to Speech with Transformer](https://www.isca-archive.org/interspeech_2020/chen20r_interspeech.pdf) - Early work on transformer-based multi-speaker TTS
- [Effective Zero-Shot Multi-Speaker Text-to-Speech](https://www.mdpi.com/1424-8220/23/23/9591) - Speaker conditioning techniques in TTS
