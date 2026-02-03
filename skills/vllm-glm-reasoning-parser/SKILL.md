---
name: vllm-glm-reasoning-parser
description: |
  Fix GLM model chain-of-thought leakage in vLLM by using the built-in reasoning parser.
  Use when: (1) GLM-4.x models output reasoning traces instead of final answers,
  (2) You see numbered sections like "1. **Analyze**" in model outputs,
  (3) vLLM serves raw chain-of-thought instead of parsed responses,
  (4) GLM-4.5, GLM-4.7, or GLM-4 Flash models leak internal reasoning.
  Covers vLLM --reasoning-parser option and glm4_moe_reasoning_parser.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# vLLM GLM Reasoning Parser

## Problem
GLM-4.x models (including GLM-4.5V, GLM-4.7-Flash, GLM-4.7-FP8) output their internal chain-of-thought reasoning as part of the response instead of providing clean user-facing answers. This results in outputs like:

```
1. **Analyze the Request**
   Topic: xxx, Language: yyy

2. **Brainstorming**
   - Point A
   - Point B

4. **Drafting the Content**
   * *Intro:* Some content here
```

Instead of just the clean response.

## Context / Trigger Conditions

- Model outputs numbered reasoning sections (1, 2, 3, 4...)
- Section headers like "**Analyze**", "**Brainstorming**", "**Drafting**"
- Actual content buried in later sections with bullet points
- Using GLM-4.5, GLM-4.7, or similar models with vLLM
- Without `--reasoning-parser` specified in vLLM startup

## Solution

### Primary Solution: Use vLLM's Built-in Reasoning Parser

vLLM has official support for parsing GLM model reasoning. Add the reasoning parser when starting the server:

```bash
python -m vllm.entrypoints.openai.api_server \
  --model "zai-org/GLM-4.7-Flash" \
  --reasoning-parser "glm4_moe" \
  --other-args...
```

Available reasoning parsers for GLM models:
- `glm4_moe` - For GLM-4 MoE models (GLM-4.7-Flash, GLM-4.7-FP8)
- `glm45` - For GLM-4.5V models

### Alternative: Custom Parsing (If Reasoning Parser Fails)

If the built-in parser doesn't work (there are known issues with streaming), you can extract content by:

1. **Identify the "Drafting" section** - Look for:
   ```regex
   \d+\.\s+\*\*Drafting\s+the\s+Content[^*]*\*\*
   ```

2. **Extract bullet points** in format `    *   *Label:* content`:
   ```python
   parts = line.split(':', 1)
   content = parts[1].strip().lstrip('*').strip()
   ```

3. **Clean artifacts**:
   ```python
   # Remove parenthetical English
   content = re.sub(r'\s*\([A-Za-z][^)]*\)', '', content)
   # Remove markdown bold
   content = re.sub(r'\*\*([^*]+)\*\*', r'\1', content)
   ```

However, **prefer the built-in reasoning parser** over custom parsing.

## Verification

After adding `--reasoning-parser "glm4_moe"`:
1. Restart vLLM server
2. Send a test request
3. Output should be clean Malay/Chinese response without numbered sections

API response will have separate `reasoning_content` and `content` fields:
```json
{
  "reasoning_content": "Internal reasoning (optional)",
  "content": "Clean user-facing response"
}
```

## Example

**Before (without reasoning parser):**
```bash
# GLM-4.7-Flash outputs full chain-of-thought
curl http://localhost:8002/v1/chat/completions -d '{
  "model": "glm-4.7-flash",
  "messages": [{"role": "user", "content": "Hello"}]
}'
# Returns: "1. **Analyze**\n2. **Drafting**\n   *Hello! I am..."
```

**After (with reasoning parser):**
```bash
# Start server with parser
python -m vllm.entrypoints.openai.api_server \
  --model "zai-org/GLM-4.7-Flash" \
  --reasoning-parser "glm4_moe" \
  --port 8002

# Same request now returns clean response
curl http://localhost:8002/v1/chat/completions -d '{
  "model": "glm-4.7-flash",
  "messages": [{"role": "user", "content": "Hello"}]
}'
# Returns: "Hello! I am a helpful assistant..."
```

## Notes

### Known Issues (2026-01-26)

1. **GLM-4.5 streaming bug** (Issue #29763, Nov 2025):
   - The `--reasoning-parser glm45` fails during streaming chat completions when no tools are used
   - Workaround: Disable streaming or use custom parsing

2. **GLM-4.7-FP8 missing tags** (Issue #31319, Dec 2025):
   - Model outputs close tags without beginning tags when hosted without reasoning_parser
   - Using `--reasoning-parser "glm4_moe"` fixes this

3. **Extraction rate limitations**:
   - Custom regex parsing achieves ~60% extraction rate
   - Built-in parser is more reliable but may still have edge cases

### Why This Happens

GLM models are trained to output their reasoning process (chain-of-thought) as part of the response. This is intentional for certain use cases (showing work), but problematic for standard chat completions where users expect clean answers.

vLLM's reasoning parser extracts the reasoning into a separate field, returning only the final answer in the main `content` field.

### Performance Impact

Using the reasoning parser adds minimal overhead - it simply parses the existing structured output rather than regenerating.

## References

- [vLLM Reasoning Outputs Documentation](https://docs.vllm.ai/en/latest/features/reasoning_outputs/)
- [vLLM GLM-4 MoE Reasoning Parser API](https://docs.vllm.ai/en/stable/api/vllm/reasoning/glm4_moe_reasoning_parser/)
- [vLLM Abs Reasoning Parsers](https://docs.vllm.ai/en/latest/api/vllm/reasoning/abs_reasoning_parsers/)
- [vLLM Issue #29763: GLM-4.5 reasoning parser streaming](https://github.com/vllm-project/vllm/issues/29763)
- [vLLM Issue #31319: GLM-4.7-FP8 missing beginning tag](https://github.com/vllm-project/vllm/issues/31319)
- [GLM-4.X LLM User Guide (vLLM Recipes)](https://docs.vllm.com.cn/projects/recipes/en/latest/GLM/GLM.html)
