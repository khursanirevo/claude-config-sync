# Superpowers Lab

Disciplined experimentation workflow for AI/ML research in Claude Code.

## What it does

Superpowers Lab enforces the scientific method for ML experiments:
- Hypothesis → Plan → Execute → Analyze → Iterate
- Every experiment tracked with reproducibility metadata
- Systematic ablation studies and hyperparameter sweeps
- Evidence before claims - no false success

## Installation

```bash
# From local directory
/plugin install /path/to/superpowers-lab

# Coming soon to marketplace
/plugin install superpowers-lab
```

## Quick Start

1. Install the plugin:
```bash
/plugin install /path/to/superpowers-lab
```

2. Start a new session and say:
```text
I want to test if adding attention helps my model
```

3. Superpowers Lab will guide you through:
- Creating an experiment plan
- Running with reproducibility tracking
- Analyzing results vs baseline
- Deciding next steps

## Example Workflow

See [docs/WORKFLOW.md](docs/WORKFLOW.md) for detailed examples.

## Skills

- **experiment-planning** - Structured questionnaire → written plan
- **experiment-execution** - Run with reproducibility tracking
- **experiment-analysis** - Compare vs baseline, collect artifacts
- **ablation-study** - Systematic component removal
- **hyperparameter-sweep** - Grid/random search tracking
- **baseline-comparison** - Head-to-head model comparison
- **reproducibility-check** - Verify experiment can be recreated
- **verification-before-completion** - Evidence before claims

## Workflow

```
User: "I want to test if adding attention helps"
→ experiment-planning: Creates comprehensive plan
→ experiment-execution: Runs with tracking
→ experiment-analysis: Compares vs baseline
→ Suggests: Ablation study to confirm?
```

## File Structure

Projects get an `experiments/` directory:
```
experiments/
├── LEDGER.md                    # Quick overview
├── EXP-20260323-01.md           # Individual experiment
├── artifacts/                   # Checkpoints, logs, predictions
└── configs/                     # Reproducibility configs
```

## Philosophy

- No experiments without written plans
- Compare against real baselines
- One variable at a time (unless intentional multi-factor)
- Document everything (seed, data version, commit, command)
- INVALID label for buggy runs (don't count as evidence)

## License

MIT License - see LICENSE file