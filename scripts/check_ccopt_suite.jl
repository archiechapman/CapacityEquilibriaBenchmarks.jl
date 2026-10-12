# Does the test case pass inside CCOpt.jl's own test suite, the way it would be merged?
#
#     julia scripts/check_ccopt_suite.jl [REV] [CHANNEL ...]
#
# REV is a CCOpt.jl git revision (default `master`); each CHANNEL is a juliaup channel
# (default `1.10 release 1.12`, which covers CCOpt's `julia = "1.10"` floor, the current
# release and the next). `scripts/check_upstream_portable.jl` checks that the single file
# runs beside CCOpt's test dependencies; this checks the layout under `upstream/ccopt/` as
# a pull request would deliver it:
#
#   1. clone CCOpt.jl at REV, copy `test/models/murphy-smeers-lcp.jl` and
#      `test/solvers/murphy-smeers.jl` into it, and add their two `include` lines to its
#      `test/runtests.jl`, beside the files they mirror;
#   2. run CCOpt's formatter settings over the two files with the pinned JuliaFormatter in
#      `scripts/format/`, and require that nothing changes, as their pre-commit hook would;
#   3. run CCOpt's whole test suite, `Pkg.test()`, under each channel, so that a name
#      collision with their own test files or a Julia-version incompatibility fails here.
#
# Exits nonzero if any step fails. Needs git, juliaup and the network.

const REPO = normpath(joinpath(@__DIR__, ".."))
const LAYOUT = joinpath(REPO, "upstream", "ccopt")
const FILES = [joinpath("test", "models", "murphy-smeers-lcp.jl"),
               joinpath("test", "solvers", "murphy-smeers.jl")]
const FORMAT_ENV = joinpath(REPO, "scripts", "format")
const URL = "https://github.com/madsuite-org/CCOpt.jl"

const REV = isempty(ARGS) ? "master" : ARGS[1]
const CHANNELS = length(ARGS) > 1 ? ARGS[2:end] : ["1.10", "release", "1.12"]

# Where the two include lines go: each after the line of the file it mirrors.
const INCLUDES = [
    "include(\"models/simple-mpcc-model.jl\")" => "include(\"models/murphy-smeers-lcp.jl\")",
    "include(\"solvers/penalty.jl\")" => "include(\"solvers/murphy-smeers.jl\")",
]

for f in FILES
    isfile(joinpath(LAYOUT, f)) ||
        error("no $(joinpath(LAYOUT, f)); run julia --project scripts/emit_upstream_test.jl")
end

# Kept after exit, so that the per-channel logs can be read when something fails.
work = mktempdir(; prefix = "ccopt_suite_", cleanup = false)
clone = joinpath(work, "CCOpt.jl")
run(`git -c core.autocrlf=false clone --quiet $URL $clone`)
run(`git -C $clone -c core.autocrlf=false checkout --quiet $REV`)
sha = readchomp(`git -C $clone rev-parse --short HEAD`)
println("CCOpt.jl at $REV ($sha), cloned to $clone")

# --- 1. place the files ----------------------------------------------------------------------

for f in FILES
    cp(joinpath(LAYOUT, f), joinpath(clone, f); force = true)
end
runtests = joinpath(clone, "test", "runtests.jl")
let text = read(runtests, String)
    for (anchor, line) in INCLUDES
        count(anchor, text) == 1 || error("expected one `$anchor` in CCOpt's test/runtests.jl")
        text = replace(text, anchor => anchor * "\n" * line)
    end
    write(runtests, text)
end
println("\nplaced the two files and their include lines:")
run(`git -C $clone --no-pager diff --stat`)

# --- 2. formatting ---------------------------------------------------------------------------

println("\n--- formatting under CCOpt's settings ---")
before = Dict(f => read(joinpath(clone, f), String) for f in FILES)
fmt = """
    import Pkg
    Pkg.instantiate(; io = devnull)
    using JuliaFormatter
    format(ARGS)
"""
run(`$(Base.julia_cmd()) --startup-file=no --project=$FORMAT_ENV -e $fmt $([joinpath(clone, f) for f in FILES])`)
unformatted = [f for f in FILES if read(joinpath(clone, f), String) != before[f]]
formatted_ok = isempty(unformatted)
println(formatted_ok ? "unchanged by the formatter" :
        "the formatter changed: " * join(unformatted, ", "))
