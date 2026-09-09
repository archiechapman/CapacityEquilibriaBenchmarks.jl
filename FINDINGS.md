# Findings — CapacityEquilibriaBenchmarks.jl

*Whether this Julia implementation reproduces Murphy and Smeers, and what "reproduces" can
mean given the edition in hand. Solver behaviour as such is the engine's ledger
(`CapacityEquilibria.jl/FINDINGS.md`); this one records model results.*

*Last updated 2026-09-09. Produced against Julia 1.11.3, CCOpt v0.1.0, PATHSolver v1.7.9,
JuMP v1.31.2, MathOptComplements v0.1.1, on Windows 11, with the Manifest committed alongside. Every number below traces
to a path named in its `evidence` field. The paper is cited by the printed page numbers of the
May 2002 working paper; PDF page = printed page + 2.*

Tiers are defined in `research-guardrails/QUALITY.md`. Statuses are `open`, `settled`,
`superseded`, `dead-end`. Ids are stable and never reused — cite `F-0001`, never the wording.

---

## F-0001 — The edition of Murphy and Smeers in hand contains no numerical example, so Phase 1 has nothing to transcribe.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `../literature/Generation_Capacity_Expansion_in_Imperfe.pdf`, 69 pages, dated May 2002; read in full at the section level, and its extracted text searched for tables, "example", "numerical", currency and unit strings, and multi-digit numbers — every hit is a year, a page number, an equation number or a footnote address
- boundary: this edition only — the May 2002 working paper, not the *Operations Research* 53(4) article it became; assumes the PDF is complete, which its continuous printed pagination 1–66 plus front matter supports; the failure mode is a numerical example placed in an online supplement to the published version, which this edition would not show and which F-0002 leaves open
- supersedes: none

The replication plan's Phase 1 begins "Transcribe the paper's data directly from its
tables: the load-duration-curve blocks … the firms and their technology portfolios,
capacity costs, variable costs". The paper has none of those. It is an analytical paper:
a model (§2), equilibrium conditions for the competitive (§3), open-loop Cournot (§4) and
closed-loop Cournot (§6) cases, sensitivity results, existence and uniqueness theorems, and
twenty pages of proofs. The only reference to numbers is a citation of Stoft (2002, chapter
2-2) for "typical cost figures", not reproduced.

What the paper does fix, exactly, is the model: two specialised players, `S` unit-width
segments, affine inverse demand with a common slope, and the assumptions
`K_p + ν_p < K_b + ν_b`, `K_b + Sν_b < K_p + Sν_p`, `α¹ > … > αˢ`, `β > 0` (pp.11–12).
`data/ms2002_instance_a.toml` transcribes those, and constructs values satisfying them.
D-0004 records what ground truth means as a result.

## F-0002 — The published 2005 article carries no numerical example either.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: the repository owner's reading of *Operations Research* 53(4), 646–661, on 2026-09-09, reported as "there are no numerical results"; independent of F-0001, which read the working paper, and of the plan, which assumed tables
- boundary: one reading by one person of the article as published; assumes the reading covered the whole article and not the abstract, which the wording supports; the failure mode is a numerical example in an online supplement or appendix held separately from the article, not reported and not checked; nothing here says the two editions agree on anything other than the absence of numbers
- supersedes: none

As first written, this entry was a statement of ignorance: the published version was not
obtainable from this machine (`../literature/README.md`), the plan assumed it had tables,
and F-0001 showed the working paper has none, so `data/ms2002_instance_a.toml` carried a
`CONFIRM` marker against it. The marker is now deleted and the entry settled. The
consequence is that D-0004's reading of the Phase 1 gate is not a stopgap pending a better
edition; it is the only reading there is. Every instance in `data/` is constructed, and
the published article gives no number that any of them should be replaced by.

## F-0003 — Both open-loop models are linear complementarity problems, so the engine's LCP plumbing applies to them unchanged.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `src/murphy_smeers.jl`, header comment and `ms_lcp`; `test/runtests.jl`, testset "the LCP assembly agrees with a direct transcription of the equations" — `M z + q` from the assembled matrix equals `ms_conditions`, a row-by-row transcription of equations (2)–(3) p.14 and (5)–(6) p.16, at three test points for each variant, to 1e-12; testset "both maps are monotone" — the symmetric part of `M` has smallest eigenvalue ≥ −1e-10 for both
- boundary: the competitive and open-loop Cournot cases only; the closed-loop model's first-order condition (16), p.24, involves derivatives of the second-stage solution map and is not affine; assumes the paper's `ωᵢˢ` is the slack of the first condition rather than an independent variable, which is how the paper uses it; the failure mode caught by the agreement test is an index error in either transcription, not an error common to both, which the hand derivation in F-0004/F-0005 covers
- supersedes: none

