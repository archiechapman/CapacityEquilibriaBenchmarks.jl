# Emit the self-contained test file offered to CCOpt.jl.
#
#     julia --project scripts/emit_upstream_test.jl
#
# DECISIONS.md D-0001: the upstream artifact is generated, never hand-written, because a
# file copied once by hand is a file that stops matching the model that validated it the
# first time either is corrected. What this script writes into `upstream/` is therefore
# assembled from three sources and nothing else:
#
#   1. `data/*.toml`               — the instances and their hand-derived equilibria, the
#                                    same files the in-repo models and tests read
#   2. `src/murphy_smeers.jl`      — the region between the `emit:ms_lcp_arrays` markers,
#                                    copied verbatim: the repository's one transcription of
#                                    the paper's equations into (M, q)
#   3. the engine's `src/lcp_nlp.jl` and `src/pairing.jl` — the vertical-form NLP and the
#                                    residual oracle, likewise copied between markers
#
# Nothing is retyped here. If a line of the model appears in the emitted file, it is the
# line this repository tests, byte for byte; the only thing this script authors is the
# scaffolding around it. `test/runtests.jl` re-runs the emitted file and checks that the
# numbers it builds still match the in-repo model, and `generated.toml` makes a stale
# artifact a CI failure (`ci/gates/check_stale_generated.py`).
#
# Why no JuMP, and why a module: CCOpt.jl's own test environment
# (`~/.julia/packages/CCOpt/*/test/Project.toml`) carries NLPModels, MPCCModels, MadNLP,
# ADNLPModels and Test but not JuMP, and its `test/MOI_wrapper.jl` wraps itself in a module.
# The emitted file follows both conventions so that it can be dropped into their `test/`
# and included from their `runtests.jl` unchanged.

using CapacityEquilibriaBenchmarks
import CapacityEquilibria
import TOML

const REPO = normpath(joinpath(@__DIR__, ".."))
const DATADIR = joinpath(REPO, "data")
const OUT = joinpath(REPO, "upstream", "test_murphy_smeers_lcp.jl")
const ENGINE = normpath(joinpath(dirname(pathof(CapacityEquilibria)), ".."))

"""
    splice(path, tag) -> String

The lines of `path` between `# emit:<tag>:begin` and `# emit:<tag>:end`, exclusive of both.
Throws if either marker is missing or if they appear out of order, so that a source file
refactored past its markers stops the emitter rather than silently emitting less.
"""
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

"""
    case_literal(tag, variant) -> String

One entry of the emitted `CASES` tuple: the instance's parameters and its hand-derived
equilibrium, read from `data/` and written out as Julia literals. The equilibrium is
packed into the `z = (x, y, λ)` layout by the same `ms_pack` the tests use, so the vector
in the emitted file is the vector this repository validated and not a re-ordering of it.
"""
function case_literal(tag::AbstractString, variant::Symbol)
    data = load_ms_instance(joinpath(DATADIR, "ms2002_instance_$tag.toml"))
    expected_path = joinpath(DATADIR, "ms2002_instance_$(tag)_expected.toml")
    z = load_ms_expected(data, expected_path, variant)
    tol = Float64(TOML.parsefile(expected_path)["tolerance"])
    label = variant === :competitive ? "competitive" : "open-loop Cournot"
    return """
    (name = "instance $(uppercase(tag)), $label",
     S = $(data.S),
     beta = $(repr(data.beta)),
     alpha = $(vecliteral(data.alpha)),
     K = $(vecliteral(data.K)),
     nu = $(vecliteral(data.nu)),
     variant = $(repr(variant)),
     tol = $(repr(tol)),
     z = $(vecliteral(z))),"""
end

const HEADER = """
# Murphy and Smeers' open-loop capacity-expansion equilibria as linear complementarity
# problems, offered to CCOpt.jl as a correctness regression case: four small problems whose
# solutions are known independently of any solver, run through both of CCOpt's methods.
#
# GENERATED FILE — DO NOT EDIT. Produced by `scripts/emit_upstream_test.jl` in
# CapacityEquilibriaBenchmarks.jl, which copies the model and the residual oracle verbatim
# from the sources that repository tests, and inlines the data from its `data/` directory.
# Edits made here would be lost and, worse, would silently detach this file from the model
# that validated its numbers.
#
# THE PROBLEM. Two players, a peaker and a base-load plant, choose capacity `x_i` and
# per-segment output `y_i^s` over `S` load segments of unit width with affine inverse
# demand `p^s = α^s − β q^s`. Under either behavioural assumption — price-taking, or
# open-loop Cournot — the equilibrium conditions are a square LCP `0 ≤ z ⟂ Mz + q ≥ 0` in
# `z = (x, y, λ)` of size `n = 2 + 4S`, and the map is monotone. See F. H. Murphy and
# Y. Smeers, "Generation Capacity Expansion in Imperfectly Competitive Restructured
# Electricity Markets", *Operations Research* 53(4), 646–661 (2005); the equilibrium
# conditions are (2)–(3) and (5)–(6) of the May 2002 working paper, pp. 14 and 16.
#
# WHERE THE ANSWERS COME FROM, AND WHERE THEY DO NOT. Neither edition of that paper
# publishes a numerical example, so the two instances below are *constructed* to satisfy
# its stated assumptions, and no number here is the authors'. Each equilibrium was derived
# by hand from the equilibrium conditions and checked by substitution; an exhaustive
# enumeration of all 2^n complementarity patterns finds it and no other solution; and PATH
# reaches it to better than 1e-9. The map being monotone, the point strictly complementary
# and its basis nonsingular, that solution is unique. Both problems are therefore the easy
# case for a relaxation or penalty scheme — a unique, strictly complementary solution —
# which is what makes them a regression test and not a demonstration of scale.
#
# The tolerances are the ones the source repository set before either CCOpt method was run
# on these problems, and are several hundred times looser than what both achieve; the
# nearest wrong regime is O(1) away on instance A and O(0.1) on instance B, so no tolerance
# here can admit a wrong answer.
#
# Full derivations, provenance for every parameter, and the PATH and enumeration results:
# https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl

"""

