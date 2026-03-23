# Workflow Examples

## Example 1: First Experiment

**Goal:** Test if a transformer layer improves sequence modeling

```text
You: I want to test if adding a transformer layer helps my LSTM model

Agent: I'll help you design an experiment. Let me ask some questions...

[Questionnaire about hypothesis, baseline, metrics, etc.]

Agent: Experiment plan created: EXP-20260323-01
- Hypothesis: Transformer improves accuracy
- Baseline: 82.3% (current best)
- Target: ≥84.0%
- Risk: 20-30% slower training
- Seed: 42, data v3

Say "run the experiment" to begin.

You: run the experiment

Agent: Running EXP-20260323-01...
[Monitors training...]

Agent: Analysis complete:
- Accuracy: 82.3% → 85.5% (+3.2%)
- Outcome: WIN, Confidence: High
- Artifacts saved to: experiments/artifacts/EXP-20260323-01/

Should we run an ablation study?
```

## Example 2: Ablation Study

```text
You: Run an ablation study on EXP-20260323-01

Agent: I'll ablate the components...
- Remove transformer: 82.1% (-3.4%)
- Remove layer norm: 84.8% (-0.7%)
- Remove dropout: 85.8% (+0.3%)

Recommendation: Keep transformer, keep layer norm, remove dropout.
```

## Example 3: Hyperparameter Sweep

```text
You: Do a hyperparameter sweep on learning rate and batch size

Agent: Creating sweep...
- lr: [0.001, 0.0001, 0.00001]
- batch_size: [32, 64, 128]
- Total: 9 experiments

Running 1/9...
[...]
Sweep complete!

Best config: lr=0.0001, bs=64 → 86.2%
```

## Example 4: Baseline Comparison

```text
You: Compare EXP-20260323-01 with the previous best model EXP-20260320-05

Agent: Comparing experiments...

EXP-20260323-01 (Transformer LSTM):
- Accuracy: 85.5%
- Training time: 2.3 hours
- Parameters: 2.1M

EXP-20260320-05 (Baseline LSTM):
- Accuracy: 82.3%
- Training time: 1.8 hours
- Parameters: 1.8M

Winner: EXP-20260323-01
- Accuracy gain: +3.2%
- Time cost: +0.5 hours (+28%)
- Parameter increase: +300K (+17%)

Recommendation: Adopt transformer architecture for production use.
```

## Example 5: Reproducibility Check

```text
You: Verify that EXP-20260323-01 is reproducible

Agent: Checking reproducibility metadata for EXP-20260323-01...

✓ Experiment plan exists
✓ Random seed recorded: 42
✓ Dataset version recorded: v3
✓ Code commit hash recorded: a1b2c3d
✓ Full command recorded
✓ Training logs available
✓ Checkpoint saved

Reproducibility Status: PASS

To reproduce, run:
python train.py --config experiments/configs/EXP-20260323-01.json --seed 42
```

## Example 6: Verification Before Completion

```text
You: I've finished implementing the new attention mechanism. It works perfectly!

Agent: That's great! Before we mark this as complete, let me verify the claims.

[Runs evaluation on test set...]

Agent: Verification Results:
- Claim: "Works perfectly"
- Test accuracy: 78.3% (baseline: 82.1%)
- Performance: -3.8% vs baseline

⚠️ VERIFICATION FAILED
The implementation actually performs worse than the baseline.

Recommendation: Debug the attention mechanism implementation before claiming success.
```
