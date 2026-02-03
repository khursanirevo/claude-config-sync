---
name: zai-api-configuration
description: |
  Z.AI (Zhipu AI) API configuration for GLM-4.7 model. Use when: (1) integrating
  with z.ai API in Python/TypeScript, (2) troubleshooting "Unknown Model" errors,
  (3) setting up OpenAI-compatible API calls for Chinese LLM provider, (4) controlling
  thinking/reasoning mode to reduce token usage and cost. Covers both general and
  coding-specific endpoints, authentication format, model naming, and thinking mode.
author: Claude Code
version: 1.1.0
date: 2026-01-24
---

# Z.AI API Configuration

## Problem
Z.AI (Zhipu AI) has specific endpoint patterns and model names that differ from
other OpenAI-compatible providers. Using incorrect endpoint or model name results
in "Unknown Model" errors (error code 1211).

## Context / Trigger Conditions
- Error: `{"error":{"code":"1211","message":"Unknown Model, please check the model code."}}`
- Integrating with Z.AI GLM-4.7 model
- Need OpenAI-compatible format for Chinese LLM
- Setting up API client for z.ai

## Solution

### Base URLs

Z.AI provides two different endpoints:

1. **General Purpose API**:
   ```
   https://api.z.ai/api/paas/v4
   ```

2. **Coding-Specific API** (used in synthlabs codebase):
   ```
   https://api.z.ai/api/coding/paas/v4
   ```

### Full Endpoint Construction

For chat completions:
```
https://api.z.ai/api/paas/v4/chat/completions
# OR for coding tasks:
https://api.z.ai/api/coding/paas/v4/chat/completions
```

### Model Name

```python
model = "glm-4.7"
```

### Authentication

Standard Bearer token authentication:
```python
headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}
```

### Request Format (OpenAI-Compatible)

```python
payload = {
    "model": "glm-4.7",
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Your question here"}
    ],
    "temperature": 0.8,
    "max_tokens": 8192,
}
```

### Complete Python Example

```python
import requests

API_KEY = "your-zai-api-key"
BASE_URL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
MODEL = "glm-4.7"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

payload = {
    "model": MODEL,
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello, how are you?"}
    ],
    "temperature": 0.8,
    "max_tokens": 8192,
}

response = requests.post(BASE_URL, headers=headers, json=payload)
result = response.json()

# Extract content
content = result["choices"][0]["message"]["content"]
print(content)
```

### TypeScript/Node.js Example

```typescript
const response = await fetch('https://api.z.ai/api/coding/paas/v4/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'glm-4.7',
    messages: [
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: 'Hello, how are you?' }
    ],
    temperature: 0.8,
    max_tokens: 8192,
  }),
});

const data = await response.json();
const content = data.choices[0].message.content;
```

### Using OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    api_key="your-zai-api-key",
    base_url="https://api.z.ai/api/paas/v4/"
)

completion = client.chat.completions.create(
    model="glm-4.7",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"}
    ]
)

print(completion.choices[0].message.content)
```

### Controlling Thinking Mode

GLM-4.7 has **thinking enabled by default**, which adds chain-of-thought reasoning
to responses. This significantly increases token usage (255+ reasoning tokens vs ~20
content tokens).

**To disable thinking and get faster, cheaper responses:**

```python
payload = {
    "model": "glm-4.7",
    "messages": [...],
    "thinking": {
        "type": "disabled"
    }
}
```

**Impact of disabling thinking:**
- **Token usage**: ~6x reduction (49 total vs 294 total in testing)
- **Cost**: ~6x cheaper
- **Speed**: Significantly faster
- **Response quality**: Slightly less reasoning for complex tasks

**Example with thinking disabled:**

```python
import requests

API_KEY = "your-zai-api-key"
BASE_URL = "https://api.z.ai/api/coding/paas/v4/chat/completions"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

payload = {
    "model": "glm-4.7",
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is 2+2?"}
    ],
    "thinking": {"type": "disabled"}  # Disable for fast response
}

response = requests.post(BASE_URL, headers=headers, json=payload)
result = response.json()

# Check reasoning tokens
print(f"Reasoning tokens: {result['usage']['completion_tokens_details']['reasoning_tokens']}")
# Output: Reasoning tokens: 0
```

**When to use each mode:**
- **Enable thinking** (default): Complex reasoning, multi-step problems, debugging, planning
- **Disable thinking**: Simple queries, fact retrieval, formatting, cost-sensitive apps

## Verification

1. Successful API call returns JSON with `choices[0].message.content`
2. No "Unknown Model" error
3. Response contains generated text in expected format

## Notes

### Endpoint Distinction

- **`/api/paas/v4`**: General purpose endpoint (documented in official docs)
- **`/api/coding/paas/v4`**: Coding-optimized endpoint (used in practice for code generation)

The coding endpoint may provide better performance for programming-related tasks.

### Model Variants

- `glm-4.7`: Main flagship model
- `glm-4.7-flash`: Faster, free coding variant (if available)

### OpenAI Compatibility

Z.AI provides full OpenAI-compatible API:
- Uses standard `chat/completions` endpoint format
- Supports streaming via `stream: true`
- Compatible with OpenAI SDKs by setting `base_url`

### Common Mistakes

1. ❌ Wrong model: `glm-4.7` not `zai-glm-4.7` or other variants
2. ❌ Wrong endpoint: `/api/paas/v4` not `/v1` like OpenAI
3. ❌ Missing `/chat/completions` path after base URL
4. ❌ Using `https://open.bigmodel.cn/` (old endpoint)
5. ❌ Not disabling thinking for simple queries (wastes 6x tokens)

### Thinking Mode Behavior

- **Default**: Enabled - provides reasoning traces but increases token usage
- **Reasoning tokens**: Typically 200-255 tokens per response
- **Content tokens**: Usually 20-30 tokens for simple responses
- **Recommendation**: Disable for simple queries, enable for complex tasks

## References

- [Z.AI API Reference - Introduction](https://docs.z.ai/api-reference/introduction)
- [GLM-4.7 Model Overview](https://docs.z.ai/guides/llm/glm-4.7)
- [Z.AI Quick Start Guide](https://docs.z.ai/guides/overview/quick-start)
- [Thinking Mode Documentation](https://docs.z.ai/guides/capabilities/thinking-mode)
