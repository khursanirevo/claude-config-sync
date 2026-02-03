---
name: ffmpeg-audio-speed-adjustment
description: |
  Adjust audio playback speed while preserving pitch using ffmpeg atempo filter.
  Use when: (1) Need to speed up/slow down audio without chipmunk effect,
  (2) Speed values outside 0.5-2.0x range, (3) Post-processing audio for TTS/ASR.
  Covers filter chaining for extreme values and quality considerations.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# ffmpeg Audio Speed Adjustment with Pitch Preservation

## Problem

Need to change audio playback speed (faster/slower) without making voices sound like
chipmunks (high pitch) or giants (low pitch). Direct resampling changes pitch with speed.

## Context / Trigger Conditions

- TTS API needs `speed` parameter (e.g., OpenAI-compatible speech API)
- Audiobook/podcast playback at different speeds
- Audio data augmentation for ML training
- Any scenario requiring 0.25x to 4.0x speed adjustment

## Solution

### Basic Usage (0.5x - 2.0x)

```bash
ffmpeg -i input.mp3 -af "atempo=1.5" output.mp3
```

### Extreme Values (< 0.5x or > 2.0x)

**Chain multiple atempo filters** - the trick is that atempo only supports [0.5, 2.0]:

```bash
# 0.25x speed (very slow) - two filters in series
ffmpeg -i input.mp3 -af "atempo=0.5,atempo=0.5" output.mp3

# 3.0x speed (very fast) - chain 2.0 + 1.5
ffmpeg -i input.mp3 -af "atempo=2.0,atempo=1.5" output.mp3

# 4.0x speed (extreme) - chain 2.0 + 2.0
ffmpeg -i input.mp3 -af "atempo=2.0,atempo=2.0" output.mp3
```

**Python implementation:**

```python
import subprocess

def apply_speed_adjustment(audio_path: str, speed: float) -> str:
    """Apply speed adjustment using ffmpeg atempo filter."""
    output_path = audio_path.replace(".mp3", f"_speed{speed}.mp3")

    if speed < 0.5:
        # Chain filters: 0.25x = 0.5 * 0.5
        filter_complex = f"[0:a]atempo={speed*2},atempo=0.5[aout]"
    elif speed > 2.0:
        # Chain filters: 3.0x = 2.0 * 1.5
        filter_complex = f"[0:a]atempo=2.0,atempo={speed/2.0}[aout]"
    else:
        filter_complex = f"[0:a]atempo={speed}[aout]"

    subprocess.run([
        "ffmpeg",
        "-i", audio_path,
        "-filter_complex", filter_complex,
        "-map", "[aout]",
        "-y",  # Overwrite output
        output_path
    ], check=True, capture_output=True)

    return output_path
```

### From Python (Alternative Libraries)

```python
# Using pydub (simpler, less control)
from pydub import AudioSegment

audio = AudioSegment.from_mp3("input.mp3")
# pydub uses playback_speed parameter (internally uses atempo)
fast_audio = audio._spawn(audio.raw_data, overrides={
    "frame_rate": int(audio.frame_rate * 1.5)
}).set_frame_rate(audio.frame_rate)
fast_audio.export("output.mp3", format="mp3")
```

## Verification

**Check audio quality:**
```bash
# Play to verify pitch is preserved
ffplay output.mp3

# Check duration change
ffprobe -i input.mp3 -show_entries format=duration
ffprobe -i output.mp3 -show_entries format=duration
```

**Expected results:**
- Duration changed by factor of 1/speed
- Pitch sounds the same as original
- Minimal artifacts for 0.75x - 1.5x range
- Some distortion at extreme values (< 0.5x or > 2.5x)

## Example

**Complete function with error handling:**

```python
import subprocess
import os

def adjust_audio_speed(
    audio_path: str,
    speed: float,
    output_path: Optional[str] = None
) -> str:
    """
    Adjust audio playback speed while preserving pitch.

    Args:
        audio_path: Input audio file path
        speed: Speed multiplier (0.25 to 4.0)
        output_path: Output path (auto-generated if None)

    Returns:
        Path to speed-adjusted audio file
    """
    if speed == 1.0:
        return audio_path  # No change needed

    # Generate output path
    if output_path is None:
        base, ext = os.path.splitext(audio_path)
        output_path = f"{base}_speed{speed}{ext}"

    try:
        # Build filter complex
        if speed < 0.5:
            # Chain for very slow speeds
            filter_complex = f"[0:a]atempo={speed*2},atempo=0.5[aout]"
        elif speed > 2.0:
            # Chain for very fast speeds
            filter_complex = f"[0:a]atempo=2.0,atempo={speed/2.0}[aout]"
        else:
            # Direct application for normal range
            filter_complex = f"[0:a]atempo={speed}[aout]"

        subprocess.run([
            "ffmpeg", "-i", audio_path,
            "-filter_complex", filter_complex,
            "-map", "[aout]",
            "-y", output_path
        ], check=True, capture_output=True)

        return output_path

    except subprocess.CalledProcessError as e:
        # Fallback: return original if ffmpeg fails
        print(f"Warning: Speed adjustment failed: {e}")
        return audio_path
```

**Usage:**
```python
# Slow down narration
slow_audio = adjust_audio_speed("podcast.mp3", speed=0.75)

# Speed up TTS output
fast_audio = adjust_audio_speed("tts_output.wav", speed=1.5)

# Extreme fast-forward
very_fast = adjust_audio_speed("lecture.mp3", speed=3.0)
```

## Notes

### Quality Considerations

- **Best quality**: 0.75x - 1.5x range (minimal artifacts)
- **Acceptable**: 0.5x - 2.0x range (slight artifacts possible)
- **Use with caution**: < 0.5x or > 2.5x (noticeable quality degradation)

### Performance

- **atempo** is slower than rubberband but more widely available
- Processing time scales with audio duration
- For batch processing, consider parallel execution

### Alternative: Rubber Band Filter

Better quality but requires ffmpeg compiled with rubberband:

```bash
ffmpeg -i input.mp3 -af "rubberband=tempo=1.5" output.mp3
```

### For Video + Audio

Must adjust both to maintain sync:

```bash
# Speed up video and audio by 1.5x
ffmpeg -i input.mp4 \
  -filter_complex "[0:v]setpts=PTS/1.5[v];[0:a]atempo=1.5[a]" \
  -map "[v]" -map "[a]" \
  output.mp4
```

## Common Pitfalls

1. **Wrong filter order**: In chaining, order doesn't matter for atempo, but keep logical
2. **Forgetting -map "[aout]"**: When using filter_complex, must map the output
3. **Extreme values**: Single atempo > 2.0 or < 0.5 will fail silently
4. **Format issues**: Output format must match input encoding expectations
5. **Path issues**: ffmpeg doesn't create directories, ensure output dir exists

## References

- [FFmpeg Audio Filters Documentation](https://ffmpeg.org/ffmpeg-filters.html#Audio-Filter-6)
- [atempo Filter Source Code](https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/af_atempo.c)
- [Rubber Band Library](https://github.com/falkTX/rubberband) - High-quality alternative
