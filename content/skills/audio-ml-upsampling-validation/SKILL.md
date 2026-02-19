---
name: audio-ml-upsampling-validation
description: |
  Fix chipmunk audio effect (high-pitched, fast playback) in PyTorch ML audio upsampling.
  Use when: (1) audio plays at wrong speed/pitch after upsampling, (2) sample rate mismatch
  between encoder and decoder, (3) ML models return wrong output shape without throwing
  exceptions, (4) WAV header sample_rate doesn't match actual audio data. Covers tensor
  shape validation for audio models (NovaSR, BigVGAN, etc.), silent failure detection,
  and sample rate consistency across audio pipeline.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Audio ML Upsampling Validation & Chipmunk Effect Fix

## Problem
When implementing audio upsampling in ML systems (e.g., 24kHz → 48kHz), audio plays back at 2x-3x speed with high pitch ("chipmunk effect") even though no errors are thrown.

## Context / Trigger Conditions

**Symptoms:**
- Audio sounds like chipmunks (high-pitched, fast playback)
- No exception or error messages in logs
- Model appears to succeed (`.infer()` returns without error)
- Backend logs show successful generation but frontend plays wrong speed

**Common Scenarios:**
- Using upsampling models: NovaSR, BigVGAN, WaveNet, etc.
- Implementing custom audio resampling with PyTorch
- Streaming audio pipelines with WAV headers + raw PCM
- Sample rate conversion (16kHz → 48kHz, 24kHz → 48kHz, etc.)

**Root Causes:**
1. **Silent Model Failure**: Model returns wrong output shape without throwing exception
2. **Sample Rate Mismatch**: WAV header/metadata says one rate, actual audio is different
3. **Tensor Shape Error**: Model expects specific dimensions (2D/3D) but receives wrong shape
4. **Exception Handling Bug**: After catching exception, code continues with modified tensor

## Solution

### 1. Preserve Original Input Before Transformation

```python
# Store original BEFORE any processing
original_audio = audio_tensor.clone()  # Critical: preserve copy
original_length = audio_tensor.shape[-1]
```

### 2. Validate Tensor Dimensions for Model Input

Check model documentation for exact input shape requirements:

```python
# Common audio model input shapes:
# - 2D: (channels, samples) - most common for unbatched
# - 3D: (batch, channels, samples) - batched processing
# - 4D: (batch, channels, time, frequency) - spectrogram-based

# Example: NovaSR expects 2D (channels, samples)
audio_input = audio_tensor.unsqueeze(0)  # (samples,) → (1, samples)

# DON'T use multiple unsqueeze unless model needs 4D
# Wrong: audio_tensor.unsqueeze(0).unsqueeze(0)  # (1, 1, samples) = 3D!
```

### 3. Validate Output by Length Ratio

Never assume model worked just because it didn't throw:

```python
upsampled = upsampler.infer(audio_input)
audio_tensor = upsampled.squeeze(0).float()

# CRITICAL: Validate actual upsampling occurred
actual_length = audio_tensor.shape[-1]
length_ratio = actual_length / original_length

# Expected: 24kHz → 48kHz = 2.0x ratio
expected_ratio = target_sample_rate / source_sample_rate
tolerance = 0.1  # Allow 10% tolerance

if abs(length_ratio - expected_ratio) > tolerance:
    logger.warning(
        f"Upsampling validation failed: "
        f"ratio={length_ratio:.2f} (expected ~{expected_ratio:.2f}), "
        f"original={original_length}, actual={actual_length}. "
        f"Using original audio."
    )
    # FALLBACK: Use original audio
    audio_tensor = original_audio
    actual_sample_rate = source_sample_rate
else:
    logger.info(f"Upsampling successful: {audio_tensor.shape}")
    actual_sample_rate = target_sample_rate
```

### 4. Ensure Sample Rate Consistency Across Pipeline

All three must use the **same** sample_rate:

```python
# 1. WAV Encoder (backend)
torchaudio.save(buffer, audio_tensor, actual_sample_rate, format="wav")

# 2. Metadata (backend → frontend)
metrics.sample_rate = actual_sample_rate  # NOT target_sample_rate if failed

# 3. AudioBuffer Decoder (frontend)
audio_buffer = audio_context.createBuffer(
    1,  # channels
    pcm_data.length,
    metadata.sample_rate  # Must match actual audio
)
```

### 5. Handle Exceptions Correctly

```python
try:
    # Upsampling attempt
    upsampled = upsampler.infer(audio_input)
    audio_tensor = upsampled.squeeze(0).float()
    # Validation here...
except Exception as e:
    logger.warning(f"Upsampling failed: {e}, using original")
    audio_tensor = original_audio  # Use preserved original
    actual_sample_rate = source_sample_rate
```

