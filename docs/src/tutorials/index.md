# The benchmark ladder

This tutorial is the whole benchmark series, read in the order it was built. There is one
model throughout, Murphy and Smeers' two-player capacity game, and four problems made from
it. Each takes away one property that made the problem before it easy, so that by the end
a solver is being asked something it can get wrong.

| | Problem | What is known about the answer | What is taken away | Standalone file |
|---|---|---|---|---|
| 1 | [An equilibrium you can solve by hand](@ref) | The unique solution, three independent ways | nothing: this is the easy case | `test_murphy_smeers_lcp.jl` |
| 2 | [Three roots, one equilibrium](@ref) | Every root of the equilibrium condition, and which one is an equilibrium | uniqueness, smoothness, nondegeneracy | `closed_loop_demonstration.jl` |
| 3 | [The best response as an MPCC](@ref) | The global optimum, by enumeration | convexity; the problem is now an optimisation | part of `hard_case_near_tie.jl` |
| 4 | [Engineering a hard case](@ref) | Both optima and the margin between them | a comfortable margin | `hard_case_near_tie.jl` |

The first chapter is a regression test of the ordinary kind: a problem with a unique
answer that any working solver should reach. The second is not a solver test at all. It
shows a complementarity system whose solution set is larger than the question it was
written to answer, so that a solver can be right and its answer meaningless. The third and
fourth are the solver tests that matter, because they have known answers *and* the solver
can miss them.

## The model in one paragraph

Two players each specialise in one technology: player ``p`` builds and runs peaking plant,
player ``b`` base-load plant (p.12 of the 2002 working paper; page numbers throughout are
that edition's). The year is divided into ``S`` load segments of unit width, ``s = 1`` the
peak (p.11). Inverse demand in segment ``s`` is ``p^s = \alpha^s - \beta q^s`` with
``q^s = y_p^s + y_b^s``, ``\alpha^1 > \dots > \alpha^S`` and ``\beta > 0`` (p.12). Player
``i`` pays ``K_i`` per unit of capacity ``x_i`` and ``\nu_i`` per unit of output
``y_i^s \le x_i``. The paper's two cost assumptions make the peaker cheaper for a single
segment and the base plant cheaper across all of them:

```math
K_p + \nu_p < K_b + \nu_b, \qquad K_b + S\nu_b < K_p + S\nu_p \qquad \text{(p.11)}.
```

## The two instances

| | ``S`` | ``\beta`` | ``\alpha`` | ``K_p, \nu_p`` | ``K_b, \nu_b`` | Units |
|---|---|---|---|---|---|---|
| A | 3 | 1 | 20, 15, 10 | 2, 3 | 7, 1 | dimensionless, chosen to be solved by hand |
| B | 4 | 10 | 150, 115, 100, 90 | 24, 30 | 50, 18 | GW and \$/MWh over quarter-year blocks |

Both are constructed; neither is the paper's, because the paper has none (see
[Read this before any number](@ref)). The tutorial works through instance A, where every
result can be checked against a fraction derived by hand, and runs instance B where it is
cheap to. The derivations and the reasoning behind each value are in the Results section.

## Reading the code blocks

Every block runs when the site is built, in order, one session per chapter. Lines
beginning `@assert` are the chapter's claims, and a claim that stops holding fails the
build. Numbers printed without an assertion beside them are reported, not claimed, and
some of them, CCOpt's accuracy for instance, depend on the solver version.

The same code runs in a REPL started with `julia --project` in the repository. Each
chapter starts by loading instance A:

```julia
using CapacityEquilibriaBenchmarks, CapacityEquilibria

datadir  = joinpath(pkgdir(CapacityEquilibriaBenchmarks), "data")
data     = load_ms_instance(joinpath(datadir, "ms2002_instance_a.toml"))
expected = joinpath(datadir, "ms2002_instance_a_expected.toml")
```

Four solver backends appear throughout, all provided by the engine: `:path`, CCOpt's
relaxation method through JuMP (`:ccopt`), and CCOpt's relaxation and penalty methods
through an MPCC model the engine builds directly (`:ccopt_relaxation`, `:ccopt_penalty`).
The engine's own documentation explains the routes, and why the pass criterion is always a
residual recomputed from the returned point rather than the solver's own status.
