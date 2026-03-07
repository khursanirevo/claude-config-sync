---
name: llm-prompt-compliance-violations
description: |
  Detect and fix LLM prompt compliance violations where explicit requirements are systematically
  ignored. Use when: (1) Quality review reveals consistent violations of explicit prompt instructions,
  (2) LLM outputs fail to meet minimum frequency requirements (e.g., "use name 5+ times" → only 1-2 uses),
  (3) Schema/content type mismatches occur despite explicit instructions, (4) Required complexity/depth
  is missing (e.g., "3 objections" → only 1). Covers generative tasks with LLMs where prompt
  requirements are treated as soft suggestions rather than hard constraints.
author: Claude Code
version: 1.0.0
date: 2026-01-24
---

# LLM Prompt Compliance Violations

## Problem
LLMs systematically ignore explicit prompt requirements, treating them as soft suggestions
rather than hard constraints. This results in:
- Insufficient frequency of required elements (names, objections, examples)
- Content type mismatches (generates wrong type of content)
- Schema violations (invalid dialogue acts, missing fields)
- Oversimplified outputs (rushed arcs, too-easy resolutions)

## Context / Trigger Conditions
**Symptoms:**
- Quality review shows consistent pattern: explicit requirements not met
- Minimum counts specified but outputs have far fewer (e.g., "use 5 times" → 1-2 actual)
- Required complexity missing (e.g., "3+ objections" → 1 objection, "15+ turns" → 8 turns)
- Content completely different from specified type (e.g., "teaching Malay" → business training)
- Schema violations persist despite "DIALOGUE_ACT_COMPLIANCE" sections in prompts

**When to use this skill:**
- After quality review of LLM-generated batch data
- When prompt engineering fails to produce compliant outputs
- When post-processing reveals systematic violations of requirements
- Before scaling up generation (critical checkpoint)

## Solution

### 1. Diagnosis: Identify the Pattern

Review quality issues and categorize violations:

| Pattern | Example | Root Cause |
|---------|---------|------------|
| **Frequency Violation** | "Use names 5+ times" → 1-2 uses | Requirement treated as optional |
| **Complexity Violation** | "3+ objections" → 1 objection | LLM optimizes for brevity |
| **Content Mismatch** | "Teaching Malay" → business contracts | Ambiguous category interpretation |
| **Schema Violation** | Invalid dialogue acts | Schema not enforced in generation |
| **Emotional/Arc Violation** | 8 turns vs required 15+ | LLM rushes to resolution |

### 2. Fix Strategy: Strengthen Prompts

