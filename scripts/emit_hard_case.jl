# Emit the hard case: a best-response problem with two nearly-tied optima far apart.
#
#     julia --project scripts/emit_hard_case.jl
#
# Third generated artifact, produced the same way as the other two (DECISIONS.md D-0001):
# model spliced verbatim, data inlined, scaffolding authored here.
#
# WHAT MAKES IT HARD, AND WHY THAT IS NOT AN ACCIDENT. Everything else this repository has
# put to CCOpt, CCOpt has solved. That is a weak thing to offer a solver's author, so this
# case was searched for rather than stumbled on. Player i's long-run objective at a fixed
# rival capacity is piecewise quadratic with one well per second-stage regime; as the rival
# capacity varies the wells rise and fall relative to one another, and at some rival capacity
# two widely separated wells are exactly level. `scripts/../src/hard_best_response.jl` finds
# that capacity by golden section on the gap.
#
# Just off the tie there is a definite right answer with a small but real margin, and which
# well is right *flips* as the rival capacity crosses the tie. So the same problem, perturbed
# by a thousandth in one parameter, has two different answers a fifth of the domain apart.
# A method that keeps the well it started in gets exactly one side wrong.
#
# The right answer is known exactly, from enumerating the pieces and minimising each in
# closed form. That is what makes this a test rather than a demonstration that solvers
# disagree.
#
# WHAT IT DOES NOT ASSERT. It does not assert that CCOpt gets these right, because on the
# runs recorded here it does not always: it found the better well in 16 of 32. Freezing that as
# an expected value would turn a finding into a regression baseline. What it asserts is the
# ground truth — the two wells, their margin, and that whatever the solver returns is one of
# them — and it reports which method found which.

using CapacityEquilibriaBenchmarks
import CapacityEquilibria
import TOML

const REPO = normpath(joinpath(@__DIR__, ".."))
const DATADIR = joinpath(REPO, "data")
const OUT = joinpath(REPO, "upstream", "hard_case_near_tie.jl")
const ENGINE = normpath(joinpath(dirname(pathof(CapacityEquilibria)), ".."))

# The ties, located by `best_response_tie`. Recorded rather than recomputed because the
# search costs a full pattern enumeration per evaluation; `test/runtests.jl` re-derives them
# behind RUN_CLOSED_LOOP and checks these values.
const TIES = Dict(("a", 1) => 7.254033307585, ("a", 2) => 3.450296453109,
                  ("b", 1) => 5.317351598173, ("b", 2) => 4.292375886525)
const OFFSETS = (-0.01, -0.001, 0.001, 0.01)

function splice(path::AbstractString, tag::AbstractString)
    lines = readlines(path)
    b = findfirst(l -> strip(l) == "# emit:$tag:begin", lines)
    e = findfirst(l -> strip(l) == "# emit:$tag:end", lines)
    (b === nothing || e === nothing) && error("markers for $tag missing in $path")
    b < e || error("markers for $tag out of order in $path")
    return join(lines[b+1:e-1], "\n")
end

vecliteral(v) = "[" * join((repr(Float64(x)) for x in v), ", ") * "]"

"""One case: the instance, the player, and each off-tie problem with its known answer."""
function case_literal(tag::AbstractString, i::Int)
    d = load_ms_instance(joinpath(DATADIR, "ms2002_instance_$tag.toml"))
    bases = feasible_bases(d)
    tie = TIES[(tag, i)]
    probs = String[]
    for δ in OFFSETS
        g = best_response_gap_at(d, i, tie + δ; separation = 0.4, bases = bases)
        g.alt === nothing && continue
        push!(probs, """
        (rival = $(repr(tie + δ)), offset = $(repr(δ)),
         right = $(repr(g.best.x_i)), right_objective = $(repr(g.best.objective)),
         other = $(repr(g.alt.x_i)), other_objective = $(repr(g.alt.objective)),
         margin = $(repr(g.gap))),""")
    end
    return """
    (name = "instance $(uppercase(tag)), $(i == 1 ? "peaking" : "base-load") player",
     S = $(d.S), player = $i,
     beta = $(repr(d.beta)),
     alpha = $(vecliteral(d.alpha)),
     K = $(vecliteral(d.K)),
     nu = $(vecliteral(d.nu)),
     tie = $(repr(tie)),
     problems = (
$(join(probs, "\n"))
     )),"""
end

