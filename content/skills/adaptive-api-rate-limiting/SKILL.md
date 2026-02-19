---
name: adaptive-api-rate-limiting
description: |
  Implement adaptive concurrency control for API rate limiting. Use when: (1) Getting
  429 "Too Many Requests" errors, (2) Multiple processes share same API key, (3) Fixed
  concurrency causes failures, (4) Need graceful degradation under rate limits. Implements
  automatic worker reduction (5→4→3→2→1), exponential backoff, and recovery without
  manual intervention. Covers Node.js/JavaScript implementation patterns.
author: Claude Code
version: 1.0.0
date: 2026-01-23
---

# Adaptive API Rate Limiting with Concurrency Control

## Problem
Fixed concurrency (e.g., 5 parallel workers) fails when API rate limits are hit,
causing all workers to fail with 429 errors. Simple retry with exponential backoff
isn't enough when the root cause is too much concurrent load.

**Typical failure:**
```
Worker 1: ❌ 429 Rate limit
Worker 2: ❌ 429 Rate limit
Worker 3: ❌ 429 Rate limit
Worker 4: ❌ 429 Rate limit
Worker 5: ❌ 429 Rate limit
→ Entire batch fails
```

## Context / Trigger Conditions

**When to use this pattern:**

1. **HTTP 429 Errors**: API returns `429 Too Many Requests`
2. **Shared API Key**: Multiple processes/scripts using same API key
3. **External Usage**: Other services using your API capacity
4. **Unpredictable Limits**: Rate limits vary by time/system load
5. **Long-Running Jobs**: Need to complete over hours without manual intervention

**Error messages that indicate this problem:**
- `API Error (429): {"error":{"code":"1302","message":"High concurrency usage"}}`
- `429: Too Many Requests`
- `RateLimitError: Rate limit exceeded`

## Solution

### Core Pattern: Adaptive Concurrency + Exponential Backoff

Instead of fixed concurrency that fails completely, dynamically reduce worker count
when rate limits are detected.

```javascript
// Rate limit state tracking
let rateLimitState = {
  currentConcurrency: 5,        // Start with optimal
  recent429Errors: [],           // Timestamps of recent 429s (sliding window)
  consecutive429s: 0,            // Back-to-back failures
  total429s: 0,                 // Lifetime error count
  last429Time: 0                // Last error timestamp
};

// Configuration
const config = {
  max429Errors: 5,              // Trigger reduction after this many in 60s
  cooldownPeriod: 60000,        // Wait 60s before considering increase
  reductionStep: 1,             // Reduce workers by this amount
  minConcurrency: 1,            // Never go below 1 worker
  backoffMultiplier: 2,         // Exponential backoff: 2s → 4s → 8s
  initialConcurrency: 5         // Starting worker count
};
```

### Implementation: 4 Steps

#### Step 1: Detect Rate Limits

```javascript
async function callAPI(systemPrompt, userPrompt, retryCount = 0) {
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(requestData)
  });

  if (!response.ok) {
    const error = await response.text();

    // Check for rate limit
    if (response.status === 429) {
      return handleRateLimit(systemPrompt, userPrompt, retryCount, error);
    }

    throw new Error(`API Error (${response.status}): ${error}`);
  }

  const data = await response.json();

  // Reset consecutive counter on success
  rateLimitState.consecutive429s = 0;

  return data;
}
```

#### Step 2: Track Rate Limits

