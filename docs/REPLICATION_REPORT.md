# Replication report

*The authoritative synthesis, per `AGENTS.md`: for each case, the paper's published number,
the PATH solve, the CCOpt.jl solve, and the tolerance each comparison was made at. Supersedes
any number in a docstring, README or commit message. Claims are made at the tier their
`FINDINGS.md` entry carries and no higher.*

*Status as of 2026-09-11: Phases 1 to 3 complete, Phase 4 in progress. Both open-loop
models are validated on two constructed instances against a hand derivation, an exhaustive
enumeration and the paper's own theorems, and are solved by PATH and by both of CCOpt.jl's
methods over four routes. The closed-loop equilibrium of each instance is found by a
solver-free enumeration, reached independently by diagonalization, and checked against
every comparative result the paper states. Phase 4 has built one player's best response as
a genuine MPCC, which CCOpt solves to its known global optimum on every case tried, and a
deliberately hard version of it on which CCOpt finds the better of two nearly tied optima
about half the time. Three upstream files are generated and passing. Not done: the
monolithic joint system, which turns out not to be the reformulation the plan describes.*

## The paper, and what it publishes

Murphy, F. H. and Smeers, Y., "Generation Capacity Expansion in Imperfectly Competitive
Restructured Electricity Markets". Edition held: the working paper of May 2002, 69 pages,
pre-publication version of *Operations Research* 53(4), 646–661 (2005).

**It publishes no numbers, in either edition.** No parameter values, no table of results,
no worked example (`FINDINGS.md` F-0001 for the working paper, F-0002 for the published
article). It publishes a model and theorems about its equilibria. So the column headed
"paper" below carries what the paper *states* — an analytical property, cited by page —
and the numerical columns compare six routes to the equilibrium of a constructed instance
that satisfies every assumption the paper makes (`DECISIONS.md` D-0004): a hand derivation
from the paper's equilibrium conditions, an exhaustive enumeration of complementarity
patterns, PATH, and CCOpt.jl reached three ways — its relaxation method through JuMP, and
its relaxation and penalty methods through an `MPCCModel` built directly, which is the only
route to the penalty method (engine `FINDINGS.md` F-0004).

## The instances

Both constructed, not transcribed. Instance A is built to be solved by hand; instance B to
be reasonable. `data/PROVENANCE.md` has the rationale for every value.

| | S | β | α | K_p, ν_p | K_b, ν_b | S_p | n | Units |
|---|---|---|---|---|---|---|---|---|
| A | 3 | 1 | 20, 15, 10 | 2, 3 | 7, 1 | 2 | 14 | dimensionless |
| B | 4 | 10 | 150, 115, 100, 90 | 24, 30 | 50, 18 | 2 | 18 | GW, $/MWh; quarter-year blocks; K is the annualised cost per MW divided by the 2190 h block |

Instance B reads as: a gas peaker at $52.6/kW-yr and $30/MWh against a combined-cycle plant
at $109.5/kW-yr and $18/MWh; demand at a $50/MWh reference of 10, 6.5, 5 and 4 GW across
the four blocks, with a long-run price elasticity of 0.5 at the peak.

## Solver agreement

For each instance and model: the residual of each route's point, recomputed from the point
alone by `lcp_residual`, and its max-norm distance from the hand-derived point. From
`scripts/report_agreement.jl`.

