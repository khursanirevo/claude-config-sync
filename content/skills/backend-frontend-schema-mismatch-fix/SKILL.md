---
name: backend-frontend-schema-mismatch-empty-ui
description: |
  Fix for React components displaying empty content when backend API doesn't
  return expected fields. Use when: (1) UI renders but shows no data, (2)
  Array.filter() returns empty results unexpectedly, (3) Backend API returns
  objects missing fields defined in TypeScript interface, (4) No console errors
  but lists/tables are empty. The fix adds default values in API transformation
  layer for missing backend fields.
author: Claude Code
version: 1.0.0
date: 2026-01-21
---

# Backend-Frontend Schema Mismatch Empty UI Fix

## Problem

React components that filter or map over API data display empty content when the
backend doesn't return all expected fields. Unlike typical API errors, this issue
produces **no console errors**—the UI simply renders without content.

**Example symptom:**
```
Frontend expects: [{ id: '1', name: 'John', tier: 'Gold' }]
Backend returns:  [{ id: '1', name: 'John' }]
Filter code:      speakers.filter(s => s.tier === 'Gold') // Returns: []
Result:           Empty UI, no errors
```

## Context / Trigger Conditions

- React component shows empty list/table despite successful API call (200 OK)
- Array.filter() or conditional rendering produces empty results
- TypeScript interface defines required fields that backend doesn't return
- No console errors or TypeScript compilation errors
- Data appears in browser DevTools Network tab but is missing fields
- Using TanStack Query, Axios, or fetch with TypeScript interfaces

**Common scenarios:**
- Backend added/removed fields without updating frontend
- Different API versions (v1 vs v2) returning different schemas
- Legacy API that doesn't match newer TypeScript types
- Optional fields treated as required in filtering logic

## Solution

Add a **transformation layer** in your API client to provide default values for
missing fields. This ensures frontend code always has expected data structure.

**Location:** API layer (client.ts, api.ts, or in the queryFn)

### Pattern 1: Map with Defaults (Recommended)

```typescript
// In your API function or queryFn
export const getSpeakers = async (): Promise<Speaker[]> => {
  const response = await apiClient.get<Speaker[]>('/speakers');

  // Transform: Add defaults for missing fields
  return response.data.map((speaker: any) => ({
    ...speaker,
    tier: speaker.tier || 'Silver',  // Default if missing
    isTemporary: speaker.isTemporary || false,
    avatar: speaker.avatar || null,   // Explicit null default
  }));
};
```

### Pattern 2: Type Guard with Defaults

```typescript
function ensureSpeakerComplete(data: any): Speaker {
  return {
    id: data.id,
    name: data.name,
    tier: data.tier ?? 'Silver',      // Nullish coalescing
    isTemporary: data.isTemporary ?? false,
    avatar: data.avatar ?? undefined,
  };
}

// Usage
export const getSpeakers = async (): Promise<Speaker[]> => {
  const response = await apiClient.get<any[]>('/speakers');
  return response.data.map(ensureSpeakerComplete);
};
```

### Pattern 3: Zod Schema Validation (Best Practice)

```typescript
import { z } from 'zod';

// Define schema with defaults
const SpeakerSchema = z.object({
  id: z.string(),
  name: z.string(),
  tier: z.enum(['Gold', 'Silver', 'Temporary']).default('Silver'),
  isTemporary: z.boolean().default(false),
  avatar: z.string().nullable().optional(),
});

type Speaker = z.infer<typeof SpeakerSchema>;

// Parse and apply defaults
export const getSpeakers = async (): Promise<Speaker[]> => {
  const response = await apiClient.get<any[]>('/speakers');
  return response.data.map(item => SpeakerSchema.parse(item));
};
```

## Verification

1. **Check Network tab**: Confirm backend is missing expected fields
2. **Add logging**: Log the API response before filtering
   ```typescript
   console.log('Speakers from API:', response.data);
   console.log('Filtered speakers:', speakers.filter(s => s.tier === 'Gold'));
   ```
3. **Verify defaults**: Check that transformed data has default values
4. **UI renders**: Component now displays items with default values

## Example

**Before (Broken):**
```typescript
// API returns: [{id: '1', name: 'John'}]
// TypeScript expects: {id: string, name: string, tier: string}

const goldSpeakers = speakers.filter((s) => s.tier === 'Gold');
// Result: [] (empty array because s.tier is undefined)
// UI: Empty sidebar, no error
```

**After (Fixed):**
```typescript
// In API layer
return response.data.map((speaker: any) => ({
  ...speaker,
  tier: speaker.tier || 'Silver', // Add default
}));

// Now speakers are: [{id: '1', name: 'John', tier: 'Silver'}]
const goldSpeakers = speakers.filter((s) => s.tier === 'Gold');
// Result: Still empty for Gold, but Silver speakers show up
// All speakers now visible in UI under Silver section
```

**Real-world fix from session:**
```typescript
// File: src/api/speakers.ts
export const getAvailableSpeakers = async (): Promise<Speaker[]> => {
  const response = await apiClient.get<GetSpeakersResponse>('/speakers');

  // Backend doesn't return tier field - add default
  return response.data.speakers.map((speaker: any) => ({
    ...speaker,
    tier: speaker.tier || 'Silver',
    isTemporary: speaker.isTemporary || false,
  }));
};
```

## Notes

**Why this happens:**
- TypeScript types are compile-time only, not runtime enforced
- `any` types in API transformations bypass type checking
- Backend and frontend contracts drift over time
- Optional fields in backend become required in frontend logic

**Prevention strategies:**
1. **Use Zod or similar**: Runtime validation ensures data matches types
2. **Shared types**: Use OpenAPI/Swagger to generate types from backend spec
3. **API contracts**: Regular audits of frontend vs backend schemas
4. **Defensive coding**: Always provide defaults for filter/sort operations

**Alternative approaches:**
- Fix backend to return all fields (ideal but not always possible)
- Make TypeScript fields optional (breaks filtering logic)
- Use GraphQL (explicit field selection prevents mismatches)

**Related issues:**
- `Cannot read property 'X' of undefined` when accessing missing fields
- Map/filter functions skipping items with undefined values
- Sort functions failing when comparing undefined values

## References

- [Zod Validation](https://zod.dev/) - Runtime type validation library
- [TanStack Query Data Transformation](https://tanstack.com/query/latest/docs/framework/react/guides/data-transformations)
- [TypeScript: Interfaces vs Types](https://www.typescriptlang.org/docs/handbook/2/types-from-types.html)
