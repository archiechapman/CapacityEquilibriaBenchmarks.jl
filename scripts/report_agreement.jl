# Print the solver-agreement table behind docs/REPLICATION_REPORT.md: for every instance,
# model and backend, the residual recomputed from the returned point and its distance from
# the derived equilibrium, plus the enumeration's solution count. Run from the repo root:
#
#     julia --project scripts/report_agreement.jl
#
# This is a reporting script, not an emitter; the emitter is scripts/emit_upstream_test.jl.
#
# Four routes reach each point. `path` and `ccopt` go through JuMP; `ccopt_relaxation` and
# `ccopt_penalty` go through an MPCCModel the engine builds directly, which is the only way
# to reach CCOpt's penalty method (engine FINDINGS.md F-0004). `ccopt` and
# `ccopt_relaxation` are the same method with and without the MathOptComplements bridges,
# and are reported separately so that a difference between them would be visible.

using CapacityEquilibriaBenchmarks
using CapacityEquilibria
using LinearAlgebra: norm
using Printf
import TOML

const DATADIR = joinpath(@__DIR__, "..", "data")

for tag in ["a", "b"]
    data = load_ms_instance(joinpath(DATADIR, "ms2002_instance_$tag.toml"))
    expected = joinpath(DATADIR, "ms2002_instance_$(tag)_expected.toml")
    tol = TOML.parsefile(expected)["tolerance"]
    println("\nInstance $(uppercase(tag)): S = $(data.S), n = $(2 + 4data.S), tolerance $tol")
    @printf("  %-18s %-17s %10s %12s %10s\n", "model", "route", "residual", "|z - hand|", "time (s)")
    for variant in MS_VARIANTS
        M, q, _ = ms_lcp(data, variant)
        z_hand = load_ms_expected(data, expected, variant)
        @printf("  %-18s %-17s %10.1e %12s\n", variant, "hand", lcp_residual(M, q, z_hand).worst, "—")
        t = @elapsed en = enumerate_lcp_solutions(M, q)
        z_en = en.solutions[1]
        @printf("  %-18s %-17s %10.1e %12.1e %10.2f   (%d solution%s)\n", "", "enumeration",
                lcp_residual(M, q, z_en).worst, norm(z_en - z_hand, Inf), t,
                length(en.solutions), length(en.solutions) == 1 ? "" : "s")
        for backend in (:path, :ccopt, :ccopt_relaxation, :ccopt_penalty)
            sol = solve_complementarity(M, q, backend)   # warm-up, excluded below
            sol = solve_complementarity(M, q, backend)
            @printf("  %-18s %-17s %10.1e %12.1e %10.3f   %s\n", "", backend,
                    lcp_residual(M, q, sol.x).worst, norm(sol.x - z_hand, Inf), sol.solve_time,
                    sol.status)
        end
        pt = ms_unpack(data, z_hand)
        println("    x = ", round.(pt.x; digits = 4), "  prices = ", round.(pt.price; digits = 3),
                "  types = ", [segment_type(data, pt, s) for s in 1:data.S])
    end
end
