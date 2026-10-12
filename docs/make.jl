# Build the documentation site.
#
#     julia --project=docs -e 'using Pkg; Pkg.instantiate()'
#     julia --project=docs docs/make.jl
#
# The site is written to docs/build/. Like the rest of this repository it reaches the engine
# by relative path, so CapacityEquilibria.jl must be cloned beside it.
#
# THE TUTORIALS ARE TESTS. Every code block in docs/src/tutorials/ runs during the build, on
# instance A, and each claim the prose makes is an `@assert` beside the code that produces
# it. A claim that stops holding fails the build rather than going stale. The build takes
# a few minutes, most of it compiling CCOpt and MadNLP.
#
# NOTHING IS DUPLICATED. The replication report, the derivations, the provenance notes and
# the two ledgers are copied in from their canonical files at build time, and the three
# generated upstream files are copied in as downloads. None of them is edited here.

using Documenter
using CapacityEquilibria
using CapacityEquilibriaBenchmarks

const DOCS = @__DIR__
const REPO = normpath(joinpath(DOCS, ".."))
const GENERATED = joinpath(DOCS, "src", "generated")

# Canonical file => page in the site.
const COPIED = [
    joinpath(REPO, "docs", "REPLICATION_REPORT.md") => "report.md",
    joinpath(REPO, "docs", "ms2002_instance_a_derivation.md") => "derivation_a.md",
    joinpath(REPO, "docs", "ms2002_instance_b_derivation.md") => "derivation_b.md",
    joinpath(REPO, "data", "PROVENANCE.md") => "provenance.md",
    joinpath(REPO, "FINDINGS.md") => "findings.md",
    joinpath(REPO, "DECISIONS.md") => "decisions.md",
]

# The standalone files, offered for download exactly as generated.
const STANDALONE = ["test_murphy_smeers_lcp.jl", "closed_loop_demonstration.jl",
                    "hard_case_near_tie.jl"]

# Julia's Markdown reads `$` as interpolation, so "$/MWh" in the copied prose would render
# without its dollar sign. Escape every `$` outside code, where a backslash would show.
function escape_dollars(text::AbstractString)
    out = String[]
    fenced = false
    for line in split(text, '\n')
        if startswith(lstrip(line), "```")
            fenced = !fenced
        elseif !fenced
            parts = String.(split(line, '`'))
            for k in 1:2:length(parts)
                parts[k] = replace(parts[k], "\$" => "\\\$")
            end
            line = join(parts, '`')
        end
        push!(out, line)
    end
    return join(out, '\n')
end

rm(GENERATED; force = true, recursive = true)
mkpath(joinpath(GENERATED, "standalone"))
for (src, dst) in COPIED
    write(joinpath(GENERATED, dst), escape_dollars(read(src, String)))
end
for f in STANDALONE
    cp(joinpath(REPO, "upstream", f), joinpath(GENERATED, "standalone", f))
end

makedocs(;
    sitename = "CapacityEquilibriaBenchmarks.jl",
    authors = "Archie Chapman",
    modules = [CapacityEquilibriaBenchmarks],
    checkdocs = :exports,
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = nothing,
        repolink = "https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl",
        size_threshold = 400_000,     # the ledger is one long page, on purpose
    ),
    remotes = nothing,
    pages = [
        "Home" => "index.md",
        "Tutorial: the benchmark ladder" => [
            "Overview" => "tutorials/index.md",
            "Part 1: An equilibrium you can solve by hand" => "tutorials/1_open_loop.md",
            "Part 2: Three roots, one equilibrium" => "tutorials/2_closed_loop.md",
            "Part 3: The best response as an MPCC" => "tutorials/3_best_response.md",
            "Part 4: Engineering a hard case" => "tutorials/4_hard_case.md",
        ],
        "The standalone files" => "standalone.md",
        "Results" => [
            "Replication report" => "generated/report.md",
            "Instance A, by hand" => "generated/derivation_a.md",
            "Instance B, by hand" => "generated/derivation_b.md",
            "Data provenance" => "generated/provenance.md",
        ],
        "Ledgers" => [
            "Findings" => "generated/findings.md",
            "Decisions" => "generated/decisions.md",
        ],
        "API reference" => "api.md",
    ],
)

# Deployment happens only from CI, and only once the repository is public, which is its
# owner's decision (DECISIONS.md D-0002). Run locally, this is skipped.
if get(ENV, "CI", "false") == "true"
    deploydocs(; repo = "github.com/archiechapman/CapacityEquilibriaBenchmarks.jl.git",
               devbranch = "main", push_preview = false)
end