```javascript
function handleRateLimit(systemPrompt, userPrompt, retryCount, originalError) {
  const now = Date.now();
  rateLimitState.total429s++;
  rateLimitState.consecutive429s++;
  rateLimitState.last429Time = now;

  // Sliding window: keep only last 60 seconds
  rateLimitState.recent429Errors = rateLimitState.recent429Errors.filter(
    t => now - t < 60000
  );
  rateLimitState.recent429Errors.push(now);

  console.error(`⚠️  Rate limit detected (429)!`);
  console.error(`   Recent 429s: ${rateLimitState.recent429Errors.length}`);
  console.error(`   Consecutive: ${rateLimitState.consecutive429s}`);
  console.error(`   Current concurrency: ${rateLimitState.currentConcurrency}`);

  // Check if should reduce concurrency
  if (rateLimitState.recent429Errors.length >= config.max429Errors) {
    return reduceConcurrencyAndRetry(systemPrompt, userPrompt, retryCount);
  }

  // Otherwise just exponential backoff
  return exponentialBackoff(systemPrompt, userPrompt, retryCount);
}
```

#### Step 3: Reduce Concurrency

```javascript
async function reduceConcurrencyAndRetry(systemPrompt, userPrompt, retryCount) {
  const oldConcurrency = rateLimitState.currentConcurrency;
  const newConcurrency = Math.max(
    config.minConcurrency,
    oldConcurrency - config.reductionStep
  );

  if (newConcurrency < oldConcurrency) {
    console.error(`\n╔══════════════════════════════════════════════════════════════╗`);
    console.error(`║  🧠 ADAPTIVE CONCURRENCY REDUCTION                          ║`);
    console.error(`╚══════════════════════════════════════════════════════════════╝`);
    console.error(`\n📉 Reducing concurrency: ${oldConcurrency} → ${newConcurrency}`);
    console.error(`💡 Reason: ${rateLimitState.recent429Errors.length} rate limits in 60s`);
    console.error(`⏱️  Cooldown: ${config.cooldownPeriod / 1000}s before considering increase\n`);

    rateLimitState.currentConcurrency = newConcurrency;
    rateLimitState.recent429Errors = []; // Reset after reduction
    rateLimitState.consecutive429s = 0;
  }

  // Wait before retry
  const backoffDelay = config.retryDelay * Math.pow(config.backoffMultiplier, retryCount);
  console.error(`⏳ Waiting ${backoffDelay}ms before retry...`);
  await sleep(backoffDelay);

  return callAPI(systemPrompt, userPrompt, retryCount);
}
```

#### Step 4: Exponential Backoff

```javascript
async function exponentialBackoff(systemPrompt, userPrompt, retryCount) {
  const backoffDelay = config.retryDelay * Math.pow(config.backoffMultiplier, retryCount);

  console.error(`⏳ Backing off ${backoffDelay}ms before retry...`);

  if (retryCount < config.maxRetries) {
    await sleep(backoffDelay);
    return callAPI(systemPrompt, userPrompt, retryCount + 1);
  }

  throw new Error(`Rate limit exceeded after ${retryCount + 1} retries`);
}
```

### Complete Pattern: Batch Processing with Adaptive Workers

```javascript
// Generate in adaptive batches
let topicIndex = 0;
let batchNumber = 1;

while (topicIndex < selectedTopics.length) {
  const currentConcurrency = rateLimitState.currentConcurrency;
  const topicsPerWorker = Math.ceil(
    (selectedTopics.length - topicIndex) / currentConcurrency
  );
  const batchSize = Math.min(
    topicsPerWorker * currentConcurrency,
    selectedTopics.length - topicIndex
  );

  console.log(`\n📦 Batch ${batchNumber}: ${batchSize} topics with ${currentConcurrency} workers`);

  // Split topics among workers
  const workers = [];
  const batchStart = topicIndex;

  for (let i = 0; i < currentConcurrency; i++) {
    const start = batchStart + i * topicsPerWorker;
    const end = Math.min(start + topicsPerWorker, batchStart + batchSize);
    const workerTopics = selectedTopics.slice(start, end);

    if (workerTopics.length > 0) {
      workers.push(worker(workerTopics, results, errors, i + 1));
    }
  }

  // Run this batch
  await Promise.all(workers);

  topicIndex += batchSize;
  batchNumber++;

  // Cooldown between batches
  if (topicIndex < selectedTopics.length) {
    await sleep(2000);
  }
}
```

