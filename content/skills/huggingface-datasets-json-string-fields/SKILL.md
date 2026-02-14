---
name: huggingface-datasets-json-string-fields
description: |
  Fix for HuggingFace datasets library returning JSON strings instead of parsed
  objects. Use when: (1) dataset fields are strings when you expect lists/dicts,
  (2) json.loads() errors on HuggingFace dataset values, (3) iteration over dataset
  returns string representations instead of actual objects. Common with datasets
  saved from pandas or with complex nested structures.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# HuggingFace Datasets JSON String Fields

## Problem
When loading datasets from HuggingFace using the `datasets` library, some fields are
returned as JSON strings instead of parsed Python objects (lists/dicts). This causes
`AttributeError: 'str' object has no attribute 'get'` and similar type errors.

## Context / Trigger Conditions
- Using `from datasets import load_dataset`
- Accessing dataset fields that should be lists or dicts but getting strings
- Error: `AttributeError: 'str' object has no attribute 'get'` (or 'keys', 'items')
- Error: `TypeError: string indices must be integers` when trying to access dict fields
- Fields containing conversation turns, metadata, or complex nested data structures

## Root Cause
HuggingFace datasets are often saved from pandas DataFrames or with schema that doesn't
preserve complex nested types. JSON-serializable objects (lists, dicts) get serialized to
strings during the save/load process.

## Solution

### Option 1: Parse on access (Recommended for existing code)

```python
from datasets import load_dataset
import json

dataset = load_dataset("username/dataset", split="train")

for item in dataset:
    # Check if field is string, parse if needed
    turns_data = item.get("turns", [])
    if isinstance(turns_data, str):
        try:
            turns = json.loads(turns_data)
        except json.JSONDecodeError:
            logger.warning(f"Failed to parse turns for {item.get('id')}")
            turns = []
    else:
        turns = turns_data
```

### Option 2: Parse in __init__ method (For class wrappers)

```python
class Conversation:
    def __init__(self, data: Dict[str, Any]):
        self.id = data.get("id", "")

        # Parse JSON string fields
        participants_data = data.get("participants", [])
        if isinstance(participants_data, str):
            self.participants = json.loads(participants_data)
        else:
            self.participants = participants_data

        # Same for other fields
        turns_data = data.get("turns", [])
        if isinstance(turns_data, str):
            self.turns = json.loads(turns_data)
        else:
            self.turns = turns_data
```

### Option 3: Dataset-wide mapping (For large datasets)

```python
def parse_json_fields(example):
    """Map function to parse all JSON string fields"""
    result = {}
    for key, value in example.items():
        if isinstance(value, str):
            try:
                result[key] = json.loads(value)
            except json.JSONDecodeError:
                result[key] = value
        else:
            result[key] = value
    return result

# Apply to dataset
dataset = dataset.map(parse_json_fields)
```

### Option 4: Use with_format (Cleanest if schema allows)

```python
# Try to load with proper types (if dataset features specify it)
dataset = load_dataset(
    "username/dataset",
    split="train",
    features=Features({
        "id": Value("string"),
        "turns": Sequence(Value("dict")),  # Specify nested structure
        # ... other fields
    })
)
```

## Verification
After parsing, the field should be accessible as a Python object:
```python
# Should work without AttributeError
first_turn = turns[0]
speaker = first_turn.get("speaker")  # Returns actual value
```

## Example

```python
from datasets import load_dataset
import json

dataset = load_dataset("khursanirevo/convo", split="train")
conv = dataset[0]

# Before fix
print(type(conv["turns"]))  # <class 'str'>
print(conv["turns"][:50])   # '[{"turn_id": 1, "speaker": "A", ...}]'

# After fix
turns_data = conv["turns"]
if isinstance(turns_data, str):
    turns = json.loads(turns_data)
else:
    turns = turns_data

print(type(turns))         # <class 'list'>
print(turns[0].get("speaker"))  # 'A' - Works!
```

## Notes
- This is most common with datasets saved from pandas `to_json()` or similar
- The `datasets` library doesn't automatically parse JSON strings
- Check `dataset.info.features` to see declared types
- Some datasets use `Sequence(Value("string"))` which keeps strings as-is
- Consider saving processed datasets with `.save_to_disk()` to avoid re-parsing
- When caching parsed data, include the full parsed objects, not strings

## Common Patterns

### Detecting JSON string fields
```python
def needs_parsing(value):
    return isinstance(value, str) and (
        value.startswith('{') or
        value.startswith('[') or
        value.startswith('"')
    )
```

### Safe parsing wrapper
```python
def safe_parse_json(value, default=None):
    """Safely parse JSON string, return default if fails"""
    if isinstance(value, (list, dict)):
        return value
    if isinstance(value, str):
        try:
            return json.loads(value)
        except (json.JSONDecodeError, TypeError):
            pass
    return default if default is not None else value
```

### Batch processing
```python
def process_batch(batch):
    """Process a batch of examples"""
    parsed = []
    for item in batch:
        parsed_item = {}
        for key, value in item.items():
            if isinstance(value, str) and value.strip().startswith(('{', '[')):
                try:
                    parsed_item[key] = json.loads(value)
                except json.JSONDecodeError:
                    parsed_item[key] = value
            else:
                parsed_item[key] = value
        parsed.append(parsed_item)
    return parsed

dataset = dataset.map(process_batch, batched=True)
```

## References
- [HuggingFace Datasets - Dataset Features](https://huggingface.co/docs/datasets/main/en/package_reference/main_classes#datasets.Dataset.features)
- [HuggingFace Datasets - map()](https://huggingface.co/docs/datasets/main/en/package_reference/main_classes#datasets.Dataset.map)
