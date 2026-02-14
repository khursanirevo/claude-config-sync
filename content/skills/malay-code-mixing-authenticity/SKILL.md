---
name: malay-code-mixing-authenticity
description: |
  Quality review criteria for Malaysian Malay conversations with English code-mixing.
  Use when: (1) Reviewing Malay conversation datasets for authenticity, (2) Distinguishing
  between natural Bahasa Rojak vs. forced English insertions, (3) Setting quality standards
  for Malaysian language data. Covers authentic Malaysian English loanwords, colloquial
  particles, and regional variations that should NOT be flagged as errors.
author: Claude Code
version: 1.0.0
date: 2026-01-24
---

# Malaysian Malay Code-Mixing Authenticity Standards

## Problem
Quality review systems incorrectly flag authentic Malaysian Malay speech patterns as "errors"
because they don't distinguish between natural code-mixing (Bahasa Rojak) and actual language
problems. This leads to false positives where legitimate Malaysian English loanwords and mixed
language expressions are marked for correction.

## Context / Trigger Conditions
- **Reviewing Malaysian Malay conversation datasets**
- **Quality agents flagging English words in Malay text as "issues"**
- **Need to distinguish**: Authentic code-mixing ✓ vs. Forced insertions ✗
- **Regional language varieties**: Malaysian, Singaporean Malay, etc.
- **Error messages like**: "English phrase breaks Malay immersion" when the phrase is actually authentic

## Solution

### ✅ AUTHENTIC Malaysian Malay Features (Do NOT Flag as Issues)

**Common English Loanwords (Natural):**
- Everyday terms: "worth it", "vibe", "stress", "confuse", "nervous", "upgrade"
- Customer service: "Have a great day", "please hold", "just a moment"
- Business/work: "Action Plan", "deadline", "meeting", "feedback", "review"
- Casual expressions: "Best gila", "okay je", "alhamdulillah", "syok"

**Malay Colloquial Particles (Expected):**
- Common: `lah`, `me`, `kan`, `kat`, `je`, `pun`, `dah`, `nak`, `tuh`, `ni`
- Regional: `weh`, `kok`, `bai` (Northern Malay), `jak` (Kelantanese), `bijak` (East Coast)

**Bahasa Rojak (Mixed Language):**
- Malaysians naturally mix Malay, English, Chinese dialects, Tamil
- This is AUTHENTIC speech, not an error to fix
- Examples: "lepaking" (preferred over "hanging out"), "study", "booking", "shopping"

### ❌ ACTUAL Red Flags (These Are Real Issues)

**Forced/Awkward Insertions:**
- English words that break conversation flow unnaturally
- Code-mixing in inappropriate contexts (e.g., overly formal situations)
- Inconsistent formality levels without narrative reason

**Broken Grammar (Any Language):**
- "konflik berjawi" → should be "konflik" or "masalah konflik"
- "perjalanan ke saya" → should be "perjalanan ke sini"
- "kawal nasi" → should be "kawal diet"

**Unnatural Phrasing:**
- Meta-commentary breaking immersion: "itu yang dikatakan profesional"
- Awkward sentence structure: "Siti bagi je kad" (context-dependent)

**Actual Quality Issues:**
- Medical safety concerns (ignoring red flag symptoms)
- Wrong dialogue acts in schema
- Rushed/unrealistic behavioral patterns
- Inauthentic negotiation dynamics

### Quality Review Decision Framework

When reviewing Malaysian Malay content, ask:

1. **Would a Malaysian speaker actually say this?**
   - Yes → Keep it (even if mixed with English)
   - No → Flag for revision

2. **Is the English word a common loanword?**
   - Yes → Authentic code-mixing
   - No → May be forced insertion

3. **Does it break flow or sound unnatural?**
   - Yes → Flag regardless of language mixing
   - No → Likely authentic

## Verification
After applying these standards, your quality review should:
- Have significantly fewer false positives on "English phrases"
- Focus on actual issues: medical safety, schema compliance, behavioral authenticity
- Preserve authentic Malaysian voice in the dataset

## Example

**Before (Incorrect Flagging):**
```
Issue Type: Naturalness
Quote: "Memang worth it lah sekali sekala."
Severity: Major
Description: Code-mixing with English "worth it" breaks natural flow
Fix: Replace with "berbaloi lah"
```

**After (Correct Assessment):**
```
Status: NO ISSUE
Reasoning: "Worth it" is a common Malaysian English loanword.
"Memang worth it lah" is authentic Bahasa Rojak expression.
```

**Actual Issue (Should Be Flagged):**
```
Issue Type: Naturalness
Quote: "Tekanan darah 140/90 tu sikit tinggi sahaja."
Severity: Critical
Description: Minimizes Stage 1 hypertension - medical safety concern
Fix: Proper medical context: "140/90 adalah tinggi dan perlu monitoring"
```

## Notes
- **Cultural Context**: Malaysia's multilingual society makes code-mixing natural
- **Not Just Malaysian**: Similar patterns exist in Singlish, Indian English, etc.
- **Academic Validation**: Research shows "lepaking" preferred over "hanging out" among Malaysians
- **Quality vs. Purity**: Dataset should reflect how Malaysians ACTUALLY speak, not prescriptive "pure" Malay
- **Previous Session Learning**: Quality review mentioned "forced English phrases" as bad - the distinction is forced ≠ natural

## References
- [MALAY-ENGLISH CODE-MIXING INSERTION: WHY 'LEPAKING' IN PREFERENCE TO 'HANGING OUT'](https://www.researchgate.net/publication/347767268_MALAY-ENGLISH_CODE-MIXING_INSERTION_WHY_'LEPAKING'_IN_PREFERENCE_TO_'HANGING_OUT')
- [Explaining the diversity in Malay-English code-switching](https://centaur.reading.ac.uk/109680/8/languages-07-00299-v2.pdf) - Treffers-Daller et al., 2022
- [Code-mixing and Code-switching Language Among Malay](https://mysitasi.mohe.gov.my/uploads/get-media-file?refId=633751c6-bdb6-486c-b2ac-11a51ec9866e) - December 2024
- [Bilingual Play and Social Identity: Code-Mixing](https://rsisinternational.org/journals/ijriss/uploads/vol9-iss22-pg97-105-202510_pdf.pdf) - October 2025
