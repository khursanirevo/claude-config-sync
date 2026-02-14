---
name: python-bytesio-torch-encoding
description: |
  Fix for "module 'torch' has no attribute 'io'" when encoding audio/video. Use when:
  (1) Using torchaudio.save() or torchvision.save(), (2) Need to encode tensors to
  in-memory bytes, (3) Getting AttributeError: module 'torch' has no attribute 'io'.
  Solution: Use Python's built-in io.BytesIO, not torch.io.BytesIO.
author: Claude Code
version: 1.0.0
date: 2025-01-21
---

# Python BytesIO for Audio/Video Encoding

## Problem
When encoding PyTorch tensors to audio/video formats (WAV, MP3, etc.) for streaming or storage, code fails with:
```
AttributeError: module 'torch' has no attribute 'io'
```

## Context / Trigger Conditions
- Using `torchaudio.save()` to encode audio tensors
- Using `torchvision.save()` or similar for video/images
- Need in-memory byte buffer instead of file
- Code attempts: `buffer = torch.io.BytesIO()`

## Root Cause
PyTorch doesn't provide its own `BytesIO` class. The standard practice is to use Python's built-in `io` module. The confusion arises because:
1. Other torch operations have torch-specific versions
2. Autocomplete or intuition suggests `torch.io` should exist
3. The error message is misleading (suggests the module exists)

## Solution
Use Python's built-in `io.BytesIO()`:

```python
# ❌ WRONG
import torch
import torchaudio

buffer = torch.io.BytesIO()  # AttributeError!
torchaudio.save(buffer, tensor, sample_rate, format="wav")

# ✅ CORRECT
import io
import torch
import torchaudio

buffer = io.BytesIO()  # Use Python's built-in
torchaudio.save(buffer, tensor, sample_rate, format="wav")
wav_bytes = buffer.getvalue()
```

## Complete Pattern for Streaming

```python
import io
import torch
import torchaudio

def tensor_to_wav_bytes(audio_tensor: torch.Tensor, sample_rate: int) -> bytes:
    """Convert PyTorch audio tensor to WAV bytes"""
    buffer = io.BytesIO()
    torchaudio.save(
        buffer,
        audio_tensor,
        sample_rate,
        format="wav"
    )
    return buffer.getvalue()

# Usage in streaming
for chunk in audio_chunks:
    wav_bytes = tensor_to_wav_bytes(chunk, 24000)
    yield wav_bytes
```

## Alternative: tempfile for File-Based APIs

Some libraries only support file paths, not BytesIO:

```python
import io
import tempfile
import os

def tensor_to_wav_bytes_tempfile(audio_tensor, sample_rate):
    """For libraries that only accept file paths"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        tmp_path = tmp.name

    # Save to temp file
    torchaudio.save(tmp_path, audio_tensor, sample_rate, format="wav")

    # Read back
    with open(tmp_path, 'rb') as f:
        wav_bytes = f.read()

    # Clean up
    os.unlink(tmp_path)
    return wav_bytes
```

## Similar Gotchas

### NumPy
```python
# ❌ WRONG
import numpy as np
buffer = np.BytesIO()  # Doesn't exist

# ✅ CORRECT
import io
buffer = io.BytesIO()
np.save(buffer, array)
```

### PIL/Pillow
```python
from PIL import Image
import io

# Pillow works with BytesIO correctly
buffer = io.BytesIO()
image.save(buffer, format='PNG')
buffer.seek(0)
```

### OpenCV
```python
import cv2
import numpy as np
import io

# OpenCV doesn't natively support BytesIO encoding
# Need to use cv2.imencode() instead
success, encoded = cv2.imencode('.png', image_array)
png_bytes = encoded.tobytes()
```

## When to Use BytesIO

**✅ Use BytesIO when:**
- Sending data over network (HTTP responses, WebSocket)
- Storing in databases (BLOB columns)
- Creating in-memory ZIP/TAR archives
- Testing without writing files
- Processing in memory pipelines

**❌ Don't use BytesIO when:**
- File is very large (risk of memory exhaustion)
- You need actual file on disk
- Library only accepts file paths

## Verification

After fixing:
1. No `AttributeError` related to `torch.io`
2. Encoding succeeds without writing temp files
3. Bytes can be sent over network or stored
4. Resulting bytes can be decoded and played back

Test the bytes:
```python
# Verify bytes are valid WAV
import wave
wav_bytes = tensor_to_wav_bytes(tensor, 24000)

# Check RIFF header
assert wav_bytes[:4] == b'RIFF'

# Can be written and played
with open('test.wav', 'wb') as f:
    f.write(wav_bytes)
```

## Performance Considerations

```python
import io
from typing import Generator

def stream_large_audio(tensors, sample_rate):
    """Stream without holding all bytes in memory"""
    for tensor in tensors:
        buffer = io.BytesIO()
        torchaudio.save(buffer, tensor, sample_rate, format="wav")
        yield buffer.getvalue()
        buffer.close()  # Explicit cleanup for large streams
```

## Notes
- `io.BytesIO` is from Python standard library (always available)
- Both `io.BytesIO` and `io.StringIO` exist (for bytes vs str)
- Remember to `buffer.seek(0)` if reading after writing
- For very large files, consider streaming to disk with temp files

## Related Gotchas

```python
# ❌ Don't forget to rewind
buffer = io.BytesIO()
buffer.write(b"data")
data = buffer.read()  # Returns b"" because position is at end!

# ✅ Rewind before reading
buffer = io.BytesIO()
buffer.write(b"data")
buffer.seek(0)  # Rewind to beginning
data = buffer.read()  # Returns b"data"

# ✅ Or getvalue() (doesn't care about position)
buffer = io.BytesIO()
buffer.write(b"data")
data = buffer.getvalue()  # Returns b"data"
```

## References
- [Python io module documentation](https://docs.python.org/3/library/io.html)
- [torchaudio.save() documentation](https://pytorch.org/audio/stable/torchaudio.html)
- [BytesIO vs StringIO](https://docs.python.org/3/library/io.html#io.BytesIO)