| Instance, model | Route | Residual | Distance from hand | Tolerance |
|---|---|---|---|---|
| A, competitive | hand derivation | 0 | — | |
| | enumeration (1 solution) | 0 | 0 | 1e-9 |
| | PATH | 3.4e-12 | 3.2e-12 | 1e-6 |
| | CCOpt relaxation, JuMP | 3.0e-8 | 1.3e-8 | 1e-6 |
| | CCOpt relaxation, direct | 3.0e-8 | 1.3e-8 | 1e-6 |
| | CCOpt penalty, direct | 7.9e-8 | 5.8e-8 | 1e-6 |
| A, open-loop Cournot | hand derivation | 0 | — | |
| | enumeration (1 solution) | 0 | 8.9e-16 | 1e-9 |
| | PATH | 9.3e-15 | 1.8e-15 | 1e-6 |
| | CCOpt relaxation, JuMP | 1.7e-8 | 1.8e-8 | 1e-6 |
| | CCOpt relaxation, direct | 1.7e-8 | 1.8e-8 | 1e-6 |
| | CCOpt penalty, direct | 5.2e-8 | 2.7e-8 | 1e-6 |
| B, competitive | hand derivation | 0 | — | |
| | enumeration (1 solution) | 0 | 0 | 1e-8 |
| | PATH | 6.7e-10 | 4.1e-10 | 1e-5 |
| | CCOpt relaxation, JuMP | 1.7e-7 | 2.4e-8 | 1e-5 |
| | CCOpt relaxation, direct | 1.7e-7 | 2.4e-8 | 1e-5 |
| | CCOpt penalty, direct | 3.6e-7 | 3.3e-8 | 1e-5 |
| B, open-loop Cournot | hand derivation | 4.3e-14 | — | |
| | enumeration (1 solution) | 4.3e-14 | 7.1e-15 | 1e-8 |
| | PATH | 9.4e-14 | 2.8e-14 | 1e-5 |
| | CCOpt relaxation, JuMP | 1.8e-7 | 5.2e-8 | 1e-5 |
| | CCOpt relaxation, direct | 1.8e-7 | 5.2e-8 | 1e-5 |
| | CCOpt penalty, direct | 3.9e-7 | 3.1e-8 | 1e-5 |

The two relaxation rows of each block are the same method on the same problem, reached with
and without the MathOptComplements bridges, and their identical figures are not a rounding
artefact: the two points are bitwise equal on every case, which the test asserts with `==`
rather than a tolerance. That is a structural fact about the bridges — they build the same
lifted model, in the same variable order, that the engine builds by hand — rather than a
numerical one about two paths converging (`FINDINGS.md` F-0008). The penalty method is the
less accurate of the two methods everywhere, by a factor of two to five in the residual,
and both are two to three orders of magnitude behind PATH.

Uniqueness, for every case: the map is monotone (Lemma 1, p.18, and its competitive
counterpart), the solution is strictly complementary, and its basis is nonsingular — which
together make it the only solution (`src/enumerate_lcp.jl`). The enumeration finds no
other.

## Case 1: competitive equilibrium — equations (2)–(3), p.14

`FINDINGS.md` F-0004 (A), F-0006 (B), tier **validated**.

| Quantity | Paper | A | B |
|---|---|---|---|
| x_p, x_b | — | 7, 8 | 1.6, 8.0 GW |
| y_p | — | 7, 4, 0 | 1.6, 0.5, 0, 0 |
| y_b | — | 8, 8, 8 | 8, 8, 8, 7.2 |
| λ_p | — | 2, 0, 0 | 24, 0, 0, 0 |
| λ_b | — | 4, 2, 1 | 36, 12, 2, 0 |
| prices | — | 5, 3, 2 | 54, 30, 20, 18 $/MWh |
| segment types, partition (13) p.22 | — | a, c, e | a, c, e, d |

| Property the paper states | Where | A | B |
|---|---|---|---|
| Production efficiency: peakers only in `s ≤ S_p`, base in all `s` | p.14 | holds | holds |
| Pricing efficiency: price = short-run marginal cost + rent, by regime | p.15 | holds | holds |
| Investment criterion: `K_i = Σ_s max(pˢ − ν_i, 0)` | p.15 | holds | holds |

Each property is checked on all four solvers' points separately, never inherited from one
to another. So is the segment-regime classification in the row above, which is the check
that a solver is on the right side of every complementarity boundary and not merely close
to the equilibrium.