The engine's ledger asked (its "What remains", item 3) whether `lcp_residual` generalises
to the mixed complementarity systems the real models need, or is an LCP-only special case.
For the two open-loop cases the question does not arise: every variable is nonnegative and
every residual is affine, so `lcp_model` and `lcp_residual` are used as they are, with
`n = 2 + 4S = 14` for instance A. The paper says as much in its own terms, restating the
open-loop game as an affine variational inequality in (7)–(11), pp.17–18. The question
returns, unchanged, for Phase 3.

`ms_lcp` builds `M` and `q`; `ms_conditions` writes `F` directly. Both were written from
the same equations by the same hand, so their agreement is evidence against a slip in
either, not against a shared misreading. That is what the hand derivation is for.

## F-0004 — Instance A, competitive equilibrium: PATH's point is the hand-derived equilibrium, is the only solution, and satisfies every property the paper states.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `test/runtests.jl`, testsets "competitive: hand derivation, enumeration and PATH agree" and "competitive: the paper's stated properties hold at the PATH point", 58/58 passing; `docs/ms2002_instance_a_derivation.md` for the derivation; `data/ms2002_instance_a_expected.toml` for the point — hand-derived point has residual 0.0 by substitution; exhaustive enumeration of all 2¹⁴ complementarity patterns finds exactly one solution, at distance 0.0 from the hand-derived point; PATH's point has recomputed residual 3.4e-12 and is 3.2e-12 from the hand-derived point (tolerance 1e-6)
- boundary: one constructed instance (`S = 3`, `β = 1`, `α = (20, 15, 10)`, `K = (2, 7)`, `ν = (3, 1)`), not a published one (F-0001); PATH under its demonstration licence, which suffices at 14 variables; uniqueness rests on the map being monotone, the point strictly complementary and its basis nonsingular, all checked, and would need re-arguing on an instance where two pairs tie; the properties checked are the three the paper states for this case — production efficiency, pricing efficiency, the investment criterion (pp.14–15) — and nothing the paper does not state
- supersedes: none

The equilibrium: `x = (7, 8)`, prices `(5, 3, 2)`, peaker output `(7, 4, 0)`, base output
`(8, 8, 8)`, `λ_p = (2, 0, 0)`, `λ_b = (4, 2, 1)`. Peakers are built and run only in the
`S_p = 2` segments where they are the efficient technology, base plants in all three, and
each investing player's capacity cost equals its strip of scarcity rents, exactly as pp.14–15
say.

Three routes to the point, none of which consults another: a derivation from the paper's
conditions by hand, checked by substitution; an enumeration that solves the linear system
of every complementarity pattern and keeps the feasible ones; and PATH. All three coincide
to 1e-11. The gate in the plan — "both cases matching the paper within tolerance" — is
met in the sense D-0004 gives it, and cannot be met in any other sense with this edition.

## F-0005 — Instance A, open-loop Cournot equilibrium: PATH's point is the hand-derived equilibrium, is the only solution, and satisfies every property the paper states — including the peaker running in the base segment.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `test/runtests.jl`, testsets "open_loop_cournot: hand derivation, enumeration and PATH agree" and "open-loop Cournot: the paper's stated properties hold at the PATH point", 58/58 passing; `docs/ms2002_instance_a_derivation.md`; `data/ms2002_instance_a_expected.toml` — hand-derived point has residual 0.0 by substitution; enumeration of all 2¹⁴ patterns finds exactly one solution, 8.9e-16 from the hand-derived point; PATH's point has recomputed residual 9.3e-15 and is 1.8e-15 from the hand-derived point (tolerance 1e-6)
- boundary: the same instance and licence as F-0004; uniqueness by the same three-part argument, which here is also the paper's Theorem 1 (p.19); the properties checked are Theorem 1, the investment criterion of p.16, Lemma 5 (p.21), Lemma 11 (p.27), Corollary 1 (p.20), Lemma 12 (p.29), and the competitive-versus-Cournot ordering of total capacity and prices; Theorem 7 (p.29) is about the closed-loop equilibrium, which is not built, and is cited only for the ordering of the two equilibria that are; the failure mode is a property that holds on this instance by accident of its regime — the peaker investing, all three segment types (a), (c), (b) present — and not in general, which a second instance with a different regime would expose and none is built yet
- supersedes: none

