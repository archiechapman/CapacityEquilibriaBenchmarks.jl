# Negative controls for the checks that guard the emitted upstream test.
#
#     julia --project scripts/negative_controls.jl
#
# A test that has never been seen to fail is not yet known to be a test. `test/runtests.jl`
# asserts that the emitted file, and its CCOpt-layout form, reproduce the in-repo model;
# this script breaks copies of them on purpose and reports whether the check meant to catch
# each break actually does. It exits nonzero if any control goes uncaught.
#
# Nothing here touches the repository. Every mutation is applied to a copy under a
# temporary directory, and the copy's module is renamed so that mutants cannot collide
# with each other or with the real file.
#
# The controls are chosen so that each one is caught by a *different* net, because the
# round-trip check has two that are easy to confuse:
#
#   * cases are matched to `data/` by their inlined parameters, so corrupting a parameter
#     makes a case unmatchable (NC2, NC3, NC4);
#   * the matrices are then compared, so corrupting the spliced model code — which leaves
#     every parameter intact and every case matchable — is caught only there (NC8).
#
# Without NC8 the matrix comparison could be deleted and every other control would still
# pass, which is the state a suite drifts into when its controls are never run.

using CapacityEquilibriaBenchmarks, CapacityEquilibria
using Test, CCOpt, MadNLP
import TOML
using Printf

const REPO = normpath(joinpath(@__DIR__, ".."))
const UPSTREAM = joinpath(REPO, "upstream", "test_murphy_smeers_lcp.jl")
const SCRATCH = mktempdir()
const NCASES = 4

isfile(UPSTREAM) || error("no emitted file at $UPSTREAM; run scripts/emit_upstream_test.jl")

# (control, the check that should catch it, did it, is being uncaught the expected result)
const RESULTS = Tuple{String,String,Bool,Bool}[]
record(name, checker, caught; expect_caught = true) =
    push!(RESULTS, (name, checker, caught, expect_caught))

# --- mutant construction -------------------------------------------------------------------

"""
    mutant(tag, mutations; strip_tests) -> path

A copy of the emitted file with `mutations` applied (first occurrence of each), its module
renamed to `Mutant<tag>`, and optionally its own `@testset` block removed so that the copy
loads cleanly and only its data is under examination.
"""
function mutant(tag::AbstractString, mutations::Vector{<:Pair}; strip_tests::Bool)
    body = read(UPSTREAM, String)
    for (old, new) in mutations
        occursin(old, body) || error("mutation target not found for $tag:\n$old")
        body = replace(body, old => new, count = 1)
    end
    body = replace(body, "module TestMurphySmeersLCP" => "module Mutant$tag")
    body = replace(body, "end # module TestMurphySmeersLCP" => "end # module Mutant$tag")
    if strip_tests
        i = findfirst("@testset \"Murphy-Smeers", body)
        i === nothing && error("could not find the testset block to strip")
        body = body[1:first(i)-1] * "\nend # module Mutant$tag\n"
    end
    path = joinpath(SCRATCH, "mutant_$tag.jl")
    write(path, body)
    return path
end

"""
    roundtrip_report(m) -> NamedTuple

The round-trip comparisons from `test/runtests.jl`, run against a loaded mutant module,
reporting which net caught what rather than a single boolean.
"""
function roundtrip_report(m; verbose = true)
    say(msg) = verbose && println("      ", msg)
    by_count = length(m.CASES) != NCASES
    by_count && say("case count is $(length(m.CASES)), expected $NCASES")
    by_match = by_M = by_q = by_z = by_tol = false
    for tag in ("a", "b"), variant in MS_VARIANTS
        data = load_ms_instance(joinpath(REPO, "data", "ms2002_instance_$tag.toml"))
        ep = joinpath(REPO, "data", "ms2002_instance_$(tag)_expected.toml")
        label = "instance $(uppercase(tag)) $variant"
        matching = [c for c in m.CASES
                    if c.variant === variant && c.S == data.S && c.beta == data.beta &&
                       c.alpha == data.alpha && c.K == data.K && c.nu == data.nu]
        if length(matching) != 1
            say("$label: $(length(matching)) matching cases, expected 1")
            by_match = true
            continue
        end
        case = only(matching)
        M, q, _ = ms_lcp(data, variant)
        z_hand = load_ms_expected(data, ep, variant)
        Me, qe = m.ms_lcp_arrays(case.S, case.beta, case.alpha, case.K, case.nu, case.variant)
        Me == M || (say("$label: M differs"); by_M = true)
        qe == q || (say("$label: q differs"); by_q = true)
        case.z == z_hand || (say("$label: z differs"); by_z = true)
        case.tol == Float64(TOML.parsefile(ep)["tolerance"]) ||
            (say("$label: tolerance differs"); by_tol = true)
    end
    any = by_count || by_match || by_M || by_q || by_z || by_tol
    return (; any, by_count, by_match, by_M, by_q, by_z, by_tol)
