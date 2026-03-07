---
name: qwen3-tts-api-usage-pitfalls
description: |
  Common pitfalls when using Qwen3-TTS Python API for voice cloning. Use when:
  (1) Getting "torch_dtype is deprecated" warnings, (2) AttributeError: 'numpy.ndarray'
  object has no attribute 'cpu', (3) Audio files having incorrect sizes (1.9MB or 7KB
  instead of 200-350KB), (4) Want to use audio-only mode without reference text,
  (5) Unexpected behavior with voice cloning generation. Covers proper model loading,
  max_new_tokens value, ICL vs x_vector modes, generation parameters, and audio
  file handling for Qwen3-TTS Base models.
author: Claude Code
version: 1.2.0
date: 2026-01-23
---

# Qwen3-TTS API Usage Pitfalls

## Problem
Several common mistakes when using the Qwen3-TTS Python API can lead to runtime errors,
deprecation warnings, or incorrect audio outputs. These issues are not immediately obvious
from the examples and can cause confusion during development.

## Context / Trigger Conditions
- Using `Qwen3TTSModel.from_pretrained()` for voice cloning
- Seeing FutureWarning about `torch_dtype` being deprecated
- Getting `AttributeError: 'numpy.ndarray' object has no attribute 'cpu'`
- Audio files with incorrect sizes (1.9MB, 7KB, or other extreme sizes)
- Audio quality issues or unexpectedly long/short generations
- Working with Qwen3-TTS Base model (not CustomVoice or VoiceDesign)

## Solution

### 1. Use `dtype` not `torch_dtype`

**Incorrect:**
```python
model = Qwen3TTSModel.from_pretrained(
    "path/to/model",
    device_map="cuda:0",
    torch_dtype=torch.bfloat16,  # ❌ Deprecated
)
```

**Correct:**
```python
model = Qwen3TTSModel.from_pretrained(
    "path/to/model",
    device_map="cuda:0",
    dtype=torch.bfloat16,  # ✅ Correct parameter name
)
```

### 2. Output is numpy array, not torch tensor

**Incorrect:**
```python
wavs, sr = model.generate_voice_clone(...)
sf.write("output.wav", wavs[0].cpu().numpy(), sr)  # ❌ AttributeError
```

**Correct:**
```python
wavs, sr = model.generate_voice_clone(...)
sf.write("output.wav", wavs[0], sr)  # ✅ Already numpy array
```

### 3. Use soundfile, not scipy.io.wavfile

**Incorrect:**
```python
import scipy.io.wavfile as wavfile
wavfile.write("output.wav", sr, wavs[0])  # ❌ Can cause format issues
```

**Correct:**
```python
import soundfile as sf
sf.write("output.wav", wavs[0], sr)  # ✅ More reliable
```

### 4. For voice cloning, pass ref_audio directly (simpler approach)

While `create_voice_clone_prompt()` exists and is valid (shown in official examples),
a simpler and more reliable approach for basic voice cloning is to pass `ref_audio`
and `ref_text` directly to each `generate_voice_clone()` call:

**Recommended:**
```python
wavs, sr = model.generate_voice_clone(
    text="Your text here",
    language="Auto",
    ref_audio="path/to/reference.mp3",
    ref_text="Reference transcript",
    max_new_tokens=512,
)
```

This approach is less error-prone than pre-creating prompts with `create_voice_clone_prompt()`
unless you need the optimization of reusing computed features across multiple generations.

### 5. CRITICAL: Use max_new_tokens=128 (not 512 or 2048)

**Incorrect:**
```python
wavs, sr = model.generate_voice_clone(
    text="Your text",
    max_new_tokens=512,  # ❌ Wrong - produces 1.9MB or 7KB files
)
```

**Correct:**
```python
wavs, sr = model.generate_voice_clone(
    text="Your text",
    max_new_tokens=128,  # ✅ Correct - produces 200-350KB files
)
```

**Why this matters:**
- `max_new_tokens=512` or higher causes the model to generate excessively long audio (1.9MB+)
- Can also cause very short outputs (7KB) due to generation issues
- `max_new_tokens=128` produces consistently sized audio files (200-350KB range)
- This parameter controls the maximum number of audio codec tokens to generate
- Official examples use 2048 but that's for very long texts; 128 is optimal for normal sentences

### 6. Two Voice Cloning Modes: ICL vs X-Vector Only

**ICL Mode (default)** - Uses both audio AND reference text:
```python
wavs, sr = model.generate_voice_clone(
    text="Your text",
    ref_audio="reference.mp3",
    ref_text="Reference transcript",  # Required
    x_vector_only_mode=False,  # or omit (default)
    max_new_tokens=128,
)
```
- **Best for**: When you have accurate transcript of reference audio
- **Advantage**: Better prosody matching using in-context learning from reference text
- **Requirement**: Must provide `ref_text`

**X-Vector Only Mode** - Uses audio speaker embedding only:
```python
wavs, sr = model.generate_voice_clone(
    text="Your text",
    ref_audio="reference.mp3",
    ref_text=None,  # Not needed
    x_vector_only_mode=True,
    max_new_tokens=128,
)
```
- **Best for**: When you don't have reference transcript or want simpler approach
- **Advantage**: No transcript needed, only speaker's voice characteristics are used
- **Trade-off**: May have slightly different prosody compared to ICL mode

## Verification
After applying these fixes:
- No deprecation warnings about `torch_dtype`
- No AttributeError when saving audio files
- Audio files are consistently sized (200-350KB for typical sentences)
- Generation completes without hanging
- Audio quality is good without excessive length or cut-off

## Example

**Complete working example for voice cloning:**
```python
import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel

# Load model with correct parameters
model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
    device_map="cuda:0",
    dtype=torch.bfloat16,
)

# Generate with reference audio
wavs, sr = model.generate_voice_clone(
    text="Saya akan menghadiri meeting esok.",
    language="Auto",
    ref_audio="reference.mp3",
    ref_text="Reference transcript here",
    max_new_tokens=128,  # CRITICAL: Use 128, not 512 or 2048
)

# Save output (wavs[0] is already numpy array)
sf.write("output.wav", wavs[0], sr)
```

## Notes
- **max_new_tokens=128 is critical for voice cloning** - higher values (512, 2048) produce
  excessively long audio (1.9MB+) or very short outputs (7KB) due to generation issues
- **Two voice cloning modes**: ICL (default, needs ref_text) vs X-Vector Only (no ref_text needed)
- X-Vector Only mode is useful when you don't have transcripts or want to simplify the workflow
- The `create_voice_clone_prompt()` method is valid and shown in official examples,
  but the direct approach is simpler for most use cases
- If using `create_voice_clone_prompt()`, you may need to specify `x_vector_only_mode`
  parameter (see official examples in `examples/test_model_12hz_base.py`)
- These issues specifically apply to Qwen3-TTS Python API v1.0.0+
- Always check model type with `model.model.tts_model_type` - Base models use
  `generate_voice_clone()`, CustomVoice uses `generate_custom_voice()`
- For very long texts (paragraphs), you may need to increase `max_new_tokens` slightly,
  but 128 is optimal for typical sentences and phrases

## References
- [Qwen3-TTS GitHub Repository](https://github.com/QwenLM/Qwen3-TTS)
- [Qwen3-TTS Official Examples](https://github.com/QwenLM/Qwen3-TTS/blob/main/examples/test_model_12hz_base.py)