## Case 2: open-loop Cournot equilibrium — equations (5)–(6), p.16

`FINDINGS.md` F-0005 (A), F-0006 (B), tier **validated**.

| Quantity | Paper | A | B |
|---|---|---|---|
| x_p, x_b | — | 65/12, 25/6 | 593/180, 271/90 GW |
| y_p | — | 65/12, 47/12, 5/3 | 593/180, 247/90, 359/180, 8/5 |
| y_b | — | 25/6, 25/6, 11/3 | 271/90, 271/90, 271/90, 14/5 |
| λ_p | — | 2, 0, 0 | 24, 0, 0, 0 |
| λ_b | — | 21/4, 7/4, 0 | 233/6, 28/3, 11/6, 0 |
| prices | — | 125/12, 83/12, 14/3 | 1565/18, 517/9, 899/18, 46 $/MWh |
| segment types | — | a, c, b | a, c, c, b |
| number of solutions | unique (Thm 1, p.19) | 1 | 1 |

| Property the paper states | Where | A | B |
|---|---|---|---|
| Base player invests a positive amount | Theorem 1, p.19 | holds | holds |
| Investment criterion: `K_i = Σ_s max(pˢ − βx_i − ν_i, 0)` | p.16 | holds | holds |
| `y_pˢ < y_bˢ` where base capacity is slack | Lemma 5, p.21 | holds, `s = 3` | holds, `s = 4` |
| Peaker at capacity ⇒ base at capacity, same segment | Lemma 11, p.27 | holds | holds |
| At capacity in `s` ⇒ at capacity in all `s' < s` | Corollary 1, p.20 | holds | holds |
| `λ_p` identical to the competitive case | Lemma 12, p.29 | holds | holds |
| Less total capacity, higher prices than competitive | Theorem 7, p.29 | 9.58 vs 15 | 6.31 vs 9.6 GW |
| Peakers may run in `s > S_p` | p.16 | yes, `s = 3` | yes, `s = 3, 4` |


## Case 3: closed-loop Cournot equilibrium — equation (16), p.24

`FINDINGS.md` F-0012 (structure), F-0013 (the equilibria), tier **validated**.
`DECISIONS.md` D-0006 says what validation means here, and it is a weaker standard than
D-0004's: there is no hand derivation, and no uniqueness is claimed.

| Quantity | Paper | A | B |
|---|---|---|---|
| x_p, x_b | — | 5, 5 | 3.03, 3.54 GW |
| y_p | — | 5, 7/2, 5/3 | 3.03, 2.48, 29/15, 8/5 |
| y_b | — | 5, 5, 11/3 | 3.54, 3.54, 47/15, 14/5 |
| λ_p | — | 2, 0, 0 | 24, 0, 0, 0 |
| λ_b | — | 4, 1/2, 0 | 30.9, 1.4, 0, 0 |
| prices | — | 10, 13/2, 14/3 | 84.3, 54.8, 148/3, 46 $/MWh |
| segment types | — | a, c, b | a, c, b, b |
| roots of (16) | — | 3, one of them an equilibrium | 3, one of them an equilibrium |

Found by `enumerate_closed_loop`, which enumerates all `2^(4S)` second-stage
complementarity patterns — each fixes every segment's regime, hence Lemma 7's derivative
table, hence an affine `ξ(x)` in two variables — and solves the small problem each induces.
No solver takes part in the search; every candidate is re-verified against a real
second-stage solve afterwards. 3.7 s on instance A, 7.2 s on instance B.

