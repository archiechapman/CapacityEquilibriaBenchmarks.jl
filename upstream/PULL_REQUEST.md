# Pull-request description for CCOpt.jl

*This file is the draft description that would accompany `test_murphy_smeers_lcp.jl` if it
is offered to `madsuite-org/CCOpt.jl`. It is written by hand, unlike the test file beside
it, which is generated (`DECISIONS.md` D-0001). Nothing has been submitted: as of
2026-09-10 the repository has zero open issues and one open pull request, and no maintainer
has been approached.*

---

## Title

Add an economic-equilibrium regression test: four small LCPs with independently known solutions

## Body

Hello — this adds one self-contained test file, `test/test_murphy_smeers_lcp.jl`, holding
four small linear complementarity problems whose solutions are known without reference to
any solver, and running each through both `RelaxationSolver` and `PenaltySolver`.

**What the problems are.** Murphy and Smeers' open-loop capacity-expansion equilibria
(*Operations Research* 53(4), 646–661, 2005): two generators, one peaking and one
base-load, choosing capacity and per-segment output against affine inverse demand over `S`
load segments. Under price-taking behaviour, and again under open-loop Cournot behaviour,
the equilibrium conditions are a square LCP `0 ≤ z ⟂ Mz + q ≥ 0` with a monotone `M`. Two
parameter sets give four problems, of 14 and 18 variables.

**Why they are worth having as a test.** The solutions are not the output of a solver. Each
was derived by hand from the equilibrium conditions and checked by substitution; an
exhaustive enumeration of all `2^n` complementarity patterns finds that point and no other;
PATH reaches it to better than 1e-9. Monotone map, strictly complementary point, nonsingular
basis, so the solution is unique. The test therefore fails if CCOpt returns *a* stationary
point that is not *the* solution, which a test whose expected values were recorded from an
earlier CCOpt run could not do.

They are also economically structured rather than synthetic — capacity constraints binding
in some segments and slack in others, a technology idle where it is uncompetitive — so the
active set at the solution is not uniform, and a bug that mishandles one branch of the
complementarity has somewhere to show up. Between them the four problems exercise five
distinct segment regimes.

**What it does not claim.** Nothing about scale: 14 and 18 variables, milliseconds each.
Nothing about hard cases: all four have a unique, strictly complementary solution, which is
the easy end for both a relaxation and a penalty scheme. It is a correctness regression
test, and that is the whole of the offer.

**Fit with the existing suite.** The file follows the conventions of `test/solvers/`: a
module, as in `test/MOI_wrapper.jl`, importing only `NLPModels`, `MPCCModels`, `MadNLP`,
`CCOpt` and `Test`, all of which `test/Project.toml` already carries. No JuMP, no new
dependency, and no dependency on the repository it came from. Data is inlined. Add
`include("test_murphy_smeers_lcp.jl")` to `runtests.jl` beside the other solver tests.

One cost worth flagging rather than letting you discover it: the eight solves take about
45 ms in total once everything is compiled, but the first run in a fresh session costs
about 30 s, essentially all of it compiling MadNLP and CCOpt for a model type they have
not seen. Your existing solver tests already pay most of that for `ADNLPModel`; a second
`AbstractNLPModel` implementation forces some of it again. If that is unwelcome, the file
works just as well cut down to the two 14-variable problems.

**Provenance, and one caveat about it.** The paper is analytical and publishes no numerical
example in either its working-paper or its journal edition, so the two parameter sets are
*constructed* to satisfy its stated assumptions, not transcribed from it. The file's header
says so, and no number in it should be attributed to the authors. The derivations, the
enumeration results, the PATH comparison and the provenance for every parameter are at
<https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl>, where the file is
generated from the model the tests there validate rather than written by hand, so the copy
here cannot quietly stop matching it.

**Results on this branch.** Both methods reach all four solutions at their default options.
Recomputed complementarity residuals, from the returned point alone:

| Problem | `RelaxationSolver` | `PenaltySolver` | Tolerance asserted |
|---|---|---|---|
| A, competitive (n = 14) | 3.0e-8 | 7.9e-8 | 1e-6 |
| A, Cournot (n = 14) | 1.7e-8 | 5.2e-8 | 1e-6 |
| B, competitive (n = 18) | 1.7e-7 | 3.6e-7 | 1e-5 |
| B, Cournot (n = 18) | 1.8e-7 | 3.9e-7 | 1e-5 |

The tolerances were fixed before either method was run on these problems and are several
hundred times looser than what both achieve; the nearest wrong regime is O(1) away on the
first pair and O(0.1) on the second, so nothing here can pass with a wrong answer.

**Two things noticed on the way, reported separately below rather than fixed here.**

1. `MOI.RawStatusString` throws. In `ext/CCOptMathOptInterface/CCOptMathOptInterface.jl`,
   `MOI.get(::Optimizer, ::MOI.RawStatusString)` reads `optimizer.solver.opt`, but the
   `RelaxationSolver` that `copy_to` always builds has the field `opts`. Any JuMP user who
   calls `raw_status` after a CCOpt solve gets `type RelaxationSolver has no field opt`.
   `TerminationStatus` is unaffected. Happy to open this as an issue, or fold a one-line
   fix into this PR if you would rather.

2. The penalty method is unreachable through JuMP. `MOI.copy_to` constructs a
   `RelaxationSolver` unconditionally, and unrecognised raw attributes are forwarded to it
   as keyword arguments rather than selecting a method, so a JuMP user cannot ask for
   `PenaltySolver` at all. That is why this test file builds `MPCCModel` directly instead
   of going through the modelling layer. Not a bug as such, and possibly deliberate for
   v0.1 — but the README presents the two methods as equal alternatives, which reads as a
   promise the MOI layer does not keep.

Happy to adjust the file's shape, naming, or assertions to whatever suits the suite, or to
drop it if a test of this kind is not what you want. It is equally useful to us as a
validation artifact on our side, so there is no cost to a no.
