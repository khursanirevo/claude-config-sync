---
name: context-aware-language-data-processing
description: |
  Context-aware vocabulary and grammar fixing for language training data preserves
  authentic code-mixing features. Use when: (1) building NLP/LLM training datasets for
  code-mixed language varieties (Manglish, Singlish, Hinglish, Spanglish, etc.),
  (2) applying post-processing fixes to conversation data where formality varies,
  (3) distinguishing real errors from authentic language varieties. Implements
  three-tier fix classification: REAL ERRORS (always fix), STYLE-DEPENDENT (fix
  only in formal contexts), TEXTING ABBREVIATIONS (always fix).
author: claude-code
version: 1.0.0
date: 2026-01-24
---

# Context-Aware Language Data Processing

## Problem

When building training datasets for NLP/LLM models, over-aggressive vocabulary and
grammar "corrections" can destroy authentic language features. Code-mixing (using
words from multiple languages) is a **legitimate linguistic feature** in many
language varieties, not an error to be fixed.

**Example:** In Malaysian Malay (Manglish), phrases like:
- "I nak call you later"
- "Charger hp mana?"
- "So, macam mana?"

are **authentic, natural speech** - not broken Malay or broken English. "Fixing"
these would remove legitimate linguistic variation and produce sterile, unrealistic
training data.

## Context / Trigger Conditions

Use this pattern when:

1. **Building conversation datasets** for code-mixed language varieties
2. **Post-processing LLM outputs** where formality levels vary by context
3. **Multi-stage data pipelines** where Stage 1 = sanitization, Stage 2 = enhancement
4. **Working with dialects/varieties**: Malaysian English, Singapore English,
   Indian English (Hinglish), Chicano English, Puerto Rican Spanish, etc.

**Symptoms that you need this approach:**
- You're "fixing" words that native speakers naturally use
- Your corrections are making dialogue sound less authentic
- Different formality levels require different treatment
- You need to preserve slang/colloquialisms for some contexts but not others

## Solution

### Architecture: Three-Tier Classification

Split all potential fixes into three categories:

#### 1. REAL ERRORS (Always Fix, Regardless of Context)

These are genuine mistakes that violate language rules:

```python
REAL_ERRORS = {
    # Wrong meaning (vocabulary misuse)
    "pelabuhan": "pelaburan",      # "harbor" vs "investment"
    "payau": "payah",              # "wild (deer)" vs "difficult"
    "lagu": "lebih",              # "song" vs "more" (context: "lagu elegan")

    # Not actual words
    "kawankan": "kawan-kawan",    # invented word

    # Typos and spelling errors
    "Sita": "Siti",               # name typo
    "aktivitas": "aktiviti",      # Indonesian vs Malaysian spelling
    "jejaskan": "jelaskan",       # typo
}
```

#### 2. STYLE-DEPENDENT (Preserve in Authentic Contexts)

These are **legitimate linguistic features** in casual/authentic speech:

```python
STYLE_DEPENDENT = {
    # Code-mixing (authentic in casual speech)
    "call": None,        # Don't fix - natural in Malaysian English
    "hp": None,          # Don't fix - standard term, not "telefon"
    "so": None,          # Don't fix - common conjunction
    "lately": None,      # Don't fix - common loanword

    # Slang (appropriate for friends/informal contexts)
    "gittew": None,      # Don't fix - authentic slang
    "goyang": None,      # Don't fix - context-dependent slang
}
```

**When to apply style-dependent fixes:**
- **Formal contexts**: medical consultations, customer service, interviews
- **Casual contexts**: Preserve the authentic variety (casual, peer support, coaching)

#### 3. TEXTING ABBREVIATIONS (Always Fix in Spoken Dialogue)

These are never appropriate in transcribed spoken dialogue:

```python
TEXTING_ABBREVS = {
    "ok2": "ok, ok",          # texting style
    "u": "you",               # SMS shorthand
    "ur": "your",             # SMS shorthand
}
```

### Implementation Pattern

#### Step 1: Determine Formality Level