The equilibrium: `x = (65/12, 25/6)`, prices `(125/12, 83/12, 14/3)`, peaker output
`(65/12, 47/12, 5/3)`, base output `(25/6, 25/6, 11/3)`, `λ_p = (2, 0, 0)`,
`λ_b = (21/4, 7/4, 0)`. Total capacity 9.58 against the competitive 15; every price higher.

Two things the paper says in words are visible in the numbers. First, p.16: "Peak plants
may indeed operate in time segments `s > S_p` where they are not most cost efficient." The
competitive peaker is idle in segment 3; the Cournot peaker runs 5/3 there, because the
base player's withholding leaves room above the peaker's operating cost. Second, Lemma 12:
the peak capacity's marginal values `λ_p^s` are the same, `(2, 0, 0)`, in both
equilibria, even though nothing else is. The regime differs from the competitive one — a
first guess at the competitive regime fails, as the derivation shows — so agreement with
the hand derivation here is not agreement with the competitive case relabelled.

## F-0006 — Instance B, a reasonable-scale benchmark: both equilibria are unique, agree with their hand derivation, and satisfy every property the paper states, on a regime set instance A does not reach.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `data/ms2002_instance_b.toml` for the values and the reasoning beside each; `docs/ms2002_instance_b_derivation.md` for the derivation; `test/runtests.jl`, testsets "instance B, competitive: derivation, enumeration, PATH and CCOpt agree", the open-loop counterpart, and the four property testsets, 155/155 passing; `scripts/report_agreement.jl` — enumeration of all 2^18 patterns finds exactly one solution per model, at 0.0 and 7.1e-15 from the derived points; PATH residuals 6.7e-10 and 9.4e-14, distances 4.1e-10 and 2.8e-14 (tolerance 1e-5)
- boundary: one constructed instance in GW and $/MWh — `S = 4` quarter-year blocks, `β = 10`, `α = (150, 115, 100, 90)`, `K = (24, 50)`, `ν = (30, 18)` — whose values are judgements about what a real two-technology system looks like, not measurements of one; the unit convention (capacity cost per MW divided by the 2190 h segment) is what makes the paper's unit-width equations apply, and a reader converting to annual figures must multiply back; uniqueness by the same three-part argument as F-0004; the derivation takes its regime from the enumeration rather than guessing it, so the two are not independent in the choice of regime, only in the arithmetic on it; the failure mode is an instance that is "reasonable" in its inputs and not in its outputs, which the rejected first candidate shows is possible
- supersedes: none

Built because the published article has no numbers to replace instance A with (F-0002) and
one hand-sized instance leaves most of the paper's segment regimes unexercised. The
competitive equilibrium: `x = (1.6, 8.0)` GW, prices `(54, 30, 20, 18)` $/MWh — the peak
price is exactly the peaker's operating cost plus its per-segment capacity cost, the high
shoulder price is the peaker's operating cost, and the base block is served below base
capacity at the base plant's operating cost. Segment types (a), (c), (e), (d), so the two
idle-peaker types missing from instance A are both present. The open-loop Cournot
equilibrium: `x = (593/180, 271/90)`, prices `(86.9, 57.4, 49.9, 46.0)`, total capacity a
third lower, the peaker's share of the mix up from 17% to 52%, and the peaker running in
both blocks beyond `S_p = 2` where competition idles it (p.16 again). Segment types (a),
(c), (c), (b).

The first candidate tried, `α = (150, 130, 115, 100)`, gave a competitive peaker of 0.3 GW
against 9.5 GW of base — its top two blocks sat so close that almost nothing was worth
building for the peak alone. It was rejected on that ground and three peakier shapes were
compared; the one kept has the widest spread of regimes. That comparison is recorded in the
data file so the choice reads as a choice.

