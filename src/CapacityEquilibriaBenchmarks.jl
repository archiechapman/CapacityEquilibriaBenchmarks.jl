"""
    CapacityEquilibriaBenchmarks

Published capacity-expansion equilibrium models with published answers, built for the
engine in `CapacityEquilibria.jl`. Phase 1 holds Murphy and Smeers' two open-loop models —
the competitive benchmark and the open-loop Cournot game — as linear complementarity
problems read from `data/`, plus the checks that decide whether a solver's point is their
equilibrium: the paper's own stated properties, and an exhaustive enumeration of
complementarity patterns that finds every solution without a solver.

Phase 3 adds the closed-loop Cournot model of the paper's section 6, in
`murphy_smeers_closed_loop.jl`. It shares its entire second stage with the open-loop
Cournot model and differs only in the condition paired with capacity, which involves the
sensitivity of the second-stage equilibrium to first-stage investment.
"""
module CapacityEquilibriaBenchmarks

using CapacityEquilibria

export MSData, MSIndex, MSPoint, MS_VARIANTS, PLAYER_P, PLAYER_B
export load_ms_instance, check_assumptions, peak_segments
export ms_lcp, ms_lcp_arrays, ms_conditions, ms_unpack, ms_pack, load_ms_expected
export investment_criterion_gap, pricing_efficiency_gap, production_efficiency_holds,
       segment_type
export enumerate_lcp_solutions, is_monotone, strictly_complementary, basis_nonsingular
export MSSecondStageIndex, ms_second_stage_lcp, ms_second_stage, segment_role,
       second_stage_jacobian, ms_closed_loop_conditions, ms_closed_loop_residual,
       ms_closed_loop_conditions_decomposed
export enumerate_closed_loop, closed_loop_affine
export closed_loop_objective, best_response_gap
export best_response, diagonalize
export ms_second_stage_arrays, ms_regime, ms_regime_jacobian, ms_closed_loop_xi

include("murphy_smeers.jl")
include("murphy_smeers_closed_loop.jl")
include("enumerate_lcp.jl")
include("enumerate_closed_loop.jl")
include("diagonalize_closed_loop.jl")

end # module