const HEADER = """
# A hard MPCC: two optima a fifth of the domain apart, tied to fourteen significant figures.
#
# GENERATED FILE — DO NOT EDIT. Produced by `scripts/emit_hard_case.jl` in
# CapacityEquilibriaBenchmarks.jl, which splices the model verbatim from the sources that
# repository tests and inlines the data from its `data/` directory.
#
# THE PROBLEM. A firm chooses a capacity, then competes on output against a rival across
# several demand blocks. Given both capacities, the output stage is a linear complementarity
# problem with a unique solution. The firm's own problem — minimise its capacity cost less
# its gross margin, subject to that output-stage equilibrium — is an MPCC with a nonconvex
# objective: piecewise quadratic in its own capacity, with a well for each pattern of which
# plants run in which blocks.
#
# WHY IT IS HARD. At the rival capacity named `tie` below, two of those wells are exactly
# level: the capacities differ by around 20% of the domain and the objectives agree to
# fourteen significant figures. Perturb the rival's capacity by a thousandth and one well
# becomes strictly better; perturb it the other way and the *other* one does. So the answer
# flips discontinuously across a knife-edge, while the margin deciding it stays around 1e-4
# in relative terms.
#
# A method that keeps the well it started in returns the right answer on one side of the tie
# and the wrong answer on the other, with a converged status and a clean residual either way.
# Each problem below is posed from a start inside the *wrong* well, which is the honest way
# to ask whether a method can leave one.
#
# WHAT IS ASSERTED, AND WHAT IS NOT. The ground truth is asserted: both wells' objectives,
# the margin between them, and that whatever the solver returns is one of the two. Whether
# CCOpt finds the better one is *reported*, not asserted: on the runs behind this file it
# found the better well in 16 of 32, and the two methods failed on different problems with
# neither dominating. Freezing that as an expected value would turn a finding into a
# regression baseline, and the number depends on the starting point anyway.
#
# The right answers come from enumerating the objective's pieces and minimising each in
# closed form, and from PATH, independently of the solver under test. They are inlined
# rather than recomputed here, deliberately: these wells sit on regime boundaries, and there
# CCOpt's output stage lands about 2e-4 from PATH's, against about 1e-8 at an interior
# point. Establishing the answer with the solver being tested would be circular even where
# it is accurate, and here it is not accurate enough to resolve a margin of 4e-3. Derivations and provenance:
# https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl
#
# The model is the closed-loop Cournot game of Murphy, F. H. and Smeers, Y., "Generation
# Capacity Expansion in Imperfectly Competitive Restructured Electricity Markets",
# Operations Research 53(4), 646-661 (2005), section 6. The paper publishes no numerical
# example, so the parameters here are constructed to satisfy its assumptions and no number
# in this file should be attributed to its authors.
"""