| Property the paper states | Where | A | B |
|---|---|---|---|
| Total capacity at least the open-loop's | Theorem 4, p.28 | 10 vs 9.58 | 6.57 vs 6.31 |
| Base capacity at least the open-loop's | Theorem 5, p.28 | 5 vs 4.17 | 3.54 vs 3.01 |
| Prices below open-loop in every segment | Theorem 6, p.28 | holds | holds |
| Total capacity between open-loop and competitive | Theorem 7, p.29 | 9.58 < 10 < 15 | 6.31 < 6.57 < 9.6 |
| `λ_p` identical to the open-loop and competitive values | Lemma 12, p.29 | holds | holds |
| `K_p = Σ λ_p` and `K_b > Σ λ_b` with a type (c) segment | Corollary 3 (18), p.28 | 0 and 2.5 | 0 and 17.7 |
| Closed-loop differs from open-loop | Theorem 3, p.26 | holds | holds |

### The two roots that are not equilibria

The result worth reporting most carefully. Equation (16) is a first-order condition at a
differentiable point, and on each instance it has three roots. Two of them are corners at
which one player invests nothing:

| Instance | Root of (16) | Best response available to the other player |
|---|---|---|
| A | (7.5, 0) | 46.3 |
| A | (0, 6.5) | 32.0 |
| A | (5, 5) | 0 |
| B | (4.8, 0) | 322.5 |
| B | (0, 4.475) | 187.9 |
| B | (3.03, 3.54) | 0 |

The corner roots are genuine roots of (16) as evaluated — their residual is zero, not small
— and they are not equilibria. They also violate Theorems 4, 6 and 7, so the paper's own
theory rejects them independently of the deviation test.

They are not local optima either (`FINDINGS.md` F-0018). At every corner the player holding
nothing gains from its very first unit of capacity: on instance A the base player's
objective falls from zero at a slope of −18, which is its capacity cost of 7 plus three
units of operating cost against the peaker's prices of 12.5, 9 and 6.5. The corners satisfy
(16) because they are kinks. With no capacity the player's output is zero, which is both
idle and at capacity, and the regime classification reads it as idle; Lemma 7 gives an idle
player a zero derivative, so (16) reduces to `ξ_i = K_i > 0`, complementary to `x_i = 0`.
Read as at capacity, which is what the player becomes the moment it builds, (16) returns the
negative right derivative instead. (16) is stated only where the second-stage solution is
differentiable (p.24), and at these points it is not.

Two consequences, both recorded rather than absorbed. Any method that evaluates (16) at a
point, rather than looking at the objective, can land on one of these points. And
`DECISIONS.md` D-0006 is amended to require a best-response check before a root of (16) is
described as an equilibrium anywhere in this repository.


## Case 4: the best response as an MPCC — equation (15), p.24

`FINDINGS.md` F-0016, tier **validated**. This is Phase 4's first result and the first place
in this programme where CCOpt is asked to *optimise* rather than to solve a square system.

One player's long-run problem, written as an MPCC: minimise its capacity cost less its gross
margin, subject to the second-stage equilibrium conditions, over `1 + 8S` nonnegative
variables with `4S` linear equalities and `4S` complementary pairs. The objective's Hessian
on each segment's own-output block is `[2β β; β 0]`, determinant `−β²`, so the problem is
indefinite in every segment. Its global optimum is known exactly from the pattern
enumeration of Phase 3, which is what makes it a test rather than a demonstration.

| What was solved | Solves | Result |
|---|---|---|
| Both players, three rival capacity vectors, two instances, both CCOpt methods | 24 | global optimum every time, objective within 1.3e-6 |
| Started at each corner root, where the player holds nothing, with every variable consistent | 8 | reached the global optimum every time |

The corner starts are degenerate: every one of the idle player's capacity pairs is biactive
and its capacity duals lie on a ray. The global answer from there is far away, worth 31.95
and 46.33 on instance A and 187.85 and 322.52 on instance B, and both of CCOpt's methods
reach it on all eight cases. They are not, however, a trap. F-0016 described each corner as
a local optimum that is not global and credited CCOpt's homotopy with escaping it; F-0018
found that the objective falls from the first unit of capacity at every corner, so a method
that only moves downhill would leave too. The row shows CCOpt handling a degenerate start,
not escaping a local optimum. The trap test is Case 5.

