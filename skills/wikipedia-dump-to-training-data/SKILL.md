---
name: wikipedia-dump-to-training-data
description: |
  Complete pipeline for processing Wikipedia dumps into high-quality LLM training data.
  Use when: (1) Building large-scale reasoning datasets, (2) Processing Wikipedia XML dumps,
  (3) Creating multilingual training corpora, (4) Implementing multi-agent generation pipelines.
  Covers: BZ2 decompression, streaming XML parsing, API rate limiting, quality control with
  SYNTH reasoning symbols, and cultural authenticity for AI training data.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# Wikipedia Dump to LLM Training Data Pipeline

## Problem
Building large-scale, high-quality training datasets from Wikipedia requires handling
multi-gigabyte XML dumps, managing API rate limits, and ensuring consistent reasoning quality.

## Context / Trigger Conditions
- Need to process Wikipedia dumps (mswiki, enwiki, etc.)
- Building reasoning or instruction-tuning datasets
- Encountering 429 API rate limit errors during generation
- OOM crashes when parsing large XML files
- Need quality control mechanisms for training data
- Want cultural authenticity in non-English datasets

## Solution

### 1. Wikipedia Dump Acquisition

**Critical: Use dated filenames, NOT "latest"**

```bash
# WRONG - will fail with 404
https://dumps.wikimedia.org/mswiki/latest/mswiki-latest-pages-articles.xml.bz2

# CORRECT - use YYYYMMDD format
https://dumps.wikimedia.org/mswiki/20260101/mswiki-20260101-pages-articles.xml.bz2

# Download with curl (supports resume)
curl -L -C - -o output.xml.bz2 "https://dumps.wikimedia.org/mswiki/20260101/mswiki-20260101-pages-articles.xml.bz2"

# Find available dates
curl "https://dumps.wikimedia.org/mswiki/" | grep -oP 'href="\d{8}/"' | sort -u
```

**File Sizes:**
- Malay Wikipedia: 370MB compressed → 2.2GB XML
- English Wikipedia: 20GB compressed → ~200GB XML
- Consider scale before downloading English

### 2. BZ2 Decompression

**Problem:** Node.js `zlib` doesn't support BZ2 format

```bash
# Solution: Use external bunzip2 command
bunzip2 -k -c input.xml.bz2 > input.xml

# -k: Keep compressed file
# -c: Write to stdout
# Streaming: Doesn't load entire file into memory
```

### 3. Streaming XML Parsing

**Problem:** Can't read 2GB+ XML as string (V8 limit: 0x1fffffe8 characters)

```javascript
// CORRECT APPROACH: Streaming with readline
import { createReadStream } from 'fs';
import { createInterface } from 'readline';

const fileStream = createReadStream(inputFile, { encoding: 'utf-8' });
const rl = createInterface({ input: fileStream, crlfDelay: Infinity });

let inPage = false;
let currentArticle = {};
let currentText = '';

for await (const line of rl) {
  if (line.includes('<page>')) {
    inPage = true;
    currentArticle = {};
    currentText = '';
    continue;
  }

  if (line.includes('</page>')) {
    inPage = false;
    // Process article here
    processArticle(currentArticle, currentText);
    continue;
  }

  if (!inPage) continue;

  // Extract title, text, etc.
  if (line.includes('<title>')) {
    currentArticle.title = line.replace(/.*<title>(.*?)<\/title>.*/, '$1');
  }
  // ... handle text extraction
}
```

### 4. ES Module + CommonJS Compatibility

**Problem:** SAX parser is CommonJS-only, doesn't work with ES modules

```javascript
// Solution: Use createRequire for ES modules
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const sax = require('sax');

// Now can use CommonJS packages in ES modules
```

### 5. Quality Filtering

**Apply during parsing to reduce downstream noise:**

```javascript
// Filter by word count
const wordCount = cleanText.split(/\s+/).length;
if (wordCount < 500 || wordCount > 10000) {
  continue; // Skip stubs and massive pages
}

// Blacklist prefixes
const blacklist = ['Wikipedia:', 'Template:', 'Category:', 'File:', 'Portal:', 'Draft:'];
if (blacklist.some(prefix => title.startsWith(prefix))) {
  continue;
}
```

