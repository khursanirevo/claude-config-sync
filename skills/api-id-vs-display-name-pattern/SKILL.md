---
name: api-id-vs-display-name-pattern
description: |
  Fix API 500 errors when frontend sends display names instead of IDs. Use when:
  (1) Backend API returns 500 Internal Server Error, (2) You're sending
  speaker_name/user_name/display_name but backend expects file path or ID,
  (3) Backend constructs file paths like os.path.join(DIR, speaker_name),
  (4) Error mentions "file not found" or "invalid speaker". Common pattern in
  file upload, TTS, and media processing apps.
author: Claude Code
version: 1.0.0
date: 2025-01-21
---

# API ID vs Display Name Pattern Fix

## Problem
Frontend sends human-readable display names (e.g., "Anwar Ibrahim") to backend APIs,
but backend expects system IDs or file names (e.g., "anwar.wav"). This causes 500
errors or "file not found" issues when backend tries to construct file paths.

## Context / Trigger Conditions
- **API returns 500 Internal Server Error**
- **Error message mentions**: "Invalid speaker selected", "file not found", or "audio file not found"
- **Backend code pattern**: `os.path.join(PERMANENT_DIR, speaker_name)` or similar
- **Frontend sends**: `speaker.name` (display name) instead of `speaker.id` (filename/ID)
- **Common in**: TTS systems, voice conversion, media apps, file management systems

## Root Cause
Backend API constructs file paths using the user-provided "name" parameter directly:
```python
audio_prompt_path_input = os.path.join(PERMANENT_DIR, speaker_name)
# speaker_name="Anwar Ibrahim" ❌
# speaker_name="anwar.wav" ✅
```

The frontend's Speaker object has both:
- `speaker.id` - The actual file name (e.g., "anwar.wav", "2469-SURAYA-Milo-MBD-Testimonial-1-BM.wav")
- `speaker.name` - The display name (e.g., "Anwar Ibrahim", "Suraya (Milo)")

## Solution

### Step 1: Check Backend Expectations
Look at the backend API endpoint definition:
```python
@web_app.post("/api/generate_tts")
async def api_generate_tts(
    text: str = Form(...),
    speaker_name: str = Form(...),  # ← Check how this is used
    ...
):
    audio_prompt_path_input = os.path.join(PERMANENT_DIR, speaker_name)
```

If `speaker_name` is used directly in file paths, it expects an ID/filename, not display name.

### Step 2: Update Frontend
Change frontend to send `speaker.id` instead of `speaker.name`:

**Before (WRONG):**
```typescript
const result = await generateTTS.mutateAsync({
  text: text.trim(),
  speakerName: selectedSpeaker.name,  // ❌ Display name
  ...
});
```

**After (CORRECT):**
```typescript
const result = await generateTTS.mutateAsync({
  text: text.trim(),
  speakerName: selectedSpeaker.id,  // ✅ File name/ID
  ...
});
```

### Step 3: Verify Backend Speaker Response Format
Check what the backend returns from `/api/speakers`:
```json
{
  "speakers": [
    {
      "id": "anwar.wav",           // ← Use this for API calls
      "name": "Anwar Ibrahim"      // ← Only use for UI display
    }
  ]
}
```

### Step 4: Apply Fix to All Affected Endpoints
Check all API calls that send speaker/user information:
- TTS generation: `speakerName: selectedSpeaker.id`
- Voice conversion: `targetSpeakerName: targetSpeaker.id`
- Any other file-path-based API

## Verification

1. **Build**: Ensure TypeScript compiles without errors
2. **Test**: Call the API endpoint with the ID
3. **Check logs**: Backend should successfully find the file
4. **Confirm**: API returns 200 OK instead of 500 error

## Example

### ChatterBox TTS Case
**Backend Code (deploy.py:168-190):**
```python
@web_app.post("/api/generate_tts")
async def api_generate_tts(
    text: str = Form(...),
    speaker_name: str = Form(...),
    ...
):
    audio_prompt_path_input = os.path.join(PERMANENT_DIR, speaker_name)
    # speaker_name must be like "anwar.wav", not "Anwar Ibrahim"
```

**Frontend Fix:**
File: `frontend-react/src/pages/TTGeneration.tsx:81`
```typescript
speakerName: selectedSpeaker.id,  // Changed from .name to .id
```

**Before Fix:**
```
POST /api/generate_tts 500
Error: "Invalid speaker selected or speaker audio file not found"
```

**After Fix:**
```
POST /api/generate_tts 200 OK
Returns: Audio file (WAV)
```

## Notes

### How to Identify This Pattern
1. Backend uses form parameter named `speaker_name`, `user_name`, `target_speaker`, etc.
2. Backend constructs file paths with: `os.path.join(DIR, parameter)`
3. Error messages mention "file not found" or "invalid [entity]"
4. Frontend Speaker/User objects have both `.id` and `.name` properties

### Related Patterns
- **User ID vs Username**: Similar issue for user accounts
- **File uploads**: May need filename vs display name
- **Database records**: Need primary key vs display name

### Prevention
- **API contract**: Document whether endpoints expect IDs or display names
- **Type safety**: Use TypeScript enums or clear naming (e.g., `speakerId` vs `speakerDisplayName`)
- **Validation**: Backend should validate file existence and return clear error messages

### When This Doesn't Apply
- If backend does lookup by display name (e.g., database query)
- If backend sanitizes/converts the name to a file path
- If using numeric IDs instead of string-based filenames

## References
- Common pattern in FastAPI + React applications
- Similar issues in Django REST frameworks, Express.js with file uploads
- ChatterBox project: `/mnt/data/work/ChatterBox/deploy.py` and `/mnt/data/work/ChatterBox/frontend-react/`
