# Does the emitted upstream file run where it is meant to run?
#
#     julia --project scripts/check_upstream_portable.jl
#
# The offer made in `upstream/PULL_REQUEST.md` is that the file needs no dependency CCOpt.jl
# does not already have. That is a claim about someone else's project, and reading their
# `test/Project.toml` is not the same as running there. This builds a throwaway project
# holding exactly their declared test dependencies plus CCOpt itself — no JuMP, no
# PATHSolver, no MathOptComplements bridges in use, and neither of this programme's own
# packages — copies the emitted file into it, and runs it.
#
# Two things are checked, and the second is the one that matters:
#
#   1. every `using`/`import` in the emitted file names a package CCOpt's test environment
#      already declares (or CCOpt, which their suite has by definition);
#   2. the file actually loads and passes there.
#
# A file that satisfied (1) and failed (2) would be one reaching a package transitively —
# exactly the failure a reading of the manifest cannot catch.
#
# The check needs the network the first time, to resolve the throwaway project.

import Pkg
import TOML

const REPO = normpath(joinpath(@__DIR__, ".."))
const EMITTED = joinpath(REPO, "upstream", "test_murphy_smeers_lcp.jl")

isfile(EMITTED) || error("no emitted file; run scripts/emit_upstream_test.jl first")

"""Locate the installed CCOpt and read the dependency list of its own test project."""
function ccopt_test_dependencies()
    root = nothing
    for depot in DEPOT_PATH
        dir = joinpath(depot, "packages", "CCOpt")
        isdir(dir) || continue
        for slug in readdir(dir)
            candidate = joinpath(dir, slug, "test", "Project.toml")
            isfile(candidate) && (root = candidate)
        end
    end
    root === nothing && error("could not find CCOpt's test/Project.toml in any depot")
    return sort(collect(keys(get(TOML.parsefile(root), "deps", Dict())))), root
end

"""Every package named by a `using` or `import` line at the top of the emitted file."""
function emitted_imports(path)
    names = String[]
    for line in eachline(path)
        s = strip(line)
        (startswith(s, "using ") || startswith(s, "import ")) || continue
        for part in split(replace(s, r"^(using|import)\s+" => ""), ",")
            name = strip(split(strip(part), ":")[1])
            isempty(name) || push!(names, String(name))
        end
    end
    return unique(names)
end

deps, project_path = ccopt_test_dependencies()
imports = emitted_imports(EMITTED)
# CCOpt is absent from its own test project because it is the package under test.
outside = setdiff(imports, vcat(deps, ["CCOpt"]))

println("CCOpt's test project: ", project_path)
println("  it declares:        ", join(deps, ", "))
println("  the file imports:   ", join(imports, ", "))
println("  outside that set:   ", isempty(outside) ? "none" : join(outside, ", "))
isempty(outside) || error("the emitted file imports $(join(outside, ", ")), which CCOpt's " *
                          "test environment does not carry — the offer in " *
                          "upstream/PULL_REQUEST.md is no longer true")

# --- build the throwaway project and run the file there -------------------------------------

env = mktempdir(; prefix = "ccopt_clean_")
println("\nbuilding a clean project at ", env)
# The three standard libraries need no entry; everything else is added by name, and CCOpt
# is pinned to the version this repository is bounded against (DECISIONS.md D-0003).
addable = filter(d -> d ∉ ("LinearAlgebra", "SparseArrays", "Test"), deps)
build = """
    import Pkg
    Pkg.activate(raw"$env")
    Pkg.add([$(join(("\"$d\"" for d in addable), ", "))])
    Pkg.add(name = "CCOpt", version = "0.1.0")
"""
run(pipeline(`$(Base.julia_cmd()) --startup-file=no -e $build`; stdout = devnull))

target = joinpath(env, basename(EMITTED))
cp(EMITTED, target)
println("running the emitted file there, with nothing else on the load path\n")
proc = run(ignorestatus(`$(Base.julia_cmd()) --startup-file=no --project=$env -e "include(raw\"$target\")"`))

println()
if proc.exitcode == 0
    println("PASSED: the emitted file runs in an environment holding only CCOpt's own test")
    println("dependencies, and imports nothing outside that set.")
else
    println("FAILED with exit code $(proc.exitcode). The file is not portable to CCOpt's")
    println("test environment as it stands, and upstream/PULL_REQUEST.md overstates it.")
end
exit(proc.exitcode)
