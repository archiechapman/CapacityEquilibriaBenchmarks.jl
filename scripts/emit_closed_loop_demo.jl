# Emit the self-contained demonstration that accompanies the note on first-order conditions.
#
#     julia --project scripts/emit_closed_loop_demo.jl
#
# Sibling of `emit_upstream_test.jl` and generated the same way (DECISIONS.md D-0001):
# the model is spliced verbatim out of the sources this repository tests, the data is
# inlined from `data/`, and this script authors only the scaffolding.
#
# WHAT THIS FILE IS FOR, AND WHY IT IS NOT A REGRESSION TEST. The open-loop file offered
# alongside it is a regression test: four problems with known unique answers, and CCOpt
# either reaches them or does not. This one asks a different question. It exhibits a
# capacity game in which the equilibrium conditions have three solutions and only one is an
# equilibrium, and it shows that a solver can be entirely correct at every step and still
# return a point that means nothing. That is a statement about the formulation rather than
# about the solver, which is why it travels as a demonstration with a note rather than as a
# proposed addition to anyone's `test/` directory.
#
# CCOpt does real work in it, and the file turned up a second result while doing so: the
# spurious roots are exactly the points where the output stage is degenerate, its dual an
# unbounded ray. Every solver agrees on the outputs there and lands somewhere different on
# the ray, and the penalty method'"'"'s recomputed residual degrades far out along it. That is
# not a defect - the problem does not determine the dual - but it is the hard case the
# open-loop test file explicitly does not cover.

using CapacityEquilibriaBenchmarks
import CapacityEquilibria
import TOML

const REPO = normpath(joinpath(@__DIR__, ".."))
const DATADIR = joinpath(REPO, "data")
const OUT = joinpath(REPO, "upstream", "closed_loop_demonstration.jl")
const ENGINE = normpath(joinpath(dirname(pathof(CapacityEquilibria)), ".."))

function splice(path::AbstractString, tag::AbstractString)
    lines = readlines(path)
    b = findfirst(l -> strip(l) == "# emit:$tag:begin", lines)
    e = findfirst(l -> strip(l) == "# emit:$tag:end", lines)
    b === nothing && error("no `# emit:$tag:begin` marker in $path")
    e === nothing && error("no `# emit:$tag:end` marker in $path")
    b < e || error("markers for $tag are out of order in $path")
    return join(lines[b+1:e-1], "\n")
end

vecliteral(v) = "[" * join((repr(Float64(x)) for x in v), ", ") * "]"

"""One case: the instance, its three roots of (16), and what each one is."""
function case_literal(tag::AbstractString)
    data = load_ms_instance(joinpath(DATADIR, "ms2002_instance_$tag.toml"))
    en = enumerate_closed_loop(data)
    entries = String[]
    for x in sort(en.solutions; by = v -> (v[1], v[2]))
        gap = best_response_gap(data, x).gap
        entries = push!(entries, """
        (x = $(vecliteral(x)), deviation_gain = $(repr(round(gap; digits = 6))),
         equilibrium = $(gap == 0.0)),""")
    end
    return """
    (name = "instance $(uppercase(tag))",
     S = $(data.S),
     beta = $(repr(data.beta)),
     alpha = $(vecliteral(data.alpha)),
     K = $(vecliteral(data.K)),
     nu = $(vecliteral(data.nu)),
     roots = (
$(join(entries, "\n"))
     )),"""
end

