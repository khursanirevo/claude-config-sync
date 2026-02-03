---
name: wav-pcm-streaming
description: |
  Stream audio from backend to frontend using WAV header + raw PCM pattern. Use when:
  (1) Implementing real-time audio streaming (TTS, music, voice), (2) WAV blob
  concatenation fails - only first chunk plays, (3) Need seamless audio chunk playback,
  (4) Server-side audio generation with progressive delivery. Simpler than SSE/MediaSource
  - uses native Web Audio API with WAV header once, raw PCM thereafter.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# WAV Header + Raw PCM Audio Streaming

## Problem

When streaming audio chunks from backend to frontend, developers often try to:
1. Send complete WAV files for each chunk and concatenate them
2. Use complex protocols (SSE, MediaSource) unnecessarily
3. Manually parse binary headers

**Symptom**: Only the first audio chunk plays, or audio has glitches/clicks between chunks.

**Root cause**: Each WAV file has a 44-byte header. When you concatenate WAV blobs:
```
[WAV header][PCM data][WAV header][PCM data][WAV header][PCM data]...
```
The browser's audio decoder sees the first WAV header, plays until it hits the second
header (which it doesn't understand), and stops.

## Context / Trigger Conditions

**Use this pattern when:**
- Building TTS (text-to-speech) streaming
- Real-time audio generation (music, voice, sound effects)
- Server-side ML model generating audio chunks
- Need progressive playback without waiting for full generation
- Seeing "queue increases but only first chunk plays" behavior

**NOT for:**
- Bidirectional communication (use WebSockets)
- Ultra-low latency <50ms (consider WebRTC)
- Large pre-recorded files (use HTTP range requests or progressive download)

## Solution

### Backend: Send WAV header once, then raw PCM

**Python/PyTorch example**:
```python
import io
import torch
import torchaudio

chunk_count = 0
first_chunk = True

for audio_tensor, metadata in audio_generator:
    chunk_count += 1

    if first_chunk:
        # First chunk: Include WAV header for decoder initialization
        buffer = io.BytesIO()
        torchaudio.save(
            buffer,
            audio_tensor,
            sample_rate=24000,
            format="wav"
        )
        wav_bytes = buffer.getvalue()
        first_chunk = False
    else:
        # Subsequent chunks: Raw PCM data only (no WAV header)
        # PyTorch tensors are float32, convert to bytes directly
        audio_tensor_np = audio_tensor.cpu().numpy()
        pcm_bytes = audio_tensor_np.tobytes()
        wav_bytes = pcm_bytes

    yield wav_bytes, metadata
```

**Key points**:
- PyTorch/NumPy default float32 matches Web Audio API Float32Array
- No need for manual byte order conversion (use system native)
- First chunk establishes sample rate, channels, bit depth for decoder

### Frontend: Decode first chunk, create AudioBuffer for raw PCM

**React/TypeScript example**:
```typescript
const audioContextRef = useRef<AudioContext | null>(null);
const audioQueueRef = useRef<AudioBuffer[]>([]);
const nextStartTimeRef = useRef<number>(0);

// Initialize AudioContext
const initAudioContext = () => {
  if (!audioContextRef.current) {
    audioContextRef.current = new AudioContext({ sampleRate: 24000 });
  }
};

// Play queued audio buffers
const playQueue = () => {
  if (!audioContextRef.current || audioQueueRef.current.length === 0) {
    return;
  }

  const buffer = audioQueueRef.current.shift()!;
  const source = audioContextRef.current.createBufferSource();
  source.buffer = buffer;
  source.connect(audioContextRef.current.destination);

  // Schedule playback at next available time
  const startTime = nextStartTimeRef.current || audioContextRef.current.currentTime;
  source.start(startTime);
  nextStartTimeRef.current = startTime + buffer.duration;

  // Schedule next buffer if available
  if (audioQueueRef.current.length > 0) {
    setTimeout(() => playQueue(), 0);
  }
};

// Handle incoming chunk
const handleChunk = async (chunk: ArrayBuffer, metadata: ChunkMetadata) => {
  initAudioContext();

  if (metadata.chunk_index === 0) {
    // First chunk: Decode as WAV (has header)
    const audioBuffer = await audioContextRef.current!.decodeAudioData(chunk);
    audioQueueRef.current.push(audioBuffer);
    playQueue();
  } else {
    // Subsequent chunks: Raw PCM data
    const pcmData = new Float32Array(chunk);
    const audioBuffer = audioContextRef.current!.createBuffer(
      1,              // mono (use 2 for stereo)
      pcmData.length,
      24000          // sample rate
    );
    audioBuffer.copyToChannel(pcmData, 0);
    audioQueueRef.current.push(audioBuffer);
    playQueue();
  }
};
```

## Verification

**Backend**:
- First chunk size ≈ 44 bytes + PCM data size
- Subsequent chunks = PCM data size only (no header overhead)
- Check logs: "First chunk with WAV header: XXXX bytes", "Chunk N raw PCM: YYYY bytes"

**Frontend**:
- Console logs show sequential start times:
  ```
  Playing buffer, duration: 0.52 start: 0.00 next: 0.52
  Playing buffer, duration: 0.64 start: 0.52 next: 1.16
  Playing buffer, duration: 0.64 start: 1.16 next: 1.80
  ```
- Audio plays continuously without gaps or clicks
- All chunks play to completion

## Example

**Before (broken - concatenating WAV blobs)**:
```typescript
// This doesn't work - each WAV has its own header
const blobs = [];
blobs.push(new Blob([chunk1], { type: 'audio/wav' }));
blobs.push(new Blob([chunk2], { type: 'audio/wav' }));
const combined = new Blob(blobs);  // Invalid: [header][data][header][data]
```

**After (working - WAV header + raw PCM)**:
```python
# Backend
if first_chunk:
    yield wav_with_header  # Initialize decoder
else:
    yield raw_pcm_bytes    # Pure data
```

```typescript
// Frontend
if (chunkIndex === 0) {
  const decoded = await decodeAudioData(wavWithHeader);
  play(decoded);
} else {
  const buffer = createBuffer(1, rawPcm.length, 24000);
  buffer.copyToChannel(new Float32Array(rawPcm), 0);
  play(buffer);
}
```

## Notes

**Why this works**:
1. **First chunk**: WAV header tells decoder sample rate, bit depth, channels
2. **Subsequent chunks**: Raw PCM is just sample values, decoder already knows format
3. **Seamless**: No re-decoding, no format mismatches, just append samples

**Data formats**:
- PyTorch/NumPy default: float32 (-1.0 to 1.0)
- Web Audio API: Float32Array (same format!)
- No conversion needed for float32 audio

**Alternative approaches** (when NOT to use this pattern):
- **SSE/MediaSource**: Overkill for simple audio streaming, adds complexity
- **WebRTC**: Only for bidirectional/ultra-low latency (<50ms)
- **Progressive download**: For large pre-recorded files, not real-time generation

**Common pitfalls**:
- ❌ Don't use int16/int24 PCM unless you convert to Float32Array
- ❌ Don't forget to handle endianness (little-endian standard for WAV)
- ❌ Don't skip the first WAV header - decoder needs initialization
- ❌ Don't mix sample rates between chunks
- ❌ Don't use `.tobytes()` on non-contiguous arrays (call `.contiguous()` first if needed)

**Performance considerations**:
- Float32 uses 4x more bandwidth than int16 (trade quality vs bandwidth)
- For high-frequency streaming (>100 Hz), consider int16 + manual conversion
- Browser `decodeAudioData()` is fast but has overhead for first chunk
- Creating AudioBuffer from Float32Array is minimal overhead

## References

- [MDN: Web Audio API Best Practices](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices)
- [Streaming PCM Data via WebSocket + Web Audio API](https://medium.com/@adriendesbiaux/streaming-pcm-data-websocket-web-audio-api-part-1-2-5465e84c36ea)
- [StackOverflow: Using Web Audio API to Get Raw PCM](https://stackoverflow.com/questions/51687308/how-to-use-web-audio-api-to-get-raw-pcm-audio)
- [Web Audio API Specification (W3C)](https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html)
