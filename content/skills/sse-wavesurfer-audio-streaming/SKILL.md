---
name: sse-wavesurfer-audio-streaming
description: |
  Use Server-Sent Events (SSE) with wavesurfer.js for audio streaming instead of
  custom binary protocols or manual Web Audio API scheduling. Apply when: (1) implementing
  real-time audio streaming from backend to frontend, (2) audio chunks aren't playing
  reliably with manual scheduling, (3) queue increases but playback stays stuck,
  (4) using complex binary protocols with metadata length prefixes. Covers FastAPI/Python
  backend SSE implementation and React frontend with wavesurfer.js.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# SSE + wavesurfer.js Audio Streaming

## Problem

When implementing real-time audio streaming (e.g., TTS, music streaming), developers often:
1. Create custom binary protocols with metadata length prefixes (e.g., `[8 bytes length][JSON metadata][audio data]`)
2. Use manual Web Audio API scheduling which is complex and error-prone
3. Experience issues like "queue keeps increasing but chunks played stay at 1"

These approaches are over-engineered and unreliable.

## Context / Trigger Conditions

**Use this skill when:**
- Implementing server-to-client audio streaming (TTS, music, podcasts)
- Audio chunks queue up but don't play or only first chunk plays
- Using custom binary protocols with manual parsing
- Frontend code manually schedules AudioBufferSourceNodes
- Seeing errors like `SyntaxError: Unexpected end of JSON input` from binary parsing

**Symptoms of the problem:**
- Complex binary parsing code with metadata length headers
- `AudioContext`, `AudioBufferSourceNode`, manual scheduling
- Audio queue grows but playback doesn't progress
- Clicks/pops between audio chunks

## Solution

### Backend: Use SSE Format (FastAPI/Python)

Instead of custom binary protocol, use Server-Sent Events:

```python
from fastapi import StreamingResponse
import base64
import json

async def generate_audio_stream():
    """Generator that yields SSE events with audio chunks"""
    try:
        for wav_bytes, metrics in audio_generator:
            # Create SSE event with base64-encoded audio
            event_data = {
                "chunk_index": metrics.chunk_index,
                "audio": base64.b64encode(wav_bytes).decode('utf-8'),
                "is_final": metrics.is_final,
                # ... other metadata
            }

            # SSE format: "data: <json>\n\n"
            yield f"data: {json.dumps(event_data)}\n\n"

    except Exception as e:
        error_data = {"error": str(e), "is_final": True}
        yield f"data: {json.dumps(error_data)}\n\n"

return StreamingResponse(
    generate_audio_stream(),
    media_type="text/event-stream",
    headers={
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "X-Accel-Buffering": "no",
    }
)
```

### Frontend: Parse SSE + Use wavesurfer.js

**Install wavesurfer.js:**
```bash
npm install wavesurfer.js
npm install --save-dev @types/wavesurfer.js  # TypeScript types
```

**Streaming player implementation:**
```typescript
import WaveSurfer from 'wavesurfer.js';

// Initialize wavesurfer once
const wavesurfer = WaveSurfer.create({
  container: '#waveform',
  waveColor: '#4a90e2',
  progressColor: '#1976d2',
  backend: 'WebAudio',
});

// Parse SSE stream
const decoder = new TextDecoder();
let buffer = '';

const reader = response.body.getReader();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;

  buffer += decoder.decode(value, { stream: true });

  // SSE messages end with \n\n
  const lines = buffer.split('\n\n');
  buffer = lines.pop() || '';

  for (const line of lines) {
    if (!line.startsWith('data: ')) continue;

    const data = JSON.parse(line.replace('data: ', '').trim());

    // Decode base64 audio
    const audioBytes = Uint8Array.from(atob(data.audio), c => c.charCodeAt(0));
    const blob = new Blob([audioBytes], { type: 'audio/wav' });

    // Concatenate blobs for streaming
    audioBlobs.push(blob);
    const combinedBlob = new Blob(audioBlobs, { type: 'audio/wav' });

    // Load into wavesurfer (preserves playback position)
    const currentTime = wavesurfer.getCurrentTime();
    const url = URL.createObjectURL(combinedBlob);
    wavesurfer.load(url);

    wavesurfer.on('ready', () => {
      wavesurfer.seekTo(currentTime / wavesurfer.getDuration());
      if (wasPlaying) wavesurfer.play();
    });
  }
}
```

### Key Implementation Details

1. **Base64 encode audio** - SSE is text-based, binary must be base64-encoded
2. **Use `\n\n` delimiter** - SSE messages end with double newline
3. **Blob concatenation** - Merge received chunks into single blob for wavesurfer
4. **Preserve playback position** - Save current time before reloading, restore after
5. **Standard headers** - Use `text/event-stream`, `Cache-Control: no-cache`, etc.

## Verification

**Backend:**
- SSE endpoint returns `Content-Type: text/event-stream`
- Response format is `data: {...json...}\n\n`
- Test with curl: `curl -N <endpoint>` should show streaming messages

**Frontend:**
- Browser DevTools Network tab shows event-stream type
- Console logs show chunk numbers increasing
- Audio plays smoothly without clicks/pops
- Waveform visualization updates as chunks arrive

## Example

**Before (complex binary protocol):**
```python
# Old way - custom binary format
metadata_json = json.dumps(metadata).encode()
metadata_length = len(metadata_json).to_bytes(8, 'big')
yield metadata_length
yield metadata_json
yield wav_bytes
```

**After (SSE):**
```python
# New way - standard SSE
event_data = {"audio": base64.b64encode(wav_bytes).decode('utf-8'), ...}
yield f"data: {json.dumps(event_data)}\n\n"
```

**Frontend before (manual parsing):**
```typescript
// 170+ lines of complex Uint8Array parsing, buffer management,
// AudioContext scheduling, etc.
```

**Frontend after (wavesurfer.js):**
```typescript
// ~50 lines - parse SSE, decode base64, concatenate blobs, load into wavesurfer
```

## Notes

**SSE vs WebSockets:**
- SSE is unidirectional (server→client) - perfect for streaming
- Simpler than WebSockets, auto-reconnects built-in
- Uses HTTP, no separate protocol upgrade needed
- Text-based, so binary data needs base64 encoding

**wavesurfer.js advantages:**
- Handles complex Web Audio API scheduling automatically
- Provides waveform visualization
- Built-in play/pause/seek/volume controls
- Prevents audio glitches between chunks

**When NOT to use:**
- Bidirectional communication needed (use WebSockets)
- Low-latency real-time communication <100ms (use WebRTC)
- Very large files >100MB (consider progressive download or range requests)

**Performance considerations:**
- Base64 encoding increases size by ~33%
- For high-frequency streaming, consider binary WebSocket protocol
- Revoke blob URLs with `URL.revokeObjectURL()` to prevent memory leaks
- Limit blob array size (e.g., max 50-100 blobs before combining)

## References

- [MDN: Using Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
- [wavesurfer.js Official Documentation](https://wavesurfer.xyz/docs)
- [FastAPI: StreamingResponse](https://fastapi.tiangolo.com/advanced/custom-response/#streamingresponse)
- [Web Audio API Best Practices (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices)
- [SSE's Glorious Comeback: Why 2025 is the Year of Server-Sent Events](https://portalzine.de/sses-glorious-comeback-why-2025-is-the-year-of-server-sent-events/)
