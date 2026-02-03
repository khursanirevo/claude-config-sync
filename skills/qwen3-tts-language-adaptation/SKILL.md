---
name: qwen3-tts-language-adaptation
description: |
  Language adaptation for Qwen3-TTS via component-specific fine-tuning. Use when:
  (1) Adding new language support to Qwen3-TTS, (2) Provided sft_12hz.py only does
  speaker adaptation not language adaptation, (3) Need to fine-tune text understanding
  separately from acoustic generation. Covers text_embedding and code_predictor
  fine-tuning,区别 between linguistic vs acoustic adaptation, and two-stage approach.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# Qwen3-TTS Language Adaptation via Component-Specific Fine-tuning

## Problem

The Qwen3-TTS fine-tuning script (`sft_12hz.py`) only supports **single-speaker adaptation** - it adds a new speaker voice but doesn't adapt the model to new languages. To add support for an unsupported language (e.g., Malay), you need **language adaptation**, which requires fine-tuning different model components.

## Context / Trigger Conditions

- You need to add a new language to Qwen3-TTS that isn't in the 10 supported languages
- The provided `sft_12hz.py` script converts Base → CustomVoice model type, which isn't what you want
- You want minimal parameter training to avoid catastrophic forgetting
- You need to understand which model components control text understanding vs acoustic generation

**Current supported languages**: Chinese, English, Japanese, Korean, German, French, Russian, Portuguese, Spanish, Italian

## Solution

### Understanding Qwen3-TTS Architecture

```
Qwen3TTSForConditionalGeneration
├── talker.model.text_embedding    # ← Text/linguistic understanding
├── talker.model.codec_embedding   # ← Audio codec tokens
├── talker.layers                  # ← Shared transformer (20 layers)
├── talker.code_predictor          # ← Acoustic code generation
└── speaker_encoder                # ← Speaker embedding (freeze for language FT)
```

**Key insight**: Text understanding and acoustic generation are **separate** and can be fine-tuned independently.

### Two-Stage Approach

#### Stage 1: Text Embedding Fine-tuning (Linguistic Adaptation)

**Target**: `talker.model.text_embedding` only (~4M params, 0.24% of 1.7B model)

**Purpose**: Adapt text understanding to new language patterns

**Training approach**:
1. Prepare text-only data (just transcripts in target language):
```jsonl
{"text":"Hai, apa khabar?"}
{"text":"Saya suka belajar bahasa."}
```

2. Fine-tune only text_embedding, freeze everything else:
```python
for name, param in model.named_parameters():
    if "text_embedding" in name:
        param.requires_grad = True
    else:
        param.requires_grad = False
```

3. Use higher learning rate (1e-4) since only training one layer

**Expected result**: Model can process target language text better, but acoustic quality may still need improvement.

#### Stage 2: Code Predictor Fine-tuning (Acoustic Alignment) - Optional

**Target**: `talker.code_predictor` (~30-50M params)

**Purpose**: Align acoustic generation to new language's phonetic patterns

**When to use**: Only if Stage 1 results are insufficient (poor pronunciation, unnatural prosody)

**Training approach**:
1. Prepare full data with audio codes pre-computed (use `prepare_data.py`)
2. Freeze text_embedding (from Stage 1), unfreeze code_predictor
3. Use lower learning rate (5e-5) for larger component

### Key Differences from Speaker Fine-tuning

| Aspect | sft_12hz.py (Speaker FT) | Language Adaptation |
|--------|--------------------------|-------------------|
| Goal | Add new speaker voice | Add new language support |
| Trains | Entire model (~1.7B params) | Single component (~4-50M params) |
| Model type change | Base → CustomVoice | Remains Base |
| API after FT | `generate_custom_voice()` | `generate_voice_clone()` |
| Use case | Voice cloning, multi-speaker | Language support |

### Template Scripts

Create these in your `finetuning/` directory:

**ft_text_embedding.py**:
```python
# Load Base model
model = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-1.7B-Base", ...)

# Freeze everything except text_embedding
for name, param in model.model.named_parameters():
    if "text_embedding" in name:
        param.requires_grad = True
    else:
        param.requires_grad = False

# Train with text-only data
# Use higher LR: 1e-4
# Save only text_embedding weights
```

**ft_code_predictor.py**:
```python
# Load Stage 1 model
model = Qwen3TTSModel.from_pretrained("./stage1_output", ...)

# Freeze everything except code_predictor
for name, param in model.model.named_parameters():
    if "code_predictor" in name:
        param.requires_grad = True
    else:
        param.requires_grad = False

# Train with full audio data
# Use lower LR: 5e-5
# Save only code_predictor weights
```

See complete scripts in: `/mnt/data/work/Qwen3-TTS/finetuning/`

## Verification

After Stage 1, test pronunciation and intelligibility:
```python
model = Qwen3TTSModel.from_pretrained("./stage1/checkpoint-epoch-4", ...)
wavs, sr = model.generate_voice_clone(
    text="Test sentence in target language",
    language="TargetLanguage",
    ref_audio="ref.wav",
    ref_text="Reference transcript"
)
```

**Evaluation checklist**:
- [ ] Pronunciation is understandable
- [ ] Intonation sounds natural for target language
- [ ] No excessive stuttering or repetition

**If good**: Stop at Stage 1
**If needs improvement**: Proceed to Stage 2

## Notes

### Why Not Use sft_12hz.py?

The provided script is designed for **speaker adaptation**, not language adaptation:

1. It adds a new speaker embedding at index 3000 in codec_embedding
2. Converts model type from "base" to "custom_voice"
3. Result can only use `generate_custom_voice()` with predefined speakers
4. Doesn't adapt text understanding to new language

For language adaptation, you need to keep the model as "base" type and train linguistic components.

### Component-Specific Training Benefits

- **Parameter efficiency**: Train 0.24% of model instead of 100%
- **Catastrophic forgetting**: Minimal since most parameters are frozen
- **Modular**: Can evaluate after each stage and decide if next stage is needed
- **Reversible**: Can discard individual stage checkpoints if needed

### Data Requirements

**Stage 1 (text_embedding)**: Text-only data sufficient
- Minimum: 100-500 sentences
- Quality over quantity: clean transcripts, proper spelling
- No audio required initially

**Stage 2 (code_predictor)**: Full audio+text data needed
- Must pre-compute audio codes using `prepare_data.py`
- Minimum: 30-60 minutes of aligned audio
- Consistent speaker voice recommended

### Language Token Configuration

After training, update `config.json` to add your language:

```json
{
  "talker_config": {
    "codec_language_id": {
      "Malay": <language_token_id>
    }
  }
}
```

You may need to determine the correct language token ID for your target language.

### Common Pitfalls

1. **Confusing speaker FT with language FT**: sft_12hz.py is for speakers, not languages
2. **Training too much at once**: Start with text_embedding only, evaluate, then decide
3. **Skipping Stage 1 evaluation**: Stage 2 is computationally expensive - only do it if needed
4. **Using wrong API**: After component FT, model remains Base type - use `generate_voice_clone()`

## References

- Qwen3-TTS GitHub: https://github.com/QwenLM/Qwen3-TTS
- Fine-tuning guide: `/mnt/data/work/Qwen3-TTS/finetuning/README.md`
- Component-specific scripts: `/mnt/data/work/Qwen3-TTS/finetuning/ft_*.py`