function emit()
    body = IOBuffer()
    print(body, HEADER)
    println(body, """
module TestMurphySmeersLCP

using Test
import LinearAlgebra
import SparseArrays
import NLPModels
import MPCCModels
import CCOpt
import MadNLP

# ---------------------------------------------------------------------------------------
# 1. The LCP as an NLP in the vertical form CCOpt's reformulations expect.
#    Copied verbatim from CapacityEquilibria.jl, `src/lcp_nlp.jl`.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(ENGINE, "src", "lcp_nlp.jl"), "lcp_nlp"))

# ---------------------------------------------------------------------------------------
# 2. The model. Copied verbatim from CapacityEquilibriaBenchmarks.jl,
#    `src/murphy_smeers.jl`; each line cites the page of the paper it encodes.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(REPO, "src", "murphy_smeers.jl"), "ms_lcp_arrays"))

# ---------------------------------------------------------------------------------------
# 3. The oracle. Copied verbatim from CapacityEquilibria.jl, `src/pairing.jl`. It consults
#    no solver: a returned point is judged by recomputing the residual from the point
#    alone, never by the status the solver reports for itself.
# ---------------------------------------------------------------------------------------

$(splice(joinpath(ENGINE, "src", "pairing.jl"), "lcp_residual"))

# ---------------------------------------------------------------------------------------
# 4. The cases: two constructed instances, two behavioural assumptions, and the equilibrium
#    of each in the layout `z = (x_p, x_b, y_p^1..S, y_b^1..S, λ_p^1..S, λ_b^1..S)`.
#    Inlined from `data/` by the emitter.
# ---------------------------------------------------------------------------------------

const CASES = (""")
    for tag in ("a", "b"), variant in (:competitive, :open_loop_cournot)
        println(body, case_literal(tag, variant))
    end
    println(body, """)

\"\"\"
    build(case) -> (M, q, mpcc, ix)

The case as an `MPCCModel`: the LCP's `x` and its residual `w = Mx + q` are the two sides
of the complementarity, paired by index. `ix` reads `x` back out of a solver's point.
\"\"\"
function build(case)
    M, q = ms_lcp_arrays(case.S, case.beta, case.alpha, case.K, case.nu, case.variant)
    n = length(q)
    nlp = LCPVerticalModel(M, q)
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect(n+1:2n))
    return M, q, mpcc, 1:n
end

@testset "Murphy-Smeers open-loop capacity equilibria" begin
    for case in CASES
        # A fresh model per solve: both solvers take ownership of the one they are given.
        @testset "\$(case.name), relaxation" begin
            M, q, mpcc, ix = build(case)
            solver = CCOpt.RelaxationSolver(
                mpcc;
                solver_opts = CCOpt.RelaxationOptions(print_level = MadNLP.ERROR),
                print_level = MadNLP.ERROR,
            )
            stats = CCOpt.solve_homotopy!(solver)
            @test stats.status == MadNLP.SOLVE_SUCCEEDED
            z = stats.solution[ix]
            @test lcp_residual(M, q, z).worst < case.tol
            @test z ≈ case.z atol = case.tol
        end

        @testset "\$(case.name), penalty" begin
            M, q, mpcc, ix = build(case)
            solver = CCOpt.PenaltySolver(
                mpcc;
                solver_opts = CCOpt.PenaltyOptions{Float64}(print_level = MadNLP.ERROR),
                print_level = MadNLP.ERROR,
            )
            stats = CCOpt.solve_homotopy!(solver)
            @test stats.status == MadNLP.SOLVE_SUCCEEDED
            z = stats.solution[ix]
            @test lcp_residual(M, q, z).worst < case.tol
            @test z ≈ case.z atol = case.tol
        end
    end
end

end # module TestMurphySmeersLCP""")

    mkpath(dirname(OUT))
    open(OUT, "w") do io
        write(io, replace(String(take!(body)), "\\r\\n" => "\\n"))
    end
    println("wrote ", relpath(OUT, REPO), " (", countlines(OUT), " lines)")
end

emit()
