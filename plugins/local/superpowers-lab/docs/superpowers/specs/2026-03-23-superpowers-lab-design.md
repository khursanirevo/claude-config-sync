# Superpowers Lab Design Spec

**Date:** 2026-03-23
**Status:** Approved
**Version:** 1.0.0

## Overview

Superpowers Lab is a disciplined experimentation workflow plugin for AI/ML research in Claude Code. It enforces the scientific method: hypothesis → plan → execute → analyze → iterate. Built as a separate plugin from superpowers, focused on research workflows rather than software development.

### Core Philosophy

Every experiment is a hypothesis test that must be planned, tracked, and analyzed systematically. No "just try it and see" - document what you're testing and why.

### Goals

1. **Enforce scientific discipline** - No experiments without written plans
2. **Ensure reproducibility** - Track seed, data version, config, commit hash
3. **Prevent wasted work** - Comprehensive planning before execution
4. **Enable learning** - Every experiment produces documented outcome (WIN/LOSS/NEUTRAL/INVALID)
5. **Framework-agnostic** - Works with any ML stack (PyTorch, TensorFlow, JAX, sklearn, etc.)

## Architecture

### Plugin Structure

```
superpowers-lab/
├── skills/
│   ├── experiment-planning/SKILL.md
│   ├── experiment-execution/SKILL.md
│   ├── experiment-analysis/SKILL.md
│   ├── ablation-study/SKILL.md
│   ├── hyperparameter-sweep/SKILL.md
│   ├── baseline-comparison/SKILL.md
│   ├── reproducibility-check/SKILL.md
│   └── verification-before-completion/SKILL.md
├── agents/
│   └── experiment-reviewer.md
├── hooks/
│   └── session-start
├── templates/
│   └── experiment-plan-template.md
├── SKILLS/
│   └── experimentation-protocol.md
└── .claude-plugin/
    └── plugin.json
```

### Session-Start Hook

The `session-start` hook injects the experimentation protocol at session start, ensuring all users get the workflow regardless of their personal CLAUDE.md configuration.

## Skills

### Core Workflow Skills

#### experiment-planning

**Purpose:** Transform rough experiment ideas into comprehensive written plans

**Triggers:**
- "run an experiment"
- "test a hypothesis"
- "design an experiment"
- "try X and see"

**Workflow:**
1. Detect experiment intent
2. Administer structured questionnaire:
   - Objective and hypothesis
   - Baseline reference (ID + metric)
   - Dataset version/split
   - Change(s) from baseline
   - Acceptance criteria (primary + secondary metrics)
   - Risk assessment (what could go wrong, time/cost estimate)
   - Resource requirements (GPU memory, runtime)
   - Success/failure criteria (when to stop, when to pivot)
   - Reproducibility info (config path, command, seed)
3. Create experiment plan document at `experiments/EXP-YYYYMMDD-XX.md`
4. Update `experiments/LEDGER.md` with new entry
5. Notify user of next step: "Plan created. Ready to execute. Say 'run the experiment' to begin."

**Invokes:** `experiment-execution` (after user approval)

**Output:** Complete experiment plan document

---

#### experiment-execution

**Purpose:** Run experiments with full reproducibility tracking

**Triggers:**
- "run the experiment"
- "start training"
- "launch the experiment"
- "execute EXP-..."

**Workflow:**
1. Load experiment plan from `experiments/EXP-YYYYMMDD-XX.md`
2. Verify reproducibility metadata is present
3. Notify user: "Running EXP-YYYYMMDD-XX. Tracking: seed, data version, config..."
4. Execute the experiment command
5. Capture outputs in real-time
6. Update experiment status to "Running" in LEDGER
7. On completion: capture artifacts, update status to "Completed"
8. Notify user: "Experiment finished. Analyzing results vs baseline..."

**Invokes:** `experiment-analysis` (automatic after completion)

**Output:** Updated experiment document with results section

---

#### experiment-analysis

**Purpose:** Compare results vs baseline, collect artifacts, assess outcome

**Triggers:**
- "analyze results"
- "compare with baseline"
- "what did we learn"
- Auto-invoked after `experiment-execution`

**Workflow:**
1. Load experiment and baseline documents
2. Extract metrics from both
3. Calculate deltas (absolute and relative)
4. Compare against acceptance criteria
5. Collect artifacts:
   - Checkpoints → `experiments/artifacts/EXP-XXXX/checkpoints/`
   - Logs → `experiments/artifacts/EXP-XXXX/logs/`
   - Predictions → `experiments/artifacts/EXP-XXXX/predictions/`
   - Metrics → `experiments/artifacts/EXP-XXXX/metrics.json`
6. Determine outcome label:
   - **WIN** - Met acceptance criteria, improvement validated
   - **LOSS** - Failed criteria, regression confirmed
   - **NEUTRAL** - Inconclusive, needs more data
   - **INVALID** - Bug, data leak, wrong config (state reason clearly)
7. Assess confidence (Low/Medium/High)
8. Update LEDGER with results
9. Suggest next action (ablation, sweep, pivot, stop)

**Output:** Completed experiment document with outcome, updated LEDGER