end

"""True if loading the mutant with its own testsets intact throws, i.e. they failed."""
function own_tests_fail(path)
    try
        include(path)
        return false
    catch
        return true
    end
end

# Mutation targets, as they appear in the emitted file. The case entries are written by
# `case_literal` in the emitter through a triple-quoted string, so they carry a one-space
# indent; the first occurrence of each parameter line is instance A / instance B
# competitive, which is what `count = 1` selects.
const A_COMP_Z = " z = [7.0, 8.0, 7.0, 4.0, 0.0, 8.0, 8.0, 8.0, 2.0, 0.0, 0.0, 4.0, 2.0, 1.0])"
const A_ALPHA  = " alpha = [20.0, 15.0, 10.0],"
const B_BETA   = " beta = 10.0,"
const ASSEMBLY = "M[r, ix_y(i, s)] = c * beta"

# --- NC5: how finely does the regime check discriminate? ------------------------------------

println("\n=== NC5: the regime classification's sensitivity ===")
let
    data = load_ms_instance(joinpath(REPO, "data", "ms2002_instance_a.toml"))
    ep = joinpath(REPO, "data", "ms2002_instance_a_expected.toml")
    tol = Float64(TOML.parsefile(ep)["tolerance"])
    want = Symbol.(TOML.parsefile(ep)["competitive"]["segment_types"])
    z = load_ms_expected(data, ep, :competitive)
    base = [segment_type(data, ms_unpack(data, z), s; tol = tol) for s in 1:data.S]
    @printf("  unperturbed        %-22s %s\n", string(base),
            base == want ? "matches the derivation" : "MISMATCH")
    # y_p^3 is exactly 0 at this equilibrium: the peaker is idle in the base segment, which
    # is what makes segment 3 type :e. Walking it off the bound is the smallest meaningful
    # regime error there is.
    for delta in (1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-2)
        zp = copy(z)
        zp[2 + 3] += delta
        got = [segment_type(data, ms_unpack(data, zp), s; tol = tol) for s in 1:data.S]
        @printf("  y_p^3 += %-8.0e %-22s %s\n", delta, string(got),
                got != want ? "CAUGHT" : "not caught")
        delta == 1e-5 && record("NC5a regime error 10x the tolerance",
                                "segment_type at the case tolerance", got != want)
        delta == 1e-8 && record("NC5b regime error below the tolerance",
                                "segment_type at the case tolerance", got != want;
                                expect_caught = false)
    end
    println("  The check discriminates at the tolerance, which is four orders finer than")
    println("  the O(0.1) distance to the nearest genuine regime, and is also its floor.")
end

# --- NC0: the control for the controls -------------------------------------------------------

println("\n=== NC0: the unmutated file ===")
let m = include(mutant("Clean", ["# GENERATED FILE" => "# GENERATED FILE"]; strip_tests = true))
    r = roundtrip_report(m)
    println("  round-trip fires on the real file? ", r.any, r.any ? "   <-- BAD" : "   (correct)")
    record("NC0 unmutated file", "round-trip comparisons stay silent", !r.any)
end

# --- NC1-NC4: corrupted data, caught by the case match or the equilibrium comparison ---------

