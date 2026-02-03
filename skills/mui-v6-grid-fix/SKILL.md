---
name: mui-v6-grid-type-error-fix
description: |
  Fix for "Property 'item' does not exist" and "No overload matches this call"
  TypeScript errors when using Material UI v6 Grid component. Use when: (1)
  migrating from MUI v5 to v6, (2) Grid item prop causes type errors in
  TypeScript, (3) MUI Grid container/item pattern fails compilation. The
  fix replaces MUI Grid with native CSS Grid via Box component.
author: Claude Code
version: 1.0.0
date: 2026-01-21
---

# MUI v6 Grid Type Error Fix

## Problem

Material UI v6 introduced breaking changes to the Grid component API. The familiar
MUI v5 pattern of using `<Grid item xs={12}>` no longer works and causes TypeScript
errors:

```
error TS2769: No overload matches this call.
error TS2339: Property 'item' does not exist on type...
error TS2724: Property 'component' is missing...
```

These errors occur because MUI v6 changed the Grid component significantly, but the
error messages don't clearly indicate the root cause (API change, not usage error).

## Context / Trigger Conditions

- Using Material UI v6 with TypeScript
- Code uses `<Grid container>` and `<Grid item>` pattern from MUI v5
- TypeScript errors mentioning missing `item` or `component` properties
- Recently upgraded from MUI v5 to v6
- Following MUI v5 documentation or tutorials

## Solution

Replace MUI Grid entirely with native CSS Grid using MUI's Box component. This is
actually simpler and more maintainable:

**Before (MUI v5 style - broken in v6):**
```tsx
<Grid container spacing={2}>
  <Grid item xs={12} sm={4}>
    <Button>Action 1</Button>
  </Grid>
  <Grid item xs={12} sm={4}>
    <Button>Action 2</Button>
  </Grid>
  <Grid item xs={12} sm={4}>
    <Button>Action 3</Button>
  </Grid>
</Grid>
```

**After (MUI v6 compatible):**
```tsx
<Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr 1fr' }, gap: 2 }}>
  <Button>Action 1</Button>
  <Button>Action 2</Button>
  <Button>Action 3</Button>
</Box>
```

**Common Grid Patterns:**

| Layout | MUI v5 (broken) | MUI v6 compatible |
|--------|-----------------|-------------------|
| 3 columns | `item xs={12} sm={4}` | `gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr 1fr' }` |
| 2 columns | `item xs={12} sm={6}` | `gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }` |
| Fixed width | `item xs={3}` | `gridTemplateColumns: '3fr 1fr'` |

## Verification

After replacing Grid with Box:
1. TypeScript compilation succeeds
2. Layout renders correctly at all breakpoints
3. No console errors during runtime
4. Responsive behavior works as expected

## Example

**TTSTab Quick Actions Row (from actual fix):**

```tsx
// ❌ Before: TypeScript errors
<Grid container spacing={2} sx={{ mt: 2 }}>
  <Grid item xs={12} sm={4}>
    <Button fullWidth variant="outlined">Load to VC</Button>
  </Grid>
  <Grid item xs={12} sm={4}>
    <Button fullWidth variant="outlined">Copy Text</Button>
  </Grid>
  <Grid item xs={12} sm={4}>
    <Button fullWidth variant="outlined" color="error">Delete</Button>
  </Grid>
</Grid>

// ✅ After: Works perfectly
<Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr 1fr' }, gap: 2, mt: 2 }}>
  <Button fullWidth variant="outlined">Load to VC</Button>
  <Button fullWidth variant="outlined">Copy Text</Button>
  <Button fullWidth variant="outlined" color="error">Delete</Button>
</Box>
```

## Notes

**Why native CSS Grid is better:**
- No dependency on MUI's Grid API which keeps changing
- More flexible and powerful than MUI's abstraction
- Better TypeScript support (native CSS properties)
- Smaller bundle size (fewer MUI components)
- Easier to understand for developers familiar with CSS Grid

**MUI v6 Grid Migration Options:**

1. **Recommended**: Replace with native CSS Grid (this skill)
2. **Alternative**: Use `@mui/material/Unstable_Grid2` (note the "Unstable" in the name)
3. **Not recommended**: Downgrade to MUI v5

**Breakpoint equivalents:**
- `xs` (mobile first): Default in `gridTemplateColumns`
- `sm`: Tablet portrait (`sm:` in sx prop)
- `md`: Desktop (`md:` in sx prop)
- `lg`: Large desktop (`lg:` in sx prop)

**Related MUI v6 changes:**
- Theme provider syntax changed
- Some component prop types were tightened
- `styled()` API has different requirements

## References

- [Material UI v5 to v6 Migration Guide](https://mui.com/material-ui/migration/migration-v5/)
- [MUI System - Grid (v6)](https://mui.com/system/grid/)
- [CSS Grid Layout - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Grid_Layout)