### Why the monolithic system in the plan is not built

The plan describes Phase 4 as stacking every player's first-order conditions into one MPCC
and calls it a reformulation. It is not one. Equation (16) depends on `B_i y_j`, which
Lemma 7 (14), p.22 gives as a piecewise-constant table indexed by regime, so (16) is not a
smooth function of the variables and no single smooth MPCC has it as stationarity
conditions. The two honest routes are a disjunctive encoding, which leaves MPCC territory,
and stacking each player's MPEC-KKT conditions, whose constraint qualifications fail
generically and demonstrably fail at the degenerate corners of F-0015. Neither is built.
Choosing between them is a modelling decision with no obviously right answer, and it is
recorded as open rather than settled.


## Case 5: a hard case, built on purpose — the best response at a near-tie

`FINDINGS.md` F-0017, tier **validated**. Everything above, CCOpt solved. A test that
nothing fails is weak, so this case was searched for rather than hoped for.

At a fixed rival capacity a player's long-run objective is piecewise quadratic, one piece
per second-stage regime, so its landscape is a row of wells. As the rival's capacity moves
the wells rise and fall relative to one another, and `best_response_tie` finds, by golden
section on the gap, the rival capacity at which two widely separated wells are level. Both
wells are verified local minima, rising on both sides.

| Instance | Player | Tie at rival capacity | Two optima at | Apart by | Objectives agree to |
|---|---|---|---|---|---|
| A | peaking | 7.254033307585 | 3.873 and 5.000 | 1.127 | 1.7e-14 relative |
| A | base-load | 3.450296453109 | 4.775 and 5.333 | 0.559 | 3.0e-15 |
| B | peaking | 5.317351598173 | 2.433 and 3.000 | 0.567 | 2.4e-14 |
| B | base-load | 4.292375886525 | 3.133 and 3.633 | 0.500 | 9.5e-15 |

Moving the rival's capacity by ±0.001 gives a definite right answer with a relative margin
of 7e-5 to 1.5e-4, and flips which well it is. Each of 32 problems (four ties, four offsets,
two methods) is posed from a start inside the wrong well.

| Warm start | Better well found |
|---|---|
| From CCOpt's own output stage, as in `upstream/hard_case_near_tie.jl` | 16 of 32 |
| From PATH's output stage, in-repository | 19 of 32 |

Both methods fail, on different problems, with neither dominating. Every returned point is
feasible and is one of the two local minima: these are converged answers to a question with
two nearly equal answers, not convergence failures. At these wells, which sit on regime
boundaries, CCOpt's second-stage solution is about 2e-4 from PATH's against about 1e-8 at an
interior point, which is why the artifact inlines its ground truth rather than recomputing
it. No other MPCC solver has been run on these problems, so nothing here says whether half
is good, bad or ordinary.


## The three artifacts offered upstream

`upstream/` holds three generated files and three hand-written notes. None of the files has
been sent to anyone.

| File | What it is | Assertions |
|---|---|---|
| `test_murphy_smeers_lcp.jl` | The four open-loop problems as a regression test: known unique answers, both CCOpt methods reach them | 24 |
| `closed_loop_demonstration.jl` | The closed-loop first-order conditions admitting three roots of which one is an equilibrium, and the degeneracy at the other two | 82 |
| `hard_case_near_tie.jl` | Case 5: the ground truth of each near-tie is asserted; how often CCOpt finds the better well is reported, not asserted | reports 16 of 32 |

All three are generated by `scripts/emit_*.jl`, registered in `generated.toml`, round-tripped
against the in-repo model by the test suite, and checked by
`scripts/check_upstream_portable.jl` to run in a project holding only CCOpt's own declared
test dependencies (F-0009, F-0011, F-0015, F-0017).