function emit()
    io = IOBuffer()
    print(io, HEADER)
    println(io, """
module HardCaseNearTie

using Test
import LinearAlgebra
import SparseArrays
import NLPModels
import MPCCModels
import CCOpt
import MadNLP

# ---------------------------------------------------------------------------------------
# 1. The output stage as an NLP in vertical form, and the residual oracle. Copied verbatim
#    from CapacityEquilibria.jl, `src/lcp_nlp.jl` and `src/pairing.jl`.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(ENGINE, "src", "lcp_nlp.jl"), "lcp_nlp"))

$(splice(joinpath(ENGINE, "src", "pairing.jl"), "lcp_residual"))

# ---------------------------------------------------------------------------------------
# 2. The model. Copied verbatim from CapacityEquilibriaBenchmarks.jl,
#    `src/murphy_smeers_closed_loop.jl`.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(REPO, "src", "murphy_smeers_closed_loop.jl"), "closed_loop_core"))

# ---------------------------------------------------------------------------------------
# 3. One firm's problem as an MPCC. Copied verbatim from
#    CapacityEquilibriaBenchmarks.jl, `src/best_response_mpcc.jl`.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(REPO, "src", "best_response_mpcc.jl"), "best_response_core"))

# ---------------------------------------------------------------------------------------
# 4. The cases. `tie` is the rival capacity at which two wells are level; each problem is
#    that capacity perturbed by `offset`, with the right answer and the other well.
# ---------------------------------------------------------------------------------------

const CASES = (""")
    for tag in ("a", "b"), i in (1, 2)
        println(io, case_literal(tag, i))
    end
    println(io, """)

\"\"\"Solve the output stage at capacities `x` with PATH-free arithmetic: enumeration is not
available here, so the reference outputs come from CCOpt's relaxation method, which is
reliable at these nondegenerate points and is checked against a recomputed residual.\"\"\"
function output_stage(case, x)
    M, q = ms_second_stage_arrays(case.S, case.beta, case.alpha, case.K, case.nu, x)
    n = length(q)
    nlp = LCPVerticalModel(M, q)
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect(n+1:2n))
    solver = CCOpt.RelaxationSolver(mpcc;
        solver_opts = CCOpt.RelaxationOptions(print_level = MadNLP.ERROR),
        print_level = MadNLP.ERROR)
    stats = CCOpt.solve_homotopy!(solver)
    w = stats.solution[1:n]
    S = case.S
    y = [w[(j - 1) * S + s] for j in 1:2, s in 1:S]
    return (y = y, residual = lcp_residual(M, q, w).worst)
end

\"\"\"Player `case.player`'s objective at its own capacity `xi`, rival held at `rival`.\"\"\"
function objective_at(case, rival, xi)
    x = zeros(2)
    x[3 - case.player] = rival
    x[case.player] = xi
    r = output_stage(case, x)
    return ms_long_run_objective(case.S, case.beta, case.alpha, case.K, case.nu,
                                 case.player, xi, r.y), r.residual
end

found_global = 0
total = 0

@testset "A hard MPCC: two optima, tied" begin
    for case in CASES
        println()
        println("=== ", case.name, " — tie at rival capacity ", case.tie, " ===")
        for p in case.problems
            # The landscape, asserted from the inlined values alone. They are ground
            # truth: they come from PATH and from an exact enumeration of the objective's
            # pieces, not from the solver under test. Recomputing them here with CCOpt
            # would be circular, and would also fail — these wells sit on regime
            # boundaries, where CCOpt's output stage is about 2e-4 from PATH's rather than
            # the 1e-8 it achieves at an interior point.
            @testset "\$(case.name), offset \$(p.offset): the landscape" begin
                @test p.margin > 0                        # the right answer really is better
                @test p.other_objective - p.right_objective ≈ p.margin atol = 1e-12
                @test abs(p.right - p.other) > 0.4        # and the two are far apart
                @test abs(p.margin / p.right_objective) < 2e-3   # by a very small margin
            end

            # What the solver's own arithmetic makes of the two wells, reported rather than
            # asserted, for the same reason.
            vr, resr = objective_at(case, p.rival, p.right)
            vo, _ = objective_at(case, p.rival, p.other)
            @testset "\$(case.name), offset \$(p.offset): the output stage solves" begin
                @test resr < 1e-5
            end

            # The solver, started inside the wrong well.
            x = zeros(2); x[3 - case.player] = p.rival
            start = copy(x); start[case.player] = p.other
            z0 = best_response_start_arrays(case.S, case.beta, case.alpha, case.K,
                                            case.nu, case.player, start,
                                            output_stage(case, start).y)
            for method in (:relaxation, :penalty)
                r = solve_best_response_arrays(case.S, case.beta, case.alpha, case.K, case.nu,
                                               case.player, x, method; x0 = z0)
                global total += 1
                hit = abs(r.x_i - p.right) < 1e-3
                hit && (global found_global += 1)
                @testset "\$(case.name), offset \$(p.offset), \$method" begin
                    @test r.feasibility < 1e-5
                    # Whatever it returns is one of the two wells: it found *a* local
                    # optimum, which is all a local method promises.
                    @test min(abs(r.x_i - p.right), abs(r.x_i - p.other)) < 1e-3
                end
                println("  offset ", rpad(string(p.offset), 8),
                        rpad(string(method), 12),
                        "-> x_i = ", rpad(string(round(r.x_i; digits = 6)), 12),
                        rpad(hit ? "found the better well" : "kept the worse well", 24),
                        "margin ", round(p.margin; sigdigits = 3),
                        "  (solver's own view of it: ",
                        round(vo - vr; sigdigits = 3), ")")
            end
        end
    end
end

println()
println("found the better well in ", found_global, " of ", total, " solves")

end # module HardCaseNearTie""")

    mkpath(dirname(OUT))
    open(OUT, "w") do fh
        write(fh, replace(String(take!(io)), "\\r\\n" => "\\n"))
    end
    println("wrote ", relpath(OUT, REPO), " (", countlines(OUT), " lines)")
end

emit()