```python
def get_formality_level(conversation: Dict) -> str:
    """
    Determine if conversation requires formal or casual treatment.

    Returns: "formal" or "casual"
    """
    conv_type = conversation.get("conversation_type", "")
    tier = conversation.get("tier", "moderate")

    # Formal conversation types
    formal_types = ["medical_consultation", "customer_service", "interview"]

    # Tier-based formality
    if tier == "minimal":
        return "casual"  # Most natural/authentic
    elif tier == "rich":
        return "formal"   # More formal

    # Conversation type-based
    if conv_type in formal_types:
        return "formal"
    elif conv_type in ["casual", "peer_support", "coaching"]:
        return "casual"

    return "casual"  # Default: preserve authentic language
```

#### Step 2: Apply Context-Aware Fixes

```python
def fix_vocabulary_errors(text: str, formality_level: str) -> Tuple[str, List[str]]:
    """
    Fix vocabulary based on context.
    """
    corrected = text
    fixes_applied = []

    # 1. Always fix REAL ERRORS
    for wrong, correct in REAL_ERRORS.items():
        if re.search(rf'\b{wrong}\b', corrected, re.IGNORECASE):
            corrected = re.sub(pattern, correct, corrected, flags=re.IGNORECASE)
            fixes_applied.append(f"'{wrong}' → '{correct}'")

    # 2. Always fix TEXTING ABBREVIATIONS
    for wrong, correct in TEXTING_ABBREVS.items():
        if wrong in corrected.lower():
            corrected = corrected.replace(wrong, correct)
            fixes_applied.append(f"'{wrong}' → '{correct}'")

    # 3. Style-dependent fixes (ONLY in formal contexts)
    if formality_level == "formal":
        for wrong, correct in STYLE_DEPENDENT.items():
            if correct is None:
                continue  # Skip items marked "don't fix even in formal"
            if re.search(rf'\b{wrong}\b', corrected, re.IGNORECASE):
                corrected = re.sub(pattern, correct, corrected, flags=re.IGNORECASE)
                fixes_applied.append(f"'{wrong}' → '{correct}'")

    return corrected, fixes_applied
```

#### Step 3: Track Context in Metadata

```python
stage2_stats = {
    "vocabulary_fixes": len(fixes_applied),
    "formality_level": formality_level,  # Track for transparency
    # ... other stats
}
```

### Formality Detection Heuristics

| Context | Formality Level | Treatment of Code-Mixing |
|---------|----------------|--------------------------|
| **Tier: minimal** | Casual | Preserve all authentic features |
| **Tier: moderate** | Mixed | Preserve most code-mixing |
| **Tier: rich** | Formal | Fix more items |
| **casual conversation** | Casual | Preserve authentic code-mixing |
| **peer_support** | Casual | Preserve slang/colloquialisms |
| **medical_consultation** | Formal | More aggressive fixing |
| **customer_service** | Formal | More aggressive fixing |
| **interview** | Formal | More aggressive fixing |
| **teaching** | Mixed | Depends on speaker role |

## Verification

**Test 1: Casual conversation preserves authentic features**
```python
# Input (casual, tier: minimal)
text = "Aku nak call you nanti ok"

# Output should preserve "call" and "nak" as authentic Malaysian Malay
assert "call" in result  # Pass: NOT changed to "hubungi"
```

**Test 2: Formal conversation applies style-dependent fixes**
```python
# Input (medical_consultation, tier: moderate)
text = "Dr: Saya call patient nanti"

# Output may fix "call" in formal medical context
# (depending on your style_dependent rules)
```

**Test 3: Real errors are always fixed**
```python
# Input (any context)
text = "Pelabuhan laba ini bagus"

# Output
assert "pelaburan" in result  # Fixed regardless of context
assert "pelabuhan" not in result
```

## Example

**Input (Casual Peer Support Conversation):**
```json
{
  "conversation_type": "peer_support",
  "tier": "moderate",
  "turn": {
    "speaker": "A",
    "text": "Aku rasa nak call kau nanti, hp lowbat plak."
  }
}
```

