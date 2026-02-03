---
name: ffmpeg-loudnorm-sample-rate-preservation
description: |
  Prevent unwanted sample rate upsampling when using ffmpeg loudnorm filter.
  Use when: (1) ffmpeg loudnorm increases file size 10x, (2) audio upsampled
  from 24kHz to 192kHz, (3) want to normalize audio while preserving original
  sample rate. The loudnorm filter defaults to input stream's sample rate which
  can cause unexpected upsampling if streams have different rates.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# FFmpeg Loudnorm Sample Rate Preservation

## Problem
Using ffmpeg's `loudnorm` filter causes unwanted audio upsampling (e.g., 24kHz → 192kHz),
resulting in much larger file sizes without quality improvement.

## Context / Trigger Conditions
- Using ffmpeg with `-af "loudnorm=..."`
- Output file is 10x larger than expected
- Sample rate increases unexpectedly (24kHz → 48kHz, 96kHz, or 192kHz)
- Using multiple audio filters or concatenating streams with different sample rates

## Root Cause
The `loudnorm` filter inherits the sample rate from the input stream. If multiple
filters are chained or if the input stream has an implicit resampler, ffmpeg may
upconvert to a higher sample rate. This happens when:
1. Input files have different sample rates
2. Using filters that have internal defaults (some default to 48kHz or 96kHz)
3. Chaining filters where the output of one becomes input to another

## Solution

### Always Explicitly Specify Output Sample Rate

Add `-ar <samplerate>` BEFORE the loudnorm filter:

```bash
# Wrong - loudnorm may upsample
ffmpeg -i input.wav -af "loudnorm=I=-16:TP=-1.5:LRA=11" output.wav

# Correct - preserves 24kHz
ffmpeg -i input.wav -ar 24000 -af "loudnorm=I=-16:TP=-1.5:LRA=11" output.wav
```

### Or Specify in Filter Chain

```bash
# Specify sample rate in the filter chain itself
ffmpeg -i input.wav -af "aresample=24000,loudnorm=I=-16:TP=-1.5:LRA=11" output.wav
```

### Complete Loudnorm Parameters

```bash
ffmpeg -i input.wav \
  -ar 24000 \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -y output.wav
```

**Parameters:**
- `I=-16`: Target integrated loudness (-16 LUFS, EBU R128 standard)
- `TP=-1.5`: True peak limit (-1.5 dBFS, prevents clipping)
- `LRA=11`: Loudness range (11, typical for speech/music)
- `-ar 24000`: Output sample rate (CRITICAL - put before -af)

## Two-Pass Loudnorm (Alternative)

For more accurate normalization, use two-pass approach:

```bash
# Pass 1: Analyze audio
ffmpeg -i input.wav -af "loudnorm=I=-16:TP=-1.5:LRA=11:linear=true" \
  -f null - 2>&1 | grep -E "(Input_I|Input_TP|Input_LRA|Target_Offset)"

# Pass 2: Apply with measured values
ffmpeg -i input.wav \
  -ar 24000 \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=-14.5:measured_TP=-1.2:measured_LRA=10.5" \
  -y output.wav
```

## Verification

### Check sample rates:
```bash
# Input
ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1 input.wav
# Output: 24000

# Output (should match)
ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1 output.wav
# Output: 24000 (not 192000!)
```

### Check file sizes:
```bash
# Before fix: 6.9 MB input → 55 MB output (10x bloat!)
# After fix: 6.9 MB input → 6.9 MB output (correct)
```

### Check bitrate:
```bash
# 24kHz stereo 16-bit PCM should be ~768 kbps
ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1 output.wav
# Should be ~768000, not ~6000000 (6Mbps)
```

## Examples

### Normalize single file:
```bash
ffmpeg -i conversation.wav -ar 24000 -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -y conversation_normalized.wav
```

### Batch normalize files:
```bash
for file in *.wav; do
  echo "Normalizing $file..."
  ffmpeg -i "$file" -ar 24000 -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
    -y "${file%.wav}_norm.wav"
done
```

### With other filters:
```bash
# Chain filters: sample rate first, then normalize
ffmpeg -i input.wav \
  -ar 24000 \
  -af "highpass=f=200,loudnorm=I=-16:TP=-1.5:LRA=11,lowpass=f=8000" \
  -y output.wav
```

## Common Sample Rates

| Format | Sample Rate | Use Case |
|--------|-------------|----------|
| Telephone | 8 kHz | Voice calls |
| Wideband | 16 kHz | VoIP, speech |
| FM Radio | 22.05 kHz | Older audio |
| CD/Audio | 44.1 kHz | Music standard |
| Professional Video | 48 kHz | Video production |
| TTS/Speech | 24 kHz | Text-to-speech |
| High-Res Audio | 96 kHz | Audiophile |
| Ultra High-Res | 192 kHz | Archival |

**For TTS systems:** Use 24kHz (ChatterBox, Coqui, etc.)

## Notes
- `-ar` must come BEFORE `-af` in the command line
- Position matters: `ffmpeg -i input -ar <rate> -af "filter" output`
- Can also use `-sample_rate` (alias for `-ar`)
- For batch processing, consider using a shell script to iterate files
- Two-pass loudnorm is more accurate but takes 2x longer
- The loudnorm filter is part of `libavfilter` (included in standard ffmpeg builds)
- If you see 192kHz output, something is forcing upsampling (add `-ar` to stop it)
- When concatenating files with different sample rates, normalize to a common rate first

## Related Filters
- `aresample`: Resample to specific rate
- `volume`: Simple gain adjustment (faster than loudnorm)
- `dynaudnorm`: Alternative to loudnorm (different algorithm)

## References
- [FFmpeg Loudnorm Documentation](https://ffmpeg.org/ffmpeg-all.html#loudnorm)
- [EBU R128 Loudness Standard](https://tech.ebu.ch/docs/r128/)
- [FFmpeg Audio Filters](https://trac.ffmpeg.org/wiki/AudioFilters)
