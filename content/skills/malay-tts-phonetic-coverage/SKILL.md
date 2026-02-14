---
name: malay-tts-phonetic-coverage
description: |
  Essential phoneme coverage requirements for Malay (Bahasa Melayu) TTS training datasets.
  Use when: (1) creating Malay language training data for speech synthesis, (2) validating
  Malay phrase diversity, (3) checking phonetic completeness in datasets. Covers nasal sounds
  (ny, ng, m), glottal stops (k final), diphthongs (ai, au, oi), consonant clusters (sy, kh, gh).
  Required for authentic Malaysian Malay pronunciation.
author: Claude Code
version: 1.0.0
date: 2026-01-27
---

# Malay TTS Phonetic Coverage Requirements

## Problem
Malay TTS models require comprehensive phonetic coverage to synthesize authentic
Malaysian Malay pronunciation. Missing phonemes result in artificial-sounding speech
or mispronunciation of common words.

## Context / Trigger Conditions
- Creating training datasets for Malay TTS (Piper, ChatterBox, Coqui, etc.)
- Validating phrase diversity for Malay voice cloning
- Checking if dataset covers all Malay phonemes
- Working with Malaysian Bahasa Melayu (not Indonesian Bahasa Indonesia)

## Solution

### Essential Phoneme Categories

#### 1. Nasal Sounds (Critical for Malay)
Malay has extensive nasal consonants that must be represented:

```
ny: as in "nyamuk" (mosquito), "nyanyian" (song), "nyata" (declare)
ng: as in "makan" (eat), "sayang" (love), "orang" (person)
m:  as in "makan" (eat), "mana" (where), "sama" (same)
```

**Why critical**: Nasals are phonemic in Malay - they distinguish word meanings.

#### 2. Glottal Stops (K Final)
Unwritten but pronounced glottal stop for final 'k':

``
akhir: [ʔaˈxɪr] - not [akir]
hantar: [haˈntar] - not [hantar]
lemak: [ləˈmaʔ] - not [lemak]
```

**Coverage strategy**: Include many words ending in -ak, -ar, -ah

#### 3. Diphthongs
Malay vowel combinations that glide:

```
ai: as in "sama" (same), "makan" (eat), "kadang-kadang"
au: as in "pulau" (island), "kau" (you), "satu" (one)
oi: as in "amboi" (exclamation), "kelingking" (pinky)
```

#### 4. Consonant Clusters
Arabic loan sounds that distinguish Malay from Indonesian:

```
sy: as in "syarat" (condition), "saya" (I), "syes" (sorry)
kh: as in "khabar" (news), "khusus" (special), "akhir" (end)
gh: as in "lembut" (soft), "ghairah" (passion)
```

### Dataset Distribution Strategy

For comprehensive coverage, use this distribution:

```python
# Pure Malay: 60% (~900 phrases)
# Focus on traditional words, full Malay sentences
examples = [
    "Apa khabar? Semua baik?",  # Contains: ph, k, b, semua
    "Saya makan nasi lemak",    # Contains: sy, m, k, n, s
]

# Mixed English-Malay: 30% (~450 phrases)
# Natural code-switching (bahasa rojak)
examples = [
    "I tak faham lah",           # Shows mixed usage
    "Best gila makan tu",        # Colloquial style
]

# English with Malaysian context: 10% (~150 phrases)
# English but culturally Malaysian
examples = [
    "Can I tapau please?",       # "Tapau" is Malaysian
    "This traffic jam gila",     # "Gila" emphasis
]
```

### Verification Checklist

```python
def verify_malay_coverage(phrases):
    """Check if Malay phrases have adequate phonetic coverage."""

    # Check for nasal sounds
    has_ny = any('ny' in p for p in phrases)
    has_ng = any('ng' in p for p in phrases)
    has_m = any(any(c in p for c in ['m', 'm']) for p in phrases)

    # Check for glottal stops (k final)
    has_k_final = any(p.rstrip().endswith('k') for p in phrases)

    # Check for diphthongs
    has_ai = any('ai' in p for p in phrases)
    has_au = any('au' in p for p in phrases)
    has_oi = any('oi' in p for p in phrases)

    # Check for consonant clusters
    has_sy = any('sy' in p for p in phrases)
    has_kh = any('kh' in p for p in phrases)
    has_gh = any('gh' in p for p in phrases)

    coverage = {
        'nasal_ny': has_ny,
        'nasal_ng': has_ng,
        'nasal_m': has_m,
        'glottal_stop': has_k_final,
        'diphthong_ai': has_ai,
        'diphthong_au': has_au,
        'diphthong_oi': has_oi,
        'cluster_sy': has_sy,
        'cluster_kh': has_kh,
        'cluster_gh': has_gh,
    }

    all_covered = all(coverage.values())
    if not all_covered:
        missing = [k for k, v in coverage.items() if not v]
        print(f"⚠️  Missing coverage: {missing}")

    return all_covered, coverage

# Usage
phrases = ["Apa khabar?", "Saya makan", "Nyamuk"]
is_complete, coverage = verify_malay_coverage(phrases)
```

### Example: Complete Phonetic Coverage

```python
malay_phrases = [
    # Nasals (ny, ng, m)
    "Nyanyian burung merdu",
    "Makan nasi lemak",
    "Sayang keluarga",

    # Glottal stops (k final)
    "Terima kasih",
    "Hantar surat",
    "Lemak lemak",

    # Diphthongs (ai, au, oi)
    "Kadang-kadang",
    "Pulau langkawi",
    "Amboi cantiknya",

    # Consonant clusters (sy, kh, gh)
    "Syarat penting",
    "Khabar angin",
    "Lembut lembut",
]
```

## Verification

Test your dataset with:

```bash
python3 << 'EOF'
import re

with open('your_malay_phrases.py') as f:
    content = f.read()
    phrases = re.findall(r'["\']([^"\']+)["\']', content)

# Check coverage
print(f"Total phrases: {len(phrases)}")
print(f"With 'ny': {sum(1 for p in phrases if 'ny' in p)}")
print(f"With 'ng': {sum(1 for p in phrases if 'ng' in p)}")
print(f"With 'sy': {sum(1 for p in phrases if 'sy' in p)}")
print(f"With 'kh': {sum(1 for p in phrases if 'kh' in p)}")
EOF
```

**Expected output for good coverage**:
```
Total phrases: 1500
With 'ny': 50-100 (3-7%)
With 'ng': 300-500 (20-33%)
With 'sy': 50-100 (3-7%)
With 'kh': 30-70 (2-5%)
```

## Notes

**Malay vs Indonesian**:
- Malaysian Malay: More Arabic loans (sy, kh, gh)
- Indonesian: More Dutch/Javanese influence
- This skill focuses on Malaysian Malay

**Code-Switching Context**:
- Malaysian Malay naturally mixes with English
- Don't avoid code-switching - it's authentic
- 30% mixed language is realistic for Malaysia

**Common Words That Test Coverage**:
```
Essential test words:
- "Nyamuk" (mosquito) → Tests 'ny'
- "Makan" (eat) → Tests 'ng' and 'n'
- "Syarat" (condition) → Tests 'sy'
- "Khabar" (news) → Tests 'kh'
- "Akhir" (end) → Tests glottal stop
- "Amboi" → Tests 'oi' diphthong
```

## References

- Malay phonology: Wikipedia "Malay language"
- TTS training best practices: Piper documentation
- Malaysian Malay vs Indonesian: linguistic studies