const HEADER = """
# Three solutions, one equilibrium: a capacity game where the first-order conditions do not
# characterise the answer.
#
# GENERATED FILE — DO NOT EDIT. Produced by `scripts/emit_closed_loop_demo.jl` in
# CapacityEquilibriaBenchmarks.jl, which splices the model verbatim from the sources that
# repository tests and inlines the data from its `data/` directory.
#
# Run it with `julia --project=. closed_loop_demonstration.jl` in a project that has CCOpt,
# MPCCModels, NLPModels, MadNLP and Test. It prints a table and asserts every claim it makes.
#
# WHAT IT SHOWS. Two generators, a peaking plant and a base-load plant, first choose capacity
# and then compete on output in each of several demand blocks. Given the capacities, the
# output stage is a linear complementarity problem with a unique solution — CCOpt solves it,
# and this file checks that it does, at every point it examines, with both of CCOpt's
# methods. The capacity stage is the interesting one. Its equilibrium condition is a
# first-order condition: "no player gains from an infinitesimal change of capacity". On each
# of the two instances below, three capacity vectors satisfy it. Only one of them is an
# equilibrium. At the other two, a player holding nothing gains a great deal by building.
#
# WHY THAT CAN HAPPEN. A player's payoff as a function of its own capacity is piecewise
# quadratic, because changing capacity changes which plants are running in which demand
# blocks, and each such switch is a kink. The first-order condition uses the derivative of
# the output stage with respect to capacity, which is constant on each operating pattern,
# and it is defined only away from the kinks. The two spurious roots sit on one. A player
# holding no capacity produces nothing, so in every block its output is at both of its
# bounds at once, zero and capacity, and the operating pattern is ambiguous. Read it as
# idle and every derivative term vanishes: the condition reduces to "capacity costs
# something", which holds at zero. Read it as at capacity and the derivative is the true
# one-sided slope, which is steeply negative: the very first unit of capacity pays. So the
# spurious roots are not local optima the derivative cannot see past. They are kinks, where
# the condition is undefined and evaluating it anyway returns a root.
#
# WHY IT MATTERS FOR A SOLVER. Nothing here is a defect in CCOpt, and this file is careful to
# demonstrate that: the solver is asked for the output-stage equilibrium at each of the three
# points and gets all of them right. The point is that a complementarity system can have a
# larger solution set than the problem it was written to represent. A solver that finds a
# root is correct; whether that root is an equilibrium is a separate question, answered
# outside the system by a deviation check.
#
# The source repository, with derivations, provenance for every number, and the same model
# validated against PATH and against exhaustive enumeration:
# https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl
#
# The model is Murphy, F. H. and Smeers, Y., "Generation Capacity Expansion in Imperfectly
# Competitive Restructured Electricity Markets", Operations Research 53(4), 646-661 (2005);
# the closed-loop Cournot model of its section 6. The paper publishes no numerical example,
# so the two instances here are constructed to satisfy its stated assumptions and no number
# in this file should be attributed to its authors.
"""