for f in FILES
    write(joinpath(clone, f), before[f])     # test what was emitted, not what was reformatted
end

# --- 3. their suite, per Julia version -------------------------------------------------------
#
# A run whose tests never started (Pkg itself failing to load or precompile, a resolver or
# network failure) says nothing about the test, so it is retried once and, if it still
# never starts, reported as inconclusive rather than as a failure. A run whose tests did
# start and failed is attributed: the same channel runs an untouched clone of the same
# revision, and if that fails too the failure is CCOpt's on that Julia version.

# The untouched copy: a local clone of the same commit, without the two files or includes.
pristine = joinpath(work, "CCOpt-pristine.jl")
run(`git -c core.autocrlf=false clone --quiet $clone $pristine`)

# Printed by `Pkg.test()` once the test environment is resolved and the tests begin.
const STARTED = "Running tests..."
# The name of the testset in `test/solvers/murphy-smeers.jl`, which its summary line prints.
const OURS = "Murphy-Smeers LCP Test"

"""
    run_suite(dir, ch, log) -> Symbol

`Pkg.test()` for the project at `dir` under juliaup channel `ch`, output to `log`:
`:passed`, `:failed` (the tests ran and failed), or `:not_started`.
"""
function run_suite(dir, ch, log)
    proc = open(log, "w") do io
        run(pipeline(ignorestatus(`julia +$ch --startup-file=no --project=$dir -e "import Pkg; Pkg.test()"`);
                     stdout = io, stderr = io))
    end
    text = read(log, String)
    if proc.exitcode == 0
        # A pass only counts for the copy carrying the test if the test actually ran in it.
        dir == clone && !occursin(OURS, text) &&
            error("CCOpt's suite passed but `$OURS` never ran in it; see $log")
        return :passed
    end
    return occursin(STARTED, text) ? :failed : :not_started
end

function run_suite_retrying(dir, ch, log)
    outcome = run_suite(dir, ch, log)
    if outcome === :not_started
        println("  the tests never started (see $log); retrying once")
        outcome = run_suite(dir, ch, replace(log, ".log" => "-retry.log"))
    end
    return outcome
end

# (label, with the test, untouched CCOpt or `nothing` when not needed)
results = Tuple{String,Symbol,Union{Nothing,Symbol}}[]
for ch in CHANNELS
    println("\n--- CCOpt's test suite under julia +$ch ---")
    # Load Pkg once first, so that compiling it is not the first thing the suite run does.
    run(ignorestatus(`julia +$ch --startup-file=no -e "import Pkg"`))
    version = readchomp(`julia +$ch --startup-file=no -e "print(VERSION)"`)
    log = joinpath(work, "suite-$version.log")
    outcome = run_suite_retrying(clone, ch, log)
    println("julia $version, with the test: $outcome")
    base = nothing
    if outcome === :failed
        println(last(read(log, String), 3000))
        base = run_suite_retrying(pristine, ch, joinpath(work, "suite-$version-pristine.log"))
        println("julia $version, untouched CCOpt: $base")
    end
    push!(results, ("julia $version", outcome, base))
end

println("\n", "="^72)
println("CCOpt.jl $REV ($sha)   logs: $work")
println("  formatting:                 ", formatted_ok ? "clean" : "NOT CLEAN")
for (label, outcome, base) in results
    verdict = outcome === :passed ? "passed" :
              outcome === :not_started ? "INCONCLUSIVE: the tests never started" :
              base === :failed ? "fails without the test too: CCOpt's failure, not this test's" :
              "FAILED, and only with the test"
    println("  test suite, ", rpad(label * ":", 16), verdict)
end
# Passing needs every channel to have run the tests: an inconclusive channel is not a pass.
allok = formatted_ok &&
        all(r -> r[2] === :passed || (r[2] === :failed && r[3] === :failed), results)
println(allok ? "\nPASSED" : "\nFAILED")
exit(allok ? 0 : 1)