## F-0007 — CCOpt's relaxation method agrees with PATH, the hand derivations and the enumeration on all four cases, to within 3e-7.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `test/runtests.jl`, the four "derivation, enumeration, PATH and CCOpt agree" testsets and the four "(ccopt)" property testsets, 155/155 passing; `scripts/report_agreement.jl` — CCOpt residuals recomputed from its points 3.0e-8, 1.7e-8 (instance A) and 1.7e-7, 1.8e-7 (instance B), distances from the derived points 1.3e-8, 1.8e-8, 2.4e-8, 5.2e-8; PATH on the same four is at or below 6.7e-10 on both measures; every property testset passes on CCOpt's point as well as on PATH's
- boundary: CCOpt v0.1.0's relaxation method only, reached through the `MathOptComplements` bridges and `CCOpt.Optimizer` as the engine's `:ccopt` backend; the penalty method is unreachable that way (engine F-0004) and has not been run on anything; both instances are strictly complementary with a unique solution, which is the easy case for a relaxation scheme, so this says nothing about degenerate or multiple equilibria; CCOpt is two to three orders of magnitude less exact than PATH here and its accuracy sets the tolerance the report uses for instance B, which is the failure mode to watch — a tolerance loosened to admit the solver under test
- supersedes: none

This is Phase 2's solver-agreement question, answered early because instance B was being run
through PATH anyway and the second backend costs one line. The answer is the one D-0002
hoped for: on four cases with known answers, CCOpt reaches them. It is a correctness
regression result, not a demonstration of scale, which is how the plan says to frame it.

Two things are worth stating. First, the tolerances. Instance A is judged at 1e-6 and
instance B at 1e-5, both set before CCOpt was run on them and both several hundred times
looser than what CCOpt achieves; the nearest wrong regime is O(1) away on A and O(0.1) on
B, so neither tolerance can admit a wrong answer. Second, the property checks are run on
CCOpt's point independently, not inherited from PATH's; a solver that landed near the right
point but on the wrong side of a complementarity boundary would fail `segment_type` and
the pricing-efficiency check even at a passing distance.

What remains of Phase 2 is the penalty route and the emitted upstream file.

---

## What this does not establish

- **Nothing about the paper's numbers.** There are none in the edition held (F-0001).
  Instance A is constructed, the report says so, and no result here should be quoted as
  "Murphy and Smeers' equilibrium".
- **Nothing about the closed-loop model.** Phase 3. Its conditions are not an LCP (F-0003)
  and its equilibrium is not unique in general (paper §7); F-0004 and F-0005 say nothing
  about it beyond the ordering Theorem 7 states.
- **Nothing about CCOpt.jl's penalty method.** Only the relaxation method is reachable
  through the JuMP path (engine F-0004); F-0007 covers that method and no other.
- **Nothing about CCOpt.jl on a hard case.** Both instances have a unique, strictly
  complementary solution. Degenerate or multiple equilibria — the closed-loop case's
  territory — have not been put to either solver.
- **Nothing beyond two regime sets.** Between them the instances show Cournot types (a),
  (b), (c) and competitive types (a), (c), (d), (e). A peaker that does not invest
  (Theorem 1 allows it), a Cournot segment of type (d) or (e), or a tie at `S_p` are not
  covered.
- **Nothing at scale.** `n = 14` and `n = 18`. The enumeration oracle is exponential and
  stops being usable somewhere around `n = 25`; a larger instance would need a different
  oracle.
- **Nothing about instance B being *the* reasonable instance.** Its values are defended in
  the data file, not measured; another author would choose others, and the paper's
  results would hold on those too.
- **Nothing about the properties' generality.** They are checked on one point of one
  instance. That they hold there is consistent with the paper, not a test of it.

## What remains

1. ~~Resolve `CONFIRM(F-0002)`.~~ Done — the published article has no numerical example.
2. Phase 2, the rest: CCOpt's penalty route through a directly built `MPCCModel` (engine
   F-0004), checked against the JuMP route on all four cases; then the emitter and the
   round-trip check for the upstream test file. The property checks and the enumeration
   oracle apply as they are.
3. ~~A second constructed instance.~~ Done — instance B (F-0006). Still uncovered: a peaker
   that does not invest, and a Cournot segment of type (d) or (e).
