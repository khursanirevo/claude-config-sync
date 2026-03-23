# Baseline Comparison

Head-to-head comparison between two models/configs to determine which is better.

## When To Use

**Triggers:**
- "compare models"
- "beat baseline"
- "model A vs model B"
- "which is better"

**Use when:** User has two experiments to compare directly.

**Don't use when:** Only one experiment exists (need two for comparison).

## The Process

### 1. Identify Experiments to Compare

**Ask user:**
- "Which experiment IDs to compare?"

Or suggest:
- "I see you just ran EXP-20260323-01. Compare vs baseline EXP-20260320-05?"

### 2. Load Both Experiments

Load:
- Experiment A: `experiments/EXP-YYYYMMDD-AA.md`
- Experiment B: `experiments/EXP-YYYYMMDD-BB.md`

### 3. Extract Metrics

From Results section of both:
- Primary metrics
- Secondary metrics
- Runtime, cost
- Resource usage

### 4. Run Statistical Significance (if applicable)

If metrics have variance/stddev:
- Ask user: "Do you have multiple runs with stddev?"
- If yes: Run t-test or similar
- Report: p-value, confidence interval

### 5. Generate Comparison Table

```markdown
# Model Comparison: EXP-AA vs EXP-BB

## Primary Metrics

| Metric | EXP-AA | EXP-BB | Delta | Winner |
|--------|--------|--------|-------|--------|
| Accuracy | 85.5% | 84.2% | +1.3% | EXP-AA |
| F1 Score | 0.83 | 0.84 | +0.01 | EXP-BB |

## Secondary Metrics

| Metric | EXP-AA | EXP-BB | Delta | Winner |
|--------|--------|--------|-------|--------|
| Training time | 1.5h | 1.2h | -0.3h | EXP-BB |
| GPU memory | 8GB | 6GB | -2GB | EXP-BB |
| Inference latency | 50ms | 35ms | -15ms | EXP-BB |

## Statistical Significance
- p-value: 0.03 (significant at α=0.05)
- Confidence interval: [0.5%, 2.1%]

## Overall Winner: EXP-AA

**Reasoning:**
- EXP-AA has significantly better accuracy (+1.3%)
- EXP-BB is faster and cheaper
- If accuracy is primary goal → EXP-AA
- If cost/latency matters → EXP-BB
```

### 6. Declare Winner and Recommend

**Overall winner:** The experiment that wins on primary metric(s)

**Recommendation:**
- "Use EXP-AA as the new baseline for accuracy-critical work"
- "Use EXP-BB for cost-sensitive applications"

### 7. Update Experiments

Link comparison from both experiment plans:

```markdown
## Comparisons
- Vs EXP-BB: [Comparison Report](./EXP-AA-vs-EXP-BB-comparison.md)
```

## Common Mistakes

**❌ Ignoring secondary metrics:**
- Primary metric wins but cost explodes → mention tradeoff

**❌ No clear winner:**
- "Results mixed. EXP-AA better on accuracy, EXP-BB better on speed. Depends on priority."

**❌ Small differences without significance:**
- "Difference 0.1% ± 0.5% - not statistically significant"

## Example Dialogue

```
User: "Compare EXP-20260323-01 vs baseline"

Agent: "Comparing EXP-20260323-01 vs EXP-20260320-05...

Primary Metrics:
- Accuracy: 85.5% vs 82.3% (+3.2%) → EXP-20260323-01
- F1: 0.83 vs 0.82 (+0.01) → EXP-20260323-01

Secondary Metrics:
- Training time: 1.5h vs 1.2h (+0.3h) → EXP-20260320-05
- GPU memory: 8GB vs 6GB (+2GB) → EXP-20260320-05

Overall Winner: EXP-20260323-01
- Significant accuracy gain (+3.2%)
- Worth extra compute cost

Recommendation: Use EXP-20260323-01 as new baseline for accuracy-critical work.

Report saved to: experiments/EXP-20260323-01-vs-EXP-20260320-05-comparison.md"
```

## References

@SKILLS/experimentation-protocol.md
@skills/experiment-analysis/SKILL.md
```

- [ ] **Step 2: Commit baseline-comparison skill**

```bash
git add skills/baseline-comparison/SKILL.md
git commit -m "feat: add baseline-comparison skill"
```

---
