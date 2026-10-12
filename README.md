# CapacityEquilibriaBenchmarks.jl

Capacity-expansion equilibrium models on instances whose answers are known independently of
any solver. Each is built twice: as a complementarity problem solved with PATH, treated as
ground truth, and as an MPCC for [CCOpt.jl](https://github.com/madsuite-org/CCOpt.jl),
treated as the object under test. Built on the engine
[CapacityEquilibria.jl](https://github.com/archiechapman/CapacityEquilibria.jl).

The model is Murphy and Smeers' two-player capacity game ("Generation Capacity Expansion in
Imperfectly Competitive Restructured Electricity Markets", *Operations Research* 53(4),
646–661, 2005) under perfect competition, open-loop Cournot and closed-loop Cournot
competition.

**Read this before any number.** Neither edition of the paper, the May 2002 working paper or
the 2005 article, publishes a numerical example, so there are no published numbers to match
(`FINDINGS.md` F-0001, F-0002). Both instances are constructed to satisfy the paper's stated
assumptions. Instance A is built to be solved by hand; instance B to be physically
reasonable: GW, $/MWh, a gas peaker against a combined-cycle plant over four quarter-year
load blocks. "Validated" means a solver's point agrees with a hand derivation and with an
exhaustive enumeration of complementarity patterns, and that every property the paper
proves about the equilibrium holds there (`DECISIONS.md` D-0004). No number here is Murphy
and Smeers' result.

## Results

| Benchmark | Result | Ledger |
|---|---|---|
| Competitive and open-loop Cournot, both instances | Unique equilibria, derived by hand and confirmed by enumeration; PATH and both CCOpt methods reach them over four routes, the two relaxation routes bitwise identically | F-0004 to F-0008 |
| Closed-loop Cournot, both instances | The equilibrium condition (16) has three roots per instance and only one is an equilibrium; the other two are corners where a player holds nothing, the output stage is degenerate, and (16) does not apply because the corner is a kink | F-0012 to F-0015, F-0018 |
| One player's best response as an MPCC | CCOpt reaches the known global optimum on all 32 solves, 8 of them started at the degenerate corners | F-0016, F-0018 |
| The best response tuned to a near-tie | Two local optima far apart and level to fourteen figures; started in the worse one, CCOpt finds the better in 16 of 32 problems; both methods fail, on different problems | F-0017 |

`docs/REPLICATION_REPORT.md` is the full account, with every number and the tolerance it was
judged at.

## Installation

The engine is reached by relative path, so clone both repositories side by side:

```
CapacityEquilibria/
  ├── CapacityEquilibria.jl
  └── CapacityEquilibriaBenchmarks.jl
```

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

927 tests in about seven minutes after precompilation, most of it the enumeration of
instance B's 2¹⁸ patterns and running the three upstream files. `RUN_CLOSED_LOOP=true` adds
the multi-start diagonalization study. No PATH licence is needed at these sizes.
`Manifest.toml` is committed: this is a reproducible study, and the resolved versions are
part of the result (D-0003).

## Usage

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

The pass criterion is always the recomputed residual, never the solver's own status.

## Documentation

```
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl          # writes docs/build/index.html
```

The site's centre is **the benchmark ladder**, a four-part tutorial on instance A in which
each part removes one property that made the one before it easy:

1. *An equilibrium you can solve by hand*: the open-loop models, their unique answers found
   three ways without a solver, and four solver routes marked against them.
2. *Three roots, one equilibrium*: the closed-loop game, every root of its equilibrium
   condition, the scan that refutes two of them, and the kink that makes them roots.
3. *The best response as an MPCC*: one player's problem handed to CCOpt, with its global
   optimum known exactly.
4. *Engineering a hard case*: the tie search, and CCOpt started in the wrong well.

Every claim in the prose is an `@assert` beside the code, so the build is a test. The
report, derivations, provenance notes and ledgers are copied in from their canonical files
at build time.

## Files for CCOpt.jl

`upstream/` holds three self-contained files, each runnable in CCOpt.jl's own test
environment with no added dependency (F-0011):

- `test_murphy_smeers_lcp.jl`: the four open-loop problems as a regression test, with known
  unique answers that both CCOpt methods reach.
- `closed_loop_demonstration.jl`: first-order conditions with three roots of which one is an
  equilibrium, and the degeneracy at the other two. A demonstration, not a regression test.
- `hard_case_near_tie.jl`: the near-tie, on which CCOpt finds the better optimum about half
  the time. The ground truth is asserted; the success count is reported.

They are generated by `scripts/emit_*.jl` from the validated model and data, never edited by
hand (D-0001), and the test suite re-runs each one against the in-repository model.

## Layout

| Path | Contents |
|---|---|
| `data/` | The two instances and their derived equilibria, with the provenance of every value in `data/PROVENANCE.md`. |
| `src/murphy_smeers.jl` | The open-loop models as `(M, q)`, an independent row-by-row transcription to check the assembly, and the paper's stated properties as checks on a point. |
| `src/enumerate_lcp.jl` | The solver-free oracle: every solution of a small LCP, and the checks that make one solution provably the only one. |
| `src/murphy_smeers_closed_loop.jl` | The closed-loop model: the second stage at fixed capacities, Lemma 7's closed-form sensitivity to capacity, and equation (16) written twice. |
| `src/enumerate_closed_loop.jl`, `src/diagonalize_closed_loop.jl` | Two independent routes to the closed-loop equilibrium: enumeration of every root, and best-response iteration with convergence diagnostics. |
| `src/best_response_mpcc.jl`, `src/hard_best_response.jl` | One player's best response as an MPCC, and the search that tunes it to a near-tie. |
| `test/` | The validation: both instances, all three models, every backend, each property cited to its page. |
| `scripts/` | The agreement table, the three emitters, the negative controls, and the portability check. |
| `docs/` | The replication report, the hand derivations, and the documentation site. |

## Rules

- **Every parameter traces to its source**, recorded in `data/` beside the value; where the
  source has no table, the file says the value is constructed and cites the assumption it
  satisfies.
- **Never adjust a value to make a result match.** A mismatch is investigated (solver
  settings, units, transcription, the paper's own ambiguity) and recorded as a finding.
- **No root of (16) is an equilibrium until a best-response check says so** (D-0006).
- **`upstream/` is generated.** Edit the emitters, then rerun them and
  `python ci/gates/check_stale_generated.py . --write`.

## Acknowledgements

The ground-truth solves depend on PATH. Thanks to Steven Dirkse, Michael Ferris and Todd
Munson for the solver and its courtesy licence, and to Oscar Dowson and the PATHSolver.jl
contributors for the Julia interface. Thanks also to François Pacaud, Anton Pozharskiy and
Armin Nurkanović for CCOpt.jl.

## Licence

BSD 3-Clause. See `LICENSE`.