The second is not a regression test and is not offered as one. Its subject is that a
complementarity system can have a larger solution set than the problem it represents, so a
solver can be correct and its answer meaningless. `upstream/NOTE_first_order_conditions.md`
is the accompanying note, written to be read without economics.

### What the demonstration shows

| Instance | Capacities | First-order condition | Second stage | Penalty residual | A deviator gains |
|---|---|---|---|---|---|
| A | (0, 6.5) | satisfied | degenerate | 9.8e-4 | 32.0 |
| A | (5, 5) | satisfied | nondegenerate | 4.7e-8 | 0 — the equilibrium |
| A | (7.5, 0) | satisfied | degenerate | 9.8e-4 | 46.3 |
| B | (0, 4.475) | satisfied | degenerate | 1.0e-3 | 187.9 |
| B | (3.03, 3.54) | satisfied | nondegenerate | 3.1e-7 | 0 — the equilibrium |
| B | (4.8, 0) | satisfied | degenerate | 1.0e-3 | 322.5 |

The degeneracy column is not a coincidence. A player holding no capacity produces nothing,
so its output is both idle and at its capacity of zero: each of its capacity pairs is
biactive. As degeneracy that leaves its shadow price undetermined, and as an ambiguous
regime it lets (16) be evaluated on the idle reading, which gives the player no revenue
term at all and makes the corner a root. One biactive pair, seen twice (F-0015, F-0018).

The penalty residuals in the degenerate rows are not errors of that size. They are the
product of a dual of order 1e5, which the problem does not determine, with a primal error of
order 1e-8, which is the real accuracy. Every solver's outputs, prices and regimes agree
there. This is a limit on the pass criterion this programme has used since Phase 0, and it
is recorded as one against the engine's `DECISIONS.md` D-0002.


## What "replicated" means here, and what it does not

Each case's PATH point agrees with two solver-free routes to the same equilibrium to better
than 1e-9, both of CCOpt's methods to better than 4e-7, and every property the paper states
about that equilibrium holds at every solver's point. That is the strongest check available
on a paper that publishes no numbers, and it is a correctness regression result for CCOpt.jl
on four cases with known answers — the framing the plan asks for, not a demonstration of
scale.

It is not a reproduction of published numbers, because there are none. Nothing in this
report should be quoted as Murphy and Smeers' result. The full negative list is in
`FINDINGS.md`, "What this does not establish"; the two items that matter most: the four
open-loop problems are the easy case of a unique strictly complementary solution, which is
exactly why their answers could be known in advance, and the closed-loop results rest on a
weaker footing again — no hand derivation, no uniqueness claim, and an enumeration that
would miss an equilibrium sitting on a kink between regimes.

## Reproducing this report

```
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project scripts/report_agreement.jl
julia --project scripts/emit_upstream_test.jl    # rewrites upstream/, which CI checks
julia --project=docs docs/make.jl                # the tutorial, which re-asserts cases 1 to 5 on instance A
```

923 tests (973 with RUN_CLOSED_LOOP=true), in about seven minutes after precompilation,
most of it the enumeration of 2¹⁴ and 2¹⁸ patterns and compiling the three upstream files,
which the suite includes and runs. No PATH licence is needed at these sizes.
`Manifest.toml` is committed; the versions it records are part of the result.

## The file offered upstream

`upstream/test_murphy_smeers_lcp.jl` is the deliverable of Phase 2: the four cases above as
a self-contained regression test for CCOpt.jl, importing nothing beyond NLPModels,
MPCCModels, MadNLP, CCOpt and Test, with the data inlined and the model copied verbatim
from the sources this repository validates. It is generated by
`scripts/emit_upstream_test.jl` and never edited by hand (`DECISIONS.md` D-0001); the test
suite re-runs it and requires it to rebuild the same matrices as the in-repo model, and
`generated.toml` makes a stale copy a CI failure here rather than a discovery made by a
maintainer. `upstream/PULL_REQUEST.md` is the description that would accompany it.
