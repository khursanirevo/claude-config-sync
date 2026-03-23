# Experiment Execution

Run experiments with full reproducibility tracking and artifact collection.

## When To Use

**Triggers:**
- "run the experiment"
- "start training"
- "launch the experiment"
- "execute EXP-..."
- Auto-invoked after `experiment-planning` user approval

**Use when:** User has an approved experiment plan and wants to run it.

**Don't use when:** No experiment plan exists yet (use `experiment-planning` first).

## The Process

### 1. Load Experiment Plan

Read from: `experiments/EXP-YYYYMMDD-XX.md`

Verify:
- Plan exists
- All required fields are filled
- Reproducibility metadata is present

If missing: "Plan incomplete. Please complete [missing field] first."

### 2. Pre-Execution Checklist

**Verify:**
- [ ] Config file exists at specified path
- [ ] Dataset is available at specified version
- [ ] Git commit hash matches current HEAD (or warn user)
- [ ] Command is complete and executable

**Notify user:**
```
Running EXP-20260323-01

Tracking:
- Seed: 42
- Data: v3
- Config: experiments/configs/EXP-20260323-01-config.yaml
- Commit: abc123

Command: python train.py --config experiments/configs/EXP-20260323-01-config.yaml
```

### 3. Execute Experiment

**Run the exact command from the plan.**

Monitor output in real-time. Capture:
- stdout/stderr
- Training progress
- Any errors or warnings

### 4. Update Status

Update experiment plan status: `Planned` → `Running`

Update LEDGER status: `Planned` → `Running`

### 5. Monitor Execution

While experiment runs:
- Display progress to user
- Note any anomalies (errors, warnings, unexpected behavior)

### 6. Post-Execution

**On success:**
1. Capture final metrics from output
2. Save run info to `experiments/artifacts/EXP-XXXX/run-info.txt`:
   ```
   Command: <exact command>
   Seed: <seed>
   Data version: <version>
   Commit: <hash>
   Environment: <python version, packages>
   Start time: <timestamp>
   End time: <timestamp>
   Duration: <hours>
   ```
3. Update experiment plan with Results section
4. Update status: `Running` → `Completed`
5. Notify user: "Experiment finished. Analyzing results vs baseline..."
6. **Auto-invoke:** `experiment-analysis` skill

**On failure:**
1. Capture error output
2. Update experiment plan with error details
3. Update status: `Running` → `Failed`
4. Determine if INVALID (bug, wrong config) or legitimate failure
5. Notify user with diagnosis
6. Suggest next action (fix and retry, pivot, etc.)

## Artifact Collection

After successful execution, ensure artifacts are saved:

```
experiments/artifacts/EXP-XXXX/
├── checkpoints/          # Model checkpoints
├── logs/                 # Training logs
├── predictions/          # Test set predictions
├── plots/                # Metrics plots
├── metrics.json          # Parsed metrics
└── run-info.txt          # Command, seed, environment
```

**Note:** The skill should remind the user to save artifacts if not automatically done by the training script.

## Common Mistakes

**❌ Running without plan:**
- "No experiment plan found. Use experiment-planning first."

**❌ Wrong git commit:**
- Warn user: "Commit hash doesn't match. Current: def456, Plan: abc123. Proceed anyway?"

**❌ Missing artifacts:**
- Remind user to save checkpoints, logs, predictions

**❌ Not capturing command output:**
- Must save stdout/stderr for reproducibility

## Example Dialogue

```
User: "run the experiment"

Agent: "Running EXP-20260323-01

Tracking:
- Seed: 42
- Data: v3
- Config: experiments/configs/EXP-20260323-01-config.yaml
- Commit: abc123

Command: python train.py --config experiments/configs/EXP-20260323-01-config.yaml
[Monitors training output...]

Experiment finished. I'll now analyze results vs baseline..."
```

## References

@SKILLS/experimentation-protocol.md
@skills/experiment-planning/SKILL.md
@skills/experiment-analysis/SKILL.md