## Verification

### Expected Behavior

**When rate limits hit:**
```
✅ [1] Completed in 65000ms
⚠️  Rate limit detected (429)!
   Recent 429s: 1
   Current concurrency: 5
✅ [2] Completed in 68000ms
⚠️  Rate limit detected (429)!
   Recent 429s: 2
   Current concurrency: 5
... (5th 429 within 60s)
╔══════════════════════════════════════════════════════════════╗
║  🧠 ADAPTIVE CONCURRENCY REDUCTION                          ║
╚══════════════════════════════════════════════════════════════╝
📉 Reducing concurrency: 5 → 4
💡 Reason: 5 rate limits in 60s
⏳ Waiting 4000ms before retry...
✅ [3] Completed in 72000ms  (continues with 4 workers)
```

**Final Statistics:**
```
🧠 Rate Limit Stats:
  Total 429s: 23
  Final Concurrency: 3
  Adaptive Adjustments: 2 reduction(s)
```

### Health Check

Verify adaptation is working:
1. Run with 5 workers initially
2. Monitor for 429 errors
3. Confirm concurrency reduces automatically
4. Verify generation continues (doesn't fail completely)
5. Check final statistics show reductions

## Example

### Scenario: Wikipedia Dataset Generation

**Problem:**
- Generating 500 Wikipedia articles with 5 workers
- After 50 samples, getting 429 errors
- Your colleague is also using same API key for another task

**Old Behavior (Fixed Concurrency):**
```
Worker 1: ❌ 429 → Retry ❌ 429 → Retry ❌ 429 → FAIL
Worker 2: ❌ 429 → Retry ❌ 429 → Retry ❌ 429 → FAIL
Worker 3: ❌ 429 → Retry ❌ 429 → Retry ❌ 429 → FAIL
Worker 4: ❌ 429 → Retry ❌ 429 → Retry ❌ 429 → FAIL
Worker 5: ❌ 429 → Retry ❌ 429 → Retry ❌ 429 → FAIL
→ Complete failure, lost time
```

**New Behavior (Adaptive Concurrency):**
```
Workers 1-5: Running...
After 5 × 429 in 60s:
  📉 Reducing concurrency: 5 → 4

Workers 1-4: Running...
(continues generating, just slower)
If rate limits continue:
  📉 Reducing concurrency: 4 → 3
  📉 Reducing concurrency: 3 → 2
  📉 Reducing concurrency: 2 → 1

Worker 1: Running... (slowest but reliable)
✅ All 500 samples completed eventually
```

## Notes

### Why This Works

**Traditional approach fails:**
- Fixed concurrency assumes constant API capacity
- Doesn't account for shared usage or time-varying limits
- All-or-nothing: either works perfectly or fails completely

**Adaptive approach succeeds:**
- Reduces load when API signals it's overloaded
- Finds sustainable concurrency level automatically
- Completes work eventually vs failing completely
- Self-tuning based on real-time conditions

### Key Design Decisions

1. **Sliding Window (60s)**: Better than total count, detects sustained issues
2. **Reduction Step (1)**: Gradual reduction vs drastic (5→1)
3. **Minimum Concurrency (1)**: Always process something, never stall
4. **Reset After Reduction**: Clean slate after adapting
5. **Exponential Backoff**: Standard pattern for retries
6. **Clear Logging**: Users see what's happening and why

### Threshold Tuning

Adjust based on your API:

```javascript
// Aggressive (reduce quickly)
max429Errors: 3

// Conservative (reduce slowly)
max429Errors: 10

// Balanced (recommended)
max429Errors: 5
```

### Monitoring

Add to your code:

```javascript
// After completion, show stats
console.log(`
🧠 Rate Limit Stats:
  Total 429s: ${rateLimitState.total429s}
  Final Concurrency: ${rateLimitState.currentConcurrency}
  Adaptive Adjustments: ${initialConcurrency - rateLimitState.currentConcurrency}
`);
```

### Integration Patterns

**With Queue Systems:**
```javascript
// Instead of workers, use queue processor
queue.process(rateLimitState.currentConcurrency, async (task) => {
  // Adaptive processing with same pattern
});
```

**With Promise Pools:**
```javascript
// Limit concurrent promises based on rateLimitState.currentConcurrency
const pool = new PromisePool({
  concurrency: rateLimitState.currentConcurrency
});
```

### Advanced: Circuit Breaker Pattern

For more complex scenarios, combine with circuit breaker:

```javascript
let circuitState = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN

if (rateLimitState.consecutive429s > 10) {
  circuitState = 'OPEN'; // Stop all requests
  setTimeout(() => circuitState = 'HALF_OPEN', 60000);
}

if (circuitState === 'OPEN') {
  throw new Error('Circuit breaker is OPEN - backing off');
}
```

## References

### Official Documentation
- [Envoy Proxy - Adaptive Concurrency](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/adaptive_concurrency_filter) - Service mesh adaptive concurrency patterns
- [AWS API Gateway - Request Throttling](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html) - AWS throttling strategies
- [Microsoft Circuit Breaker Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker) - Resilience patterns

### Best Practices Articles (2025-2026)
- [10 Best Practices for API Rate Limiting in 2025](https://zuplo.com/learning-center/10-best-practices-for-api-rate-limiting-in-2025) - Comprehensive modern guide
- [API Rate Limiting at Scale: Patterns, Failures, and Control](https://www.gravitee.io/blog/rate-limiting-apis-scale-patterns-strategies) - Production patterns from Gravitee
- [The Rapidly Changing Landscape of APIs in 2026](https://konghq.com/blog/engineering/a-rapidly-changing-landscape) - AI-driven API calls requiring new patterns
- [API Governance Best Practices for 2026](https://treblle.com/blog/api-governance-best-practices) - Current standards

### Implementation Guides
- [How to Handle LinkedIn API Rate Limits](https://www.liseller.com/linkedin-growth-blog/how-to-handle-linkedin-api-rate-limits) - Practical strategies
- [How To Implement API Rate Limiting and Avoid 429](https://www.geoapify.com/how-to-avoid-429-too-many-requests-with-api-rate-limiting/) - Implementation guide
- [How to handle API rate limits and HTTP 429 errors](https://dev.to/robertobutti/how-to-handle-api-rate-limits-and-http-429-errors-in-an-easy-and-reliable-way-14e6) - Client-side patterns

### Academic Research
- [Rethinking HTTP API Rate Limiting: A Client-Side Approach](https://arxiv.org/html/2510.04516v3) - Recent research on client-side strategies
- [API Rate Limit Adoption - A Pattern Collection](https://www.researchgate.net/publication/377466057_API_Rate_Limit_Adoption_-A_pattern_collection) - Pattern analysis

### Community Resources
- [Vector - Adaptive Request Concurrency](https://vector.dev/blog/adaptive-request-concurrency/) - Real-world implementation
- [Netflix Tech Blog - Performance Under Load](https://netflixtechblog.medium.com/performance-under-load-3e6fa9a60581) - Netflix's approach to adaptive limits

## Common Pitfalls

❌ **Don't use fixed retry delay alone**: Simple `setTimeout(2000)` doesn't adapt
❌ **Don't retry immediately**: Will just hit rate limit again
❌ **Don't ignore 429s**: They won't go away by themselves
❌ **Don't reduce to 0 workers**: Minimum should be 1 (slow progress > no progress)
❌ **Don't reset counters too early**: Need sustained improvement before increasing back

✅ **Track temporal patterns**: Sliding window better than total count
✅ **Reduce gradually**: Step down (5→4→3) not jump (5→1)
✅ **Provide visibility**: Log what's happening and why
✅ **Reset after adaptation**: Clean slate after reducing concurrency
✅ **Combine with exponential backoff**: Both strategies together
