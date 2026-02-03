---
name: python-format-keyword-error
description: |
  Fix KeyError when using Python string .format() method with placeholders.
  Use when: (1) KeyError raised for template placeholder like {variable},
  (2) variable exists in scope but .format() doesn't recognize it,
  (3) modifying existing template systems with new placeholders. Covers
  Python str.format() method and template string formatting.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# Python .format() KeyError Fix

## Problem
Adding a new placeholder to a template string causes `KeyError` even though the variable exists in the function scope.

## Context / Trigger Conditions
- Error: `KeyError: 'variable_name'`
- Using Python `.format()` method on strings
- Template contains `{placeholder}` that's causing the error
- Variable with same name exists in local scope
- Common when modifying existing prompt/template systems

## Solution
When adding a placeholder to a template string, you must also pass it as an explicit keyword argument to `.format()`:

**Wrong:**
```python
def build_prompt(template, language_variety):
    # Template has {language_variety}
    return template.format(name="John")  # KeyError!
```

**Correct:**
```python
def build_prompt(template, language_variety):
    # Template has {language_variety}
    return template.format(
        name="John",
        language_variety=language_variety  # Must pass explicitly
    )
```

**Pattern:**
1. Template string: `"{new_var}"` - add placeholder
2. Format call: `.format(new_var=value, **kwargs)` - add kwarg

Both steps are required. Step 2 is often forgotten.

## Verification
After adding the keyword argument, the `.format()` call succeeds and the placeholder is substituted correctly.

## Example
**Session that triggered this skill:**
- Modified `TEACHING_USER` prompt to include `{language_variety}`
- Forgot to add to `.format()` kwargs in `build_prompt_with_schema()`
- Error: `KeyError: 'language_variety'` despite variable being in scope
- Fix: Added `language_variety=language_variety` to line 91 of prompts.py

**Code diff:**
```python
# Before (line 85-92)
user_prompt = user_template.format(
    NAME_A=name_ctx["NAME_A"],
    NAME_B=name_ctx["NAME_B"],
    ...
)

# After (line 85-93)
user_prompt = user_template.format(
    NAME_A=name_ctx["NAME_A"],
    NAME_B=name_ctx["NAME_B"],
    ...
    language_variety=language_variety,  # Added this line
)
```

## Notes
- **Why this is confusing**: The variable exists in the function scope, so intuition says it should be available. But `.format()` only receives what's explicitly passed as kwargs.
- **Alternative**: Consider using f-strings (`f"{variable}"`) which have access to the enclosing scope. However, `.format()` is better for templates where variables aren't known at definition time.
- **Debugging tip**: When you get `KeyError` from `.format()`, check both the template string AND the format call. The missing kwarg is often the issue.
- **Related patterns**: Similar issue with `string.Template()` which requires `substitute(keyword=value)` for each placeholder.

## References
- [Python String format() Method](https://docs.python.org/3/library/stdtypes.html#str.format)
- [Format String Syntax](https://docs.python.org/3/library/string.html#format-string-syntax)
