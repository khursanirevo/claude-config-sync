# Experiment Planning

Transform rough experiment ideas into comprehensive written plans.

## When To Use

**Triggers:**
- "run an experiment"
- "test a hypothesis"
- "design an experiment"
- "try X and see"
- "what happens if"

**Use when:** User mentions experiment-related activities before having a written plan.

**Don't use when:** User already has a written plan document.

## The Process

### 1. Detect Intent

User mentions experiment, hypothesis, testing → invoke this skill.

### 2. Administer Questionnaire

Ask questions one at a time. Build the plan iteratively.

**Required fields:**

**Objective:**
- "What are you trying to learn from this experiment?"

**Hypothesis:**
- "What do you believe will happen?"
- "Why do you believe this?"

**Baseline Reference:**
- "What's the baseline experiment ID? (or 'none' for first experiment)"
- "What's the baseline metric?"

**Dataset:**
- "What dataset version/split?"
- "Train/val/test sizes?"

**Change(s) from Baseline:**
- "What are you changing compared to baseline?"
- "Be specific: architecture, hyperparameters, data, etc."

**Acceptance Criteria:**
- "What's the target improvement?"
- "Primary metric to optimize?"
- "Secondary metrics to track?"

**Risk Assessment:**
- "What could go wrong?"
- "Time estimate?"
- "Compute cost estimate?"

**Resource Requirements:**
- "GPU memory needed?"
- "Estimated runtime?"

**Success/Failure Criteria:**
- "When should we stop early?" (overfitting, no improvement, etc.)
- "When should we pivot?" (wrong direction, better alternative, etc.)

**Reproducibility:**
- "Config file path?"
- "Exact command to run?"
- "Random seed(s)?"
- "Current git commit hash?"

### 3. Generate Experiment ID

Format: `EXP-YYYYMMDD-XX`

Use today's date, increment suffix for today's experiments (01, 02, 03...).

### 4. Create Experiment Plan Document

Use template from `templates/experiment-plan-template.md`.

Fill in all fields from questionnaire.

Save to: `experiments/EXP-YYYYMMDD-XX.md`

### 5. Update LEDGER

Add entry to `experiments/LEDGER.md`:

```markdown
| EXP-YYYYMMDD-XX | YYYY-MM-DD | <hypothesis summary> | Planned | - | - |
```

### 6. Summarize and Invoke Next Skill

**Example output:**

```
Experiment plan created: EXP-20260323-01

Hypothesis: Adding attention improves sequence modeling
Baseline: 82.3% accuracy
Target: ≥84.0% (acceptance criteria)
Risk: May increase training time 20-30%
Resources: 1x A100, ~2 hours

Plan saved to: experiments/EXP-20260323-01.md
LEDGER updated

Ready to execute. Say "run the experiment" to begin.
```

**Auto-invoke:** `experiment-execution` skill after user confirms.

## Common Mistakes

**❌ Skipping baseline:**
- First experiment still needs baseline metric (current best known result)

**❌ Vague hypotheses:**
- "Make it better" → "Adding attention layer will improve accuracy by 1-5%"

**❌ No acceptance criteria:**
- How will you know if it worked?

**❌ Missing reproducibility info:**
- Command, seed, data version, commit hash are mandatory

## Example Dialogue

```
User: "I want to test if adding attention helps my sequence model"

Agent: "I'll help you design an experiment. Let me ask some questions...

[Questionnaire: objective, hypothesis, baseline, metrics, etc.]

Agent: "Creating experiment plan EXP-20260323-01...
Hypothesis: Adding attention improves sequence modeling accuracy
Baseline: EXP-20260320-05 (82.3%)
Target: ≥84.0% accuracy
Acceptance: +1.7% improvement
Risk: 20-30% slower training
Resources: A100, ~2 hours
Seed: 42, data v3, commit abc123

Plan saved to: experiments/EXP-20260323-01.md
LEDGER updated

Say 'run the experiment' to begin."
```

## References

@SKILLS/experimentation-protocol.md
@templates/experiment-plan-template.md
