# Experimentation Protocol

This protocol is injected at session start via the session-start hook. All skills reference this document for the core methodology.

## Core Rules

1. **No experiments without a plan** - Every experiment must have a written plan document before execution
2. **Evidence before claims** - Never claim improvement without fresh verification
3. **Compare against real baselines** - Always have a baseline reference experiment
4. **One variable at a time** - Change one meaningful variable per experiment unless running a designed multi-factor study
5. **Document everything** - Command, seed, data version, commit hash, environment

## Experiment Lifecycle

1. **Plan** → Write experiment plan with hypothesis, baseline, acceptance criteria
2. **Execute** → Run with reproducibility tracking (seed, data version, config)
3. **Analyze** → Compare vs baseline, collect artifacts, assess confidence
4. **Decide** → WIN/LOSS/NEUTRAL/INVALID, document next action

## Required Metadata

Every experiment MUST record:
- Exact command run
- Config file + resolved hyperparameters
- Random seed(s)
- Dataset/version
- Code commit hash
- Results (baseline → new, delta)
- Outcome label + confidence

## Failure Modes

- **INVALID** = Bug, data leak, wrong config, crashed run
- Report INVALID clearly, state reason
- INVALID experiments don't count as evidence

## Outcome Labels

- **WIN** - Met acceptance criteria, improvement validated
- **LOSS** - Failed criteria, regression confirmed
- **NEUTRAL** - Inconclusive, needs more data
- **INVALID** - Bug, data leak, wrong config (state reason clearly)

## Confidence Levels

- **High** - Clear result, multiple runs, statistical significance
- **Medium** - Direction clear but magnitude uncertain
- **Low** - Too noisy, needs more data