println("\n=== NC1: inlined equilibrium corrupted (A competitive, x_p 7.0 -> 7.001) ===")
let m = include(mutant("Z", [A_COMP_Z => replace(A_COMP_Z, "[7.0, 8.0" => "[7.001, 8.0")];
                             strip_tests = true))
    r = roundtrip_report(m)
    record("NC1 corrupted equilibrium", "round-trip `case.z == z_hand`", r.by_z)
end

println("\n=== NC2: inlined demand intercept corrupted (A alpha^3 10.0 -> 10.5) ===")
let m = include(mutant("Q", [A_ALPHA => " alpha = [20.0, 15.0, 10.5],"]; strip_tests = true))
    r = roundtrip_report(m)
    record("NC2 corrupted parameter (alpha)", "round-trip case match against data/", r.by_match)
end

println("\n=== NC3: inlined slope corrupted (B beta 10.0 -> 10.1) ===")
let m = include(mutant("Mb", [B_BETA => " beta = 10.1,"]; strip_tests = true))
    r = roundtrip_report(m)
    record("NC3 corrupted parameter (beta)", "round-trip case match against data/", r.by_match)
end

println("\n=== NC4: a case silently dropped ===")
let
    body = read(UPSTREAM, String)
    k = findfirst("(name = \"instance B, open-loop Cournot\"", body)
    zstart = findnext(" z = [", body, first(k))
    zend = findnext("]),\n", body, first(zstart))
    m = include(mutant("Drop", [body[first(k):last(zend)] => ""]; strip_tests = true))
    println("  cases in mutant: ", length(m.CASES))
    r = roundtrip_report(m)
    record("NC4 dropped case", "round-trip case count and match", r.by_count || r.by_match)
end

# --- NC8: corrupted model code, which only the matrix comparison can catch --------------------

println("\n=== NC8: spliced assembly corrupted (`c * beta` -> `beta`), parameters intact ===")
let m = include(mutant("Asm", [ASSEMBLY => "M[r, ix_y(i, s)] = beta"]; strip_tests = true))
    r = roundtrip_report(m)
    # The mutation is a no-op where c == 1, so only the two Cournot cases should move, and
    # every case should still match on its parameters.
    println("  caught by case match: ", r.by_match, "   by `Me == M`: ", r.by_M,
            "   by `qe == q`: ", r.by_q)
    record("NC8 corrupted model code", "round-trip `Me == M`", r.by_M && !r.by_match)
end

# --- NC6, NC7: does the emitted file catch these on its own, with no repository beside it? ----

println("\n=== NC6: the upstream copy alone, corrupted equilibrium ===")
record("NC6 corrupted equilibrium, upstream copy alone",
       "the emitted file's own `z ≈ case.z`",
       own_tests_fail(mutant("LiveZ", [A_COMP_Z => replace(A_COMP_Z, "[7.0, 8.0" => "[7.001, 8.0")];
                             strip_tests = false)))

println("\n=== NC7: the upstream copy alone, corrupted parameter ===")
record("NC7 corrupted parameter, upstream copy alone",
       "the emitted file's own `z ≈ case.z`",
       own_tests_fail(mutant("LiveQ", [A_ALPHA => " alpha = [20.0, 15.0, 10.5],"];
                             strip_tests = false)))

# --- NC9-NC11: the same test in CCOpt.jl's layout --------------------------------------------
#
# `upstream/ccopt/test/` holds the model file and the solver file a pull request would add.
# They are loaded the way CCOpt's `runtests.jl` loads its own, into one namespace holding
# `Test`, `CCOpt` and `MadNLP`. The targets below are as the formatter writes them.

const LAYOUT = joinpath(REPO, "upstream", "ccopt", "test")
const LAYOUT_MODEL = joinpath(LAYOUT, "models", "murphy-smeers-lcp.jl")
const LAYOUT_SOLVERS = joinpath(LAYOUT, "solvers", "murphy-smeers.jl")
const LAYOUT_Z = "z = [7.0, 8.0, 7.0, 4.0, 0.0, 8.0, 8.0, 8.0, 2.0, 0.0, 0.0, 4.0, 2.0, 1.0],"

