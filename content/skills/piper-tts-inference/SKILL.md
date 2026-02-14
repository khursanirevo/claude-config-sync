---
name: piper-tts-inference
description: |
  Generate audio from trained Piper TTS models (PyTorch checkpoints exported to ONNX).
  Use when: (1) you have a trained Piper model in ONNX format, (2) piper binary is missing,
  (3) piper_cli.py infer fails with "mode: invalid choice", (4) need to generate test samples
  from a fine-tuned voice. Covers the Python API: piper.PiperVoice.load() and handling
  AudioChunk objects with audio_int16_bytes attribute.
author: Claude Code
version: 1.0.0
date: 2026-01-27
---

# Piper TTS Inference with Trained Models

## Problem
After training a Piper TTS model and exporting to ONNX, generating audio samples is not
straightforward:
- The `piper_cli.py infer` command expects only "zero-shot" or "onnx" modes for already-built models
- The `piper` binary may not be installed or accessible
- Direct PyTorch checkpoint inference is complex without the right API
- Documentation focuses on training, not inference with custom models

## Context / Trigger Conditions
- You have an ONNX model at `exports/your_model.onnx` (from `piper_cli.py export`)
- The config.json file exists at `work_dir/config.json` or elsewhere
- Running `.venv/bin/piper -m exports/your_model.onnx` fails with "FileNotFoundError"
- You need to generate test audio samples from your fine-tuned voice model
- `piper_cli.py infer onnx` doesn't recognize your model path

## Solution

### Method 1: Python API with piper.PiperVoice (Recommended)

Use the Piper Python API directly:

```python
from piper import PiperVoice

# Load the trained model
voice = PiperVoice.load('./exports/your_model.onnx')

# Synthesize text (returns generator)
audio_chunk = next(voice.synthesize("Your text here"))

# Save to file - audio_int16_bytes is already-encoded WAV data
with open('output.wav', 'wb') as f:
    f.write(audio_chunk.audio_int16_bytes)
```

**Key Points**:
- `synthesize()` returns a **generator**, not a direct array
- Each yielded item is an `AudioChunk` object
- Use `audio_int16_bytes` attribute for WAV file output (already encoded)
- Sample rate is typically 22050 Hz for Piper models

### Complete Example: Generate 5 Samples

```python
from piper import PiperVoice
from pathlib import Path

voice = PiperVoice.load('./exports/anwar.onnx')

texts = [
    "Hello everyone, I hope you're having a wonderful day today.",
    "The training process requires patience, consistency, and dedication.",
    "Technology is transforming how we work, communicate, and live.",
    "I really appreciate your help with this project, thank you so much!",
    "The weather is beautiful this morning, perfect for a walk."
]

for i, text in enumerate(texts, 1):
    audio_chunk = next(voice.synthesize(text))
    with open(f'sample_{i:02d}.wav', 'wb') as f:
        f.write(audio_chunk.audio_int16_bytes)

    # Get metadata
    size_kb = len(audio_chunk.audio_int16_bytes) / 1024
    duration = len(audio_chunk.audio_float_array) / audio_chunk.sample_rate
    print(f"Sample {i}: {size_kb:.1f} KB, {duration:.2f}s")
```

### AudioChunk Attributes

The AudioChunk object has these useful attributes:

- `audio_float_array`: Raw audio as numpy float array (for processing)
- `audio_int16_array`: Audio as int16 numpy array (for processing)
- `audio_int16_bytes`: Encoded WAV file data (for direct file writing) ⭐
- `sample_rate`: Sample rate (usually 22050 Hz)
- `sample_width`: Bit depth (usually 16-bit)
- `sample_channels`: Number of channels (usually 1 for mono)

## Common Pitfalls

### ❌ WRONG: Treating generator as array
```python
# This will fail!
audio = voice.synthesize("text")
numpy.save('output.wav', audio)  # Error: generator has no shape
```

### ❌ WRONG: Using audio_float_array directly
```python
chunk = next(voice.synthesize("text"))
sf.write('output.wav', chunk.audio_float_array)  # Wrong format
```

### ✅ CORRECT: Handle generator + use bytes
```python
chunk = next(voice.synthesize("text"))
with open('output.wav', 'wb') as f:
    f.write(chunk.audio_int16_bytes)  # Correct!
```

## Alternative: Using PyTorch Checkpoint Directly

If you have the PyTorch checkpoint (`.ckpt` file) and want to use it directly:

```python
import torch
from piper_train.vits.config import load_config
from piper_train.vits.infer import Synthesizer

# Load model
config = load_config('./work_dir/config.json')
model = Synthesizer.load('./work_dir/lightning_logs/version_0/checkpoints/epoch=2463.ckpt', config)

# Synthesize
audio = model.synthesize("Your text here")

# Save
import soundfile as sf
sf.write('output.wav', audio, 22050)
```

Note: This requires `piper_train` module which may not be in your venv.

## Verification

Generate a test sample and verify:

```bash
# Run the Python script
python3 generate_samples.py

# Check file exists and is valid
ls -lh sample_01.wav
file sample_01.wav  # Should show "RIFF (little-endian) data, WAVE audio"
```

Expected output:
- File size: ~100-300 KB depending on text length
- Format: RIFF WAVE audio
- Duration: Varies with text length

## Notes

**Model Requirements:**
- ONNX model file (`.onnx`)
- Config file (`model.onnx.json` or `config.json`) in the same directory
- Config must match the model (sample rate, phoneme map, etc.)

**For Zero-Shot Inference:**
```python
from piper import PiperVoice

# Load zero-shot model
voice = PiperVoice.load()  # Auto-finds model in pretrained/
audio = next(voice.synthesize("Text here"))
```

**Common Issues:**
- **ImportError**: Make sure you're using the correct Python environment (venv activated)
- **FileNotFoundError**: Ensure paths are relative to current directory
- **AttributeError**: You're accessing the wrong attribute (use audio_int16_bytes)
- **Generator exhausted**: Call next() once per synthesis, not multiple times on same generator

## References

- Piper GitHub: https://github.com/rhasspy/piper
- Piper PyPI: https://pypi.org/project/piper-tts/
- Piper Documentation: https://github.com/rhasspy/piper/tree/main/docs
