# Reproducibility Check

Verify that an experiment can be recreated exactly from its documentation.

## When To Use

**Triggers:**
- "reproduce"
- "can you recreate"
- "verify reproducibility"
- "is this reproducible"

**Use when:** User wants to verify an experiment can be recreated.

**Don't use when:** Experiment plan doesn't exist yet.

## The Process

### 1. Load Experiment Plan

Read: `experiments/EXP-YYYYMMDD-XX.md`

### 2. Verify Reproducibility Metadata

Check all required fields are present:

| Field | Required | Location |
|-------|----------|----------|
| Config path | ✓ | Reproducibility section |
| Exact command | ✓ | Reproducibility section |
| Seed(s) | ✓ | Reproducibility section |
| Data version | ✓ | Dataset section |
| Commit hash | ✓ | Reproducibility section |

**If missing:**
- "Cannot reproduce - [field] is missing. Please add to experiment plan."

### 3. Verify Artifacts Exist

Check:
- [ ] Config file exists at specified path
- [ ] Dataset version is available
- [ ] Git commit is reachable

**If missing:**
- "Config file not found: [path]. Cannot reproduce."

### 4. Check Git Commit

Compare plan's commit hash vs current HEAD:

```bash
git rev-parse HEAD
```

**If different:**
- "Commit mismatch. Plan: abc123, Current: def456. Checkout abc123?"
- If user agrees: `git checkout abc123`

### 5. Attempt Recreate

**Run exact command from plan:**

```bash
# From plan's "Exact command" field
<exact command from plan>
```

### 6. Compare Outputs

Compare new run vs original:
- Metrics should match (or very close)
- Runtime should be similar
- No new errors/warnings

### 7. Generate Reproducibility Report

```markdown
# Reproducibility Check: EXP-YYYYMMDD-XX

## Status: PASS | FAIL

## Metadata Check
- [x] Config path present
- [x] Exact command present
- [x] Seed specified
- [x] Data version specified
- [x] Commit hash recorded

## Artifact Check
- [x] Config file exists: experiments/configs/EXP-XXXX-config.yaml
- [x] Dataset available: data-v3
- [x] Commit reachable: abc123

## Recreate Attempt
- Original metric: 85.5%
- Recreated metric: 85.4%
- Delta: -0.1% (within acceptable variance)

## Conclusion
✅ Experiment is reproducible
- Metrics match within acceptable variance
- All artifacts available
- Command executes correctly
```

Save to: `experiments/EXP-YYYYMMDD-XX-reproducibility.md`

### 8. Update Experiment Plan

Link reproducibility report:

```markdown
## Reproducibility
- Status: Verified PASS
- Report: [EXP-XXXX-reproducibility.md](./EXP-XXXX-reproducibility.md)
```

## Common Mistakes

**❌ Missing metadata:**
- "Cannot reproduce - seed not specified. Add to plan first."

**❌ Wrong commit:**
- Warn user and offer to checkout correct commit

**❌ Config file missing:**
- "Config file not found. Restore from backup?"

## Example Dialogue

```
User: "Verify EXP-20260323-01 is reproducible"

Agent: "Checking reproducibility of EXP-20260323-01...

Metadata check:
- Config path: ✓
- Exact command: ✓
- Seed: ✓ (42)
- Data version: ✓ (v3)
- Commit hash: ✓ (abc123)

Artifact check:
- Config file: ✓ (experiments/configs/EXP-20260323-01.yaml)
- Dataset: ✓ (data-v3)
- Commit: ✓ (reachable)

Git commit:
- Current HEAD: def456
- Plan commit: abc123
- Mismatch detected. Checkout abc123? [y/n]

User: "y"

Agent: "Checking out abc123...
Running exact command: python train.py --config experiments/configs/EXP-20260323-01.yaml --seed 42

[Training output...]

Comparing results:
- Original accuracy: 85.5%
- Recreated accuracy: 85.4%
- Delta: -0.1%

✅ Experiment is reproducible
Report saved to: experiments/EXP-20260323-01-reproducibility.md"
```

## References

@SKILLS/experimentation-protocol.md
@TEMPLATES/experiment-plan.md
