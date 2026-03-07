---
name: zipvoice-multilingual-finetuning
description: |
  Add new languages to ZipVoice TTS via fine-tuning with espeak tokenizer.
  Use when: (1) Fine-tuning ZipVoice for languages other than Chinese/English,
  (2) Converting JSON+audio datasets to ZipVoice TSV format, (3) Understanding
  espeak tokenizer language support. Covers espeak-ng language codes (ms, fr, de, etc.),
  tokenizer selection parameters (is_zh_en=0, lang=code, tokenizer=espeak), and
  data format conversion workflow.
author: Claude Code
version: 1.0.0
date: 2025-01-22
---

# ZipVoice Multi-lingual Fine-tuning

## Problem
ZipVoice's main documentation focuses on Chinese+English (Emilia tokenizer), making
it unclear how to add support for other languages. The espeak tokenizer supports
100+ languages but this requires specific parameter configuration.

## Context / Trigger Conditions
- Need to fine-tune ZipVoice for languages beyond Chinese/English (e.g., Malay, French, German)
- Converting datasets from JSON+audio format to ZipVoice's TSV format
- Understanding which tokenizer to use and what language codes are supported
- Working with symlinked audio files that need path resolution

## Solution

### Tokenizer Selection

ZipVoice has two main tokenizers:

| Tokenizer | Use Case | Language Parameter |
|-----------|----------|-------------------|
| `emilia` | Chinese + English only | None needed |
| `espeak` | All other languages (~100+ supported) | `lang` required (ISO 639-1 code) |

### Critical Fine-tuning Parameters

For non-Chinese/English languages, set these in your fine-tuning script:

```bash
is_zh_en=0        # NOT Chinese/English
lang=ms           # ISO 639-1 language code (e.g., ms=Malay, fr=French, de=German)
tokenizer=espeak  # Multi-lingual tokenizer
```

### Language Code Reference

Find espeak-ng language codes at: [espeak-ng/docs/languages.md](https://github.com/espeak-ng/espeak-ng/blob/master/docs/languages.md)

Common codes:
- `ms` - Malay
- `fr` - French
- `de` - German
- `es` - Spanish
- `ja` - Japanese
- `ko` - Korean

### Data Format Conversion

ZipVoice expects TSV format: `{uniq_id}\t{text}\t{absolute_audio_path}`

When converting from JSON+audio datasets:
1. **Resolve symlinks**: Use `Path.resolve()` to get absolute paths
2. **Handle different JSON structures**: Datasets may have different schemas
3. **Output correct split names**: Use `dev` not `valid` for validation set

### Token Files

The pre-trained `tokens.txt` from ZipVoice already includes espeak phonemes
for all supported languages. No need to generate new tokens for your language.

### Complete Fine-tuning Workflow

1. **Convert data to TSV format**
2. **Prepare manifests**: `zipvoice.bin.prepare_dataset`
3. **Add espeak tokens**: `zipvoice.bin.prepare_tokens --tokenizer espeak --lang <code>`
4. **Compute Fbank features**: `zipvoice.bin.compute_fbank`
5. **Download pre-trained model**: Get `model.pt`, `tokens.txt`, `model.json`
6. **Fine-tune**:
   ```bash
   python3 -m zipvoice.bin.train_zipvoice \
       --finetune 1 \
       --tokenizer espeak \
       --lang <language_code> \
       --base-lr 0.0001 \
       --num-iters 10000 \
       ...
   ```
7. **Average checkpoints**: `zipvoice.bin.generate_averaged_model`
8. **Test inference**: `zipvoice.bin.infer_zipvoice --tokenizer espeak --lang <code>`

## Verification

**Check espeak-ng supports your language:**
```bash
espeak-ng --voices | grep <language_code>
```

**Test tokenization:**
```bash
python3 -m zipvoice.bin.prepare_tokens \
    --tokenizer espeak \
    --lang ms \
    --input-file test.jsonl.gz \
    --output-file test_output.jsonl.gz
```

**Verify model loads:**
```bash
python3 -m zipvoice.bin.infer_zipvoice \
    --model-name zipvoice \
    --model-dir exp/zipvoice_malay_finetune/ \
    --checkpoint-name iter-10000-avg-2.pt \
    --tokenizer espeak \
    --lang ms \
    ...
```

## Example: Adding Malay Support

**Data conversion script pattern:**
```python
def extract_text(dataset_json):
    # Handle different JSON structures per dataset
    if "transcription" in dataset_json:
        for entry in dataset_json["transcription"]:
            if entry.get("label_source") == "reference":
                return entry["transcript"]
    return dataset_json.get("text", "")

# Resolve symlinks to absolute paths
audio_path = Path(symlink_path).resolve()
```

**Fine-tuning script parameters:**
```bash
is_zh_en=0
lang=ms
tokenizer=espeak
```

**Expected dataset size:**
- Minimum: 3-5 hours for acceptable quality
- Recommended: 10-50 hours for good quality
- The pre-trained model was trained on 1000+ hours, so fine-tuning adapts
  pronunciation but some base model characteristics remain

## Notes

**Training time estimates** (for ~5 hours data):
- 4x A100: 2-3 hours
- 4x V100: 4-5 hours
- 1x A100: 8-10 hours

**Quality expectations:**
- With 5 hours: Good quality, slight accent from pre-trained model
- With 10+ hours: Better native pronunciation
- Fine-tuning adapts to target language but base model characteristics persist

**Common issues:**
- **"Error: lang is not set!"**: Ensure `is_zh_en=0` and `lang=<code>` are both set
- **CUDA out of memory**: Reduce `--max-duration` or decrease `--world-size`
- **Slow tokenization**: Pre-compute tokens with `prepare_tokens` before training
- **Symlink resolution failures**: Use absolute paths, not relative paths

**Alternative approach: ONNX export for CPU deployment:**
After fine-tuning, export to ONNX for faster CPU inference:
```bash
python3 -m zipvoice.bin.onnx_export \
    --model-name zipvoice \
    --model-dir exp/zipvoice_malay_finetune/ \
    --checkpoint-name iter-10000-avg-2.pt \
    --onnx-model-dir exp/zipvoice_malay_finetune/
```

## References

- [ZipVoice GitHub Repository](https://github.com/k2-fsa/ZipVoice)
- [ZipVoice Documentation](https://zipvoice.github.io/)
- [espeak-ng Language Codes](https://github.com/espeak-ng/espeak-ng/blob/master/docs/languages.md)
- [eSpeak NG Speech Synthesizer](https://github.com/espeak-ng/espeak-ng)
- [Adding Language Support with espeak-ng](https://facefx.com/content/adding-language-support-espeak-ng)
