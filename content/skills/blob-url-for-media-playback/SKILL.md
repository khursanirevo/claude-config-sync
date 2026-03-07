---
name: blob-url-for-media-playback
description: |
  Fix "NotSupportedError: The element has no supported sources" when using HTMLAudioElement
  or HTMLVideoElement with Base64 data URLs. Use when: (1) audio/video from localStorage or
  APIs fails to play, (2) data: URLs as src cause browser compatibility issues, (3) mobile
  Safari refuses to load media. Covers fetch + URL.createObjectURL pattern for better browser
  support, especially for localStorage persistence and file uploads.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Blob URLs for Media Playback

## Problem
When using Base64-encoded data URLs (data URIs) as the `src` for `<audio>` or `<video>` elements, browsers may fail with:

```
NotSupportedError: The element has no supported sources
```

This happens because:
- Base64 data URLs have inconsistent browser support for media elements
- Mobile Safari has known bugs with data URIs for media playback
- Large Base64 strings can cause performance issues

## Context / Trigger Conditions

**When to use this pattern:**
- Audio/video stored in localStorage as Base64
- Media files returned from APIs as Base64 strings
- File uploads that need preview before upload
- Any scenario using `data:audio/...` or `data:video/...` URLs as media src

**Specific symptoms:**
- `NotSupportedError: The element has no supported sources`
- Audio/video works on desktop but fails on mobile Safari
- Media element shows loading spinner but never plays
- Browser console shows no other errors

## Solution

Convert Base64 data URLs to Blob URLs using the fetch API:

```typescript
/**
 * Convert a Base64 data URL to a Blob URL for reliable media playback
 */
async function ensureBlobUrl(dataUrl: string): Promise<string> {
  // If it's already a blob URL, return as-is
  if (dataUrl.startsWith('blob:')) {
    return dataUrl;
  }

  // If it's a data URL, convert to blob URL
  if (dataUrl.startsWith('data:')) {
    const response = await fetch(dataUrl);
    const blob = await response.blob();
    return URL.createObjectURL(blob);
  }

  // Otherwise return as-is (http/https URLs)
  return dataUrl;
}
```

**In React components:**

```typescript
const AudioPlayer: React.FC<{ audioUrl: string }> = ({ audioUrl }) => {
  const [processedUrl, setProcessedUrl] = useState<string>(audioUrl);

  useEffect(() => {
    const processUrl = async () => {
      const url = await ensureBlobUrl(audioUrl);
      setProcessedUrl(url);
    };
    processUrl();
  }, [audioUrl]);

  return <audio src={processedUrl} controls />;
};
```

**Memory cleanup (important!):**

```typescript
useEffect(() => {
  // Create blob URL
  const url = await ensureBlobUrl(audioUrl);
  setProcessedUrl(url);

  // Cleanup: revoke blob URL when component unmounts
  return () => {
    if (url.startsWith('blob:')) {
      URL.revokeObjectURL(url);
    }
  };
}, [audioUrl]);
```

## Verification

After applying this fix:
1. Audio/video should play across all browsers (Chrome, Firefox, Safari, Edge)
2. Mobile Safari should successfully load and play media
3. No `NotSupportedError` in console
4. Check memory usage - blob URLs use less memory than large data URLs

## Example

**Before (broken):**

```typescript
// Audio from localStorage (Base64)
const base64Audio = localStorage.getItem('savedAudio');
<audio src={base64Audio} />  // ❌ May fail with NotSupportedError
```

**After (fixed):**

```typescript
const [audioSrc, setAudioSrc] = useState<string>('');

useEffect(() => {
  const loadAudio = async () => {
    const base64Audio = localStorage.getItem('savedAudio');
    const blobUrl = await ensureBlobUrl(base64Audio);
    setAudioSrc(blobUrl);
  };
  loadAudio();

  // Cleanup
  return () => {
    if (audioSrc.startsWith('blob:')) {
      URL.revokeObjectURL(audioSrc);
    }
  };
}, []);

<audio src={audioSrc} />  // ✅ Works reliably
```

## Notes

**Why this works:**
- Blob URLs have consistent browser support (all modern browsers)
- Better memory efficiency for large media files
- No data URI size limitations
- Mobile Safari has fewer issues with blob URLs than data URIs

**Caveats:**
- Always revoke blob URLs with `URL.revokeObjectURL()` to avoid memory leaks
- Blob URLs are only valid for the lifetime of the document
- For server-hosted media, regular http/https URLs are still best

**When NOT to use:**
- For regular remote URLs (http/https) - use them directly
- For small images that work fine as data URIs
- When you need the URL to persist across page reloads (blob URLs don't survive)

**Related patterns:**
- For file uploads: `URL.createObjectURL(file)` on File objects
- For canvas exports: `canvas.toBlob()` then `URL.createObjectURL(blob)`
- For MediaRecorder: Use `blob` from `dataavailable` event

## References

- [MDN: Audio and Video Delivery Guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Audio_and_video_delivery)
- [MDN: Data URLs Reference](https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/data)
- [WebKit Bug: Safari iOS cannot play video from data URI](https://bugs.webkit.org/show_bug.cgi?id=232076)
- [Stack Overflow: Data URIs in audio tags](https://stackoverflow.com/questions/2270151/is-it-possible-to-use-data-uris-in-video-and-audio-tags)
- [Can I Use: Blob URLs](https://caniuse.com/bloburls)
