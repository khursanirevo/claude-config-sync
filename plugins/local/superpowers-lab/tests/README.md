# Testing Guide

This guide provides comprehensive testing procedures for validating all Superpowers Lab skills and workflows.

## Manual Testing Checklist

### Session-Start Hook
- [ ] Hook runs at session start
- [ ] Protocol is injected into context
- [ ] No errors in hook execution
- [ ] Protocol reference is available (@SKILLS/experimentation-protocol.md)

### Experiment Planning
- [ ] Triggers on "run an experiment" or similar intent
- [ ] Asks all required questions (objective, hypothesis, baseline, metrics, etc.)
- [ ] Creates experiment plan document in experiments/
- [ ] Updates LEDGER with new experiment entry
- [ ] Generates valid experiment ID (EXP-YYYYMMDD-XX format)
- [ ] Handles missing information gracefully

### Experiment Execution
- [ ] Loads existing experiment plan by ID
- [ ] Runs the specified command
- [ ] Captures output to logs/
- [ ] Updates experiment status to "Running" then "Completed"
- [ ] Saves artifacts (checkpoints, predictions, etc.)
- [ ] Records runtime information

### Experiment Analysis
- [ ] Loads experiment and baseline
- [ ] Calculates deltas correctly (primary and secondary metrics)
- [ ] Determines correct outcome label (WIN/LOSS/NEUTRAL/INVALID)
- [ ] Updates LEDGER with results
- [ ] Suggests next action based on outcome
- [ ] Handles missing baseline gracefully

### Ablation Study
- [ ] Identifies components to ablate from model
- [ ] Creates child experiments for each component removal
- [ ] Uses same seed and data across all ablations
- [ ] Generates comparison report with all results
- [ ] Recommends which components to keep/remove
- [ ] Handles component dependencies correctly

### Hyperparameter Sweep
- [ ] Generates all combinations (grid) or samples (random)
- [ ] Tracks progress in LEDGER for all experiments
- [ ] Identifies best configuration
- [ ] Generates comprehensive sweep report
- [ ] Handles large sweeps efficiently
- [ ] Supports custom parameter ranges

### Baseline Comparison
- [ ] Loads both experiments correctly
- [ ] Generates comparison table with all metrics
- [ ] Declares winner based on primary metric
- [ ] Handles mixed results (win on primary, lose on secondary)
- [ ] Provides clear recommendation
- [ ] Handles tie scenarios

### Reproducibility Check
- [ ] Verifies all metadata is present
- [ ] Checks all artifacts exist
- [ ] Attempts recreation with same config
- [ ] Reports PASS/FAIL correctly
- [ ] Lists missing information when fails
- [ ] Validates random seeds and data versions

### Verification Before Completion
- [ ] Detects completion claims (e.g., "model achieves 95%")
- [ ] Runs verification command/test
- [ ] Blocks false claims with evidence request
- [ ] Allows verified claims with evidence
- [ ] Provides clear feedback on what's missing
- [ ] Handles edge cases gracefully

## Test Projects

Create test projects to validate end-to-end workflows:

### Test 1: Simple Classification

**Objective:** Validate experiment planning and analysis workflow

