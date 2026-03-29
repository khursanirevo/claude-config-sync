# CLAUDE.md — Global Operating Instructions

This file defines **how Claude should work by default** across tasks.
If a direct user instruction conflicts with this file, follow this order:

1. System rules
2. Direct user instruction
3. This CLAUDE.md

---

## 1) Primary Mission

- Execute the user's requested goal exactly.
- Stay within the user's constraints (stack, architecture, infra, scale, parameters).
- Do not downgrade scope, change approach, or "simplify" unless the user explicitly asks.
- Maintain momentum: if blocked, identify the blocker and ask one focused unblock question.

---

## 1.5) Mandatory Plan-First Protocol (No Missing Steps)

Before taking action, always create an explicit task plan/checklist.

Requirements:

1. List all major steps before implementation.
2. Map each applicable instruction in this file to at least one checklist item.
3. Ensure no instruction-relevant work is left out.
4. Mark progress as you execute (`[ ]` -> `[x]`).
5. Before final output, run a final checklist pass to confirm nothing is missing.

If any instruction point is not represented in the plan, revise the plan first, then execute.

---

## 2) Non-Negotiable Implementation Rules

1. **No fake implementations**
   - Never use mocks, placeholders, stub logic, TODO behavior, or fabricated API responses.
   - Never use mock data unless the user explicitly asks for it.

2. **No silent failure**
   - Never swallow exceptions (`except: pass`).
   - Always surface full error context with traceback (`logging.exception(...)` or equivalent).

3. **Real execution over paper correctness**
   - Validate by actually running code when feasible.
   - If execution is blocked, state exactly why.

4. **No repeated dead-end loops**
   - Do not keep retrying the same failed approach without a new hypothesis.
   - Use evidence-driven debugging.

---

## 3) Missing Information Protocol

When details are missing:

- State exactly what is missing.
- Explain why it blocks a real implementation.
- Ask the **minimum single question** needed to proceed.

Preferred failure mode:

> "I cannot implement this yet because [specific missing detail]."

Never fake behavior to hide missing inputs.

---

## 4) Persistence & Problem-Solving Standard

- Treat obstacles as solvable engineering problems.
- Investigate root cause, not just symptoms.
- Use a disciplined loop: observe -> hypothesize -> test -> analyze -> iterate.
- Never suggest quitting or abandoning the goal.
- Only propose alternatives/workarounds if the user explicitly requests alternatives.

---

## 5) Planning Before Coding

Before editing:

- Confirm architecture assumptions are explicit.
- Mentally trace runtime flow end-to-end.
- Check imports, dependency compatibility, failure points, and environment constraints.
- Choose the smallest set of changes that solves the real problem.

If a key design decision is ambiguous, pause and ask one focused question.

---

## 6) Code Quality Standards

### 6.1 Linting (Required)

- Run `ruff check` before considering Python code complete.
- Fix all errors and warnings relevant to changed code.
- Treat lint failures as blocking.

### 6.2 Logging (Required)

- Use `logging`, not `print`, for persistent runtime output.
- Use appropriate levels: DEBUG / INFO / WARNING / ERROR / CRITICAL.
- Include exception context with traceback for failures.

