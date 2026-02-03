---
name: wikipedia-dump-llm-dataset-integration
description: |
  Integration of Wikipedia dumps for LLM training dataset generation. Use when:
  (1) Building knowledge-augmented LLM training pipelines, (2) Need legal/efficient
  Wikipedia data access vs web scraping, (3) Building semantic search indexes for
  large text corpora, (4) Enhancing multi-agent pipelines with external knowledge,
  (5) Processing multi-million document datasets with streaming. Covers Wikipedia
  dump downloading, XML parsing with SAX, ChromaDB vector indexing, bilingual
  knowledge alignment, and JSONL streaming patterns.
author: Claude Code
version: 1.1.0
date: 2026-01-21
---

# Wikipedia Dump Integration for LLM Training Datasets

## Problem

Building LLM training datasets requires large-scale knowledge sources, but web scraping Wikipedia is:
- **Legally questionable** as of 2025 (Wikipedia urging AI companies to stop scraping)
- **Technically challenging** due to rate limits (200 req/sec) and IP blocking
- **Resource-intensive** for both scraper and Wikipedia servers
- **Incomplete** compared to official dumps

## Context / Trigger Conditions

Use this skill when:
- Building knowledge-augmented LLM training pipelines
- Need multi-million document corpora for fine-tuning
- Want legal, sanctioned Wikipedia data access
- Processing datasets too large for memory (>10GB XML files)
- Building semantic search for text corpora
- Enhancing multi-agent pipelines with external knowledge retrieval
- Working with bilingual/multilingual datasets (English + target language)

## Solution

### 1. Use Wikipedia Official Dumps (Not Scraping)

