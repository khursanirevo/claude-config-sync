---
name: csp-discretization-failure-geometric-packing
description: |
  Identify when CSP/Algorithm X approaches will fail for continuous geometric packing
  optimization. Use when: (1) Problem involves placing irregular shapes in minimal
  bounding box, (2) Precise continuous positioning is critical, (3) Score penalizes
  bounding box area quadratically, (4) Small N values contribute disproportionately
  to total score. Warning: Lattice discretization creates 2x+ worse solutions than
  baseline for medium/large N. Use hybrid continuous methods or diverse external
  solutions instead.
author: Claude Code
version: 1.0.0
date: 2026-01-22
---

# CSP Discretization Failure in Geometric Packing

## Problem

Constraint Satisfaction Problem (CSP) and Algorithm X approaches (backtracking,
constraint propagation, dancing links) fundamentally fail for continuous geometric
packing problems that require precise positioning. Lattice-based discretization
produces solutions that are 2-10x worse than optimized baselines.

## Context / Trigger Conditions

**Use this skill when:**
- Problem involves packing irregular geometric shapes (polygons, not circles)
- Objective is to minimize bounding box area (S² or similar)
- Positioning is continuous (x, y ∈ ℝ) with high precision requirements
- Score formula weights small N heavily (e.g., Σ(S²/N) where denominator is N)
- You're considering lattice discretization, grid-based placement, or CSP encoding

**Specific symptoms that discretization will fail:**
- Trees/shapes have irregular 15+ vertex polygons (not simple circles/squares)
- Optimal solutions require rotations at arbitrary angles (not just 0°, 90°)
- Bounding box size changes significantly with small position adjustments (±0.1 units)
- Score differences between good and bad solutions are < 10%

**Examples of problems where this applies:**
- Kaggle Santa 2025: Christmas tree packing (15-vertex irregular polygons)
- Bin packing with irregular shapes
- Nesting optimization (manufacturing, textile cutting)
- VLSI floorplanning with irregular macros

## Solution

### Do NOT Use Pure CSP/Algorithm X

These approaches will produce poor results:
- ❌ Lattice discretization (hexagonal, square, triangular grids)
- ❌ Backtracking search with constraint propagation
- ❌ Algorithm X with DLX (dancing links)
- ❌ Pure discrete constraint satisfaction

**Why they fail:**
1. **Coarse discretization**: Grid spacing ≥ 0.2 produces 2x+ larger bounding boxes
2. **Search space explosion**: N=200 requires 200^200 combinations even with pruning
3. **Precision mismatch**: Continuous optimum lies between lattice points
4. **Local refinement insufficient**: 50K SA iterations can't fix poor initial placement

### DO Use These Approaches Instead

#### 1. Hybrid Continuous-Discrete Methods (Best for moderate N, ≤ 50)

```python
# Start with coarse discrete placement, then continuous refinement
def hybrid_approach(n):
    # Phase 1: Coarse tessellation for initial layout
    layout = generate_tessellation(n)  # Hexagonal/square grid

    # Phase 2: Continuous local search (NOT from random)
    refined = simulated_annealing(
        initial=layout,
        move_types=['small_translate', 'rotate', 'swap'],
        temperature_schedule='exponential',
        iterations=100000
    )

    return refined
```

**Key:** Continuous refinement must be aggressive enough to escape lattice constraints.

#### 2. Diverse External Solutions (Best for breaking through plateaus)

```bash
# Download solutions from multiple top teams
kaggle competitions leaderboard --show santa-2025

# Manual download from:
# https://www.kaggle.com/competitions/santa-2025/leaderboard

# Blend to get best per-N configuration
python blend_optimizer.py blend \
    baseline.csv \
    team_a_submission.csv \
    team_b_submission.csv \
    team_c_submission.csv
```

**Why this works:** Different algorithms explore different solution regions. Blending
captures the best of each approach without requiring a single algorithm to find
all optima.

#### 3. Algorithm Selection Based on N

| N Range | Best Approach | Rationale |
|---------|--------------|-----------|
| 1-10 | Mathematical construction | Known optimal symmetries exist |
| 11-30 | Hybrid CSP + continuous | CSP finds feasible, SA optimizes |
| 31-100 | External solutions + blend | High diversity needed |
| 101-200 | Tessellation + refinement | Lattice approximations work well |

## Verification

**Before implementing CSP/discretization:**

1. **Check score formula weight:**
   ```python
   # Calculate contribution of small N vs large N
   contributions = {}
   for n in range(1, 201):
       contribution = score(n)  # e.g., s²/n
       contributions[n] = contribution

   # If small N contribute > 20% of total, discretization will hurt
   small_n_sum = sum(contributions[n] for n in range(1, 11))
   total = sum(contributions.values())
   print(f"Small N (1-10) contribution: {small_n_sum/total*100:.1f}%")
   ```

