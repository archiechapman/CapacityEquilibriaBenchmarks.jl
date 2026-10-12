# API reference

```@meta
CurrentModule = CapacityEquilibriaBenchmarks
```

The functions the tutorial uses, grouped roughly in the order it introduces them. Several
functions come in two forms, one taking an `MSData` and one taking the parameters as plain
numbers: the `_arrays` functions, `ms_regime`, `ms_regime_jacobian`, `ms_closed_loop_xi`
and `ms_long_run_objective`. The plain-numbers form is the code spliced verbatim into the
standalone files, and the `MSData` form is a wrapper that adds nothing but unpacking.

```@docs
CapacityEquilibriaBenchmarks
```

## Instances

```@docs
MSData
load_ms_instance
check_assumptions
peak_segments
load_ms_expected
```

## The open-loop models

```@docs
ms_lcp
ms_lcp_arrays
ms_conditions
MSIndex
MSPoint
ms_pack
```

## The paper's stated properties

```@docs
investment_criterion_gap
pricing_efficiency_gap
production_efficiency_holds
segment_type
```

## The solver-free oracle

```@docs
enumerate_lcp_solutions
is_monotone
strictly_complementary
basis_nonsingular
```

## The closed-loop model

```@docs
ms_second_stage_arrays
ms_second_stage_lcp
MSSecondStageIndex
ms_second_stage
ms_regime
ms_regime_jacobian
segment_role
second_stage_jacobian
ms_closed_loop_xi
ms_closed_loop_conditions
ms_closed_loop_residual
ms_closed_loop_conditions_decomposed
ms_long_run_objective
closed_loop_objective
```

## Finding and testing closed-loop equilibria

```@docs
enumerate_closed_loop
closed_loop_affine
best_response_gap
best_response
diagonalize
```

## Best-response MPCC

```@docs
BestResponseNLP
best_response_mpcc_arrays
best_response_mpcc
best_response_start_arrays
best_response_start
solve_best_response_arrays
solve_best_response_mpcc
```

## Building hard cases

```@docs
feasible_bases
best_response_wells
best_response_gap_at
best_response_tie
```