Based on [2026 prompt engineering research](https://medium.com/@mjgmario/prompt-engineering-basics-2026-93aba4dc32b1):

#### A. Use Positive Framing (Not Negative)
❌ **Bad:** "JANGAN guna nama hanya 1-2 kali"
✅ **Good:** "Guna nama sekurang-kurangnya 5 kali dalam perbualan"

Research shows [positive prompts outperform negative ones](https://gadlet.com/posts/negative-prompting/).

#### B. Add Minimum Thresholds
❌ **Vague:** "Guna nama dalam teks"
✅ **Specific:** "Guna nama '{NAME_A}' dan '{NAME_B}' sekurang-kurangnya 5 kali setiap satu"

#### C. Explain WHY Constraints Exist
From [Claude's best practices](https://claude.com/blog/best-practices-for-prompt-engineering):
> "Explain why certain constraints exist" - this improves compliance

Example:
```
Guna nama sekurang-kurangnya 5 kali. KEPENTINGAN: Ini penting untuk
membangun rapport dalam perbualan sebenar. Nama bukan sekadar dibuka
dan ditutup, tetapi digunakan semula secara natural sepanjang dialog.
```

#### D. Provide Negative Examples
❌ **No counter-examples:** "Guna 2-3 bantahan"
✅ **With counter-examples:**
```
Pembeli MESTI raise 2-3 bantahan berbeza SEBELUM consider.

CONTOH YANG SALAH (jangan buat ini):
- Pembeli: "Mahal" → Sales: "Okay diskaun" → Pembeli: "Okay deal"
(Hanya 1 bantahan, terlalu mudah setuju)

CONTOH YANG BETUL:
- Pembeli: "Mahal" → Sales: "Boleh bincang" → Pembeli: "Aku kena tanya isteri"
  → Sales: "Promosi sampai bila?" → Pembeli: "Okay kalau macam tu"
(2-3 bantahan, negotiate dulu baru setuju)
```

#### E. Add Quantifiable Validation Checks
```
KEPERLUAN WAJIB:
- Sekurang-kurangnya 5 bantahan berbeza
- Minimum 3 pusingan negotiate
- Pembeli TIDAK boleh terima offer pertama terus
- Jika kurang dari 15 turn, emosi tidak realistik
```

### 3. Implement Post-Processing Validation

Add verification stage if prompt strengthening isn't enough:

```python
def validate_prompt_compliance(conversation, requirements):
    """Check if LLM followed explicit requirements."""
    issues = []

    # Check frequency requirements
    if requirements.get("min_name_usage", 0) > 0:
        name_count = count_name_occurrences(conversation)
        if name_count < requirements["min_name_usage"]:
            issues.append(f"Name usage: {name_count} < {requirements['min_name_usage']}")

    # Check complexity requirements
    if requirements.get("min_objections", 0) > 0:
        objections = count_objections(conversation)
        if objections < requirements["min_objections"]:
            issues.append(f"Objections: {objections} < {requirements['min_objections']}")

    return issues
```

### 4. Design Prompts as Contracts

From [2026 LLMOps guide](https://redis.io/en/blog/large-language-model-operations-guide/):

Treat prompts as formal contracts with:
- **Obligation** (MUST do): Minimum counts, required elements
- **Constraint** (MUST NOT do): Forbidden patterns
- **Validation** (HOW to check): Verifiable criteria

Example contract structure:
```markdown
## KONTRAK GENERASI
**WAJIB (OBLIGATION):**
- Guna nama sekurang-kurangnya 5 kali
- 2-3 bantahan berbeza
- 15-25 turn untuk pemprosesan emosi

**LARANGAN (CONSTRAINT):**
- JANGAN terima offer selepas 1 bantahan sahaja
- JANGAN selesaikan masalah dalam <10 turn

**PENGESAHAN (VALIDATION):**
- Count nama occurrences
- Count objection types
- Verify turn count
```

## Verification

After applying fixes, verify by:

1. **Generate test batch** (2-5 conversations per type)
2. **Automated validation**: Run compliance checks
3. **Manual review**: Spot-check for adherence
4. **Compare metrics**: Before vs after fix rates

**Success criteria:**
- 90%+ compliance rate on minimum frequency requirements
- Content type matches specification 100%
- Schema violations <5%

## Example

### Before (Violates Prompt)
```
Requirement: "Guna nama '{NAME_A}' dan '{NAME_B}' dalam teks"
Result: Names used 1-2 times in 20+ turns
Issue: Requirement treated as optional
```

### After (Compliant)
```
Requirement: """
Guna nama '{NAME_A}' dan '{NAME_B}' sekurang-kurangnya 5 kali setiap satu.

CONTOH penggunaan nama yang betul:
Turn 1: "Eh Siti, apa khabar?"
Turn 8: "Tapi Ahmad, macam mana tu?"
Turn 15: "Siti, faham tak apa aku cakap?"
Turn 20: "Terima kasih Ahmad!"
Turn 23: "Bye Siti, jumpa lagi!"

JANGAN guna nama hanya 1-2 kali sahaja.
"""

Result: Names used 5-7 times consistently
```

## Notes

### Why This Happens

LLMs are trained to be helpful and concise, which conflicts with:
- **Minimum frequency requirements** (optimizes for brevity)
- **Complexity requirements** (optimizes for quick resolution)
- **Exact schema compliance** (prioritizes natural language over structure)

### Research-Backed Solutions

1. **[Positive framing > Negative framing](https://gadlet.com/posts/negative-prompting/)** - Convert "JANGAN" to "GUNA"
2. **[Explain reasoning](https://claude.com/blog/best-practices-for-prompt-engineering)** - "Kenapa" improves compliance
3. **[Design as contracts](https://medium.com/@mjgmario/prompt-engineering-basics-2026-93aba4dc32b1)** - Formal obligation structure
4. **[Add examples](https://www.promptingguide.ai/introduction/examples)** - Show what NOT to do

### Limitations

Even with strong prompts, some violations occur. Consider:
- **Post-processing validation** (automated checks)
- **Regeneration with feedback** (tell LLM what it missed)
- **Human-in-the-loop** for critical quality gates

### When to Use Each Approach

| Approach | Best For | Cost |
|----------|----------|------|
| Strengthen prompts | Preventing future violations | Low (one-time) |
| Post-processing validation | Catching violations in batch | Medium (development) |
| Regeneration with feedback | Fixing specific conversations | High (per conversation) |
| Human review | Critical content/high-stakes | Very High (per item) |

## References

- [Prompt Engineering Basics 2026: Practical Guide](https://medium.com/@mjgmario/prompt-engineering-basics-2026-93aba4dc32b1)
- [Claude: Best Practices for Prompt Engineering](https://claude.com/blog/best-practices-for-prompt-engineering)
- [Why Positive Prompts Outperform Negative Ones](https://gadlet.com/posts/negative-prompting/)
- [Palantir: Prompt Engineering Best Practices](https://palantir.com/docs/foundry/aip/best-practices-prompt-engineering/)
- [PromptingGuide.ai: Examples](https://www.promptingguide.ai/introduction/examples)
- [Redis: LLMOps Guide 2026](https://redis.io/en/blog/large-language-model-operations-guide/)
- [Improving Negation Reasoning in LLMs](https://aclanthology.org/2025.findings-emnlp.761.pdf)
