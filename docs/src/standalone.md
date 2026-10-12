# The standalone files

Three of the tutorial's four chapters also exist as a single self-contained Julia file:
the model, the data, the known answers and the assertions, with no dependency on this
repository or on the engine. They were written for CCOpt.jl's maintainers, who could drop
one into their `test/` directory without taking on a dependency, and they serve equally
well as the shortest route to running a chapter somewhere else.

| File | Chapter | What it asserts | What it reports | Size |
|---|---|---|---|---|
| [`test_murphy_smeers_lcp.jl`](generated/standalone/test_murphy_smeers_lcp.jl) | 1 | Both CCOpt methods reach the four known unique solutions | — | 24 assertions |
| [`closed_loop_demonstration.jl`](generated/standalone/closed_loop_demonstration.jl) | 2 | Three roots of the first-order condition on each instance, exactly one of them an equilibrium; the dual ray at each corner | — | 82 assertions, about 30 s |
| [`hard_case_near_tie.jl`](generated/standalone/hard_case_near_tie.jl) | 3 and 4 | The ground truth of each near-tie, and that CCOpt returns one of the two wells | How often CCOpt finds the better well | about 30 s |

Each imports only `Test`, `LinearAlgebra`, `SparseArrays`, `NLPModels`, `MPCCModels`,
`MadNLP` and `CCOpt`, which is CCOpt.jl's own declared test environment plus the standard
library. That claim has been checked by running, not by reading: each file passes in a
throwaway project built from CCOpt's `test/Project.toml` and nothing else (`FINDINGS.md`
F-0011).

## Running one

In any directory, with nothing else installed:

```
julia -e 'using Pkg; Pkg.activate(temp = true); Pkg.add(["CCOpt", "MPCCModels", "NLPModels", "MadNLP"]); include("hard_case_near_tie.jl")'
```

The first run spends most of its time compiling MadNLP and CCOpt for model types they have
not seen. Once compiled, the eight solves of the first file take about 45 milliseconds.

## Generated, never written

None of the three was written by hand, and none should be edited by hand. Each is produced
by a script in `scripts/`, which splices the model into the file verbatim from the sources
this repository tests, between `# emit:<tag>:begin` and `# emit:<tag>:end` markers, and
inlines the parameters and answers from `data/`. What the emitter writes itself is only
the scaffolding: the imports, the table of cases, the test sets and the header. Nothing
that could be wrong about the economics or the arithmetic is retyped (`DECISIONS.md`
D-0001).

Three checks keep the copies honest:

1. **A round trip.** The test suite includes each file, so its own assertions run, and then
   requires the matrices its inlined parameters build to be `==` to the ones the in-repo
   model builds. Equality rather than a tolerance is possible because the file *is* the
   model, not a transcription of it (F-0009).
2. **A staleness gate.** `generated.toml` records a hash of each file and of every source
   it is spliced from, including two engine files across the repository boundary, and
   `ci/gates/check_stale_generated.py` fails when a source changes without the file being
   regenerated.
3. **Negative controls.** `scripts/negative_controls.jl` breaks a copy of the first file
   eight ways, one token at a time, and fails unless the check that should notice each break
   does (F-0010). A check that has never been seen to fail is not yet known to be a check.

Each file's header says, in its own words, that the instances are constructed, that the
paper publishes no numbers, and what the file does and does not claim. A reader who sees
only one of these files should not come away believing it reproduces published results.