function emit()
    io = IOBuffer()
    print(io, HEADER)
    println(io, """
module ClosedLoopDemonstration

using Test
import LinearAlgebra
import SparseArrays
import NLPModels
import MPCCModels
import CCOpt
import MadNLP

# ---------------------------------------------------------------------------------------
# 1. The output-stage problem as an NLP in the vertical form CCOpt's reformulations expect.
#    Copied verbatim from CapacityEquilibria.jl, `src/lcp_nlp.jl`.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(ENGINE, "src", "lcp_nlp.jl"), "lcp_nlp"))

# ---------------------------------------------------------------------------------------
# 2. The residual oracle. Copied verbatim from CapacityEquilibria.jl, `src/pairing.jl`.
#    It consults no solver: a returned point is judged by recomputing from the point alone.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(ENGINE, "src", "pairing.jl"), "lcp_residual"))

# ---------------------------------------------------------------------------------------
# 3. The model. Copied verbatim from CapacityEquilibriaBenchmarks.jl,
#    `src/murphy_smeers_closed_loop.jl`. The output stage, the regime classification,
#    Lemma 7's closed-form sensitivity of the output stage to capacity, and equation (16).
# ---------------------------------------------------------------------------------------

$(splice(joinpath(REPO, "src", "murphy_smeers_closed_loop.jl"), "closed_loop_core"))

# ---------------------------------------------------------------------------------------
# 4. The cases: two constructed instances and, for each, every capacity vector satisfying
#    the first-order conditions, with what a deviating player could gain at it. Inlined by
#    the emitter; `deviation_gain` is the improvement available to the better-off deviator,
#    found by a global scan over that player's capacity in the source repository.
# ---------------------------------------------------------------------------------------

const CASES = (""")
    for tag in ("a", "b")
        println(io, case_literal(tag))
    end
    println(io, """)

\"\"\"Solve the output stage at `x` with `method`, and return the outputs and duals.\"\"\"
function output_stage(case, x, method::Symbol)
    M, q = ms_second_stage_arrays(case.S, case.beta, case.alpha, case.K, case.nu, x)
    n = length(q)
    nlp = LCPVerticalModel(M, q)
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect(n+1:2n))
    solver = if method === :relaxation
        CCOpt.RelaxationSolver(mpcc;
            solver_opts = CCOpt.RelaxationOptions(print_level = MadNLP.ERROR),
            print_level = MadNLP.ERROR)
    else
        CCOpt.PenaltySolver(mpcc;
            solver_opts = CCOpt.PenaltyOptions{Float64}(print_level = MadNLP.ERROR),
            print_level = MadNLP.ERROR)
    end
    stats = CCOpt.solve_homotopy!(solver)
    w = stats.solution[1:n]
    S = case.S
    y = [w[(i - 1) * S + s] for i in 1:2, s in 1:S]
    return (status = stats.status, w = w, M = M, q = q, y = y)
end

\"\"\"
    snap_and_bump(case, x, w, bump) -> (residual, lambda_max)

Put the non-investing player's output exactly on its bound, add `bump` to that player's
capacity duals, and recompute the residual.

Snapping matters. At these points the player holds no capacity, so its output is zero and
its capacity constraint binds at zero, and *any* sufficiently large shadow price satisfies
the conditions. The dual is an unbounded ray. A solver's returned point sits somewhere out
along it with a small primal error, and the product of a large dual with a small primal
error is a large residual — which is why the residual is not a useful accuracy measure
here. Snapping removes the primal error so that the freedom in the dual can be seen on its
own.
\"\"\"
function snap_and_bump(case, x, w, bump)
    S = case.S
    idle = x[1] < 1e-9 ? 1 : 2
    w2 = copy(w)
    for s in 1:S
        w2[(idle - 1) * S + s] = 0.0                       # output exactly at its bound
        w2[2 * S + (idle - 1) * S + s] += bump             # dual pushed along the ray
    end
    M, q = ms_second_stage_arrays(case.S, case.beta, case.alpha, case.K, case.nu, x)
    return lcp_residual(M, q, w2).worst, maximum(w2[(2 * S + 1):(4 * S)])
end

@testset "Three solutions, one equilibrium" begin
    for case in CASES
        println()
        println("=== ", case.name, " ===")
        for root in case.roots
            corner = any(root.x .< 1e-9)
            ref = output_stage(case, root.x, :relaxation)

            for method in (:relaxation, :penalty)
                r = output_stage(case, root.x, method)
                @testset "\$(case.name), x = \$(root.x), \$method output stage" begin
                    @test r.status == MadNLP.SOLVE_SUCCEEDED
                    # The outputs are pinned by the problem and every method finds them.
                    @test r.y ≈ ref.y atol = 1e-5
                    if corner
                        # The duals are not pinned: see the ray check below. So the only
                        # thing asserted here is that the point is feasible in the primal,
                        # and the residual is reported rather than thresholded, because far
                        # out along a ray it is a statement about where the solver stopped
                        # and not about whether it was right.
                        @test all(r.w .>= -1e-6)
                    else
                        @test lcp_residual(r.M, r.q, r.w).worst < 1e-5
                    end
                end
            end

            # The first-order condition of the capacity stage, at CCOpt's own outputs.
            types, roles = ms_regime(case.S, root.x, ref.y; tol = 1e-5)
            xi = ms_closed_loop_xi(case.S, case.beta, case.alpha, case.K, case.nu,
                                   ref.y, types, roles)
            @testset "\$(case.name), x = \$(root.x), first-order condition" begin
                @test all(xi .>= -1e-5)
                @test maximum(abs.(root.x .* xi)) < 1e-4
            end

            if corner
                # Why the duals are not pinned: adding an arbitrary amount to the
                # non-investing player's capacity duals leaves an exact solution. The
                # player holds nothing, so its capacity constraint binds at zero for any
                # shadow price high enough, and the problem never picks one.
                @testset "\$(case.name), x = \$(root.x), the dual is a ray" begin
                    base, _ = snap_and_bump(case, root.x, ref.w, 0.0)
                    for bump in (1.0, 1.0e3, 1.0e5)
                        moved, lam = snap_and_bump(case, root.x, ref.w, bump)
                        # However far the dual is pushed, the point stays a solution to
                        # the same accuracy. Nothing in the problem picks a value for it.
                        @test moved <= base + 1e-9
                        @test lam >= bump
                    end
                end
            end

            mark = root.equilibrium ? "equilibrium" : "not an equilibrium"
            deg = corner ? "degenerate: dual is a ray" : "nondegenerate"
            pen = output_stage(case, root.x, :penalty)
            println("  x = ", rpad(string(round.(root.x; digits = 4)), 22),
                    rpad(deg, 28),
                    "penalty residual ",
                    rpad(string(round(lcp_residual(pen.M, pen.q, pen.w).worst;
                                      sigdigits = 2)), 10),
                    rpad("deviation gain " * string(root.deviation_gain), 26), mark)
        end

        @testset "\$(case.name): only one root is an equilibrium" begin
            @test count(r -> r.equilibrium, case.roots) == 1
            for root in case.roots
                root.equilibrium && continue
                @test root.deviation_gain > 1.0
                @test any(root.x .< 1e-9)      # each is a corner: a player holding nothing
            end
        end
    end
end

end # module ClosedLoopDemonstration""")

    mkpath(dirname(OUT))
    open(OUT, "w") do fh
        write(fh, replace(String(take!(io)), "\\r\\n" => "\\n"))
    end
    println("wrote ", relpath(OUT, REPO), " (", countlines(OUT), " lines)")
end

emit()
