# CapacityEquilibriaBenchmarks.jl

Published capacity-expansion equilibrium models, on instances whose answers are known
independently of any solver, built twice each: once as a complementarity problem solved
with PATH, treated as ground truth, and once as an MPCC for CCOpt.jl, treated as the object
under test.

Two outputs, deliberately kept distinct: a replication study (does this Julia implementation
reproduce the paper's model and every result it proves), and a validation contribution to
CCOpt.jl (given a problem whose answer is known, does CCOpt.jl reach it).

**Status: Phases 1 to 3 complete; Phase 4 in progress.** Murphy and Smeers' competitive and
open-loop Cournot models are built as linear complementarity problems, solved with PATH and
with both of CCOpt.jl's methods over four routes, and validated on two constructed
instances against a hand derivation, an exhaustive enumeration, and the paper's own
theorems. The closed-loop model is transcribed, both instances' closed-loop equilibria are
found by a solver-free enumeration and checked against every comparative result the paper
states, diagonalization reaches the same point from every start tried, and two further
roots of the equilibrium condition on each instance are shown to be kinks that are not
equilibria. Phase 4 has built one player's best response as a genuine MPCC, which CCOpt
solves to its known global optimum on every case tried, and a deliberately hard version of
it on which CCOpt finds the better of two nearly tied optima about half the time. The
monolithic joint system the plan describes is not built, because it is not the
reformulation the plan took it for. Three self-contained files for CCOpt.jl are generated
into `upstream/`; none has been offered to anyone.

**One thing to know before reading any number here.** Neither edition of the paper, the May
2002 working paper or the 2005 *Operations Research* article, publishes a numerical
example, so there were no tables to transcribe and there are no published numbers to match
(`FINDINGS.md` F-0001, F-0002). Both instances are constructed to satisfy the paper's
stated assumptions, and "validated" means that PATH's point coincides with a hand
derivation and with an exhaustive enumeration of complementarity patterns, and that every
property the paper proves about the equilibrium holds at it (`DECISIONS.md` D-0004).
Nothing here is Murphy and Smeers' result. Instance A is built to be solved by hand;
instance B is built to be reasonable — GW, $/MWh, a gas peaker against a combined-cycle
plant over four quarter-year load blocks.

## What was found

| Benchmark | Result | Ledger |
|---|---|---|
| Competitive and open-loop Cournot, both instances | Unique equilibria, derived by hand and confirmed by enumeration; PATH and both CCOpt methods reach them over four routes, the two relaxation routes bitwise identically | F-0004 to F-0008 |
| Closed-loop Cournot, both instances | Three roots of the equilibrium condition (16) per instance, one of them an equilibrium; the other two are corners at which a player holds nothing, the output stage is degenerate, and (16) does not apply because the corner is a kink | F-0012 to F-0015, F-0018 |
| One player's best response as an MPCC | CCOpt reaches the known global optimum on all 32 solves, 8 of them started at the degenerate corners | F-0016, F-0018 |
| The best response tuned to a near-tie | Two local optima far apart and level to fourteen figures; CCOpt, started in the worse one, finds the better in 16 of 32 problems; both methods fail, on different problems | F-0017 |

F-0018 is a correction worth knowing about. The ledger first explained the corner roots as
local optima that a first-order condition cannot see past. They are not local optima: the
player holding nothing gains from its very first unit of capacity. The corners satisfy (16)
only because a biactive pair, idle and at capacity at once, is read as idle. The
documentation's tutorial caught this when its own assertion failed.

## Layout

| Path | What it is |
|---|---|
| `data/` | The two instances and their derived equilibria, each file stating where every value came from. See `data/PROVENANCE.md` — this is the repository's one dangerous area. |
| `src/murphy_smeers.jl` | The two open-loop models as `(M, q)` for the engine's `lcp_model`, a second row-by-row transcription of the equations to check the assembly against, and the paper's stated properties as checks on a point. |
| `src/enumerate_lcp.jl` | The solver-free oracle: every solution of a small LCP by enumerating its complementarity patterns, plus the monotonicity and strict-complementarity checks that make one solution provably the only one. |
| `src/murphy_smeers_closed_loop.jl` | The closed-loop model of the paper's section 6: the short-run equilibrium at fixed capacities, Lemma 7's closed-form sensitivity of it to capacity, and equation (16) written twice. |
| `src/enumerate_closed_loop.jl`, `src/diagonalize_closed_loop.jl` | Phase 3: two independent routes to the closed-loop equilibrium, a solver-free enumeration of every root and best-response iteration with convergence diagnostics. |
| `src/best_response_mpcc.jl`, `src/hard_best_response.jl` | Phase 4: one player's best response as a genuine MPCC for CCOpt, and the search that tunes it until two optima are tied to fourteen figures and far apart. |
| `test/` | The validation: both instances, all three models, every backend, each property cited to its page. |
| `docs/src/` | The documentation site: a four-part tutorial, the page on the standalone files, and the API reference. |
| `docs/` | Also the plan and its corrections, the derivations of both instances, and the replication report. |
| `scripts/` | `report_agreement.jl` prints the solver-agreement table; `emit_upstream_test.jl`, `emit_closed_loop_demo.jl` and `emit_hard_case.jl` write the three upstream files; `negative_controls.jl` breaks a copy of the first eight ways and checks the tests notice; `check_upstream_portable.jl` runs the files in a CCOpt-only environment; `share_upstream.sh` publishes them as gists. |
| `upstream/` | Three generated files — `test_murphy_smeers_lcp.jl`, the open-loop regression test; `closed_loop_demonstration.jl`, which shows the first-order conditions admitting roots that are not equilibria; and `hard_case_near_tie.jl`, a deliberately hard MPCC on which CCOpt is about a coin flip — beside the hand-written notes that would accompany them: `ISSUE.md`, `PULL_REQUEST.md` and `NOTE_first_order_conditions.md`. Edit the emitters, never the files. Nothing has been posted. |

## Getting set up

This project reaches the engine by relative path, so clone both side by side:

```
CapacityEquilibria/
  ├── CapacityEquilibria.jl
  └── CapacityEquilibriaBenchmarks.jl
```

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

923 tests (973 with `RUN_CLOSED_LOOP=true`), including the ones the three emitted upstream
files run for themselves. About seven minutes after precompilation, most of it the
enumeration of instance B's 2¹⁸ patterns and compiling the three upstream files. No PATH
licence is needed at these sizes, which top out at 18 variables; the engine's README
explains how to set one, and how the engine checks that it has taken.

`Manifest.toml` is committed here, unlike in the engine: this is a reproducible study rather
than a library, and the resolved dependency versions are part of the result (`DECISIONS.md`,
D-0003).

## Documentation

A documentation site builds from `docs/`:

```
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl          # writes docs/build/index.html
```

Its centre is **the benchmark ladder**, a tutorial that is the whole benchmark series read in
the order it was built, on instance A. Each part takes away one property that made the one
before it easy:

1. *An equilibrium you can solve by hand* — the open-loop models, their unique answers found
   three ways without a solver, four solver routes marked against them.
2. *Three roots, one equilibrium* — the closed-loop game, every root of its equilibrium
   condition, the scan that refutes two of them, the kink that makes them roots, and the
   degeneracy that comes with it.
3. *The best response as an MPCC* — one player's problem handed to CCOpt, with its global
   optimum known exactly.
4. *Engineering a hard case* — the tie search, and CCOpt started in the wrong well.

Parts 1, 2 and 4 each end with the standalone upstream file that packages them, which the
site offers as a download. Every code block runs during the build, and every claim in the
prose is an `@assert` beside the code, so a claim that stops holding fails the build. The
build takes about three minutes. The replication report, the derivations, the provenance
notes and the two ledgers are copied into the site from their canonical files at build
time, never duplicated. The plan and the drafted notes to CCOpt.jl's maintainers are left
out. `make.jl` deploys only from CI, which does not exist yet and will not until this
repository is public (D-0002).

## Using the models

```julia
using CapacityEquilibriaBenchmarks, CapacityEquilibria

data = load_ms_instance("data/ms2002_instance_b.toml")   # checks the paper's assumptions
M, q, ix = ms_lcp(data, :open_loop_cournot)              # or :competitive
sol = solve_complementarity(M, q, :path)                  # or :ccopt, :ccopt_relaxation,
lcp_residual(M, q, sol.x).worst                          #    :ccopt_penalty
pt = ms_unpack(data, sol.x)                               # pt.x, pt.y, pt.λ, pt.price
enumerate_lcp_solutions(M, q).solutions                   # every solution, no solver

roots = enumerate_closed_loop(data)                       # every root of (16), no solver
[best_response_gap(data, x).gap for x in roots.solutions] # zero only at an equilibrium
```

The four backends are PATH, CCOpt's relaxation method through JuMP, and CCOpt's relaxation
and penalty methods through an `MPCCModel` the engine builds directly — the only route to
the penalty method (`CapacityEquilibria.jl` `FINDINGS.md` F-0004). The pass criterion is
always the recomputed residual, never the solver's own status.

## The rules that matter most

**Every parameter traces to a table and a page**, recorded in `data/` beside the value — or,
where the source has no table, the file says the value is constructed and cites the
assumption it was chosen to satisfy. The plan calls this the single highest-risk point in
the whole exercise, because every later comparison is downstream of it.

**Never adjust a value to make a result match.** A mismatch is investigated — solver
settings, then units, then transcription, then the paper's own ambiguity — and the
explanation is recorded as a finding. Tuning until the numbers agree destroys the only thing
this repository is for.

**No root of (16) is an equilibrium until a best-response check says so.** The equilibrium
condition is a first-order condition, and on both instances two of its three roots are not
equilibria (`DECISIONS.md` D-0006).

**`upstream/` is generated.** Edit the emitter in `scripts/`, never the artifact. After any
change to `data/`, to the model files in `src/`, or to the two engine files the emitters
splice, rerun `emit_upstream_test.jl`, `emit_closed_loop_demo.jl` and `emit_hard_case.jl`,
then `python ci/gates/check_stale_generated.py . --write`. The round-trip checks in the test
suite stop the copies CCOpt.jl's maintainers would hold from drifting away from the model
that validated them; the staleness gate stops the files in this repository drifting from
their own sources.

## Documents

- `AGENTS.md` — the agent guide, and the hard rules
- `docs/src/` — the documentation site's own pages; `docs/make.jl` builds it
- `docs/REPLICATION_REPORT.md` — the authoritative synthesis of results
- `docs/ms_ccopt_replication_plan.md` — the phased plan, and its corrections
- `docs/ms2002_instance_a_derivation.md`, `docs/ms2002_instance_b_derivation.md` — the equilibria, by hand
- `data/PROVENANCE.md` — where every number came from
- `FINDINGS.md`, `DECISIONS.md` — the claim ledger and the decision log

## Acknowledgements

The ground-truth solves here depend on PATH. Thanks to Steven Dirkse, Michael Ferris and
Todd Munson for making the solver, and a courtesy licence for it, freely available to
academic users, and to Oscar Dowson and the PATHSolver.jl contributors for the Julia
interface that makes it usable from JuMP. Thanks also to François Pacaud, Anton Pozharskiy
and Armin Nurkanović for CCOpt.jl, the solver these benchmarks exist to test.
