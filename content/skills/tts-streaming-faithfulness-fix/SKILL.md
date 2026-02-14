---
name: tts-streaming-faithfulness-fix
description: |
  Fix missing text and repetition issues in transformer-based streaming TTS.
  Use when: (1) TTS output is missing words from input text, (2) Generated
  speech has repetitions like "i hope you can hear this i hope you can hear
  this", (3) Word-chunk based streaming loses context between chunks.
  Covers Chatterbox T3, VITS, and autoregressive transformer TTS models
  using KV cache.
author: Claude Code
version: 1.0.0
date: 2026-01-21
---

# TTS Streaming Faithfulness Fix

## Problem

When implementing streaming TTS by splitting text into word-based chunks and processing each chunk independently, the generated audio has two critical issues:

1. **Missing text**: Words from the input text are not present in the output
2. **Repetition**: Phrases are repeated unexpectedly in the generated speech

**Example**:
- Input: "Hello! This is a test of the streaming TTS service. I hope you can hear this clearly..."
- Output: "Hello! This is a test of the streaming. I hope you can hear this i hope you can hear this clearly..."
- Issues: "TTS service" is missing, "i hope you can hear this" is repeated

## Context / Trigger Conditions

- **Symptoms**: Transcribed output doesn't match input text; words missing or repeated
- **Architecture**: Transformer-based autoregressive TTS (T3, VITS variants, etc.)
- **Implementation**: Word-chunk or sentence-chunk based streaming where each chunk calls `generate()` independently
- **Models affected**: Any TTS model using transformer decoder with KV cache (Chatterbox T3, similar architectures)

## Root Cause

The word-chunk streaming approach calls the model's `generate()` method independently for each chunk. Each call:

1. Tokenizes just that chunk (not the full context)
2. Runs inference from scratch with no knowledge of previous chunks
3. Generates audio without state (KV cache, text tokens, speech tokens) from prior chunks
4. This causes context loss and potential repetition as the model "forgets" what came before

The transformer's internal KV cache IS used during generation loop within each chunk, but is discarded between chunks.

## Solution

**Correct approach: Token-level streaming with state preservation**

1. **Tokenize the full text upfront** (or stream text tokens in progressively)
2. **Process text tokens incrementally** through the encoder
3. **Maintain KV cache across chunks** during autoregressive speech token generation
4. **Stream audio output** as speech tokens are decoded

**Implementation options**:

### Option A: Use existing streaming implementation
- For Chatterbox: Reference [chatterbox-streaming](https://github.com/davidbrowne17/chatterbox-streaming) repo
- The codebase may already have `AlignmentStreamAnalyzer` (often commented out in `t3.py`) for token-level streaming

### Option B: Modify generation to preserve state
```python
# Instead of calling generate() for each chunk independently:
for chunk in text_chunks:
    audio = model.generate(text=chunk)  # ❌ Wrong - loses state

# Use a streaming-aware approach:
streaming_state = model.init_streaming(text_tokens)
while not streaming_state.done:
    audio_chunk, streaming_state = model.stream_step(streaming_state)  # ✅ Correct
```

Key state to preserve across chunks:
- **past_key_values** (KV cache from transformer layers)
- **text_tokens** (full or incremental text token sequence)
- **generated_speech_tokens** (autoregressive speech generation context)
- **position embeddings** (proper indexing for incremental generation)

## Verification

1. Generate streaming TTS with a multi-sentence text
2. Transcribe the output audio
3. Compare transcription with input text
4. Confirm: (a) all words present, (b) no unintended repetitions

## Example

**ChatterBox T3 Investigation**:

The file `backend/streaming_service.py` had a `StreamingTTS` class that split text into word chunks:

```python
def generate_stream(self, text: str, chunk_size_words: int = 10):
    text_chunks = self._split_text_into_chunks(text, chunk_size_words)
    for chunk_index, text_chunk in enumerate(text_chunks):
        audio_chunk = self.model.generate(  # ❌ Independent call
            text=text_chunk,
            audio_prompt_path=None,  # Conditioning prepared once
            # ...
        )
        yield audio_chunk, metrics
```

**The fix**: The model already uses KV cache internally during generation (see `backend/chatterbox/src/chatterbox/models/t3/t3.py` lines 311-372), but each `generate()` call starts fresh. The proper streaming implementation needs to:

1. Call `t3.inference()` once with full text tokens
2. Return speech tokens incrementally via the generation loop
3. Preserve `past_key_values` across the autoregressive generation steps
4. Yield audio chunks as speech tokens are decoded

The `AlignmentStreamAnalyzer` class exists in the codebase for this purpose but is commented out in the current implementation.

## Notes

- **Word-chunk vs Token-level streaming**: Word-chunk has lower latency for first audio (~2-3s vs ~5-10s for full text), but sacrifices faithfulness. Token-level streaming provides both low latency AND faithfulness.
- **Latency targets**: Production voice agents need sub-300ms total latency, with sub-100ms time-to-first-byte (TTFB) for streaming TTS
- **Look-ahead mechanism**: Some implementations use k future tokens look-ahead to trade off latency and accuracy
- **KV cache compression**: For long-form content, consider memory-constrained KV cache compression techniques

## References

- [SpeakStream: Streaming Text-to-Speech with Interleaved](https://arxiv.org/pdf/2505.19206) - arXiv 2025
- [Text-to-Speech Architecture: Production Trade-Offs & Best Practices](https://deepgram.com/learn/text-to-speech-architecture-production-tradeoffs) - Deepgram 2025
- [Transducer for Text to Speech (NeurIPS 2021)](https://proceedings.neurips.cc/paper/2021/file/344ef5151be171062f42f03e69663ecf-Paper.pdf)
- [Streaming Speech Tokenizer](https://www.emergentmind.com/topics/streaming-speech-tokenizer) - Emergent Mind 2025
