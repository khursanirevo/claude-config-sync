---
name: parallel-dataset-generation
description: |
  Generate large training datasets (1000+ items) using parallel subagents with
  rate limit handling. Use when: (1) need to generate >1000 phrases/questions/examples,
  (2) Task tool hits 429 errors with concurrent agents, (3) need topic-specific variety
  in generated content, (4) working with multilingual datasets. Covers batch sizing
  (6 agents per batch), topic distribution strategy, and verification patterns.
author: Claude Code
version: 1.0.0
date: 2026-01-27
---

# Parallel Dataset Generation with Rate Limit Handling

## Problem
Generating large training datasets (1000+ items) using Claude Code's Task tool
often hits API rate limits (429 errors) when launching too many parallel agents
simultaneously. Sequential generation is too slow for large datasets.

## Context / Trigger Conditions
- Need to generate 500+ items (phrases, questions, examples, etc.)
- Task tool returns "429 High concurrency usage" error
- Dataset needs diverse topic coverage
- Manual generation would take hours
- Using Claude Code's Task tool with general-purpose subagents

## Solution

### Step 1: Plan Topic Distribution
Divide target count by number of topics (aim for ~115-120 items per topic):

```python
target = 1500  # Total items needed
num_topics = 12  # Number of categories
per_topic = target // num_topics  # ~125 items per topic
```

### Step 2: Launch in Batches (Not All at Once)
**Critical**: Launch agents in batches of 5-6, NOT all simultaneously:

```python
# ❌ WRONG - All at once causes 429 errors:
for i in range(12):
    Task(subagent_type="general-purpose", prompt=...)

# ✅ CORRECT - Batches of 6:
# Batch 1: Topics 1-6
Task(..., prompt="Topic 1")
Task(..., prompt="Topic 2")
...
Task(..., prompt="Topic 6")

# Wait for Batch 1 completion, then:
# Batch 2: Topics 7-12
Task(..., prompt="Topic 7")
...
```

**Why batches of 6?** Empirically tested - 6 agents work reliably, 7+ may trigger rate limits.

### Step 3: Structured Prompt Template
Each agent needs consistent structure:

```
Generate exactly 115-120 [items] as a Python list.

Distribution:
- Category A: 60%
- Category B: 30%
- Category C: 10%

Requirements:
1. [Quality criteria]
2. [Authenticity requirements]
3. [Format specifications]

Output format: Return ONLY the Python list, no explanations.
```

### Step 4: Collect and Verify
After agents complete:

```python
# Count generated items
import re
with open('generated_file.py') as f:
    content = f.read()
    items = re.findall(r'["\']([^"\']+)["\']', content)
    print(f"Generated: {len(items)} items")

# Verify all topics present
topics = ['PHRASES_TOPIC1', 'PHRASES_TOPIC2', ...]
for topic in topics:
    if topic in content:
        print(f"✅ {topic} found")
    else:
        print(f"❌ {topic} MISSING")
```

### Step 5: Merge and Validate
Create combined dataset with both topic-specific and legacy structures:

```python
# Topic-specific lists (new)
PHRASES_TOPIC1 = [...]
PHRASES_TOPIC2 = [...]

# Legacy structure (backward compatible)
PHRASES_ALL = (
    PHRASES_TOPIC1 +
    PHRASES_TOPIC2 + ...
)
```

## Verification
```bash
# Run this to verify:
python3 << 'EOF'
import re
with open('your_file.py') as f:
    items = re.findall(r'["\']([^"\']+)["\']', f.read())
    print(f"Total: {len(items)} items")
    print(f"Target: 1500 items")
    print(f"Achieved: {len(items) >= 1500}")
EOF
```

Expected output: `Total: 1570 items`, `Achieved: True`

## Example: Full Workflow

**Scenario**: Generate 1500 Malay TTS phrases in 12 categories

```python
# Define 12 topics
topics = [
    ("Daily Conversations", "greetings, small talk"),
    ("Food & Dining", "meals, cooking"),
    ("Family", "relationships, kinship"),
    # ... 9 more topics
]

# Batch 1: First 6 topics
Task(prompt="Generate 115-120 phrases for Daily Conversations...")
Task(prompt="Generate 115-120 phrases for Food & Dining...")
Task(prompt="Generate 115-120 phrases for Family...")
Task(prompt="Generate 115-120 phrases for Work...")
Task(prompt="Generate 115-120 phrases for Education...")
Task(prompt="Generate 115-120 phrases for Shopping...")

# Wait for completion, check results

# Batch 2: Last 6 topics
Task(prompt="Generate 115-120 phrases for Travel...")
# ... remaining 5 topics

# Merge all files into final dataset
```

**Result**: 1569 phrases generated (exceeded 1500 target by 69)

## Notes

**Batch Size Tuning**:
- Safe: 5-6 agents per batch
- Risky: 7-10 agents (may hit 429)
- Dangerous: 12+ agents (almost guaranteed 429)

**Handling Interruptions**:
- If agents get interrupted, relaunch individually
- Generated content is preserved in agent outputs
- Extract using regex pattern from displayed outputs

**Quality vs Speed**:
- Batches of 6 = ~5-10 minutes per batch
- Sequential (1 at a time) = ~30 minutes per batch
- Parallel batches = 3x faster with same quality

**Regex for Quote-Agnostic Extraction**:
```python
# Captures both single and double quoted strings
r'["\']([^"\']+)["\']'
```

## Common Pitfalls

❌ **Launching all agents at once** → 429 rate limit errors
✅ **Launch in batches of 5-6** → Reliable execution

❌ **Vague prompts** → Inconsistent quality/style
✅ **Structured prompts with distribution** → Consistent output

❌ **Not counting quotes properly** → Off-by-phrase counts
✅ **Use quote-agnostic regex** → Accurate counts

❌ **Only topic categories** → Breaking existing code
✅ **Dual structure (topics + legacy)** → Backward compatible

## References

- Claude Code Task tool documentation (internal)
- Parallel processing patterns for ML datasets
- Rate limiting best practices for API calls
