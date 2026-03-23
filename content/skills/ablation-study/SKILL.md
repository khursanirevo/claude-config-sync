# Ablation Study

Systematically remove or vary components to isolate what contributes to performance.

## When To Use

**Triggers:**
- "ablation"
- "what if we remove X"
- "which component helped"
- "isolate the improvement"

**Use when:** User wants to understand which components of a model/config are responsible for performance.

**Don't use when:** No baseline experiment exists to ablate from.

## The Process

### 1. Identify Base Experiment

Load the "full" experiment to ablate: `experiments/EXP-YYYYMMDD-XX.md`

### 2. Identify Components to Ablate

**From user:**
- "Which components should we ablate?"

**Or suggest from config:**
- "I see these components in the config: [attention, layer_norm, dropout]. Which should we ablate?"

### 3. Design Ablation Matrix

For each component, create an experiment that removes/disables it.

Example:
```
Base: Full model (attention + layer_norm + dropout)
Ablation 1: Remove attention
Ablation 2: Remove layer_norm
Ablation 3: Remove dropout
```

### 4. Create Ablation Experiments

For each ablation:
1. Create child experiment plan using `experiment-planning` skill
2. Use same seed, data, commit as base
3. Only change: the component being ablated
4. Experiment ID: `EXP-YYYYMMDD-XX-ablate-<component>`

### 5. Execute Ablation Experiments

For each ablation experiment:
1. Run using `experiment-execution` skill
2. Analyze using `experiment-analysis` skill

### 6. Generate Comparison Report

Create ablation study report:

```markdown
# Ablation Study: EXP-YYYYMMDD-XX

## Base Model
- **Metric:** 85.5% accuracy
- **Components:** attention, layer_norm, dropout

## Ablation Results

| Component Removed | Accuracy | Delta | Conclusion |
|-------------------|----------|-------|------------|
| None (base) | 85.5% | - | - |
| Attention | 82.1% | -3.4% | Attention critical |
| Layer Norm | 84.8% | -0.7% | Minor contribution |
| Dropout | 85.8% | +0.3% | Dropout not needed |

## Recommendations

- **Keep:** Attention (major contribution)
- **Keep:** Layer Norm (small but positive)
- **Remove:** Dropout (hurts performance)
```

Save to: `experiments/EXP-YYYYMMDD-XX-ablation-study.md`

### 7. Update Base Experiment

Link to ablation study from base experiment plan:

```markdown
## Related Experiments
- Ablation study: [EXP-YYYYMMDD-XX-ablation-study](./EXP-YYYYMMDD-XX-ablation-study.md)
```

## Common Mistakes

**❌ Changing multiple variables:**
- Each ablation should only change one component

**❌ Different seed/data:**
- Must use same seed, data, commit for fair comparison

**❌ Not documenting what was removed:**
- Clearly state which component was ablated

## Example Dialogue

```
User: "Run an ablation study on EXP-20260323-01"

Agent: "I'll ablate the components from EXP-20260323-01.

Components found: attention, layer_norm, dropout

Ablation plan:
1. Remove attention
2. Remove layer_norm
3. Remove dropout

Each will use same seed (42), data (v3), commit (abc123).

Creating ablation experiments...
[Creates 3 child experiments]

Running ablation 1/3: Remove attention...
[Runs and analyzes...]

Running ablation 2/3: Remove layer_norm...
[Runs and analyzes...]

Running ablation 3/3: Remove dropout...
[Runs and analyzes...]

Ablation study complete!

Base: 85.5% (attention + layer_norm + dropout)
- Remove attention: 82.1% (-3.4%) ← Critical
- Remove layer_norm: 84.8% (-0.7%) ← Minor
- Remove dropout: 85.8% (+0.3%) ← Not needed

Recommendation: Keep attention and layer_norm, remove dropout.

Report saved to: experiments/EXP-20260323-01-ablation-study.md"
```

## References

@SKILLS/experimentation-protocol.md
@skills/experiment-planning/SKILL.md
@skills/experiment-execution/SKILL.md
@skills/experiment-analysis/SKILL.md
```

- [ ] **Step 2: Commit ablation-study skill**

```bash
git add skills/ablation-study/SKILL.md
git commit -m "feat: add ablation-study skill"
```

---
