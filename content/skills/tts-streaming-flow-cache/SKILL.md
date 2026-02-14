---
name: tts-streaming-flow-cache
description: |
  Implement seamless streaming for flow-matching TTS models by preserving model
  state across chunks. Use when: (1) Audio generation has discontinuities at
  chunk boundaries, (2) Flow matching models need to process variable-size
  chunks incrementally, (3) Tensor size mismatch errors occur during streaming,
  (4) "The expanded size of the tensor must match" errors in cache operations.
  Covers: CausalMaskedDiffWithXvec, CausalConditionalCFM, HiFi-GAN caching.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Flow Cache Preservation for Streaming TTS

## Problem

When implementing streaming TTS with flow-matching models, audio has discontinuities/glitches at chunk boundaries (~every 0.5s). The root cause is that each chunk is processed independently without preserving the model state (noise tensor z and encoder output mu) from previous chunks.

## Context / Trigger Conditions

**Symptoms:**
- Visible mel-spectrogram discontinuities at chunk transitions
- Audio glitches or clicks every ~0.5 seconds during streaming
- Tensor size mismatch errors: "The expanded size of the tensor (X) must match the existing size (Y) at non-singleton dimension 2"
- Flow cache returns None instead of preserving state

**When to use:**
- Implementing streaming with flow-matching based TTS models
- Working with `CausalMaskedDiffWithXvec`, `ConditionalCFM`, or similar architectures
- Variable-size chunks cause cache mismatch errors
- Need seamless audio boundaries in generative streaming

## Solution

### Core Principle

The flow matching model needs to see the **ENTIRE context** (prompt + all previous chunks + current chunk) to maintain seamless boundaries. The cache must preserve the FULL previous z and mu tensors, not just prompt + overlap frames.

### Architecture Pattern

```
Token Accumulation (across chunks)
    ↓
Full Context → Flow Matching (with cached z/mu for previous portions)
    ↓
Extract only NEW mel frames (using prev_mel_len tracker)
    ↓
HiFi-GAN (with cached source features)
    ↓
Seamless audio chunks
```

### Implementation Steps

#### 1. Token Accumulation Layer

```python
# In your streaming generate() method
accumulated_tokens = []
prev_mel_len = 0  # Track previous mel length

for speech_tokens_chunk, new_state in t3.inference_stream(...):
    # Accumulate tokens for FULL context
    accumulated_tokens.append(speech_tokens_chunk)
    all_speech_tokens = torch.cat(accumulated_tokens, dim=1)

    # Pass FULL context to flow inference
    all_mels, flow_cache = self.s3gen.flow.inference(
        token=all_speech_tokens,  # Full accumulated context!
        token_len=...,
        flow_cache=flow_cache,  # Preserved from previous iteration
        ...
    )

    # Extract only NEW mel frames
    new_mels = all_mels[:, :, prev_mel_len:]
    prev_mel_len = all_mels.shape[2]

    # Process new_mels → audio
```

#### 2. Fix Flow Cache for Variable-Size Chunks

In `CausalConditionalCFM.forward()` (or similar flow matching decoder):

```python
def forward(self, mu, mask, n_timesteps, temperature=1.0,
            spks=None, cond=None, prompt_len=0,
            flow_cache=torch.zeros(1, 80, 0, 2)):

    z = self.rand_noise[:, :, :mu.size(2)] * temperature
    cache_size = flow_cache.shape[2]

    # CRITICAL: Handle variable-size chunks
    if cache_size != 0:
        copy_size = min(cache_size, mu.size(2))  # Use min()!
        z[:, :, :copy_size] = flow_cache[:, :, :copy_size, 0]
        mu[:, :, :copy_size] = flow_cache[:, :, :copy_size, 1]

    # Cache FULL z and mu (not just prompt + last 34 frames)
    flow_cache = torch.stack([z, mu], dim=-1)

    # ... rest of forward pass
    return output, flow_cache
```

**Key changes:**
- Use `min(cache_size, mu.size(2))` to handle size mismatches
- Cache the FULL z and mu tensors (not truncated)
- Remove prompt-only caching strategy

#### 3. Add Flow Cache Parameter to Inference

In the flow model's inference method:

```python
def inference(self, token, token_len, prompt_token, prompt_token_len,
              prompt_feat, prompt_feat_len, embedding, finalize,
              flow_cache=None):  # Add this parameter

    # Initialize cache if None
    if flow_cache is None:
        flow_cache = torch.zeros(1, 80, 0, 2).to(embedding.device)

    # ... process tokens ...

    # Pass to decoder with cache
    feat, flow_cache = self.decoder(
        mu=h.transpose(1, 2).contiguous(),
        mask=mask.unsqueeze(1),
        spks=embedding,
        cond=conds,
        n_timesteps=10,
        prompt_len=mel_len1,
        flow_cache=flow_cache,  # Pass it through
    )

    return feat, flow_cache
```

#### 4. Fix HiFi-GAN Cache

In `HiFTGenerator.inference()`:

```python
def inference(self, speech_feat, cache_source=torch.zeros(1, 1, 0)):
    # ... generate source features ...

    # Handle variable-size chunks
    if cache_source.shape[2] != 0:
        copy_size = min(cache_source.shape[2], s.shape[2])
        s[:, :, :copy_size] = cache_source[:, :, :copy_size]

    generated_speech = self.decode(x=speech_feat, s=s)
    return generated_speech, s
```

### Files to Modify

1. **Flow matching decoder** (`flow_matching.py`, `ConditionalCFM`, `CausalConditionalCFM`):
   - Modify `forward()` to cache full z/mu
   - Add `min()` size matching for variable chunks

2. **Flow model** (`flow.py`, `CausalMaskedDiffWithXvec`):
   - Add `flow_cache` parameter to `inference()`
   - Pass cache to decoder with `prompt_len`

3. **HiFi-GAN decoder** (`hifigan.py`, `HiFTGenerator`):
   - Fix cache handling with `min()` size matching

4. **TTS wrapper** (`tts.py`, `ChatterboxTTS.generate_stream()`):
   - Accumulate tokens across chunks
   - Track `prev_mel_len` to extract new frames
   - Pass full context to flow inference

## Verification

**Expected results:**
1. Server logs show successful generation of all chunks with NO errors
2. Mel-spectrogram shows NO visible discontinuities at boundaries
3. Audio playback is smooth with NO clicks/glitches
4. No tensor size mismatch errors in logs

**Test script:**
```python
# Save complete audio and check for duplicates
python3 test_streaming_save.py
# Should show N chunks with only 1 final=True chunk
# Audio file should have smooth playback
```

**Server log verification:**
```
INFO: Generated chunk 0: 0.52s, final=False
INFO: Generated chunk 1: 0.64s, final=False
INFO: Generated chunk 2: 0.12s, final=True
INFO: Streaming generation complete
# NO errors about tensor size mismatches
```

## Common Pitfalls

### 1. Caching Only Prompt + Overlap
**Wrong:** `z_cache = torch.concat([z[:, :, :prompt_len], z[:, :, -34:]], dim=2)`

**Right:** `flow_cache = torch.stack([z, mu], dim=-1)` (cache everything)

**Why:** For streaming, each chunk has different total size, so prompt+overlap caching causes size mismatches.

### 2. Not Accumulating Tokens
**Wrong:** Passing only the current chunk tokens to flow inference

**Right:** Accumulating all tokens and passing full context

**Why:** The flow matching model needs to see the entire sequence to maintain continuity.

### 3. Forgetting to Extract Only New Frames
**Wrong:** Yielding all mels (including previous chunks)

**Right:** `new_mels = all_mels[:, :, prev_mel_len:]`

**Why:** Otherwise you're re-sending previous audio, causing repetition and delays.

### 4. Missing HiFi-GAN Cache Fix
**Error:** Tensor size mismatch in HiFiGAN decoder

**Fix:** Add `min()` size matching in `HiFTGenerator.inference()`

## Example

**Before (broken):**
```python
# Each chunk processed independently
for chunk in chunks:
    mels = flow.inference(chunk, ...)  # No cache!
    audio = hifigan(mels)
    yield audio
# Result: glitches at boundaries
```

**After (seamless):**
```python
flow_cache = torch.zeros(1, 80, 0, 2)
hift_cache = torch.zeros(1, 1, 0)
accumulated_tokens = []
prev_mel_len = 0

for chunk in chunks:
    accumulated_tokens.append(chunk)
    all_tokens = torch.cat(accumulated_tokens, dim=1)

    all_mels, flow_cache = flow.inference(
        all_tokens, ..., flow_cache=flow_cache)

    new_mels = all_mels[:, :, prev_mel_len:]
    prev_mel_len = all_mels.shape[2]

    audio, hift_cache = hifigan(new_mels, cache_source=hift_cache)
    yield audio
# Result: seamless audio
```

## Notes

**Architecture assumptions:**
- Flow matching model uses deterministic diffusion with noise tensor z
- Encoder output mu conditions the diffusion process
- Both z and mu must be preserved for consistent generation

**Performance considerations:**
- Processing full context each iteration is more expensive than chunk-only
- Trade-off: slightly higher latency for MUCH better quality
- For very long sequences (>30s), consider windowed approaches

**Related techniques:**
- KV cache preservation in transformers (similar concept)
- Stateful RNN/LSTM processing (analogous)
- Streaming VAE decoding (similar challenges)

**Duplicate chunk issue:**
- Some implementations yield final chunk multiple times
- Add safeguard: `if final_chunk_sent: continue`
- Root cause is in generator EOS handling, not cache logic

## References

- [Flow Matching for Generative Modeling](https://arxiv.org/abs/2210.15427) - Flow matching theory
- [Causal Flow Matching](https://github.com/FunAudioLLM/CosyVoice) - CausalMaskedDiffWithXvec implementation
- [HiFi-GAN V2](https://github.com/jik876/hifi-gan) - Hierarchical backend for source features
