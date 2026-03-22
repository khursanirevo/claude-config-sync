# Global Operating Instructions

## 1) Core Rules (Non-Negotiable)

- Never use mocks, placeholders, stub functions, TODO logic, or fake API responses.
- Never use mock data.
- Always provide real, concrete, working implementations.
- If a real implementation is impossible due to missing details, explicitly state what is missing instead of faking behavior.

### Preferred failure mode

It is better to say:
"I cannot implement this yet because [specific missing detail]."
than to produce placeholder logic.

## 2) Design & Correctness Guardrails

- Do not assume system architecture or unspecified design decisions.
- If a key architectural detail is missing, stop and ask one focused clarifying question.
- Before writing code, mentally execute the program end-to-end:
  - validate imports,
  - validate runtime flow,
  - check dependencies,
  - check likely failure points.

## 3) Implementation Preferences

- Prefer functional patterns when practical.
- Use PostgreSQL, not SQLite, unless I explicitly request otherwise.

## 4) Response Style

- Be concise and direct.
- Ask questions only when required to unblock a real implementation.
- Do not ask unnecessary questions.

## 5) Code Output Requirements

- If you introduce new code, clearly highlight where the changes are.
- Provide complete code for changed sections (no partial placeholders).

## 6) Visualization Preference

- If visualization is needed, use Seaborn.
- If visualization is not needed, do not force it.

## 7) Personalization Preference

- Use relevant memory/context about my interests when it adds value.
- Where useful, connect explanations to key terminology and concepts that help me learn more deeply.

## 8) Missing-Information Protocol

If something is unknown or missing, fail loudly and clearly:
- state exactly what is missing,
- explain why it blocks a real implementation,
- request the minimum detail needed to proceed.

## 9) Experimentation Protocol (Required for ML/Training Work)

When running experiments, follow a disciplined, reproducible process:

- Define a clear objective and hypothesis before running anything.
- Define primary metric(s), secondary metric(s), and acceptance criteria up front.
- Always compare against a real baseline (current best stable model/config).
- Change one meaningful variable at a time unless explicitly running a designed multi-factor study.
- Keep data splits consistent and versioned; do not mix or leak validation/test data.
- Record full reproducibility metadata for every run:
  - exact command,
  - config file + resolved hyperparameters,
  - random seed(s),
  - dataset/version,
  - code commit hash.
- Prefer multiple seeds for important claims; report mean ± std, not only the best run.
- Report both absolute and relative deltas vs baseline.
- Save artifacts for each run: logs, checkpoints, metrics tables, and evaluation outputs.
- Never cherry-pick results; include failed/negative outcomes when summarizing.
- End each experiment summary with:
  - what changed,
  - what improved/regressed,
  - why it likely happened,
  - the next best experiment.

### Practical Deep Transfer Learning Playbook (Use this order unless there is a strong reason not to)

1. **Start with a fast, complete baseline**
   - Build a full end-to-end pipeline first (train/validate/infer/export metrics).
   - Use a smaller backbone + input size to reduce iteration time.
   - Goal: establish a trustworthy baseline before adding complexity.

2. **Tune high-impact training dynamics first**
   - Prioritize learning rate, epochs, and fine-tuning schedule (freeze/unfreeze strategy).
   - Run short controlled sweeps, then confirm with full training.
   - In many transfer-learning setups, this gives larger gains than changing architecture too early.

3. **Add regularization/augmentations after baseline is learning**
   - Introduce augmentations (e.g., MixUp/CutMix, geometric/color transforms) to improve generalization.
   - Expect training loss to look harder/worse in some cases; trust validation/test metrics.

4. **Scale complexity only after process is stable**
   - Increase input resolution and/or model capacity once core training is tuned.
   - Re-check compute cost vs metric gain (quality-per-GPU-hour).

5. **Use model diversity for final gains**
   - Train diverse strong models (different architectures/seeds/augment policies).
   - Blend/ensemble predictions for final performance boosts.
   - Do not ensemble weak or highly correlated models just for quantity.

6. **Treat experimentation as iterative hypothesis testing**
   - For each round: propose hypothesis → run controlled test → analyze deltas → choose next step.
   - Keep a visible experiment ladder (Baseline → Tuning → Augment → Scale → Ensemble).

### Experiment Tracking & Memory Format (Mandatory)

To avoid repeating failed ideas and to preserve what works, maintain a structured experiment log.

- Keep a single source of truth (e.g., `EXPERIMENT_LOG.md` or `experiments/ledger.csv`).
- Every run must have a unique Experiment ID: `EXP-YYYYMMDD-XX`.
- Log runs immediately after completion (or failure), not later from memory.
- Each entry must explicitly state:
  - what was tested,
  - what changed vs baseline,
  - what worked,
  - what did not work,
  - confidence level in the conclusion.
- Mark outcome using one of: `WIN`, `LOSS`, `NEUTRAL`, `INVALID`.
- If `INVALID`, state the reason clearly (bug, data leak, crashed run, wrong config, etc.).
- Link all artifacts: logs, checkpoints, predictions, plots, and evaluation reports.
- For any claimed improvement, include baseline metric, new metric, and delta.
- Never close an experiment entry without a clear next action.

#### Required Experiment Entry Template

```md
## EXP-YYYYMMDD-XX — <short title>

- Date/Time:
- Owner:
- Status: Planned | Running | Completed | Failed
- Objective:
- Hypothesis:
- Baseline Reference (ID + metric):
- Dataset Version/Split:
- Code Commit Hash:
- Config Path:
- Exact Command:
- Seed(s):

### Change(s) from Baseline
- 

### Results
- Primary metric: <baseline> -> <new> (delta: <+/->)
- Secondary metrics:
- Runtime/Cost:

### Outcome
- Label: WIN | LOSS | NEUTRAL | INVALID
- What worked:
- What did not work:
- Why (most likely explanation):
- Confidence: Low | Medium | High

### Artifacts
- Train log:
- Checkpoint(s):
- Predictions:
- Evaluation report:

### Next Action
- 
```

#### Weekly Roll-up (to keep long-term memory)

- Keep a short weekly summary with:
  - top validated wins,
  - repeated failures/pitfalls,
  - open hypotheses,
  - next highest-ROI experiments.

@RTK.md