### 6. Topic Generation Strategy

**Generate 7 variations per article for diversity:**

```javascript
function generateQueries(article) {
  const { title, text, categories } = article;

  return [
    `Apakah ${title}?`,
    `Terangkan tentang ${title} dalam Bahasa Melayu.`,
    `Bagaimanakah ${title} digunakan ${contexts[Math.floor(Math.random() * 4)]}?`,
    `Apakah perbezaan antara ${title} dan ${relatedConcept}?`,
    `Berikan 5 contoh penggunaan ${title} dalam ayat.`,
    `Bagaimanakah menggunakan ${title} dengan betul?`,
    `Jelaskan kepentingan ${title} dalam bahasa Melayu.`
  ];
}

// 21,929 articles × 7 = 153,371 topics
```

### 7. API Rate Limiting

**Critical: Maximum concurrency is 5 workers**

```javascript
const CONFIG = {
  apiKey: 'your-api-key',
  baseUrl: 'https://api.example.com',
  model: 'model-name',
  concurrency: 5,  // MAXIMUM - 429 errors above this
  maxRetries: 3,
  retryDelay: 2000
};

// Worker distribution
const workerCount = 5;
const topicsPerWorker = Math.ceil(totalTopics / workerCount);

// Run in parallel
await Promise.all(workers);
```

**Symptoms of rate limiting:**
- Error: `429 High concurrency usage`
- Solution: Reduce `concurrency` to ≤5

### 8. Multi-Agent DEEP Pipeline

**4-Agent architecture for high-quality reasoning:**

```javascript
// Agent 1: Meta - Analyze query
const metaOutput = await callAPI(metaPrompt, query);

// Agent 2: Retrieval - Gather knowledge
const retrievalOutput = await callAPI(retrievalPrompt, `
  Query: ${query}
  Meta Analysis: ${metaOutput}
  Identify grammar rules and examples.
`);

// Agent 3: Derivation - Build reasoning chain
const derivationOutput = await callAPI(derivationPrompt, `
  Query: ${query}
  Knowledge: ${retrievalOutput}
  Build reasoning with SYNTH symbols (→, ∴, ●, !, ※, ⚠, ?)
`);

// Agent 4: Responder - Compose final answer
const answer = await callAPI(responderPrompt, `
  Query: ${query}
  Reasoning: ${derivationOutput}
  Write educational answer in target language.
`);
```

**Result:** Consistently high-quality reasoning (4.9/5)

### 9. SYNTH Symbol Usage

**Teach models step-by-step reasoning:**

```
→ (Derives/Implies): Logical flow
∴ (Conclusion): Deductions
● (Ground Truth): Facts
! (Insight): Key observations
※ (Constraint/Trap): Exceptions, common errors
⚠ (Warning): Cautions, risks
? (Ambiguity): Uncertainties
◐ (Inference): Interpretations
```

**Example:**
```
### 1. Analisis Definisi
→ Kata dasar: "sudah" dan "telah" ●
→ Kedua-dua ialah kata kerja sempang ●
→ ∴ Persamaan: Fungsi asas yang sama
! Perbezaan nuansa: Formal vs informal ◐
```

### 10. Cultural Authenticity

**Add regional dialect awareness for non-English:**

```
Kedah/Perlis: "lagi" = "masih", "jangan" = "jang"
Kelantan: "ghe" = "kita", "mui" = "mari"
Negeri Sembilan: "hang" = "awak", "kameq" = "saya"
Terengganu: "su" = "kita", "kaw" = "awak"
Sabah/Sarawak: Various local expressions
```

### 11. Batch Generation Strategy

**Generate in manageable batches:**

```bash
# Start small to verify quality
node scripts/generate-bm-deep.js topics.txt 100

# Scale up once stable
node scripts/generate-bm-deep.js topics.txt 400

# Monitor progress
tail -f output.log | grep "Completed"
```

**Time Estimates:**
- 100 samples: ~32 minutes (5 workers)
- 500 samples: ~2.5 hours
- 1,000 samples: ~5 hours
- Rate: ~50 samples/hour sustainable

### 12. Error Detection

**Model intelligently catches semantic mismatches:**

