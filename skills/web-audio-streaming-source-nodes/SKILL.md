---
name: web-audio-streaming-source-nodes
description: |
  Fix for Web Audio API streaming audio players getting stuck or not playing. Use when:
  (1) Building chunked audio streaming with decodeAudioData, (2) Player shows "playing"
  but no audio outputs, (3) Audio chunks queue but never play, (4) Source node references
  are null on first chunk. Critical: AudioBufferSourceNode objects are single-use - must
  create new source for each chunk, never reuse.
author: Claude Code
version: 1.0.0
date: 2025-01-21
---

# Web Audio API Streaming Audio Pattern

## Problem
When building a streaming audio player that plays chunks sequentially, the player gets stuck showing "playing" state but no audio outputs. The issue occurs when checking for existing source nodes before playing.

## Context / Trigger Conditions
- Using Web Audio API's `decodeAudioData()` with chunked audio
- Audio chunks queue but never play
- Player state shows "playing" but no sound
- Code checks `if (sourceNodeRef.current)` before playing
- Each chunk should play sequentially after the previous finishes

## Root Cause
AudioBufferSourceNode objects in Web Audio API are **single-use**. Once started, they cannot be started again. The pattern of checking for an existing source node before creating a new one causes a deadlock:

```javascript
// ❌ BUGGY CODE - causes deadlock
if (!sourceNodeRef.current || !gainNodeRef.current || queue.length === 0) {
  return; // Returns immediately when sourceNodeRef is null (initial state)
}
```

The first chunk arrives, sourceNodeRef is null, so the function returns early without playing anything.

## Solution
Remove the `sourceNodeRef.current` check from the guard clause. Create a fresh source node for each chunk:

```javascript
// ✅ CORRECT CODE
const playNextChunk = useCallback(async () => {
  // Don't check sourceNodeRef.current - it's always null before we create it
  if (!audioContextRef.current || !gainNodeRef.current || audioQueueRef.current.length === 0) {
    setIsPlaying(false);
    isPlayingRef.current = false;
    return;
  }

  const chunk = audioQueueRef.current.shift()!;

  try {
    const audioBuffer = await audioContextRef.current.decodeAudioData(chunk);

    // Create NEW source for this chunk (source nodes are single-use)
    sourceNodeRef.current = audioContextRef.current.createBufferSource();
    sourceNodeRef.current.buffer = audioBuffer;
    sourceNodeRef.current.connect(gainNodeRef.current);

    // Schedule playback
    sourceNodeRef.current.start();

    // When this chunk ends, play the next one
    sourceNodeRef.current.onended = () => {
      playNextChunk();
    };

  } catch (error) {
    console.error('Error playing audio chunk:', error);
  }
}, []);
```

## Key Pattern
- **Source nodes are ephemeral**: Create them fresh each time you play audio
- **Store reference for cleanup**: Keep `sourceNodeRef.current` so you can call `.stop()` if needed
- **Don't guard on it**: Never check `if (sourceNodeRef.current)` before creating a new one
- **Chain with onended**: Use `sourceNodeRef.current.onended` to trigger next chunk

## Verification
After fixing:
1. First chunk should play immediately when received
2. Subsequent chunks should play automatically when previous finishes
3. Player state should accurately reflect playback status
4. No "stuck playing" state

## Common Variations

### Pattern for Continuous Playback
```javascript
// Queue multiple chunks, play sequentially
const queueRef = useRef([]);
const isPlayingRef = useRef(false);

const addToQueue = (chunk) => {
  queueRef.current.push(chunk);
  if (!isPlayingRef.current) {
    playNextChunk();
  }
};

const playNextChunk = async () => {
  if (queueRef.current.length === 0) {
    isPlayingRef.current = false;
    return;
  }

  isPlayingRef.current = true;
  const chunk = queueRef.current.shift();

  const source = audioContext.createBufferSource();
  source.buffer = await audioContext.decodeAudioData(chunk);
  source.connect(audioContext.destination);
  source.onended = playNextChunk; // Chain next chunk
  source.start();
};
```

### Pattern with Gapless Playback
```javascript
// For gapless playback, schedule next chunk before current ends
const scheduleNext = (chunk, when) => {
  const source = audioContext.createBufferSource();
  source.buffer = chunk;
  source.connect(audioContext.destination);
  source.start(when); // Start at exact time
  return source;
};
```

## Related Anti-Patterns

### ❌ Don't: Reuse source nodes
```javascript
sourceNodeRef.current.start();
// Later...
sourceNodeRef.current.start(); // ERROR: can't start twice
```

### ❌ Don't: Check before creating
```javascript
if (!sourceNodeRef.current) {
  sourceNodeRef.current = audioContext.createBufferSource();
}
// This causes initial chunk to never play
```

### ❌ Don't: Store source nodes in array for streaming
```javascript
const sources = []; // Unnecessary - create and discard
```

## Notes
- This applies to AudioBufferSourceNode, OscillatorNode, and other scheduled sources
- MediaElementAudioSourceNode behaves differently (can be paused/resumed)
- For gapless playback, consider scheduling ahead with `audioContext.currentTime`
- The `onended` handler fires even if playback was interrupted with `.stop()`

## References
- [Web Audio API - AudioBufferSourceNode](https://developer.mozilla.org/en-US/docs/Web/API/AudioBufferSourceNode)
- [Web Audio API best practices](https://web.dev/articles/audio-scheduling-exact/)
- [Why AudioBufferSourceNode is single-use](https://stackoverflow.com/questions/27070603/why-audio-buffer-source-node-can-only-be-played-once)
