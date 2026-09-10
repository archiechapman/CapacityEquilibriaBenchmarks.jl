# Note to open on madsuite-org/CCOpt.jl

*This is the short note that opens the conversation. It offers the test case and asks
whether it is wanted; `PULL_REQUEST.md` beside it is the longer description that would go
with the file itself if the answer is yes. Nothing has been posted. `scripts/share_upstream.sh`
publishes the file as a public gist and prints the exact `gh` command to post this.*

*Addressed to François Pacaud (`@frapac`). Anton Pozharskiy (`@apozharski`) is the
repository's main committer and Armin Nurkanović (`@nurkanovic`) its third author, so
consider whether to tag them too before posting.*

---

**Title**

Offer: four small LCPs with independently known solutions, as a regression test

**Body**

Hi @frapac,

I have been using CCOpt.jl to solve capacity-expansion equilibrium problems in electricity
markets, and along the way built four small complementarity problems whose solutions are
known without reference to any solver. They have been useful to me as a correctness check
on CCOpt, and I wondered whether you would want them in `test/`.

**What they are.** Murphy and Smeers' open-loop capacity-expansion equilibria (*Operations
Research* 53(4), 2005). Two generators, one peaking and one base-load, choosing capacity and
per-segment output against affine inverse demand. Under price-taking and again under
open-loop Cournot behaviour the equilibrium conditions form a square LCP with a monotone
matrix. Two parameter sets give four problems, of 14 and 18 variables.

**Why they might earn their place.** The expected values are not a recorded CCOpt run. Each
was derived by hand from the equilibrium conditions and checked by substitution, an
exhaustive enumeration of all `2^n` complementarity patterns finds that point and no other,
and PATH reaches it to better than 1e-9. The map is monotone, the point strictly
complementary, its basis nonsingular, so the solution is unique. A test built this way fails
if CCOpt returns *a* stationary point that is not *the* solution, which a test seeded from an
earlier CCOpt run cannot do.

They are also structured rather than synthetic: capacity binding in some segments and slack
in others, a technology idle where it is uncompetitive, five distinct active-set regimes
across the four problems. So a bug that mishandles one branch of the complementarity has
somewhere to show up.

**What it is not.** Not a scale test: 14 and 18 variables, about 45 ms for all eight solves
once compiled. Not a hard case either, and deliberately so, since all four have a unique
strictly complementary solution, which is what let their answers be known in advance.

**Fit.** One self-contained file, in a module like `test/MOI_wrapper.jl`, importing only
`NLPModels`, `MPCCModels`, `MadNLP`, `CCOpt` and `Test`. I checked that against a throwaway
project built from your `test/Project.toml` plus CCOpt and nothing else, and it passes there,
so it should need no new test dependency. Data is inlined. `include` it from `runtests.jl`
beside the other solver tests.

Both methods reach all four solutions at their default options. Recomputed complementarity
residuals, from the returned point alone:

| Problem | `RelaxationSolver` | `PenaltySolver` | asserted |
|---|---|---|---|
| A, competitive (n = 14) | 3.0e-8 | 7.9e-8 | 1e-6 |
| A, Cournot (n = 14) | 1.7e-8 | 5.2e-8 | 1e-6 |
| B, competitive (n = 18) | 1.7e-7 | 3.6e-7 | 1e-5 |
| B, Cournot (n = 18) | 1.8e-7 | 3.9e-7 | 1e-5 |

The file is here, ready to drop into `test/`: GIST_URL

```
curl -O GIST_RAW_URL
```

**Two things I noticed on the way**, neither of which the file depends on:

1. `MOI.RawStatusString` throws. In `ext/CCOptMathOptInterface/CCOptMathOptInterface.jl`,
   `MOI.get(::Optimizer, ::MOI.RawStatusString)` reads `optimizer.solver.opt`, but the
   `RelaxationSolver` that `copy_to` always builds has the field `opts`. Calling
   `JuMP.raw_status` after a CCOpt solve gives `type RelaxationSolver has no field opt`.
   `TerminationStatus` is unaffected. Happy to open it separately or send a one-line fix.

2. `PenaltySolver` is unreachable through JuMP: `copy_to` builds a `RelaxationSolver`
   unconditionally and forwards unrecognised raw attributes to it as keyword arguments, so
   a JuMP user cannot select the penalty method. That is why the file builds `MPCCModel`
   directly. Possibly deliberate for v0.1, though the README presents the two methods as
   equal alternatives.

Happy to reshape the file, rename things, cut it to the two smaller problems, or drop it
entirely if a test of this kind is not what you want. It is a validation artifact on my side
either way, so a no costs nothing.

Provenance, in the interest of not overstating it: the paper is analytical and publishes no
numerical example in either edition, so the two parameter sets are *constructed* to satisfy
its stated assumptions rather than transcribed from it. The file's header says so, and no
number in it should be attributed to the authors. Derivations and the PATH and enumeration
results are in my own repository, which I can open up or send if it would help.
