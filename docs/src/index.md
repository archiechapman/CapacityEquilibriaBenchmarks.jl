# CapacityEquilibriaBenchmarks.jl

Capacity-expansion equilibrium models with independently known answers, each built twice:
once as a complementarity problem solved with PATH, treated as ground truth, and once for
CCOpt.jl, a young open-source solver for mathematical programs with complementarity
constraints (MPCCs), treated as the object under test.

The model is Murphy and Smeers' two-player capacity game from "Generation Capacity
Expansion in Imperfectly Competitive Restructured Electricity Markets" (*Operations
Research* 53(4), 646–661, 2005). A peaking generator and a base-load generator each choose
a capacity, then an output in each of several load segments, against affine inverse
demand. The paper studies three market structures: perfect competition, open-loop Cournot
competition, where capacity and output are chosen together, and closed-loop Cournot
competition, where capacity is chosen first in anticipation of the output game it
creates.

## Read this before any number

**The paper publishes no numerical example**, in either its 2002 working-paper edition or
its 2005 journal edition. It is an analytical paper: a model, equilibrium conditions, and
theorems about the equilibria. So there are no published numbers to reproduce, and none is
reproduced here.

The two instances used throughout are *constructed* to satisfy every assumption the paper
states. Instance A is small and rational, so that its equilibria can be derived by hand.
Instance B is built to be physically reasonable: gigawatts and dollars per megawatt-hour, a
gas peaker against a combined-cycle plant, four quarter-year load blocks. "Validated" in
this repository means that a solver's point agrees with answers found without any solver
(a hand derivation, an exhaustive enumeration of complementarity patterns), and that every
property the paper proves about the equilibrium holds at it. No number here should be
quoted as Murphy and Smeers' result.

## What is here

- **[The benchmark ladder](@ref)**, a four-part tutorial that climbs the benchmarks in the
  order they were built. Each rung takes away one property that made the one before it
  easy: first a unique equilibrium you can solve by hand, then a game whose first-order
  conditions have roots that are not equilibria, then a nonconvex optimisation, then a
  problem tuned until its two best answers are tied to fourteen significant figures. Every
  code block runs when the site is built, and every claim is asserted.
- **[The standalone files](@ref)**: one self-contained Julia file per benchmark, generated
  from the code these pages run and importing nothing beyond CCOpt.jl's own test
  dependencies. They are the tutorial's chapters in a form someone else can run.
- **Results**: the replication report, the hand derivations of both instances, and the
  provenance of every parameter.
- **Ledgers**: every finding with its evidence tier and its boundary, and every decision
  with the reasoning behind it.

## What was found, in brief

| Benchmark | Result | Ledger |
|---|---|---|
| Competitive and open-loop Cournot, both instances | Unique equilibria, derived by hand, confirmed by enumeration; PATH and both CCOpt methods reach them over four routes | F-0004 to F-0008 |
| Closed-loop Cournot, both instances | The first-order conditions have three roots on each instance, and only one is an equilibrium; the other two are kinks at which the output stage is degenerate and the condition does not apply | F-0012 to F-0015, F-0018 |
| One player's best response as an MPCC | CCOpt reaches the known global optimum on all 32 solves, including 8 started at the degenerate corners | F-0016, F-0018 |
| The same problem, tuned to a near-tie | CCOpt finds the better of two nearly tied optima in about half of 32 problems; both methods fail, on different problems | F-0017 |

## Running it

The repository reaches the engine, `CapacityEquilibria.jl`, by relative path, so clone the
two side by side:

```
CapacityEquilibria/
  ├── CapacityEquilibria.jl
  └── CapacityEquilibriaBenchmarks.jl
```

```
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

No PATH licence is needed at these sizes, which top out at 18 variables.

## Acknowledgements

The ground-truth solves depend on PATH. Thanks to Steven Dirkse, Michael Ferris and Todd
Munson for the solver and its courtesy licence, and to Oscar Dowson and the PATHSolver.jl
contributors for the Julia interface. Thanks to François Pacaud, Anton Pozharskiy and Armin Nurkanović for
CCOpt.jl, and to Frederic Murphy and Yves Smeers for a model whose theorems are precise
enough to test a solver against.