---

### Specialized Skills

#### ablation-study

**Purpose:** Systematically remove or vary components to isolate what contributes to performance

**Triggers:**
- "ablation"
- "what if we remove X"
- "which component helped"
- "isolate the improvement"

**Workflow:**
1. Identify components to ablate (from user or from baseline config)
2. Create ablation matrix (each component removed individually)
3. For each ablation:
   - Create child experiment plan
   - Execute with same seed/data
   - Compare vs full model
4. Generate comparison table showing contribution of each component
5. Recommend which components to keep/remove

**Output:** Ablation study report with component contribution analysis

---

#### hyperparameter-sweep

**Purpose:** Grid or random search across hyperparameter space with tracking

**Triggers:**
- "sweep"
- "grid search"
- "tune hyperparameters"
- "find best config"

**Workflow:**
1. Define search space (hyperparameters, ranges)
2. Choose search strategy (grid, random, Bayesian - user specifies)
3. Generate experiment plans for each config
4. Execute sweep (can run in parallel if resources allow)
5. Track all runs in LEDGER
6. Generate sweep report:
   - Best config
   - Metric vs hyperparameter plots
   - Recommendation

**Output:** Sweep report with best configuration and analysis

---

#### baseline-comparison

**Purpose:** Head-to-head comparison between two models/configs

**Triggers:**
- "compare models"
- "beat baseline"
- "model A vs model B"
- "which is better"

**Workflow:**
1. Load both experiment documents
2. Run statistical significance tests if applicable
3. Compare on all metrics (primary + secondary)
4. Generate comparison table
5. Declare winner with confidence assessment
6. Recommend which to use going forward

**Output:** Comparison report with recommendation

---

### Quality Skills

#### reproducibility-check

**Purpose:** Verify experiment can be recreated exactly

**Triggers:**
- "reproduce"
- "can you recreate"
- "verify reproducibility"
- "is this reproducible"

**Workflow:**
1. Load experiment document
2. Verify all reproducibility metadata present:
   - Config file exists and matches
   - Seed specified
   - Data version specified
   - Commit hash recorded
   - Command is exact
3. Attempt to recreate:
   - Checkout commit hash
   - Run exact command
   - Compare outputs
4. Report reproducibility status

**Output:** Reproducibility report (PASS/FAIL with details)

---

#### verification-before-completion

**Purpose:** Evidence before claiming results (prevents false success claims)

**Triggers:**
- Auto-invoked before any completion claim
- Before marking experiment as WIN
- Before saying "this works"

**Workflow:**
1. Identify what was claimed (metric improvement, fix, etc.)
2. Run verification command to check actual output
3. Compare claim vs reality
4. If mismatch: block completion, require re-run
5. If match: allow completion

**Output:** Verification result (blocks false claims)

---

## File Structure

### Project-Side Structure

```
project-root/
├── experiments/
│   ├── LEDGER.md                    # Index of all experiments
│   ├── EXP-20260323-01.md           # Individual experiment docs
│   ├── EXP-20260323-02.md
│   ├── artifacts/
│   │   ├── EXP-20260323-01/
│   │   │   ├── checkpoints/         # Model checkpoints
│   │   │   ├── logs/                # Training logs
│   │   │   ├── predictions/         # Test set predictions
│   │   │   ├── plots/               # Metrics plots
│   │   │   ├── metrics.json         # Parsed metrics
│   │   │   └── run-info.txt         # Command, seed, environment
│   │   └── EXP-20260323-02/
│   └── configs/                     # Reproducibility configs
│       ├── EXP-20260323-01-config.yaml
│       └── EXP-20260323-02-config.yaml
```

### LEDGER.md Format

```markdown
# Experiment Ledger

| ID | Date | Hypothesis | Status | Baseline → New (Δ) | Confidence |
|----|------|------------|--------|-------------------|------------|
| EXP-20260323-01 | 2026-03-23 | Attention improves seq modeling | WIN | 82.3% → 85.5% (+3.2%) | High |
| EXP-20260323-02 | 2026-03-23 | Deeper network hurts | LOSS | 85.5% → 84.1% (-1.4%) | High |
```

### Experiment Plan Document

```markdown
# EXP-YYYYMMDD-XX — <short title>

## Metadata
- **Date/Time:**
- **Owner:**
- **Status:** Planned | Running | Completed | Failed

## Objective
- What are we testing?

## Hypothesis
- What do we believe will happen?

## Baseline Reference
- **Experiment ID:** EXP-YYYYMMDD-YY
- **Metric:** 82.3% accuracy

## Dataset
- **Version/Split:**
- **Train/Val/Test sizes:**

## Change(s) from Baseline
-

## Acceptance Criteria
- **Primary metric:** target ≥ 84.0%
- **Secondary metrics:**

## Risk Assessment
- **What could go wrong:**
- **Time estimate:**
- **Compute cost:**

## Resource Requirements
- **GPU memory:**
- **Estimated runtime:**

## Success/Failure Criteria
- **Stop if:**
- **Pivot if:**

## Reproducibility
- **Config path:**
- **Exact command:**
- **Seed(s):**
- **Code commit hash:**

## Results (filled after execution)
- **Primary metric:** <baseline> → <new> (delta: <+/->)
- **Secondary metrics:**
- **Runtime/Cost:**

## Outcome
- **Label:** WIN | LOSS | NEUTRAL | INVALID
- **What worked:**
- **What didn't work:**
- **Why (explanation):**
- **Confidence:** Low | Medium | High

## Artifacts
- **Checkpoints:**
- **Logs:**
- **Predictions:**

## Next Action
-
```