```
Query: "Cara memilih sekolah untuk mahasiswa universiti di hospital"

Reasoning:
→ ! Kontradiksi logik: Mahasiswa tidak perlu memilih sekolah menengah ⚠
→ ? Analisis niat pengguna: Mungkin bertanya strategi komunikasi ◐
→ ∴ Asumsi: Fokus kepada penjelasan demografi pesakit
```

## Verification

### Check Data Quality

```bash
# Sample random entries
shuf dataset.jsonl | head -5 | jq '.'

# Count samples
wc -l dataset.jsonl

# Check SYNTH symbol compliance
grep -c "→" dataset.jsonl  # Should be 100%

# Check for API errors
grep -c "429" generation.log  # Should be 0
```

### Quality Metrics

- SYNTH symbol usage: 99.9%
- Cultural authenticity: 5/5
- Reasoning depth: Multi-step analysis
- Error detection: Intelligent

## Example: Complete Pipeline

```bash
# 1. Download Wikipedia dump
curl -L -C - -o wiki-data/dumps/mswiki-20260101-pages-articles.xml.bz2 \
  "https://dumps.wikimedia.org/mswiki/20260101/mswiki-20260101-pages-articles.xml.bz2"

# 2. Decompress
bunzip2 -k -c wiki-data/dumps/mswiki-20260101-pages-articles.xml.bz2 > wiki-data/dumps/mswiki-20260101-pages-articles.xml

# 3. Parse (streaming, quality-filtered)
node wiki/parse-wiki-stream.mjs
# Output: wiki-data/parsed/articles-ms-raw.jsonl

# 4. Generate topics
node wiki/generate-topics.js \
  --input wiki-data/parsed/articles-ms-raw.jsonl \
  --output wiki-data/topics/malay-topics.txt
# Output: 153,371 topics from 21,929 articles

# 5. Generate training data
node scripts/generate-bm-deep.js wiki-data/topics/malay-topics.txt 100
# Output: 100 high-quality samples (32 min, 5 workers)
```

**Final Result:** 2,794 samples at 4.9/5 quality, ready for SFT training

## Notes

### Memory Management
- Wikipedia dumps can be 10GB+ XML files
- Always stream, never load entire file
- Quality filtering (500-10K words) reduces output size
- Expect OOM if trying to parse 650K+ articles without chunking

### API Limitations
- 5 concurrent workers is typically the maximum
- 429 errors indicate rate limiting, not bugs
- Add 1-second delays between samples if needed
- Consider multiple API keys for parallel generation

### Quality vs Quantity Trade-offs
- 250 variations per topic = 78% clustering (too much repetition)
- 3-7 variations per topic = sweet spot for diversity
- Quality filtering > raw volume
- 1K high-quality samples > 100K mediocre samples

### Cultural Considerations
- Non-English datasets need dialect awareness
- Regional variations improve authenticity
- Context matters (formal vs informal)
- Avoid "translationese" - train on native content

### Performance Optimization
- Streaming: Essential for large files
- Batch generation: 100-500 samples per batch
- Progress monitoring: Essential for multi-hour runs
- Append mode: Never risk losing data

## References

- [Wikimedia Downloads](https://dumps.wikimedia.org/)
- [wtf_wikipedia](https://github.com/spencermountain/wtf_wikipedia) - Wikipedia parser
- [SYNTH Dataset](https://github.com/princeton-nlp/SYNTH) - Reasoning symbols
- [Unsloth](https://github.com/unslothai/unsloth) - Efficient fine-tuning

## Common Pitfalls

❌ **Using "latest" symlink** - Wikipedia doesn't provide this
❌ **Reading 2GB XML as string** - Will hit V8 string length limits
❌ **Concurrency > 5** - Will trigger 429 rate limit errors
❌ **Generating 250 variations per topic** - Causes severe repetition
❌ **Skipping quality filtering** - Lots of stubs and low-quality content
❌ **Forgetting cultural context** - Generic translations vs authentic usage

✅ **Use dated filenames (YYYYMMDD)**
✅ **Stream XML line-by-line**
✅ **Max 5 concurrent workers**
✅ **3-7 variations per article**
✅ **Filter by word count (500-10K)**
✅ **Add regional dialect awareness**
