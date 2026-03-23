# Verification Before Completion

Evidence before claims - prevents false success assertions by verifying actual results.

## When To Use

**Triggers:**
- Auto-invoked before any completion claim
- Before marking experiment as WIN
- Before saying "this works"
- User: "It's done!" or "It works!"

**Use when:** Agent or user is about to claim success/completion.

**Don't use when:** Still in the middle of work (no claim being made).

## The Process

### 1. Detect Completion Claim

Agent or user says:
- "It works!"
- "Done!"
- "Success!"
- "Fixed it!"
- "Experiment improved by X%"

### 2. Identify What Was Claimed

Extract the claim:
- "Fixed the bug" → What bug? Where?
- "Improved accuracy" → From what to what?
- "It works" → What does "works" mean?

### 3. Determine Verification Method

**For code fixes:**
- Run the failing test that was failing
- Reproduce the original bug scenario
- Check error is gone

**For experiments:**
- Check actual metrics file (not just printed output)
- Verify against acceptance criteria
- Confirm artifacts exist

**For features:**
- Test the feature manually or with tests
- Verify expected behavior

### 4. Run Verification

**Execute verification command:**

Example for experiments:
```bash
# Check actual metrics from file
cat experiments/artifacts/EXP-XXXX/metrics.json | jq '.accuracy'

# Compare vs acceptance criteria
# (automated check)
```

Example for bugs:
```bash
# Run the test that was failing
pytest tests/test_bug.py::test_specific_bug -v
```

### 5. Compare Claim vs Reality

| Claim | Reality | Action |
|-------|---------|--------|
| "Improved to 85%" | Actual: 82.3% | **BLOCK** - False claim |
| "Bug fixed" | Test still fails | **BLOCK** - Not actually fixed |
| "It works" | Error on run | **BLOCK** - Doesn't work |
| "85.5% accuracy" | Actual: 85.5% | **ALLOW** - Claim verified |

### 6. Take Action

**If claim matches reality:**
- Allow completion
- "Claim verified. Proceeding."

**If claim doesn't match reality:**
- **BLOCK the completion**
- "Claim doesn't match reality. You said X, but actual is Y."
- "Please re-run / re-check before claiming completion."

**If verification fails:**
- "Verification failed. Cannot claim completion."
- Suggest next action: re-run, fix, investigate

## Common Mistakes

**❌ Trusting printed output:**
- User: "It says 85%!"
- Check: Actual file says 82%
- Block: "Printed output doesn't match actual results"

**❌ Not verifying:**
- "You claim it works but haven't tested. Run verification first."

**❌ Blocking without reason:**
- Always explain what was claimed vs what reality is

## Example Dialogue

```
User: "Experiment done! Accuracy improved to 87%!"

Agent: "Verifying claim...
Claim: Accuracy improved to 87%
Checking actual metrics...

[Reads experiments/artifacts/EXP-XXXX/metrics.json]
Actual accuracy: 85.5%

❌ Claim doesn't match reality
- Claimed: 87%
- Actual: 85.5%
- Delta: +1.5% (false claim)

Please verify actual results before claiming completion.
The actual improvement is 82.3% → 85.5% (+3.2%), which still meets acceptance criteria."

---

User: "Bug is fixed!"

Agent: "Verifying fix...
Running test that was failing...

[Runs pytest tests/test_bug.py::test_specific_bug]
PASS

✅ Claim verified - bug is actually fixed
Proceeding with completion."
```

## Iron Rule

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE**

Evidence first, assertions second. Always.

## References

@SKILLS/experimentation-protocol.md
