# Experiment Analysis

Compare results vs baseline, collect artifacts, assess outcome (WIN/LOSS/NEUTRAL/INVALID).

## When To Use

**Triggers:**
- "analyze results"
- "compare with baseline"
- "what did we learn"
- Auto-invoked after `experiment-execution` completes

**Use when:** Experiment has finished running and results need to be interpreted.

**Don't use when:** Experiment hasn't run yet or is still running.

## The Process

### 1. Load Documents

Load:
- Current experiment: `experiments/EXP-YYYYMMDD-XX.md`
- Baseline experiment: `experiments/EXP-YYYYMMDD-YY.md` (if exists)

### 2. Extract Metrics

From Results section of experiment plan:
- Primary metric value
- Secondary metrics
- Runtime, cost

From baseline:
- Baseline metric values

### 3. Calculate Deltas

For each metric:
- Absolute delta: `new - baseline`
- Relative delta: `((new - baseline) / baseline) * 100`

Example:
```
Accuracy: 82.3% → 85.5% (+3.2%, +3.9%)
Loss: 0.45 → 0.38 (-0.07, -15.6%)
Runtime: 1.2h → 1.5h (+0.3h, +25%)
```

### 4. Compare Against Acceptance Criteria

From experiment plan's Acceptance Criteria section:
- Primary metric: Was target met?
- Secondary metrics: Any red flags?

**Determine outcome:**

| Condition | Outcome |
|-----------|---------|
| Met acceptance criteria, improvement validated | WIN |
| Failed criteria, regression confirmed | LOSS |
| Inconclusive, needs more data | NEUTRAL |
| Bug, data leak, wrong config, crashed | INVALID |

### 5. Assess Confidence

**High:**
- Clear improvement/degradation
- Multiple runs consistent
- Statistical significance (if applicable)

**Medium:**
- Direction clear but magnitude uncertain
- Single run only

**Low:**
- Too noisy
- Conflicting metrics
- Needs more data

### 6. Collect Artifacts

Ensure artifacts are saved to `experiments/artifacts/EXP-XXXX/`:
- Checkpoints
- Logs
- Predictions
- Metrics JSON
- Run info

If missing: "Please save [missing artifact] to experiments/artifacts/EXP-XXXX/"

### 7. Update Experiment Plan

Fill in Results and Outcome sections:

```markdown
## Results
- **Primary metric:** 82.3% → 85.5% (+3.2%)
- **Secondary metrics:** Loss: 0.45 → 0.38 (-15.6%)
- **Runtime/Cost:** 1.2h → 1.5h (+25%)

## Outcome
- **Label:** WIN
- **What worked:** Adding attention improved accuracy as expected
- **What didn't work:** Training time increased more than expected
- **Why:** Attention allows better long-range dependencies
- **Confidence:** High
```

### 8. Update LEDGER

Update entry in `experiments/LEDGER.md`:

```markdown
| EXP-20260323-01 | 2026-03-23 | Attention improves seq modeling | WIN | 82.3% → 85.5% (+3.2%) | High |
```

### 9. Suggest Next Action

Based on outcome:

**WIN:**
- "Results improved by X%. Should we run an ablation study to confirm which component helped?"
- "Should we try further improvements?"

**LOSS:**
- "Results regressed by X. Should we pivot to different approach?"
- "Should we analyze why it didn't work?"

**NEUTRAL:**
- "Results inconclusive. Should we run with more data/different seed?"

**INVALID:**
- "Experiment was INVALID due to [reason]. Fix and retry?"

## Common Mistakes

**❌ Missing baseline:**
- First experiment: "No baseline to compare. This is the new baseline."

**❌ Ignoring secondary metrics:**
- Primary improved but loss exploded → might be overfitting

**❌ Wrong outcome label:**
- INVALID doesn't mean "didn't work" - it means "buggy run"

**❌ No next action:**
- Always suggest what to do next

## Example Dialogue

```
User: [after experiment finishes]

Agent: "Analyzing results vs baseline...

Results:
- Accuracy: 82.3% → 85.5% (+3.2%, +3.9%)
- Loss: 0.45 → 0.38 (-15.6%)
- Runtime: 1.2h → 1.5h (+25%)

Acceptance criteria: ≥84.0% accuracy → MET (85.5%)

Outcome: WIN, Confidence: High
What worked: Adding attention improved accuracy
What didn't: Training time increased more than expected
Why: Attention captures long-range dependencies better

Artifacts saved to: experiments/artifacts/EXP-20260323-01/
LEDGER updated

Should we run an ablation study to confirm the attention layer is responsible?"
```

## References

@SKILLS/experimentation-protocol.md
@skills/experiment-execution/SKILL.md