**Why Dumps?**
- **Legal and sanctioned**: Officially provided by [Wikimedia Foundation](https://dumps.wikimedia.org/)
- **Complete data**: Entire Wikipedia projects in compressed files
- **No server strain**: Download once, parse locally
- **Structured format**: XML with metadata and revision history
- **Free**: CC-BY-SA 4.0 licensed (attribution required)

**Download Command:**
```bash
# Download from official mirrors
curl -C - -o mswiki-latest-pages-articles.xml.bz2 \
  https://dumps.wikimedia.org/mswiki/20250101/mswiki-latest-pages-articles.xml.bz2
```

**File Sizes (2025):**
- Malay Wikipedia (mswiki): ~400MB compressed
- English Wikipedia (enwiki): ~20GB compressed
- All languages: ~1TB compressed

### 2. Parse with SAX Streaming (Not DOM)

**Why SAX?**
- **Memory-efficient**: Processes element-by-element, doesn't load entire file
- **Handles huge files**: 20GB+ XML files without memory overflow
- **Fast**: Streaming processing with minimal overhead

**Node.js SAX Implementation:**
```javascript
import * as sax from 'sax';

const parser = sax.parser(true, { trim: true, normalize: true });

parser.onopentag = (tag) => {
  if (tag.name === 'page') {
    currentArticle = {};
  }
};

parser.ontext = (text) => {
  if (currentArticle && currentArticle.textStart) {
    currentText += text;
  }
};

parser.onclosetag = (tag) => {
  if (tag.name === 'page') {
    // Process article
    outputStream.write(JSON.stringify(article) + '\n');
  }
};
```

**BZ2 Decompression:**
```bash
# Wikipedia dumps are BZ2 compressed - use external bunzip2
bunzip2 -k -c mswiki-latest-pages-articles.xml.bz2 > mswiki-parsed.xml
```

### 3. Build Vector Index with ChromaDB (Embedded)

**Why ChromaDB?**
- **Embedded mode**: Runs in-process like SQLite, no separate server
- **Zero-config**: Works out-of-the-box for most use cases
- **Persistent**: SQLite-backed automatic disk storage
- **AI-native**: Designed for LLM/RAG applications
- **Cost-effective**: Open source, no licensing fees

**ChromaDB Initialization:**
```javascript
import { ChromaClient } from 'chromadb';

// ⚠️ IMPORTANT: Do NOT use 'path' parameter - it's deprecated and causes errors
// ✅ CORRECT: Initialize without parameters for embedded mode
const client = new ChromaClient();

const collection = await client.getOrCreateCollection({
  name: 'wiki-articles',
  metadata: { description: 'Wikipedia articles for LLM training' }
});
```

**Common Error - Deprecated Path Parameter:**
```
Error: The 'path' argument is deprecated. Please use 'ssl', 'host', and 'port' instead
```
This error is misleading - the actual solution is to **remove the path parameter entirely** and use `new ChromaClient()` without arguments for embedded mode.

**Batch Embedding Generation:**
```javascript
import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function indexBatch(articles) {
  const texts = articles.map(a => `${a.title}. ${a.text.slice(0, 500)}`);

  const response = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: texts
  });

  await collection.add({
    ids: articles.map(a => a.id),
    embeddings: response.data.map(d => d.embedding),
    metadatas: articles.map(a => ({
      title: a.title,
      lang: a.lang,
      categories: a.categories.join(',')
    })),
    documents: texts
  });
}
```

**Cost:**
- OpenAI `text-embedding-3-small`: $0.00002/1K tokens
- Pilot (100 articles): ~$0.001
- Full Malay Wikipedia (350K articles): ~$3.50

### 4. Semantic Search Integration

**Query Pattern:**
```javascript
async function searchWithWiki(query) {
  // Generate query embedding
  const queryEmbedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: query
  });

  // Search ChromaDB
  const results = await collection.query({
    queryEmbeddings: [queryEmbedding.data[0].embedding],
    nResults: 3,
    where: { lang: 'ms' }  // Language filter
  });

  return results.documents[0].map((doc, i) => ({
    title: results.metadatas[0][i].title,
    text: doc,
    distance: results.distances[0][i]
  }));
}
```

**Latency:** <500ms per query for 350K articles

### 5. Multi-Agent Pipeline Enhancement

**Pattern: Inject knowledge between Meta and Retrieval agents**

**Original Pipeline:**
```
Query → Meta → Retrieval → Derivation → Responder
```

**Enhanced Pipeline:**
```
Query → [Wiki Search] → Meta → Wiki-Enhanced Retrieval → Derivation → Responder
                  ↑
            ChromaDB Index
```

**Implementation:**
```javascript
async function generateWithWikiEnhancement(topic) {
  // Step 1: Search Wikipedia
  const wikiArticlesMS = await searchWithWiki(topic, 'ms', 3);
  const wikiArticlesEN = await searchWithWiki(topic, 'en', 2);

  // Step 2: Build context string
  const wikiContext = `
Wikipedia Bahasa Melayu:
${wikiArticlesMS.map(a => `- ${a.title}: ${a.text.slice(0, 500)}`).join('\n')}

Wikipedia English:
${wikiArticlesEN.map(a => `- ${a.title}: ${a.text.slice(0, 300)}`).join('\n')}
  `;

  // Step 3: Pass to Retrieval Agent
  const retrievalPrompt = loadPrompt('retrieval-wiki-enhanced');
  const retrievalInput = `
Query: ${topic}
${wikiContext}
Meta Analysis: ${JSON.stringify(metaParsed)}
  `;

  const retrievalOutput = await callAPI(retrievalPrompt, retrievalInput);

  // Continue with Derivation and Responder...
}
```

**Enhanced Retrieval Prompt Key Additions:**
- Wikipedia context analysis instructions
- Cross-language insight markers (● for Malay facts, ◐ for English inferences)
- Citation guidelines for wiki articles
- Cultural authenticity preservation

### 6. JSONL Streaming for Large Datasets

**Why JSONL?**
- **Line-by-line processing**: Read/parse one sample at a time
- **Append-only safe**: Never lose existing data
- **Streamable**: Works with Unix pipes (`|`, `>`)
- **Compression friendly**: Gzip each line independently

**Read Pattern:**
```javascript
import { createReadStream } from 'fs';
import { createInterface } from 'readline';

const fileStream = createReadStream('articles-ms-raw.jsonl');
const rl = createInterface({ input: fileStream, crlfDelay: Infinity });

for await (const line of rl) {
  const article = JSON.parse(line);
  // Process article
}
```

**Write Pattern (Always Append):**
```javascript
import { appendFileSync } from 'fs';

function saveResult(result) {
  const line = JSON.stringify(result) + '\n';
  appendFileSync('dataset.jsonl', line);  // Safe: never deletes
}
```

**Batch Processing:**
```bash
# Process in chunks
head -n 1000 articles.jsonl | node process.js
tail -n +1001 articles.jsonl | node process.js
```

### 7. Bilingual Knowledge Alignment

**Strategy: Use English to fill Malay content gaps**

```javascript
// 1. Search Malay Wikipedia (primary)
const msResults = await searchWithWiki(query, 'ms', 3);

// 2. Search English Wikipedia (supplementary)
const enResults = await searchWithWiki(query, 'en', 2);

// 3. Combine with language markers
const context = {
  primary: msResults.map(r => ({ ...r, source: 'wikipedia-ms', certainty: '●' })),
  supplementary: enResults.map(r => ({ ...r, source: 'wikipedia-en', certainty: '◐' }))
};
```

**Citation Convention:**
- ● (Ground truth): Malay Wikipedia facts
- ◐ (Inference): Cross-language insights from English
- ! (Insight): Cultural observations
- ※ (Constraint): Rules/limitations from articles

## Verification

**Pilot Scale (100 articles):**
- Download: ~5-10 min for 400MB dump
- Parse: <1 min for 100 articles
- Index: 2-3 min (ChromaDB + OpenAI embeddings)
- Search: <500ms per query
- **Total**: ~15 min end-to-end

**Quality Checks:**
1. Search returns relevant top-3 articles for test queries
2. Embedding cost under $0.01 for pilot
3. No memory overflow during XML parsing
4. JSONL files append correctly (no data loss)
5. Wiki citations appear in generated samples

## Example

**Full Pipeline Execution:**

```bash
# 1. Download Malay Wikipedia
node wiki/download-dumps.js --lang ms

# 2. Parse with SAX streaming
node wiki/parse-dump.js --lang ms --limit 1000

# 3. Filter by category
node wiki/filter-topics.js --category linguistics

# 4. Build ChromaDB index
node wiki/build-index.js --lang ms --limit 1000

# 5. Generate queries from articles
node wiki/generate-topics.js --limit 100

# 6. Generate SYNTH samples with wiki enhancement
node scripts/generate-bm-deep-wiki.js wiki-data/topics/wiki-topics-generated.txt 50
```

**Output Schema:**
```json
{
  "query": "Apakah perbezaan antara 'sudah' dan 'telah'?",
  "reasoning": "### 1. Analisis Definisi → Kata dasar: 'sudah' dan 'telah' ●...",
  "answer": "# Perbezaan antara 'sudah' dan 'telah'...",
  "language": "ms",
  "model": "glm-4.7",
  "timestamp": "2026-01-21T...",
  "duration": 4500,
  "generation_mode": "deep-wiki",
  "wiki_articles_used": [
    { "id": "Sudah", "title": "Sudah", "lang": "ms" },
    { "id": "Telah", "title": "Telah", "lang": "ms" },
    { "id": "Malay grammar", "title": "Malay grammar", "lang": "en" }
  ],
  "wiki_enabled": true,
  "agents": ["meta", "retrieval-wiki", "derivation", "responder"]
}
```

## Notes

**Changelog:**
- **v1.1.0 (2026-01-21)**: Fixed ChromaDB initialization - removed deprecated `path` parameter which causes misleading error. Use `new ChromaClient()` without arguments for embedded mode.
- **v1.0.0 (2026-01-21)**: Initial skill creation

**Legal Considerations:**
- Wikipedia content is CC-BY-SA 4.0 licensed
- Must provide attribution when using dump data
- Share-alike requirement applies to derivative works
- As of November 2025, Wikipedia is [urging AI companies to use paid APIs instead of scraping](https://techcrunch.com/2025/11/10/wikipedia-urges-ai-companies-to-use-its-paid-api-and-stop-scraping/)
- Official dumps are the legally sanctioned method for large-scale access

**Performance Benchmarks:**

| Scale | Articles | Parse Time | Index Time | Storage |
|-------|----------|------------|------------|---------|
| Pilot | 100 | <1 min | 2-3 min | ~10MB |
| Medium | 10K | ~5 min | ~20 min | ~1GB |
| Full (MS) | 350K | ~4 hours | ~10 hours | ~12GB |
| Full (EN+MS) | 6.5M | ~48 hours | ~120 hours | ~200GB |

**ChromaDB vs Alternatives (2025-2026):**

| Feature | ChromaDB | Pinecone | Qdrant |
|---------|----------|----------|---------|
| Deployment | Embedded | Cloud | Client-server |
| Cost | Free (OSS) | Paid | Free (OSS) |
| Setup | Zero-config | Managed | Moderate |
| Scaling | Local resources | Auto-scales | Distributed |
| **Use when** | **<1M vectors** | **>1M vectors** | **Self-hosted scale** |

**Multi-Agent Pipeline Pattern:**
- Knowledge injection point: Between Meta and Retrieval agents
- Prompt enhancement: Add context-specific instructions
- Output augmentation: Add metadata fields (wiki_articles_used, wiki_enabled)
- Backward compatibility: Keep original pipeline intact, create separate script

**JSONL Best Practices:**
- Always append mode (`appendFileSync`, never `writeFileSync` for updates)
- One JSON object per line (no pretty-printing)
- Compress with gzip for storage (`dataset.jsonl.gz`)
- Stream with Unix tools: `zcat dataset.jsonl.gz | grep "pattern"`

**Cultural Authenticity:**
- Prioritize target language (Malay) over English sources
- Use English only to fill content gaps
- Preserve regional dialects and variations mentioned in articles
- Validate cultural appropriateness in manual review

**Error Handling:**
- SAX parsing: Catch and log per-article errors, continue processing
- Embedding generation: Retry with exponential backoff
- ChromaDB: Use batch inserts (1000 articles) for performance
- API rate limits: Respect provider limits (concurrency=5 for Z.ai)

## References

- [Wikipedia:Database Download](https://en.wikipedia.org/wiki/Wikipedia:Database_download) - Official dump information
- [Wikimedia Dump Downloads](https://dumps.wikimedia.org/) - Official mirror site
- [License Information](https://dumps.wikimedia.org/legal.html) - CC-BY-SA 4.0 license details
- [ChromaDB Documentation](https://www.trychroma.com/) - Official ChromaDB docs
- [RealPython: ChromaDB Vector Search](https://realpython.com/chromadb-vector-search/) - Tutorial on embeddings and ChromaDB
- [DataCamp: Best Vector Databases 2026](https://www.datacamp.com/blog/the-top-5-vector-databases) - Vector database comparison
- [TechCrunch: Wikipedia Anti-Scraping Stance](https://techcrunch.com/2025/11/10/wikipedia-urges-ai-companies-to-use-its-paid-api-and-stop-scraping/) - November 2025 policy update
- [James Thorne: Processing Wikipedia Efficiently](https://jamesthorne.com/blog/processing-wikipedia-in-a-couple-of-hours/) - Processing strategies