**Setup:**
- Binary classification task (e.g., sklearn's breast cancer dataset)
- Compare logistic regression vs random forest
- Use accuracy as primary metric, F1 as secondary

**Validation Points:**
1. Create experiment plan for both models
2. Run experiments with same train/test split
3. Analyze results and compare
4. Verify LEDGER entries are complete
5. Check all artifacts are saved

**Expected Outcome:**
- Two complete experiment entries
- Clear winner declared
- All metadata captured
- Reproducible with same seed

### Test 2: Hyperparameter Sweep

**Objective:** Validate sweep tracking and reporting

**Setup:**
- Small grid search (2x2x2 = 8 experiments)
- Parameters: learning_rate [0.001, 0.0001], batch_size [32, 64], optimizer [adam, sgd]
- Use simple model (e.g., neural network on MNIST subset)
- Fixed random seed across all runs

**Validation Points:**
1. Create sweep plan with all combinations
2. Run all 8 experiments
3. Verify LEDGER tracks all experiments
4. Check sweep report identifies best config
5. Validate progress tracking
6. Verify all artifacts are organized

**Expected Outcome:**
- 8 experiment entries with proper parent/child relationships
- Sweep report with ranked configurations
- Best config clearly identified
- All runs reproducible

### Test 3: Ablation Study

**Objective:** Validate ablation matrix and component analysis

**Setup:**
- Model with 3 components (e.g., transformer + layer norm + dropout)
- Run baseline with all components
- Ablate each component individually
- Use same dataset and seed throughout

**Validation Points:**
1. Create baseline experiment
2. Run ablation for each component
3. Verify all use same seed and data
4. Check comparison report
5. Validate recommendations
6. Ensure all results are comparable

**Expected Outcome:**
- 4 experiments (1 baseline + 3 ablations)
- Clear comparison table
- Recommendation on which components to keep
- Quantified impact of each component

## Integration Testing

Test with Claude Code to validate full integration:

### Installation Test

```bash
# Install plugin locally
cd /home/sani/superpowers-lab
claude plugin install .

# Verify installation
claude plugin list | grep superpowers-lab
```

**Expected:** Plugin appears in list with correct version

### Session Start Test

```bash
# Start new Claude Code session
# Check that experimentation protocol is available
```

**Validation:**
- Session starts without errors
- Protocol is referenced in context
- No hook execution errors

### End-to-End Workflow Test

```bash
# In Claude Code session, test each skill:

# 1. Experiment Planning
"Help me design an experiment to test a new optimizer"

# 2. Experiment Execution
"Run experiment EXP-20260323-01"

# 3. Experiment Analysis
"Analyze experiment EXP-20260323-01 vs baseline"

# 4. Ablation Study
"Run an ablation study on the model components"

# 5. Hyperparameter Sweep
"Do a hyperparameter sweep on learning rate and batch size"

# 6. Baseline Comparison
"Compare EXP-20260323-01 vs EXP-20260323-02"

# 7. Reproducibility Check
"Check if experiment EXP-20260323-01 is reproducible"

# 8. Verification
"Verify that the model achieves 90% accuracy"
```

**Validation:**
- Each skill triggers correctly
- Required questions are asked
- Files are created in correct locations
- LEDGER is updated properly
- No errors in execution

### Error Handling Test

Test various error scenarios:
- Invalid experiment ID
- Missing experiment plan
- Incomplete experiments
- Missing artifacts
- Invalid configurations

**Expected:** Graceful error messages with clear guidance

## Continuous Validation

### Pre-Commit Checklist

Before committing changes:
- [ ] All skill files have correct format
- [ ] All references to @SKILLS/ are valid
- [ ] No TODO or placeholder comments remain
- [ ] All examples are complete and runnable
- [ ] LEDGER template is valid
- [ ] Plugin manifest is correct

### Post-Commit Validation

After committing changes:
- [ ] Plugin installs successfully
- [ ] Session-start hook runs without errors
- [ ] All skills are accessible
- [ ] Test projects run successfully
- [ ] Documentation is consistent

## Test Coverage Summary

| Component | Manual Tests | Integration Tests | Status |
|-----------|--------------|-------------------|--------|
| Session-Start Hook | ✓ | ✓ | Pending |
| Experiment Planning | ✓ | ✓ | Pending |
| Experiment Execution | ✓ | ✓ | Pending |
| Experiment Analysis | ✓ | ✓ | Pending |
| Ablation Study | ✓ | ✓ | Pending |
| Hyperparameter Sweep | ✓ | ✓ | Pending |
| Baseline Comparison | ✓ | ✓ | Pending |
| Reproducibility Check | ✓ | ✓ | Pending |
| Verification Before Completion | ✓ | ✓ | Pending |

## Bug Reporting

When issues are found, document in tests/BUGS.md with:
- Issue title and description
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Error messages or logs
- Severity level (Critical/High/Medium/Low)

## Test Maintenance

Update this guide when:
- New skills are added
- Testing procedures change
- New test projects are created
- Bug reports reveal new test cases
- Integration requirements change