"""
    layout_mutant(tag, mutations; run_tests) -> (sandbox, own_tests_failed)

The layout's model file with `mutations` applied (first occurrence of each), loaded into a
fresh namespace like CCOpt's; with `run_tests`, the solver file is then included too, and
whether its testsets failed is reported.
"""
function layout_mutant(tag, mutations; run_tests::Bool)
    body = read(LAYOUT_MODEL, String)
    for (old, new) in mutations
        occursin(old, body) || error("mutation target not found for $tag:\n$old")
        body = replace(body, old => new, count = 1)
    end
    path = joinpath(SCRATCH, "layout_$tag.jl")
    write(path, body)
    sandbox = Module(:CCOptTestNamespace)
    Core.eval(sandbox, :(using Test, CCOpt, MadNLP))
    Base.include(sandbox, path)
    failed = false
    if run_tests
        try
            Base.include(sandbox, LAYOUT_SOLVERS)
        catch
            failed = true
        end
    end
    return sandbox, failed
end

top_level_names(sandbox) =
    setdiff(names(sandbox; all = true), names(Module(:CCOptTestNamespace); all = true))

println("\n=== NC0L: the unmutated layout ===")
let (sb, failed) = layout_mutant("Clean", Pair{String,String}[]; run_tests = true)
    r = roundtrip_report(sb.MurphySmeersLCP)
    println("  own testsets failed? ", failed, "   round-trip fires? ", r.any,
            "   top-level names: ", top_level_names(sb))
    record("NC0L unmutated layout", "own testsets pass, round trip silent, one name",
           !failed && !r.any && top_level_names(sb) == [:MurphySmeersLCP])
end

println("\n=== NC9: layout, inlined equilibrium corrupted, caught by its own testsets ===")
let (sb, failed) = layout_mutant("Z", [LAYOUT_Z => replace(LAYOUT_Z, "[7.0, 8.0" => "[7.001, 8.0")];
                                 run_tests = true)
    r = roundtrip_report(sb.MurphySmeersLCP)
    record("NC9 layout, corrupted equilibrium", "its own testsets, and round-trip `case.z`",
           failed && r.by_z)
end

println("\n=== NC10: layout, assembly corrupted, parameters intact ===")
let (sb, _) = layout_mutant("Asm", [ASSEMBLY => "M[r, ix_y(i, s)] = beta"]; run_tests = false)
    r = roundtrip_report(sb.MurphySmeersLCP)
    record("NC10 layout, corrupted model code", "round-trip `Me == M`", r.by_M && !r.by_match)
end

println("\n=== NC11: layout, a helper leaked to the top level of CCOpt's namespace ===")
let (sb, _) = layout_mutant("Leak", ["end # module MurphySmeersLCP" =>
                                     "end # module MurphySmeersLCP\nconst CASES = MurphySmeersLCP.CASES"];
                            run_tests = false)
    leaked = top_level_names(sb)
    println("  top-level names: ", leaked)
    record("NC11 layout, name leaked", "only `MurphySmeersLCP` at the top level",
           leaked != [:MurphySmeersLCP])
end

# --- summary ---------------------------------------------------------------------------------

println("\n", "="^88)
println("NEGATIVE CONTROL SUMMARY")
println("="^88)
# A control that behaved unexpectedly is a check that is not checking. NC5b is the one
# control expected *not* to fire: it is the sensitivity floor, not a defect.
const GAPS = count(r -> r[3] != r[4], RESULTS)
for (name, checker, caught, expect) in RESULTS
    note = expect ? "" : "   (expected to slip through: this is the sensitivity floor)"
    @printf("  [%s] %-44s %s%s\n", caught == expect ? "ok  " : "GAP ", name, checker, note)
end
println()
if GAPS == 0
    println("Every control behaved as expected. Each check has now been seen to fail.")
else
    println("$GAPS control(s) did not behave as expected — a check above is not checking.")
end
exit(GAPS == 0 ? 0 : 1)