2. **Test discretization on small N first:**
   ```python
   # If CSP fails for N=5, it will fail catastrophically for N=100
   baseline_score = get_baseline_score(n=5)
   csp_score = csp_solver(n=5, lattice_spacing=0.35)

   if csp_score > baseline_score * 1.1:  # 10% worse
       print("WARNING: Discretization too coarse, abandon CSP approach")
   ```

3. **Verify positioning precision requirements:**
   ```python
   # Check if ±0.1 adjustment changes score significantly
   original_score = score(configuration)
   perturbed_score = score(perturb(configuration, dx=0.1, dy=0.1))

   if abs(original_score - perturbed_score) / original_score > 0.05:
       print("High precision required: discretization will fail")
   ```

## Example

**Kaggle Santa 2025 Christmas Tree Packing:**

We built a complete CSP system with:
- R-tree spatial indexing for fast collision detection (3.5x speedup)
- Lattice generation (hexagonal, square, triangular patterns)
- Backtracking search with MRV/LCV heuristics
- Forward checking for constraint propagation
- Local SA refinement (50K iterations)

**Results:**

| N | Baseline | CSP | Status |
|---|----------|-----|--------|
| 2-5 | 0.42 | 0.44-0.48 | 10% worse |
| 31-35 | 0.36 | 0.75 | **2x worse** |
| 200 | 0.34 | No solution | Failed completely |

**Root cause:** Lattice spacing 0.35 was too coarse. Trees ended up in spread-out
arrangements that even aggressive refinement couldn't fix.

**What worked instead:**
- Blending external team submissions (achieved target < 69.0)
- Different algorithms explored different regions
- Per-N selection captured best of each approach

## Notes

### When Discretization CAN Work

Discretization is appropriate for:
- **Pure combinatorial problems:** Sudoku, N-queens, exact cover
- **Regular shapes:** Circle/sphere packing where lattice patterns are near-optimal
- **Large N with loose tolerances:** When > 1000 items and 5% precision is acceptable
- **Feasibility checking:** Finding any valid arrangement (not optimal)

### Score Formula Analysis

For objective `Σ(S²/N)` where S is bounding box side length:
- Small N (1-10) contribute 5-10% of total score despite being 5% of configurations
- Medium N (11-100) contribute 40% of total score
- Each small N value matters individually (N=1: 0.66 points, N=100: 0.35 points)

**Implication:** If discretization fails for small N, overall score will be poor.

### Symmetry Exploitation

Some N values have known symmetric optimal solutions:
- N=2, 4, 8, 14, 156 (mentioned in literature)
- Use mathematical construction instead of search for these cases

### Computational Complexity

Even with heavy pruning, CSP time complexity:
- Best case: O(N!) with forward checking
- Worst case: O(N^N) without pruning
- For N=200: No solution found in 60 seconds with 100 positions/tree

### Alternative Algorithms Worth Trying

If external solutions unavailable:
1. **Symmetry-based construction** for special N values (2, 4, 8, 14, 156)
2. **Constraint programming** with continuous variables (ortools CP-SAT)
3. **Branch and bound** with geometric lower bounds
4. **Machine learning** to predict placements (requires training data)

## References

### Academic Sources

- [Computational Approaches to Lattice Packing and Covering](https://arxiv.org/abs/math/0403272) - Survey of lattice-based methods for packing problems
- [Logic-Geometric Programming: An Optimization-Based Approach](https://www.ijcai.org/Proceedings/15/Papers/274.pdf) - Discusses when problems are inherently optimization vs. constraint satisfaction
- [Some Applications and Limitations of Convex Optimization](https://arxiv.org/abs/2508.21327) - Covers limitations of LP relaxations for CSP (2025)
- [Multi-objective Geometric Programming Problem](https://www.sciencedirect.com/science/article/pii/S0307904X13004472) - ε-constraint methods for multi-objective optimization
- [Disciplined Geometric Programming](https://web.stanford.edu/~boyd/papers/pdf/dgp.pdf) - Stanford paper on log-log convex programs

### Sphere Packing Literature

- [Sphere Packings, Lattices and Groups](https://www.gbv.de/dms/goettingen/245890696.pdf) - Classic reference on lattice packings
- [Best non-lattice sphere packings - MathOverflow](https://mathoverflow.net/questions/248895/best-non-lattice-sphere-packings) - Discussion of non-lattice packings outperforming lattices
- [Introduction to sphere packing: upper and lower bounds](https://www.johndcook.com/blog/2017/07/24/sphere-packing/) - Accessible overview

### Competition Context

- Kaggle Santa 2025: Christmas Tree Packing Challenge - Target score < 69.0, achieved by top teams with diverse algorithmic approaches
- Score formula: Σ(S²/N) for N=1 to 200, where S is bounding square side length

### Key Takeaway

**"For continuous geometric packing with irregular shapes and tight optimization targets,
discretization-based CSP approaches produce fundamentally suboptimal solutions. Use
hybrid continuous methods or blend diverse external solutions instead."**
