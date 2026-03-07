---
name: react-high-frequency-updates-optimization
description: |
  Fix React performance issues with high-frequency updates causing hanging/crashing.
  Use when: (1) Component receives rapid updates (>5 per second) causing re-render issues,
  (2) Streaming data, audio chunks, or real-time metrics freeze the page, (3) State updates
  interfere with async operations (Web Audio API, animations, timers). Pattern: Separate
  data tracking (useRef) from UI display (throttled useState).
author: Claude Code
version: 1.0.0
date: 2025-01-22
---

# React High-Frequency Updates Optimization

## Problem
When React components receive high-frequency updates (streaming data, audio chunks, real-time metrics),
using `useState` for every update causes excessive re-renders that can:
- Make the page hang or freeze
- Crash the browser
- Interrupt async operations (Web Audio API playback, animations, timers)
- Cause poor UX with janky UI

**Common symptoms:**
- Streaming audio plays first chunk then hangs
- Real-time charts/progress bars freeze mid-update
- Component becomes unresponsive during rapid data updates
- Browser dev tools show thousands of re-renders per second

## Context / Trigger Conditions
Use this pattern when:
- Updates arrive more than 5 times per second
- Data changes don't need immediate UI reflection
- State is used for tracking but doesn't directly render
- Re-renders interfere with async operations (audio playback, video, timers)

**Real-world examples:**
- Audio/video streaming with chunk-by-chunk updates
- WebSocket messages arriving rapidly
- Scroll/animation position tracking
- Real-time metrics or progress indicators
- File upload/download progress

## Solution

### Core Pattern: Separate Tracking from Display

**1. Use `useRef` for frequently updated data**
```javascript
// ❌ BAD - Causes re-render on every chunk
const [currentChunkIndex, setCurrentChunkIndex] = useState(0);

// ✅ GOOD - No re-render, just data storage
const currentChunkIndexRef = useRef(0);
```

**2. Use throttled `useState` for UI updates**
```javascript
const [uiChunkIndex, setUiChunkIndex] = useState(0);
const uiUpdateTimerRef = useRef<number | null>(null);

const scheduleUiUpdate = useCallback(() => {
  if (uiUpdateTimerRef.current !== null) {
    return; // Already scheduled
  }

  uiUpdateTimerRef.current = window.setTimeout(() => {
    setUiChunkIndex(currentChunkIndexRef.current);
    uiUpdateTimerRef.current = null;
  }, 100); // Throttle to 100ms max
}, []);
```

**3. Update refs frequently, state rarely**
```javascript
const handleChunk = useCallback((chunk, metadata) => {
  // Update ref on every chunk (no re-render)
  currentChunkIndexRef.current = metadata.chunk_index;

  // Throttle UI update
  scheduleUiUpdate();

  // Continue processing...
}, [scheduleUiUpdate]);
```

### Complete Example: Streaming Audio Player

```javascript
export const StreamingAudioPlayer = () => {
  // State only for UI that MUST trigger re-render
  const [isPlaying, setIsPlaying] = useState(false);
  const [uiChunkIndex, setUiChunkIndex] = useState(0);  // Display value

  // Refs for frequently updated data (no re-renders)
  const currentChunkIndexRef = useRef(0);
  const uiUpdateTimerRef = useRef<number | null>(null);
  const audioQueueRef = useRef<ArrayBuffer[]>([]);

  // Throttled UI update (max 100ms)
  const scheduleUiUpdate = useCallback(() => {
    if (uiUpdateTimerRef.current !== null) return;

    uiUpdateTimerRef.current = window.setTimeout(() => {
      setUiChunkIndex(currentChunkIndexRef.current);
      uiUpdateTimerRef.current = null;
    }, 100);
  }, []);

  // Handle incoming chunks
  const handleChunk = useCallback((chunk, metadata) => {
    audioQueueRef.current.push(chunk);

    // Update ref (no re-render)
    currentChunkIndexRef.current = metadata.chunk_index;

    // Schedule throttled UI update
    scheduleUiUpdate();

    // Continue processing...
  }, [scheduleUiUpdate]);

  // Cleanup
  useEffect(() => {
    return () => {
      if (uiUpdateTimerRef.current !== null) {
        clearTimeout(uiUpdateTimerRef.current);
      }
    };
  }, []);

  return (
    <div>
      <audio ref={audioRef} />
      <progress value={uiChunkIndex} /> { /* UI displays throttled value */ }
    </div>
  );
};
```

## Verification

**Before fix:**
- Browser DevTools React Profiler shows hundreds of re-renders per second
- Component becomes unresponsive during streaming
- Console logs show rapid state updates
- Performance tab shows high main thread blocking

**After fix:**
- Re-renders limited to ~10 per second (throttle rate)
- Component remains responsive during streaming
- Data tracking continues at full frequency (via refs)
- Async operations (audio playback, timers) complete without interruption

**Metrics to check:**
```javascript
// Add logging to verify
console.log('Re-renders:', renderCount);
console.log('Data updates:', dataUpdateCount);
// Ratio should be > 10:1 (data updates : re-renders)
```

## Notes

**Why this works:**
- `useRef` mutations don't trigger re-renders
- Throttling limits expensive DOM updates
- Data tracking remains accurate (refs update instantly)
- UI updates are perceptually smooth (100ms = 10fps is adequate for most indicators)

**Throttle rate guidelines:**
- 100ms (10fps): Progress indicators, counters, text labels
- 50ms (20fps): Smooth animations, visual feedback
- 16ms (60fps): Direct visual feedback (mouse tracking, games)

**Alternative approaches:**
- **React.memo**: Prevents parent re-renders, but not child state updates
- **useTransition**: Marks updates as non-urgent, but still triggers re-renders
- **Web Workers**: Offloads computation, but doesn't solve re-render issue
- **Debouncing**: Good for user input (search), bad for streaming (loses data)

**When NOT to use this pattern:**
- Low-frequency updates (< 1 per second) - normal useState is fine
- Direct user input (form fields) - use controlled components
- Values that directly affect rendering logic - use useState

## Common Pitfalls

1. **Forgetting cleanup**: Always clear timers in useEffect cleanup
   ```javascript
   useEffect(() => {
     return () => {
       if (timerRef.current) clearTimeout(timerRef.current);
     };
   }, []);
   ```

2. **Using stale values in callbacks**: Include refs/throttle in useCallback dependencies
   ```javascript
   const handleChunk = useCallback((chunk) => {
     currentChunkIndexRef.current = chunk.index; // ✅ Ref dependency-free
     scheduleUiUpdate(); // ✅ Included in dependencies
   }, [scheduleUiUpdate]);
   ```

3. **Throttling too aggressively**: UI looks laggy if throttle > 200ms
4. **Not throttling at all**: Defeats the purpose, causes re-render spam

## References

- **[useState vs useRef: Optimizing React Performance](https://medium.com/@rrardian/usestate-vs-useref-optimizing-react-performance-by-preventing-unnecessary-re-renders-c8c9e4211cb2)** (Medium, 2024)
- **[React Performance Optimization: 15 Best Practices for 2025](https://dev.to/alex_bobes/react-performance-optimization-15-best-practices-for-2025-17l9)** (Dev.to, December 2025)
- **[When to Use useState vs useRef in React](https://javascript.plainenglish.io/usestate-vs-useref-the-decision-that-can-make-or-break-your-react-app-0c2604a358a1)** (JavaScript Plain English)
- **[useState vs useRef - You're Using the WRONG One](https://www.youtube.com/watch?v=7wScZIUoRc0)** (YouTube tutorial)