## Verification

**Before Fix:**
```
Browser console: sample_rate=48000, samples=72000, duration=1.50s
Backend logs: duration=3.00s  # Mismatch!
Audio plays: 2x speed (chipmunk)
```

**After Fix:**
```
Browser console: sample_rate=24000, samples=72000, duration=3.00s
Backend logs: duration=3.00s  # Match!
Audio plays: normal speed
```

**Check:**
- Sample rate matches in WAV header, metadata, and AudioBuffer
- Duration calculation: `samples / sample_rate = seconds` is consistent
- No chipmunk effect during playback

## Example: Complete Upsampling Function

```python
def safe_upsample(
    audio_tensor: torch.Tensor,
    source_sr: int,
    target_sr: int,
    upsampler,
    logger
) -> tuple[torch.Tensor, int]:
    """
    Safely upsample audio with validation and fallback.

    Returns:
        (audio_tensor, actual_sample_rate)
    """
    # Preserve original
    original_audio = audio_tensor.clone()
    original_length = audio_tensor.shape[-1]
    expected_ratio = target_sr / source_sr

    try:
        # Prepare input shape (model-specific!)
        audio_input = audio_tensor.unsqueeze(0)  # 2D: (1, samples)
        audio_input = audio_input.cuda().half()

        # Upsample
        upsampled = upsampler.infer(audio_input)
        audio_tensor = upsampled.squeeze(0).float()

        # Validate output
        actual_length = audio_tensor.shape[-1]
        length_ratio = actual_length / original_length

        if abs(length_ratio - expected_ratio) > 0.1:
            logger.warning(f"Validation failed, using original")
            return original_audio, source_sr

        logger.info(f"Upsampling successful: {length_ratio:.2f}x")
        return audio_tensor, target_sr

    except Exception as e:
        logger.warning(f"Upsampling failed: {e}, using original")
        return original_audio, source_sr
```

## Notes

### Chipmunk Effect Root Cause
Playing audio at wrong sample rate:
- 48kHz audio played at 24kHz = 0.5x speed (deep voice)
- 24kHz audio played at 48kHz = 2x speed (chipmunk) ← **Our case**
- Always check: `duration = samples / sample_rate` is consistent

### Why Silent Failures Happen
- ML models use shape inference (no compile-time checking)
- `.infer()` methods catch internal errors and return default values
- Shape mismatches may produce wrong output without exceptions
- Always validate outputs for audio/time-domain models

### Tensor Shape Quick Reference
```python
# 1D audio tensor (most common starting point)
tensor.shape  # (samples,)

# Add batch dimension (for batched models)
tensor.unsqueeze(0).shape  # (1, samples)

# Add channel dimension (for multi-channel)
tensor.unsqueeze(0).shape  # (1, samples) - mono
# For stereo starting from 2D: (channels, samples)
```

### Common Model Input Requirements
- **NovaSR**: 2D `(channels, samples)` or 3D `(batch, channels, samples)`
- **BigVGAN**: 3D `(batch, channels, samples)`
- **WaveNet**: 3D `(batch, time, channels)`
- Always check model's `forward()` signature or documentation

### Performance Considerations
- Validation adds ~1% overhead (negligible)
- Cloning tensor: O(n) but prevents irreversible failures
- Fallback to original is better than corrupted audio

## References

- [PyTorch Upsample Documentation](https://docs.pytorch.org/docs/stable/generated/torch.nn.Upsample.html) - Official docs on upsampling layers
- [TorchAudio Resampling Tutorial](https://docs.pytorch.org/audio/stable/tutorials/audio_resampling_tutorial.html) - Audio frequency conversion best practices
- [Audio Resampling Tutorial (PyTorch)](https://docs.pytorch.org/audio/0.11.0/tutorials/audio_resampling_tutorial.html) - Covers Resample transforms
- [ML Model Silent Failures](https://medium.com/codetodeploy/the-silent-mistakes-that-make-your-ml-models-fail-in-production-4fe348acfa6c) - Silent failure patterns in production ML
- [AI Model Testing Guide 2026](https://www.prismetric.com/ai-model-testing-guide/) - Modern validation approaches
- [Model Monitoring in Production](https://www.evidentlyai.com/ml-in-production/model-monitoring) - ML output validation strategies

## Related Skills

- `pytorch-shape-debugging` - Debugging tensor shape mismatches
- `audio-sample-rate-mismatch` - Fixing sample rate issues without ML models
