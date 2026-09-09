# Replication report

*The authoritative synthesis, per `AGENTS.md`: for each case, the paper's published number,
the PATH solve, the CCOpt.jl solve, and the tolerance each comparison was made at. Supersedes
any number in a docstring, README or commit message. Claims are made at the tier their
`FINDINGS.md` entry carries and no higher.*

*Status as of 2026-09-09: Phase 1 complete; Phase 2's solver-agreement half complete. Not
done: CCOpt's penalty route, and the emitted upstream test file.*

## The paper, and what it publishes

Murphy, F. H. and Smeers, Y., "Generation Capacity Expansion in Imperfectly Competitive
Restructured Electricity Markets". Edition held: the working paper of May 2002, 69 pages,
pre-publication version of *Operations Research* 53(4), 646–661 (2005).

**It publishes no numbers, in either edition.** No parameter values, no table of results,
no worked example (`FINDINGS.md` F-0001 for the working paper, F-0002 for the published
article). It publishes a model and theorems about its equilibria. So the column headed
"paper" below carries what the paper *states* — an analytical property, cited by page —
and the numerical columns compare four routes to the equilibrium of a constructed instance
that satisfies every assumption the paper makes (`DECISIONS.md` D-0004): a hand derivation
from the paper's equilibrium conditions, an exhaustive enumeration of complementarity
patterns, PATH, and CCOpt.jl's relaxation method.

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
| | CCOpt (relaxation) | 3.0e-8 | 1.3e-8 | 1e-6 |
| A, open-loop Cournot | hand derivation | 0 | — | |
| | enumeration (1 solution) | 0 | 8.9e-16 | 1e-9 |
| | PATH | 9.3e-15 | 1.8e-15 | 1e-6 |
| | CCOpt (relaxation) | 1.7e-8 | 1.8e-8 | 1e-6 |
| B, competitive | hand derivation | 0 | — | |
| | enumeration (1 solution) | 0 | 0 | 1e-8 |
| | PATH | 6.7e-10 | 4.1e-10 | 1e-5 |
| | CCOpt (relaxation) | 1.7e-7 | 2.4e-8 | 1e-5 |
| B, open-loop Cournot | hand derivation | 4.3e-14 | — | |
| | enumeration (1 solution) | 4.3e-14 | 7.1e-15 | 1e-8 |
| | PATH | 9.4e-14 | 2.8e-14 | 1e-5 |
| | CCOpt (relaxation) | 1.8e-7 | 5.2e-8 | 1e-5 |

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

Each property is checked on PATH's point and on CCOpt's point separately.

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

## What "replicated" means here, and what it does not

Each case's PATH point agrees with two solver-free routes to the same equilibrium to better
than 1e-9, CCOpt's to better than 3e-7, and every property the paper states about that
equilibrium holds at both solvers' points. That is the strongest check available on a paper
that publishes no numbers, and it is a correctness regression result for CCOpt.jl on four
cases with known answers — the framing the plan asks for, not a demonstration of scale.

It is not a reproduction of published numbers, because there are none. Nothing in this
report should be quoted as Murphy and Smeers' result. The full negative list is in
`FINDINGS.md`, "What this does not establish"; the three items that matter most: nothing
here concerns the closed-loop model, nothing has been run through CCOpt's penalty method,
and both instances are the easy case of a unique strictly complementary solution.

## Reproducing this report

```
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project scripts/report_agreement.jl
```

155 tests; about three minutes after precompilation, most of it the enumeration of 2¹⁴ and
2¹⁸ patterns. No PATH licence is needed at these sizes. `Manifest.toml` is committed; the
versions it records are part of the result.
