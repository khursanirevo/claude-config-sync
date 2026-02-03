---
name: tts-broadcast-injection-issues
description: |
  Avoid broadcast speaker injection (injecting embeddings to ALL codec positions)
  in multi-speaker TTS training. Use when: (1) Training codec-based TTS models
  with multiple speakers, (2) Model generates to max_new_tokens instead of
  stopping at EOS, (3) Audio duration is excessively long (e.g., 163 seconds
  for short text). Fix: Use single-position injection (position-6) which
  preserves EOS detection. More speaker conditioning is NOT always better.
author: Claude Code
version: 1.0.0
date: 2025-01-24
---

# TTS Broadcast Speaker Injection Issues

## Problem

Broadcast speaker injection (injecting speaker embeddings to ALL codec positions)
seems intuitive for multi-speaker TTS training, but it breaks the model's ability
to detect end-of-sequence (EOS) tokens, causing it to generate until hitting
`max_new_tokens` instead of stopping naturally.

## Context / Trigger Conditions

**When this issue occurs:**
- Training multi-speaker TTS models with codec-based architectures
- Using broadcast injection: `input_codec_embedding = input_codec_embedding + speaker_embedding.unsqueeze(1) * mask`
- During inference, audio generates for exactly `max_new_tokens / sample_rate` seconds
- For 12.5Hz codec with max_new_tokens=2048: always generates 163.6 seconds regardless of text length

**Symptoms:**
- Audio files are consistently 10-25x larger than expected
- All samples from a speaker have identical duration (e.g., exactly 163.60s)
- Training loss is higher than baseline
- Model ignores EOS token and generates to max limit

**Root Cause:**
Broadcasting speaker information across ALL codec positions disrupts the model's
learned relationship between codec embeddings and EOS detection. The model can no
longer properly learn when to stop generation.

## Solution

**Use single-position injection (position-6) instead:**

```python
# ❌ BROKEN: Broadcast injection breaks EOS detection
codec_mask_expanded = codec_mask.unsqueeze(-1).expand_as(input_codec_embedding)
input_codec_embedding = input_codec_embedding + speaker_embedding.unsqueeze(1) * codec_mask_expanded

# ✅ CORRECT: Single-position injection preserves EOS detection
input_codec_embedding[:, 6, :] = speaker_embedding
```

**Why position-6 works:**
- Preserves the codec embedding structure
- Allows model to learn proper EOS behavior
- Provides sufficient speaker conditioning without disrupting generation
- Lower training loss + correct generation behavior

## Verification

After switching to position-6 injection:
1. Training loss should decrease (e.g., 11.40 vs 12.74 for broadcast)
2. Generated audio duration should match text length (6-20s, not 163s)
3. Model should stop at EOS token, not max_new_tokens
4. Audio files should vary in size, not be identical

**Test command:**
```python
import soundfile as sf
audio, sr = sf.read("output.wav")
duration = len(audio) / sr
# Should be 5-30 seconds for normal speech, NOT 163+ seconds
```

## Example

**Training multi-speaker Malay TTS with 11,552 samples:**

| Strategy | Training Loss | Generation | Verdict |
|----------|--------------|------------|---------|
| Position-6 | 11.40 | 6-19s (correct) | ✅ Use this |
| Broadcast | 12.74 | 163.6s (broken) | ❌ Avoid |

**Sample results:**
```
norzaihan_1_position6.wav:  15.3s, 736 KB  ✅
norzaihan_1_broadcast.wav: 163.6s, 7.8 MB ❌ (10x too long)
```

## Notes

**Counterintuitive Result:** More speaker conditioning (broadcast) is WORSE than
minimal conditioning (position-6). This is because:
1. Codec embeddings encode BOTH audio features AND structural information
2. Overwriting all positions destroys the structural cues needed for EOS detection
3. Single-position injection provides speaker identity without breaking structure

**Related approaches that work:**
- Cross-attention conditioning (speaker embeddings via attention layers)
- Encoder-based injection (concatenating with encoder outputs)
- Single-token injection (position-6 or similar fixed position)

**When to use each:**
- **Codec-based models**: Use position-6 or single-token injection
- **Attention-based models**: Cross-attention conditioning may work better
- **Flow-based models**: Decoder input conditioning is standard

**Detection pattern:** If you see `Setting pad_token_id to eos_token_id` warnings
combined with all audio having identical maximum duration, you're likely hitting
this issue.

## References

- [FMSD-TTS: Few-shot Multi-Speaker Multi-Dialect TTS](https://arxiv.org/html/2505.14351v1) - Multi-speaker training framework
- [Koel-TTS: LLM-based Speech Generation](https://aclanthology.org/2025.emnlp-main.1076.pdf) - Cross-attention speaker conditioning
- [YourTTS: Zero-Shot Multi-Speaker TTS](https://proceedings.mlr.press/v162/casanova22a/casanova22a.pdf) - Flow-based decoder conditioning
- [Deep Voice 2: Multi-Speaker Neural TTS](http://papers.neurips.cc/paper/6889-deep-voice-2-multi-speaker-neural-text-to-speech.pdf) - Low-dimensional speaker embeddings
- [Neural Codec Language Models are Zero-Shot TTS](https://www.researchgate.net/publication/388058656_Neural_Codec_Language_Models_are_Zero-Shot_Text_to_Speech_Synthesizers) - Codec-based TTS architecture
