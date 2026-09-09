# CapacityEquilibriaBenchmarks.jl

Published capacity-expansion equilibrium models with published answers, built twice each:
once as a complementarity problem solved with PATH, treated as ground truth, and once as an
MPCC for CCOpt.jl, treated as the object under test.

Two outputs, deliberately kept distinct: a replication study (does this Julia implementation
reproduce the paper's numbers), and a validation contribution to CCOpt.jl (given a problem
whose answer is known, does CCOpt.jl reach it).

**Status: Phase 1 complete; Phase 2's solver-agreement half done.** Murphy and Smeers'
competitive and open-loop Cournot models are built as linear complementarity problems,
solved with both PATH and CCOpt.jl, and validated on two constructed instances against a
hand derivation, an exhaustive enumeration, and the paper's own theorems.
`docs/REPLICATION_REPORT.md` is the synthesis. Not yet done from Phase 2: CCOpt's penalty
route, and the emitted upstream test file.

**One thing to know before reading any number here.** The edition of the paper in hand — the
May 2002 working paper — publishes no numerical example, so there were no tables to
transcribe and there are no published numbers to match (`FINDINGS.md` F-0001). Instance A
is constructed to satisfy the paper's stated assumptions, and "validated" means that PATH's
point coincides with a hand derivation and with an exhaustive enumeration of complementarity
patterns, and that every property the paper proves about the equilibrium holds at it
(`DECISIONS.md` D-0004). Nothing here is Murphy and Smeers' result, and the published 2005
article has no numerical example either (F-0002), so there is none to aim at. Instance A is
built to be solved by hand; instance B is built to be reasonable — GW, $/MWh, a gas peaker
against a combined-cycle plant over four quarter-year load blocks.

## Layout

| Path | What it is |
|---|---|
| `data/` | The two instances and their derived equilibria, each file stating where every value came from. See `data/PROVENANCE.md` — this is the repository's one dangerous area. |
| `src/murphy_smeers.jl` | The two open-loop models as `(M, q)` for the engine's `lcp_model`, a second row-by-row transcription of the equations to check the assembly against, and the paper's stated properties as checks on a point. |
| `src/enumerate_lcp.jl` | The solver-free oracle: every solution of a small LCP by enumerating its complementarity patterns, plus the monotonicity and strict-complementarity checks that make one solution provably the only one. |
| `test/` | The validation: both instances, both models, both solvers, each property cited to its page. |
| `docs/` | The plan and its corrections, the derivations of both instances, and the replication report. |
| `scripts/` | `report_agreement.jl` prints the solver-agreement table. The emitters arrive with the rest of Phase 2. |
| `upstream/` | Empty until Phase 2: the generated upstream test files. |

## Getting set up

This project reaches the engine by relative path, so clone both side by side:

```
Code dev/CapacityEquilibria/
  ├── CapacityEquilibria.jl
  └── CapacityEquilibriaBenchmarks.jl
```

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

About three minutes after precompilation, most of it the enumeration of instance B's 2¹⁸
patterns. No PATH licence is needed at 14 and 18 variables, though the engine's README
explains how to set one before it is.

`Manifest.toml` is committed here, unlike in the engine: this is a reproducible study rather
than a library, and the resolved dependency versions are part of the result (`DECISIONS.md`,
D-0003).

### PATH licence

Without a licence PATH runs in demonstration mode (300 variables, 2000 nonzeros), which is
enough for the two instances here and will not be enough for the closed-loop runs. The PATH
authors publish a courtesy licence string at
<https://pages.cs.wisc.edu/~ferris/path/julia/LICENSE>; set it as the `PATH_LICENSE_STRING`
environment variable, permanently rather than per session, following
<https://pages.cs.wisc.edu/~ferris/path/julia/README>. The engine's README has the
per-shell commands and the test that checks the licence is actually in effect. The string
is not recorded anywhere in this repository, and should not be.

## Using the models

```julia
using CapacityEquilibriaBenchmarks, CapacityEquilibria

data = load_ms_instance("data/ms2002_instance_b.toml")   # checks the paper's assumptions
M, q, ix = ms_lcp(data, :open_loop_cournot)              # or :competitive
sol = solve_complementarity(() -> lcp_model(M, q), :path)   # or :ccopt
lcp_residual(M, q, sol.x).worst                          # the pass criterion, not sol.status
pt = ms_unpack(data, sol.x)                               # pt.x, pt.y, pt.λ, pt.price
enumerate_lcp_solutions(M, q).solutions                   # every solution, no solver
```

## The rules that matter most

**Every parameter traces to a table and a page**, recorded in `data/` beside the value — or,
where the source has no table, the file says the value is constructed and cites the
assumption it was chosen to satisfy. The plan calls this the single highest-risk point in
the whole exercise, because every later comparison is downstream of it.

**Never adjust a value to make a result match.** A mismatch is investigated — solver
settings, then units, then transcription, then the paper's own ambiguity — and the
explanation is recorded as a finding. Tuning until the numbers agree destroys the only thing
this repository is for.

**`upstream/` is generated.** Edit the emitter in `scripts/`, never the artifact. The
round-trip check is what stops the copy CCOpt.jl's maintainers hold from drifting away from
the model that validated it.

## Documents

- `AGENTS.md` — the agent guide, and the hard rules
- `docs/REPLICATION_REPORT.md` — the authoritative synthesis of results
- `docs/ms_ccopt_replication_plan.md` — the phased plan, and its corrections
- `docs/ms2002_instance_a_derivation.md`, `docs/ms2002_instance_b_derivation.md` — the equilibria, by hand
- `data/PROVENANCE.md` — where every number came from
- `FINDINGS.md`, `DECISIONS.md` — the claim ledger and the decision log

## Acknowledgements

The ground-truth solves here depend on PATH. Thanks to Steven Dirkse, Michael Ferris and
Todd Munson for making the solver, and a courtesy licence for it, freely available to
academic users, and to Oscar Dowson and the PATHSolver.jl contributors for the Julia
interface that makes it usable from JuMP.
