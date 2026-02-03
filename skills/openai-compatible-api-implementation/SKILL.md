---
name: openai-compatible-api-implementation
description: |
  Implement OpenAI-compatible API endpoints alongside existing proprietary API.
  Use when: (1) Adding OpenAI SDK compatibility to existing service, (2) Need
  to support both OpenAI format and custom API simultaneously, (3) Implementing
  streaming endpoints that match OpenAI's binary format vs SSE. Covers FastAPI,
  voice mapping, extended parameters, and streaming format differences.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# OpenAI-Compatible API Implementation

## Problem

Existing proprietary APIs need OpenAI SDK compatibility without breaking current users.
OpenAI uses specific request/response formats and streaming conventions that differ from
typical REST APIs.

## Context / Trigger Conditions

- Building a TTS/ASR/LLM service that should work with OpenAI Python/JavaScript SDKs
- Need to support both proprietary format and OpenAI format simultaneously
- Implementing streaming that matches OpenAI's binary chunk format
- FastAPI or similar framework being used

## Solution

### 1. Add New Endpoints Alongside Existing Ones

**Never replace existing endpoints** - add `/v1/*` routes alongside `/api/*`:

```python
# Keep existing proprietary API
@app.post("/api/generate_tts")
async def generate_tts():
    # Your existing implementation
    pass

# Add OpenAI-compatible endpoint
@app.post("/v1/audio/speech")
async def create_speech(request: OpenAISpeechRequest):
    # OpenAI-compatible implementation
    pass
```

### 2. Map OpenAI Voice Names to Your Speakers

Create a voice mapping configuration:

```json
{
  "openai_voices": {
    "alloy": {"speaker_file": "speaker1.wav", "name": "Speaker 1"},
    "echo": {"speaker_file": "speaker2.wav", "name": "Speaker 2"}
  }
}
```

Resolver function:

```python
def resolve_speaker(voice: str) -> str:
    mapping = get_voice_mapping()
    return mapping.get(voice, mapping.get("alloy"))  # Fallback
```

### 3. Match OpenAI Request/Response Format

**Non-streaming:**
```python
from pydantic import BaseModel

class OpenAISpeechRequest(BaseModel):
    model: str
    input: str
    voice: str
    response_format: str = "mp3"  # mp3, wav, opus
    speed: float = 1.0  # 0.25 to 4.0

@app.post("/v1/audio/speech")
async def create_speech(request: OpenAISpeechRequest):
    # Generate audio
    return FileResponse(audio_path, media_type="audio/mpeg")
```

**Streaming - CRITICAL DIFFERENCE:**
- **SSE (Server-Sent Events)**: Your existing API probably uses this
  ```python
  yield f"data: {json.dumps(event_data)}\n\n"
  ```

- **Raw binary (OpenAI standard)**: OpenAI SDKs expect raw bytes
  ```python
  @app.post("/v1/audio/speech?stream=true")
  async def create_speech_stream():
      async def generate():
          for audio_chunk in audio_generator:
              yield audio_chunk  # Raw bytes, not SSE!

      return StreamingResponse(generate(), media_type="audio/mpeg")
  ```

### 4. OpenAI-Style Error Responses

```python
class OpenAIError(BaseModel):
    message: str
    type: str = "invalid_request_error"
    param: Optional[str] = None
    code: Optional[str] = None

# Return JSON errors for 4xx/5xx
return JSONResponse(
    content={"error": {"message": "Invalid voice", "type": "invalid_request_error"}},
    status_code=400
)
```

### 5. Extended Parameters (Optional)

Support custom parameters alongside OpenAI's:

```python
class OpenAISpeechRequest(BaseModel):
    # Standard OpenAI params
    model: str
    input: str
    voice: str

    # Your custom extensions
    preset: Optional[str] = None
    temperature: Optional[float] = None
    custom_param: Optional[str] = None
```

## Verification

Test with official OpenAI SDKs:

**Python:**
```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:9090/v1", api_key="dummy")

response = client.audio.speech.create(
    model="your-model",
    voice="alloy",
    input="Hello world"
)
response.stream_to_file("test.mp3")
```

**JavaScript:**
```javascript
const openai = new OpenAI({
  baseURL: 'http://localhost:9090/v1',
  apiKey: 'dummy'
});

const mp3 = await openai.audio.speech.create({
  model: 'your-model',
  voice: 'alloy',
  input: 'Hello world'
});
```

## Example

**File: `backend/openai_compat.py`**
```python
from pydantic import BaseModel
from typing import Optional

class OpenAISpeechRequest(BaseModel):
    """Matches OpenAI's AudioSpeechCreate schema"""
    model: str = "chatterbox-tts"
    input: str
    voice: str
    response_format: str = "mp3"
    speed: float = 1.0

    # Extended params
    preset: Optional[str] = "neutral"

def get_voice_mapping() -> dict:
    """Load voice mappings from config"""
    return {
        "alloy": "speaker1.wav",
        "echo": "speaker2.wav"
    }
```

**File: `backend/main.py`**
```python
@app.post("/v1/audio/speech")
async def create_speech(request: OpenAISpeechRequest, stream: bool = False):
    speaker_file = resolve_speaker(request.voice)

    if stream:
        # Raw binary streaming for OpenAI compatibility
        return StreamingResponse(
            generate_raw_audio(),
            media_type=get_content_type(request.response_format)
        )
    else:
        # Non-streaming
        return FileResponse(generate_audio(), media_type="...")
```

## Notes

- **Breaking changes**: Never modify existing `/api/*` endpoints when adding OpenAI compatibility
- **Streaming format**: OpenAI uses raw binary chunks, NOT SSE with JSON metadata
- **Voice mapping**: Provide sensible defaults (fallback to first available voice)
- **Authentication**: OpenAI SDKs send api-key header; validate if needed
- **Model name**: Can be arbitrary (`model: "chatterbox-tts"`), only used for validation
- **Speed parameter**: If implementing, use post-processing (ffmpeg atempo) rather than generation-time

## Common Pitfalls

1. **Wrong streaming format**: Using SSE when SDK expects raw binary
2. **Voice name mismatch**: Not mapping OpenAI voices (alloy, echo) to your speakers
3. **Response headers**: Missing or incorrect `Content-Type` for binary audio
4. **Error format**: Returning HTML instead of JSON for errors
5. **CORS**: OpenAI SDKs may need CORS headers for browser-based usage

## References

- [OpenAI Audio API Reference](https://platform.openai.com/docs/api-reference/audio/createSpeech)
- [OpenAI Python SDK](https://github.com/openai/openai-python)
- [FastAPI StreamingResponse](https://fastapi.tiangolo.com/advanced/custom-response/#streamingresponse)