**Stage 2 Processing:**
```python
formality_level = get_formality_level(conv)  # Returns "casual"

# Apply fixes:
# - "nak" → preserved (authentic)
# - "call" → preserved (authentic code-mixing)
# - "hp" → preserved (standard term)
# - "lowbat" → preserved (authentic slang)

result = "Aku rasa nak call kau nanti, hp lowbat plak."
```

**Metadata Output:**
```json
{
  "stage2_stats": {
    "vocabulary_fixes": 0,
    "formality_level": "casual"
  }
}
```

## Notes

### Key Insights from Research

1. **Code-mixing is linguistic identity**: Research shows that code-switching
   is a feature of multilingual communities, not an error ([Evaluating Code-Mixing in LLMs](https://arxiv.org/pdf/2507.18791), 2025)

2. **Authenticity matters for model quality**: Training on over-corrected data produces
   models that can't handle real-world language use ([DialectBench](https://arxiv.org/html/2403.11009v2), 2024)

3. **Malaysian English has active research**: Multiple dedicated datasets exist
   for Malay-English code-switching ([Bi-annotated Manglish Dataset](https://www.sciencedirect.com/science/article/pii/S2352340924000088), 2024)

### Anti-Patterns to Avoid

❌ **Don't** fix all English words in Malay text - many are authentic borrowings
❌ **Don't** remove slang from casual conversations - it's natural speech
❌ **Don't** apply the same rules to all conversation types
❌ **Don't** assume formal = "better" for language data

### Best Practices

✅ **Do** preserve code-mixing in casual contexts
✅ **Do** track formality level in metadata for transparency
✅ **Do** validate with native speakers when possible
✅ **Do** consider the persona/relationship (friends vs doctor-patient)
✅ **Do** keep real errors separate from style-dependent items

### Extension to Other Language Varieties

This pattern applies to any code-mixed language:

| Variety | Authentic Features | Formal Contexts |
|---------|-------------------|-----------------|
| **Manglish** (Malaysian English) | "call", "hp", "so", "nak" | Business emails, formal writing |
| **Singlish** (Singapore English) | "lah", "meh", "shiok" | Government communications |
| **Hinglish** (Indian English) | "prepone", "do the needful" | Academic writing |
| **Spanglish** (US Latino) | "te llamo para atrás" | Professional settings |
| **Chicano English** | "fo", "farwest" | Formal presentations |

## References

### Academic Papers
- [Evaluating Code-Mixing in LLMs Across 18 Languages](https://arxiv.org/pdf/2507.18791) (2025)
- [Language Augmentation Approach for Code-Mixed Text](https://www.sciencedirect.com/science/article/pii/S2949719123000390) (2023)
- [Code-Mixing English-Centric LLM](https://aclanthology.org/2024.findings-naacl.198.pdf) (2024)
- [DialectBench: NLP Benchmark for Dialects and Varieties](https://arxiv.org/html/2403.11009v2) (2024)

### Malaysian English Datasets
- [Bi-annotated Malay-English Code-Switching (Manglish) Dataset](https://www.sciencedirect.com/science/article/pii/S2352340924000088) (2024)
- [Mixed Malay–English COVID-19 Twitter Dataset](https://www.mdpi.com/2504-2289/7/2/61) (2023)
- [Code-Switch Language Modeling for English and Malay](https://github.com/kjgpta/Code-Switch-Language-Modeling-for-English-and-Malay) (GitHub)

### Dialect/Variety Processing
- [Natural Language Processing for Dialects of a Language](https://dl.acm.org/doi/10.1145/3712060) (2025 Survey)
- [NLP for Similar Languages, Varieties, and Dialects](https://www.cambridge.org/core/journals/natural-language-engineering/article/natural-language-processing-for-similar-languages-varieties-and-dialects-a-survey/229652C86E329F83346BB6C66B9521A6) (2020 Survey)
- [Language Varieties of Italy: Technology Challenges](https://direct.mit.edu/tacl/article doi/10.1162/tacl_a_00631) (2024)
