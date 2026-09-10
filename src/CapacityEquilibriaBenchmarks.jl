"""
    CapacityEquilibriaBenchmarks

Published capacity-expansion equilibrium models with published answers, built for the
engine in `CapacityEquilibria.jl`. Phase 1 holds Murphy and Smeers' two open-loop models —
the competitive benchmark and the open-loop Cournot game — as linear complementarity
problems read from `data/`, plus the checks that decide whether a solver's point is their
equilibrium: the paper's own stated properties, and an exhaustive enumeration of
complementarity patterns that finds every solution without a solver.
"""
module CapacityEquilibriaBenchmarks

using CapacityEquilibria

export MSData, MSIndex, MSPoint, MS_VARIANTS, PLAYER_P, PLAYER_B
export load_ms_instance, check_assumptions, peak_segments
export ms_lcp, ms_lcp_arrays, ms_conditions, ms_unpack, ms_pack, load_ms_expected
export investment_criterion_gap, pricing_efficiency_gap, production_efficiency_holds,
       segment_type
export enumerate_lcp_solutions, is_monotone, strictly_complementary, basis_nonsingular

include("murphy_smeers.jl")
include("enumerate_lcp.jl")

end # module
