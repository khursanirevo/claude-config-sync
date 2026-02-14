---
name: chatterbox-piper-dataset-generation
description: |
  Generate Piper TTS training datasets using ChatterBox HTTP API. Use when: (1)
  Training TTS models with synthetic data, (2) ChatterBox backend available at port 9090,
  (3) Need to create Piper-compatible datasets from phrase lists, (4) Zero-shot voice cloning
  for TTS fine-tuning. Covers OpenAI-compatible API integration, speaker management,
  and metadata.csv generation.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# ChatterBox to Piper Dataset Generation

## Problem
Need to generate synthetic audio datasets for Piper TTS training using ChatterBox's HTTP API
instead of direct Python imports, enabling remote generation and API-based workflows.

## Context / Trigger Conditions
- **ChatterBox backend**: Running at `http://localhost:9090` (or configurable URL)
- **Goal**: Create Piper-compatible training dataset
- **Available endpoints**:
  - `GET /` - Health check
  - `GET /api/speakers` - List available speakers
  - `POST /v1/audio/speech` - OpenAI-compatible TTS generation

## Solution

### 1. List Available Speakers
```bash
curl http://localhost:9090/api/speakers
```

Response format:
```json
{
  "speakers": [
    {"id": "anwar.wav", "name": "Anwar Ibrahim"},
    {"id": "suraya.wav", "name": "Suraya (Milo)"}
  ]
}
```

**Important**: Speaker IDs are **filenames**, not mapped IDs. Use the exact `id` value (e.g., `"anwar.wav"`).

### 2. Generate Audio via API

**Request format** (OpenAI-compatible):
```python
import requests

response = requests.post(
    "http://localhost:9090/v1/audio/speech",
    json={
        "model": "chatterbox-tts",
        "input": "Apa khabar? Semua baik?",  # Your text here
        "voice": "anwar.wav",                 # Speaker filename
        "response_format": "wav",
        "speed": 1.0,
        "preset": "neutral",
        "temperature": 0.8,
        "exaggeration": 0.5,
        "cfg_weight": 0.5
    },
    headers={"Content-Type": "application/json"},
    timeout=60
)

if response.status_code == 200:
    with open("output.wav", "wb") as f:
        f.write(response.content)
```

**Parameters**:
- `input` (required): Text to synthesize
- `voice` (required): Speaker filename from `/api/speakers`
- `response_format`: `"wav"` or `"mp3"`
- `speed`: 0.25 to 4.0 (default 1.0)
- `temperature`: 0.0 to 1.0 (default 0.8)
- `exaggeration`: 0.0 to 1.0 (emotion intensity)
- `cfg_weight`: 0.0 to 1.0 (classifier-free guidance)

### 3. Create Piper-Compatible Dataset

**Directory structure**:
```
datasets/
  voice_name/
    metadata.csv    # Format: filename|text
    wavs/
      voice_00001.wav
      voice_00002.wav
      ...
```

**metadata.csv format**:
```
voice_00001.wav|Apa khabar? Semua baik?
voice_00002.wav|Selamat pagi dan selamat sejahtera.
voice_00003.wav|Apa khabar? Saya sihat.
```

### 4. Complete Generation Script

```python
import requests
import time
from pathlib import Path

API_URL = "http://localhost:9090/v1/audio/speech"
SPEAKERS_URL = "http://localhost:9090/api/speakers"

def generate_dataset(phrases, voice, output_dir):
    """Generate complete Piper dataset"""
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    wavs_dir = output_path / "wavs"
    wavs_dir.mkdir(exist_ok=True)

    metadata_file = output_path / "metadata.csv"

    with open(metadata_file, 'w', encoding='utf-8') as f:
        for i, phrase in enumerate(phrases, 1):
            filename = f"voice_{i:05d}.wav"
            audio_path = wavs_dir / filename

            # Generate TTS
            response = requests.post(
                API_URL,
                json={
                    "model": "chatterbox-tts",
                    "input": phrase,
                    "voice": voice,
                    "response_format": "wav"
                },
                timeout=60
            )

            if response.status_code == 200:
                with open(audio_path, 'wb') as af:
                    af.write(response.content)
                f.write(f"{filename}|{phrase}\n")
                print(f"[{i}/{len(phrases)}] {filename}")

            time.sleep(0.3)  # Avoid overwhelming server

# Usage
phrases = ["Hello", "World", "Test"]
generate_dataset(phrases, "anwar.wav", "datasets/test_voice")
```

## Verification
After generation:
```bash
# Check file count
ls -1 datasets/voice_name/wavs/ | wc -l

# Verify metadata format
head datasets/voice_name/metadata.csv

# Test with Piper (optional)
python3 -m piper_train --help
```

Expected:
- Number of WAV files = number of phrases
- metadata.csv has correct `filename|text` format
- UTF-8 encoding for non-English text

## Example Workflow

### Generate 200 Malay samples with Anwar's voice:
```bash
python3 generate_malay_dataset.py \
  --voice "anwar.wav" \
  --output datasets/malay_voice \
  --count 200
```

### Train Piper model:
```bash
python3 cloneToPiper.py \
  MalayVoice \
  anwar.wav \
  --samples 200 \
  --epochs 300 \
  --quality medium \
  --language ms
```

## Notes

### Speaker Management
- **Permanent speakers**: Located in `backend/audios/`
- **Temporary speakers**: Located in `backend/temp_audios/`
- **Upload via API**: Use `POST /api/create_speaker` with multipart form data
- **Speaker ID format**: Always filename with extension (e.g., `"anwar.wav"`)

### Performance Optimization
- **Batch size**: 0.3s delay between requests avoids overwhelming the server
- **Timeout**: 60s default timeout for long phrases
- **Parallel generation**: ChatterBox supports concurrent requests (limit to 4-6 workers)

### Error Handling
- **404**: Speaker not found (check filename matches exactly)
- **500**: Server error (check ChatterBox logs)
- **Timeout**: Phrase too long or server overloaded
- **Empty audio**: Text normalization failed (check for special characters)

### Language Support
ChatterBox supports:
- Malay (Bahasa Melayu)
- English
- Code-switching (mixed Malay-English)
- Chinese, Japanese, and other languages (depending on model)

### API Alternatives
If HTTP API is unavailable:
1. **Direct Python import**: `from chatterbox.tts_turbo import ChatterboxTurboTTS`
2. **WebSocket endpoint**: `ws://localhost:9090/ws/tts` (for streaming)
3. **Streaming API**: `POST /api/generate_tts_stream` (real-time generation)

## References
- ChatterBox Backend: `/mnt/data/work/ChatterBox/backend/`
- Piper TTS Training: `CLAUDE.md` in Piper_TTS_Training_Suite
- OpenAI API compatibility: `backend/openai_compat.py`
