---
name: streaming-flow-cache-preservation
description: |
  Implement seamless streaming for flow-matching generative models by preserving
  model state across chunks. Use when: (1) Audio generation has discontinuities at
  chunk boundaries (~every 0.5s), (2) Flow matching models need to process variable-size
  chunks incrementally, (3) Tensor size mismatch errors: "The expanded size of the tensor
  (X) must match the existing size (Y) at non-singleton dimension 2", (4) CausalConditionalCFM
  or similar flow matching architectures. Covers: flow cache preservation, token
  accumulation, HiFi-GAN cache handling, Web Audio API streaming.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Flow Cache Preservation for Streaming Generative Models

## Problem

When implementing streaming output for flow-matching generative models (especially TTS/audio), audio has discontinuities or glitches at chunk boundaries. The root causes are:
1. Each chunk processed independently without preserving model state
2. Flow cache doesn't transfer across variable-size chunks
3. HiFi-GAN cache has tensor size mismatches

## Context / Trigger Conditions

**Symptoms:**
- Visible mel-spectrogram discontinuities at chunk transitions
- Audio glitches or clicks every ~0.5 seconds during streaming
- Tensor size mismatch: "The expanded size of the tensor (X) must match the existing size (Y) at non-singleton dimension 2"
- Context loss across chunks causing repetitions or missing audio

**When to use:**
- Implementing streaming with flow-matching based TTS models
- Working with `CausalMaskedDiffWithXvec`, `ConditionalCFM`, or similar architectures
- Variable-size chunks causing cache mismatch errors
- Need seamless audio boundaries in generative streaming

## Solution

### Core Principle

The flow matching model needs to see the **ENTIRE context** (prompt + all previous chunks + current chunk) to maintain seamless boundaries. The cache must preserve the z (noise) and mu (encoder output) from the full previous generation.

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

In your streaming generate() method:
```python
accumulated_tokens = []
prev_mel_len = 0  # Track previous mel length to extract only new frames

for speech_tokens_chunk, new_state in model.inference_stream(...):
    # Accumulate tokens for FULL context
    accumulated_tokens.append(speech_tokens_chunk)
    all_speech_tokens = torch.cat(accumulated_tokens, dim=1)

    # Pass FULL context to flow inference
    all_mels, flow_cache = model.flow.inference(
        token=all_speech_tokens,  # Full accumulated context!
        flow_cache=flow_cache,  # Preserved from previous iteration
        ...
    )

    # Extract only the NEW mel frames
    new_mels = all_mels[:, :, prev_mel_len:]
    prev_mel_len = all_mels.shape[2]

    # Process new_mels → audio
```

**Critical**: Never pass only the new chunk to flow.inference(). Always accumulate and pass full context.

#### 2. Fix Flow Cache for Variable-Size Chunks

In the flow matching decoder (e.g., `CausalConditionalCFM.forward()`):

```python
def forward(self, mu, mask, n_timesteps, temperature=1.0,
            spks=None, cond=None, prompt_len=0,
            flow_cache=None):  # Add this parameter

    if flow_cache is None:
        flow_cache = torch.zeros(1, 80, 0, 2).to(mu.device)

    z = torch.randn_like(mu).to(mu.device).to(mu.dtype) * temperature
    cache_size = flow_cache.shape[2]

    # CRITICAL: Handle variable-size chunks
    if cache_size != 0:
        copy_size = min(cache_size, mu.size(2))  # Use min() for size mismatch!
        z[:, :, :copy_size] = flow_cache[:, :, :copy_size, 0]
        mu[:, :, :copy_size] = flow_cache[:, :, :copy_size, 1]

    # Cache FULL z and mu (not just prompt + last 34 frames)
    flow_cache = torch.stack([z, mu], dim=-1)

    # ... rest of forward pass
    return output, flow_cache
```

**Key changes**:
- Add `flow_cache` and `prompt_len` parameters
- Use `min(cache_size, mu.size(2))` to handle size mismatches
- Cache FULL tensors (not truncated portions)

#### 3. Add Flow Cache to Flow Model Inference

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
        prompt_len=mel_len1,  # Tell decoder where prompt ends
        flow_cache=flow_cache,  # Pass it through
    )

    return feat, flow_cache
```

#### 4. Fix HiFi-GAN Cache

In the HiFi-GAN decoder (e.g., `HiFTGenerator.inference()`):

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

**Key**: Use `min()` to handle variable-size chunks without errors.

## Verification

**Expected results:**
1. Server logs show successful generation of all chunks with NO errors
2. Mel-spectrogram shows NO visible discontinuities at boundaries
3. Audio playback is smooth with NO clicks/glitches
4. No tensor size mismatch errors in logs

**Test command:**
```python
# Test with various texts
texts = [
    "Hello world",
    "The quick brown fox jumps over the lazy dog.",
    "Machine learning is transforming technology.",
    # ... more test texts
]

for text in texts:
    response = requests.post(url, files={'text': text, ...})
    # Parse chunks and verify audio quality
```

## Example

**Before (broken)**:
```python
# Each chunk processed independently
for chunk in chunks:
    mels = flow.inference(chunk, ...)  # No cache!
    audio = hifigan(mels)
    yield audio
# Result: glitches at boundaries
```

**After (seamless)**:
```python
flow_cache = torch.zeros(1, 80, 0, 2)
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

**Common pitfalls:**
1. **Caching only prompt + overlap** - Causes size mismatches with variable chunks
2. **Not accumulating tokens** - Causes context loss and repetitions
3. **Forgetting prev_mel_len tracker** - Results in re-sending previous audio
4. **Not using min() for cache copying** - Tensor size mismatch errors

**Related techniques:**
- KV cache preservation in transformers (similar concept)
- Stateful RNN/LSTM processing (analogous)
- Streaming VAE decoding (similar challenges)

## References

- [Flow Matching for Generative Modeling](https://arxiv.org/abs/2210.15427) - Flow matching theory
- [Causal Flow Matching Implementation](https://github.com/FunAudioLLM/CosyVoice) - Reference implementation
- [Web Audio API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API) - Browser audio playback