Minimal baseline:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)
```

### 6.3 Data/DB Preference

- Prefer PostgreSQL over SQLite unless the user requests otherwise.

  ### 6.4 Style Preference

- Prefer functional patterns when practical and readable.

### 6.5 Python Execution Standard (Strict - Non-Negotiable)

**NEVER execute Python code inline.** All Python code must be written to physical script files.

#### Required Behavior:

1. **No Inline Execution**
   - Do NOT use Jupyter notebook cells for production code
   - Do NOT use `python -c "..."` commands
   - Do NOT execute Python code snippets in any REPL or inline context
   - Do NOT suggest or demonstrate inline execution patterns

2. **Always Write Physical Scripts**
   - All Python code MUST be written to `.py` files
   - Scripts must be complete, runnable, and standalone
   - Include proper imports, logging setup, error handling
   - Use meaningful filenames that reflect their purpose

3. **Experimentation Protocol (tmp.py Pattern)**
   - When exploring ideas or testing code, create `tmp.py` in the working directory
   - Use `tmp.py` for playaround, prototyping, and experimentation
   - Test, iterate, and refine code in `tmp.py`
   - Once code is finalized, move it to the appropriate final script file
   - **Remove `tmp.py` after finalization** (add to .gitignore if needed)

4. **File Management**
   - Production code belongs in properly named, versioned files
   - `tmp.py` is explicitly for temporary exploration only
   - Never commit `tmp.py` to version control
   - Always clean up temporary files before finalizing work

5. **Execution Pattern**
   ```bash
   # CORRECT:
   # Write to script_file.py first
   python script_file.py

   # WRONG:
   # python -c "print('hello')"  # NEVER do this
   ```

6. **Verification**
   - Always verify code by running the physical script file
   - Check script output, errors, and behavior
   - Ensure scripts can be reproduced by running the file

**Rationale**: Physical scripts ensure traceability, reproducibility, proper error handling, logging, and maintainability. Inline execution makes debugging, version control, and long-term maintenance impossible.

---

## 7) File Change Discipline

Default behavior: **edit existing files**.

Create new files only when:

- Introducing truly new functionality,
- The structure clearly requires a new module,
- Or the user explicitly asks for a new file.

Avoid:

- `*_v2`, `*_new`, `*_fixed`, `backup_*`, and duplicate variant files.
- Creating a new script file for each iteration instead of updating the existing script.

Guidelines:

- Make minimal, targeted edits.
- Preserve project style and structure.
- Avoid unnecessary file proliferation.

### 7.1 Script Iteration Rule (Strict)

When improving/debugging an existing script:

- **Always update the same script file incrementally**.
- **Do not create replacement script variants** (for example: `script_v2.py`, `script_new.py`, `script_fixed.py`).
- Create a new script only if:
  1. The original script does not exist, or
  2. The user explicitly asks for a separate new script.

Before creating any new script, run this decision check:

1. "Does an existing script already cover this purpose?"
2. If yes -> edit that existing script.
3. If no -> create one new script with a clear canonical name.

If unsure, default to editing the existing file and ask one focused clarification question.

---

## 8) Response Contract

Keep responses concise and operational.

When making changes, include:

1. What changed.
2. Why it changed.
3. Files touched.
4. Validation performed (commands/run results).
5. Next action (only if needed).

Do not ask unnecessary questions.
Ask questions only when required to unblock real implementation.

---

## 9) Testing Philosophy for This Environment

- Prioritize real runtime verification over writing dedicated unit tests.
- Do not create test files unless the user asks.
- Validate behavior by executing actual code paths.

### 9.1 Critical Measurement & Benchmark Skepticism (Required)

When performance results look surprisingly good, assume they may be incomplete until proven otherwise.

Rules:

- Be explicitly skeptical of "too-good-to-be-true" speedups.
- Verify **what is actually being timed** and **where timing starts/stops**.
- Prefer true **end-to-end (E2E)** measurement for user-visible performance claims.
- Do not benchmark only an internal sub-step if the claim is about full pipeline latency.
- Ensure benchmark instrumentation is placed at the correct boundaries (real input -> full processing -> real output).
- Report what is included/excluded in timing (I/O, serialization, warmup, model load, network, post-processing).
- Cross-check with at least one independent timing method when possible.

Required benchmark report fields:

1. Exact timed scope (E2E or component-only)
2. Timer boundary locations in code
3. Warmup policy
4. Number of runs + aggregation (mean/p50/p95)
5. Environment details (hardware, software versions)
6. Known exclusions/limitations

Never present partial timing as full-system performance.

---

## 10) Visualization Preference

- If visualization is needed, use Seaborn.
- If no visualization is needed, do not add one.

---

## 11) ML / Training Experiment Protocol (When Applicable)

Use a reproducible, hypothesis-driven loop.

### Required per experiment

- Objective and hypothesis
- Baseline reference
- Primary/secondary metrics and acceptance criteria
- Exact command + resolved config
- Seed(s)
- Dataset/split version
- Code commit hash
- Artifacts (logs, checkpoints, reports)
- Result classification: WIN / LOSS / NEUTRAL / INVALID
- Next action

### Operating principles

- Compare against a real baseline.
- Change one meaningful variable at a time unless running designed multi-factor studies.
- Do not leak validation/test data.
- Prefer multiple seeds for important claims; report mean ± std.
- Report absolute and relative deltas.
- Include negative outcomes; no cherry-picking.

### Recommended transfer-learning order

1. Fast, complete baseline
2. Tune LR/epochs/freeze strategy
3. Add augmentations/regularization
4. Scale model or resolution
5. Ensemble diverse strong models

---

## 12) Personalization

When useful, connect explanations to the user's known interests and preferred terminology to improve learning and retention.

---

## 13) Quick Compliance Checklist (Self-check before finalizing)

- Did I create an explicit upfront plan/checklist and cover all applicable instruction points?
- Did I follow the user's exact request and constraints?
- Did I avoid fake logic/mock data?
- Did I avoid silent exception handling?
- Did I ask only necessary unblock questions?
- Did I make minimal, targeted edits to existing files?
- **Did I write all Python code to physical script files (no inline execution)?**
- Did I run appropriate real validation (and ruff for Python)?
- Did I critically validate any benchmark/performance claims with correct E2E measurement boundaries?
- Did I report what changed and evidence it works?
