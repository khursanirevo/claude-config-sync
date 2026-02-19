---
name: smart-clone
description: Intelligently clone conversation by summarizing only relevant early context using explicit criteria, then append recent half unchanged.
---

Intelligently reduce conversation context by summarizing the early half (keeping only points relevant to recent work), then appending the later half unchanged.

## Core Principle

**Keep ONLY early context that is directly referenced or used in the recent half.**

If information from the first half is NOT mentioned, used, or needed in the second half → EXCLUDE IT.

## Explicit Inclusion Criteria

**INCLUDE early context ONLY if it meets ALL of these:**

1. **Directly referenced** - Recent messages explicitly mention it
   - Examples: "the function we created earlier", "that bug from step 1", "the config file we edited"
   - Look for: references back, "as mentioned above", "like we did", "continuing from"

2. **Currently active** - Still being used/modified in recent work
   - Examples: Functions still being called, files still being edited, variables still in use
   - Look for: Same file paths, function names, variable names appearing in recent half

3. **Affects current decisions** - Recent choices depend on it
   - Examples: Architecture decisions, rejected approaches, constraints discovered
   - Look for: "because of that", "given that we decided", "based on earlier"

4. **Technical context** - Needed to understand recent code/commands
   - Examples: API endpoints, database schemas, file paths, command syntax
   - Look for: Technical details that appear without explanation in recent half

## Explicit Exclusion Criteria

**EXCLUDE early context if it meets ANY of these:**

1. **Different feature/topic** - Unrelated to recent work
   - Examples: Fixed a different bug, worked on separate feature, discussed unrelated tool
   - Test: Would removing this break understanding of recent half? If no → exclude

2. **Completed and abandoned** - Done and never referenced again
   - Examples: Installed a tool (not used recently), researched an option (not chosen), fixed a one-time issue
   - Test: Does recent half depend on this? If no → exclude

3. **Superseded by newer info** - Old approach replaced
   - Examples: Tried X but switched to Y, old API version upgraded
   - Test: Is there a newer version in recent half? If yes → exclude old

4. **One-time setup** - Installation/configuration not needed for current work
   - Examples: Installed dependencies, initial setup, environment config
   - Test: Is this actively being used/debugged in recent half? If no → exclude

5. **Dead ends** - Approaches that didn't work (unless relevant to avoiding them)
   - Examples: Tried library X (didn't work), attempted solution Y (failed)
   - Test: Is recent half avoiding this specific dead end? If no → exclude

## Summary Template

When creating the summary, use ONLY these sections (skip empty sections):

```markdown
## Goal
<What we're currently working on - from recent half>

## Relevant Progress (from earlier context)
<ONLY items that meet inclusion criteria>
- Completed: [specific tasks referenced in recent half]
- Decisions: [choices affecting current work]
- Discovered: [constraints/requirements that matter now>

## Active Technical Context
<ONLY technical details from early half that appear in recent half>
- Files: [paths still being edited]
- Functions/Classes: [names still being used]
- APIs/Tools: [still actively being called]
- Commands: [patterns still being used>

## What Didn't Work (if relevant to recent work)
<ONLY failed approaches that recent half is avoiding>
- Failed approach 1: [why it failed - ONLY if recent work references this]
- Failed approach 2: [why it failed - ONLY if recent work references this]
```

## Decision Framework

When deciding whether to include something from early half, ask:

**Question 1:** Is this mentioned in the recent half?
- NO → Exclude it
- YES → Go to question 2

**Question 2:** Does removing this break understanding of the recent half?
- NO → Exclude it
- YES → Include it

**Question 3:** Is this actively being used/modified in recent work?
- NO → Exclude it
- YES → Include it

## Examples

### Include:
```
Early half: "We decided to use PostgreSQL instead of MySQL"
Recent half: "Let's update the PostgreSQL query..."
→ INCLUDE (decision affects current work)
```

### Exclude:
```
Early half: "Installed Redis for caching"
Recent half: [no mention of Redis]
→ EXCLUDE (not referenced, not being used)
```

### Include:
```
Early half: "Created function validateUser() in auth.js"
Recent half: "We need to fix validateUser() to handle..."
→ INCLUDE (directly referenced, actively modified)
```

### Exclude:
```
Early half: "Fixed login bug by resetting tokens"
Recent half: "Working on payment feature now..."
→ EXCLUDE (different feature, completed and abandoned)
```

## Steps

1. **Get session info:**
   ```bash
   tail -1 ~/.claude/history.jsonl | jq -r '[.sessionId, .project] | @tsv'
   ```

2. **Find half-clone script:**
   ```bash
   find ~/.claude -name "half-clone-conversation.sh" 2>/dev/null | sort -V | tail -1
   ```

3. **Preview the conversation:**
   ```bash
   <script-path> --preview <session-id> <project-path>
   ```

4. **Split and analyze:**
   - Read the full conversation
   - Split at the midpoint
   - For EACH item in early half, apply the inclusion criteria
   - Be ruthless: if unsure, EXCLUDE it

5. **Create the summary:**
   - Use the template above
   - Include ONLY items that pass all 3 questions
   - Keep it concise (100-200 words max)

6. **Create the cloned conversation:**
   - Run half-clone script to get base file
   - Prepend your summary at the beginning
   - Mark with `[SMART-CLONE <timestamp>]`

7. **Tell user:**
   "Smart-clone complete! Access with: `claude -r` and look for `[SMART-CLONE <timestamp>]`. Summarized only relevant early context, recent half preserved."