## Workflow

### End-to-End Example

```
User: "I want to test if adding attention helps my sequence model"

↓ experiment-planning triggers

Agent: "I'll help you design an experiment. Let me ask some questions..."
[Questionnaire: hypothesis, baseline, metrics, acceptance criteria, risks, resources, reproducibility]

Agent: "Creating experiment plan EXP-20260323-01. Here's what will be included:
- Hypothesis: Adding attention layer improves sequence modeling accuracy
- Baseline: EXP-20260320-05 (82.3% accuracy)
- Primary metric: Validation accuracy
- Acceptance: ≥84.0% (target +1.7% improvement)
- Risk: May increase training time by 20-30%
- Resources: 1x A100, ~2 hours
- Seed: 42, data split v3, commit abc123

Ready to create plan. Proceed?"

User: "yes"

Agent: [Creates experiments/EXP-20260323-01.md, updates LEDGER.md]
"Plan created. Say 'run the experiment' to begin execution."

User: "run the experiment"

↓ experiment-execution triggers

Agent: "Running EXP-20260323-01. Tracking: seed=42, data=v3, config saved."
[Monitors training, captures outputs]

↓ After 2 hours

Agent: "Experiment finished. I'll now analyze results vs baseline..."
[experiment-analysis: compares 85.5% vs 82.3%, collects artifacts]

Agent: "Results: 82.3% → 85.5% (+3.2%). Acceptance criteria met (≥84.0%).
Outcome: WIN, Confidence: High
Artifacts saved to experiments/artifacts/EXP-20260323-01/

Should we run an ablation study to confirm the attention layer is responsible?"
```

### Automatic Chaining with Transparency

Skills automatically invoke the next skill in the workflow, but always notify the user:

- "I'll now analyze the results..."
- "Running experiment EXP-20260323-01..."
- "Creating ablation study..."

User can interrupt at any point. Automation with control.

## Integration

### Claude Code Plugin Manifest

```json
{
  "name": "superpowers-lab",
  "version": "1.0.0",
  "description": "Disciplined experimentation workflow for AI/ML research",
  "author": "Superpowers Lab Contributors",
  "license": "MIT",
  "skills": [
    "skills/experiment-planning",
    "skills/experiment-execution",
    "skills/experiment-analysis",
    "skills/ablation-study",
    "skills/hyperparameter-sweep",
    "skills/baseline-comparison",
    "skills/reproducibility-check",
    "skills/verification-before-completion"
  ],
  "hooks": {
    "SessionStart": "hooks/session-start"
  }
}
```

### Installation (Future)

```bash
# After publishing to marketplace
/plugin install superpowers-lab

# Or from local repo
/plugin install /path/to/superpowers-lab
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Separate plugin from superpowers | Different audience (researchers vs software devs), independent evolution |
| Claude Code only initially | Most common for ML/AI work, expand to other platforms later |
| Auto-chain with transparency | Automation with user control - agent explains next step |
| Framework-agnostic | Works with PyTorch, TF, JAX, sklearn - concepts not implementation |
| Comprehensive plans | Reduces wasted experiments, forces thinking upfront |
| LEDGER + individual files | Quick overview + detailed tracking |
| Session-start protocol | All users get workflow, no CLAUDE.md dependency |
| One variable at a time | Prevents confounding factors unless intentional multi-factor study |
| INVALID label | Distinguishes failed experiments from buggy runs |

## Non-Goals

These are explicitly out of scope:

- **Framework-specific integrations** - No PyTorch/TensorFlow-specific code
- **Automatic hyperparameter optimization** - User drives the search, skill tracks it
- **Distributed training** - Assumes single-machine experiments
- **Model serving/deployment** - Focused on research, not production
- **Data versioning** - User specifies data version, skill doesn't manage it

## Success Criteria

Plugin is successful when:

1. Users create experiment plans before running experiments
2. Every experiment has documented outcome (WIN/LOSS/NEUTRAL/INVALID)
3. LEDGER provides quick overview of all experiments
4. Users can reproduce experiments from saved configs
5. Workflow reduces wasted experiments (more WIN, fewer INVALID)

## Future Enhancements

Potential v2.0 features:

- Support for Cursor, Codex, OpenCode, Gemini
- Integration with MLflow/Weights & Biases
- Automatic statistical significance testing
- Visualization of experiment relationships (experiment graph)
- Parallel experiment execution
- Cost tracking and budgeting
- Multi-factor experimental design

## References

- User's CLAUDE.md Experimentation Protocol
- Superpowers plugin architecture
- Scientific method best practices
- ML reproducibility research
