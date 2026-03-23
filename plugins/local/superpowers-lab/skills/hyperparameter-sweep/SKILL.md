# Hyperparameter Sweep

Grid or random search across hyperparameter space with systematic tracking.

## When To Use

**Triggers:**
- "sweep"
- "grid search"
- "tune hyperparameters"
- "find best config"

**Use when:** User wants to systematically search hyperparameter space.

**Don't use when:** Only testing a single config (use regular experiment workflow).

## The Process

### 1. Define Search Space

**Ask user:**
- "Which hyperparameters to tune?"
- "What ranges/values for each?"

Example:
```
learning_rate: [0.001, 0.0001, 0.00001]
batch_size: [32, 64, 128]
dropout: [0.0, 0.1, 0.2, 0.5]
```

### 2. Choose Search Strategy

**Ask user:**
- "Grid search (all combinations) or random search (N random samples)?"

**Grid search:**
- Exhaustive, tests all combinations
- Can be very large (product of all parameter counts)

**Random search:**
- Tests N random combinations
- More efficient for high-dimensional spaces
- Ask: "How many random samples?"

### 3. Generate Experiment Plans

For each config in the sweep:
1. Generate experiment ID: `EXP-YYYYMMDD-XX-sweep-NN`
2. Create experiment plan using `experiment-planning` skill
3. Hypothesis: "Config [params] will improve over baseline"
4. Use same seed, data, commit across all sweep experiments

### 4. Update LEDGER

Add sweep tracking to LEDGER:

```markdown
## Sweep: EXP-YYYYMMDD-XX-sweep
- **Status:** In Progress
- **Total experiments:** 12
- **Completed:** 0/12
- **Best so far:** -
```

### 5. Execute Sweep

For each experiment in the sweep:
1. Run using `experiment-execution` skill
2. Analyze using `experiment-analysis` skill
3. Update LEDGER with progress
4. Track best config so far

**Optionally run in parallel** (if resources allow):
- "I can run up to N experiments in parallel. How many?"

### 6. Generate Sweep Report

After all experiments complete:

```markdown
# Hyperparameter Sweep: EXP-YYYYMMDD-XX-sweep

## Search Space
- learning_rate: [0.001, 0.0001, 0.00001]
- batch_size: [32, 64, 128]
- dropout: [0.0, 0.1, 0.2, 0.5]

## Strategy
- Grid search (36 combinations)

## Results

| Config | Accuracy | Rank |
|--------|----------|------|
| lr=0.0001, bs=64, do=0.1 | 86.2% | 🥇 |
| lr=0.0001, bs=128, do=0.1 | 85.9% | 🥈 |
| lr=0.001, bs=64, do=0.1 | 85.7% | 🥉 |
| ... | ... | ... |

## Best Config
- **learning_rate:** 0.0001
- **batch_size:** 64
- **dropout:** 0.1
- **Accuracy:** 86.2% (+0.7% vs baseline)

## Recommendations
- Use best config for future experiments
- learning_rate=0.0001 consistently performs well
- Larger batch sizes (128) don't help
```

Save to: `experiments/EXP-YYYYMMDD-XX-sweep-report.md`

### 7. Update Base Experiment

Link to sweep report from base experiment plan.

## Common Mistakes

**❌ Too large search space:**
- Warn user: "This will generate 100 experiments. Are you sure?"

**❌ Different seeds across sweep:**
- Use same seed for fair comparison

**❌ Not tracking sweep in LEDGER:**
- Update LEDGER with sweep progress

## Example Dialogue

```
User: "Do a hyperparameter sweep"

Agent: "I'll help you design a sweep.

Which hyperparameters to tune?
User: "learning rate, batch size, dropout"

Agent: "What ranges?
User: "lr: 0.001 to 0.00001, bs: 32-128, dropout: 0-0.5"

Agent: "Grid search or random search?
User: "grid search"

Agent: "This will generate 36 experiments. Proceed?
User: "yes"

Agent: "Creating 36 experiment plans...
[Creates all experiments]

Sweep: EXP-20260323-02-sweep
- Total: 36 experiments
- Status: In Progress

Running experiment 1/36: lr=0.001, bs=32, do=0.0...
[Runs and analyzes...]

Running experiment 2/36: lr=0.001, bs=32, do=0.1...
...

Sweep complete!

Best config: lr=0.0001, bs=64, do=0.1 → 86.2%

Report saved to: experiments/EXP-20260323-02-sweep-report.md"
```

## References

@SKILLS/experimentation-protocol.md
@skills/experiment-planning/SKILL.md
@skills/experiment-execution/SKILL.md
@skills/experiment-analysis/SKILL.md
```

- [ ] **Step 2: Commit hyperparameter-sweep skill**

```bash
git add skills/hyperparameter-sweep/SKILL.md
git commit -m "feat: add hyperparameter-sweep skill"
```

---
