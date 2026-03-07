---
name: critical-thinking-when-coding
description: Use when writing ANY code. Question every assumption. Verify logic is correct. People can die from shitty code.
---

# Critical Thinking When Coding

## Overview

**Your code can kill people.**

Medical devices, aerospace, autonomous systems, infrastructure - bugs have consequences.

**Think critically BEFORE, DURING, and AFTER writing every line.**

## When to Use

ALWAYS. No exceptions.

- Writing production code
- Writing tests
- Writing examples
- Copying code
- Fixing bugs
- Reviewing PRs

## Core Pattern

**WITHOUT critical thinking:**
```
See requirement → Write code → Hope it works
```

**WITH critical thinking:**
```
See requirement → Question assumptions → Verify logic → Consider failure modes → THEN write code → Test edge cases → Verify again
```

## Investigation Checklist

**BEFORE writing each line:**

1. What am I assuming?
2. What if I'm wrong?
3. Is this actually correct?

**AFTER writing each line:**

4. Test it NOW (not later)
5. What did I miss?

## Quick Reference

| Writing This? | Ask Yourself FIRST |
|---------------|-------------------|
| Variable assignment | What if it's null/wrong type? |
| Function call | What if it throws? Unexpected return? |
| Logic/condition | What if assumption is wrong? Edge case? |
| Data access | What if data doesn't exist? Different format? |
| "Simple" fix | What's actually wrong? Did I measure? |
| Copy-paste | Do I understand WHY it was written that way? |

## Real-World Impact

**Medical:** Bug in dosage = patient dies

**Aerospace:** Off-by-one = crash

**Infrastructure:** Missing validation = breach

**ALL because someone didn't think critically.**

## Red Flags

- "This is simple"
- "Obviously correct"
- "Should work"
- "Just change this"
- "Quick fix"
- "I'll test later"

**ALL mean: STOP. THINK. VERIFY.**
