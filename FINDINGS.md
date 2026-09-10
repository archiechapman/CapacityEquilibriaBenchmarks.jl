# Findings — CapacityEquilibriaBenchmarks.jl

*Whether this Julia implementation reproduces Murphy and Smeers, and what "reproduces" can
mean given the edition in hand. Solver behaviour as such is the engine's ledger
(`CapacityEquilibria.jl/FINDINGS.md`); this one records model results.*

*Last updated 2026-09-10. Produced against Julia 1.11.3, CCOpt v0.1.0, MadNLP v0.10.1,
PATHSolver v1.7.9, JuMP v1.31.2, MathOptComplements v0.1.1, MPCCModels v0.1.0, on Windows 11,
with the Manifest committed alongside. Every number below traces
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

What remained of Phase 2 at the time this entry was written — the penalty route and the
emitted upstream file — is F-0008 and F-0009.


## F-0008 — CCOpt's penalty method reaches all four equilibria too, and the MathOptComplements bridges change nothing.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `scripts/report_agreement.jl` and `test/runtests.jl`, the four "derivation, enumeration, PATH and CCOpt agree" testsets and the eight property testsets, 311 passing — the penalty method's recomputed residuals are 7.9e-8 and 5.2e-8 on instance A and 3.6e-7 and 3.9e-7 on instance B, at distances 5.8e-8, 2.7e-8, 3.3e-8 and 3.1e-8 from the hand-derived points, against tolerances of 1e-6 and 1e-5 set before it was run; the relaxation method reached through the engine's direct `MPCCModel` route returns the same residual and the same distance as the JuMP route on every case, and the two points are bitwise identical (max-norm difference exactly 0.0 on all four cases, asserted with `==`)
- boundary: CCOpt v0.1.0 over MadNLP v0.10.1, both methods at their default options apart from silence, on four linear complementarity problems of 14 and 18 variables, each with a unique strictly complementary solution — the easy case for either scheme, and the one that says least about a solver; the bitwise agreement of the two relaxation routes covers only what these problems ask the bridges to do, which is to lift an affine `[F; x]` pairing over nonnegative variables, and would break on any change to the bridges' variable ordering as well as on free variables or a nonlinear map; the regime check is run at the case tolerance rather than `segment_type`'s stricter 1e-7 default, which is the right tolerance for the claim but leaves it unable to detect a solver whose regime error is smaller than the tolerance at which its point is accepted at all; the penalty method's residuals run two to five times the relaxation method's and both are two to three orders behind PATH, which is the number to watch if a tolerance is ever loosened; the failure mode is a case where the two methods agree with each other and both are wrong, which nothing here would catch and which is why the hand derivation and the enumeration remain the oracles
- supersedes: none — extends F-0007 from one CCOpt method to both, and from two routes to four

Phase 2's remaining solver question, and the answer is the same as F-0007's: on four
problems with known answers, both of CCOpt's documented methods reach them. That is a
correctness regression result and not a demonstration of scale, which is how the plan asks
for it to be framed.

Two things are worth separating out. First, **the bridges construct exactly the lifting
the engine writes by hand.** `:ccopt` and `:ccopt_relaxation` are one method on one problem,
reached with and without the MathOptComplements bridge stack, and they return *bitwise
identical* vectors on all four cases — not agreement to some number of digits, which is how
an earlier draft of this entry put it and which invited the misreading that two independent
numerical paths had converged. What the equality actually says is structural: the bridges
produce the same NLP in the same variable order, and MadNLP is deterministic over it. So
the JuMP-route results in F-0007 are results about the method, not about the bridges.

Second, **every check is run on every backend's point**, independently rather than
inherited: production and pricing efficiency, the investment criterion, Theorem 1, Lemmas 5,
11 and 12, Corollary 1, and the segment-regime classification of partition (13) are each
recomputed from whatever point each solver returned. The regime check matters most here,
because it is the one that distinguishes a solver merely *near* the equilibrium from one on
the right side of every complementarity boundary: a point at a passing distance but in the
wrong regime fails it. None does, on any backend.

That last sentence is a correction. As first written, this entry appealed to `segment_type`
as a check on the CCOpt points when the test ran it on PATH's point alone, so the argument
was not supported by the code beneath it. The check was extended to all four backends rather
than the claim weakened, because the measurements show it survives: the penalty method's
worst point sits 5.8e-8 from the derived one and every regime boundary is O(0.1) away.

The penalty method is slightly the less accurate of the two on every case, by a factor of
two to five in the residual. On these problems that is a remark, not a finding: both sit
hundreds of times inside a tolerance fixed before either ran.

## F-0009 — The upstream test file is generated from the same sources the tests validate, and re-running it reproduces the in-repo model exactly.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `scripts/emit_upstream_test.jl` writes `upstream/test_murphy_smeers_lcp.jl`; `test/runtests.jl`, testset "the emitted upstream file is the same model, and still solves it", which includes the emitted file — running its own 24 assertions against both CCOpt methods inside this suite — and then checks, for each of the four cases, that the matrices its inlined parameters build are `==` to the in-repo `ms_lcp` matrices, that its inlined equilibrium is `==` to `load_ms_expected`, that its inlined tolerance is the instance's own, and that the residual oracle travelling with it returns the same number as the engine's; `generated.toml` and `ci/gates/check_stale_generated.py`, whose baseline covers `data/`, `src/murphy_smeers.jl`, the emitter and the two engine files it splices, and which was confirmed to fail on an edit to the engine file across the repository boundary
- boundary: equality of the matrices, not agreement to a tolerance, which is achievable only because the emitted file's parameters are the same Float64 literals and its assembly is the same code — a future emitter that rounded a parameter for readability would break this check, and should; the round trip establishes that the emitted copy *is* the validated model, not that the validated model is right, which is F-0004 to F-0008's job; the staleness gate compares hashes and so catches a source edited without regenerating, but cannot catch a source and an artifact edited to agree with each other, which is what "generated files are never hand-edited" is for; the failure mode is a reader who takes the emitted file for a replication of the paper's numbers, which its header is written to prevent
- supersedes: none

D-0001 chose a generator over a hand-written file to stop the copy CCOpt.jl's maintainers
might hold from drifting away from the model that validated it. The mechanism is stronger
than that decision anticipated: the emitted file contains no second transcription of
anything. The model assembly is copied verbatim out of `src/murphy_smeers.jl` between
markers, the vertical-form NLP and the residual oracle verbatim out of the engine, and the
data inlined from `data/`. What the emitter authors is the scaffolding — the imports, the
case table, the testsets and the header — and nothing that could be wrong about the
economics or the arithmetic.

That is why the round-trip check can demand exact equality rather than agreement within a
tolerance, and why the check is worth having: it fails the moment the emitted copy stops
being the same object as the model, rather than the moment the two disagree by enough to
notice.

The header of the emitted file says, in its own words, that the instances are constructed,
that neither edition of the paper publishes numbers, and that both problems are the easy
case of a unique strictly complementary solution. A reviewer who reads only that file
should not be able to come away believing this is a replication of published results.


## F-0010 — The checks that guard the emitted upstream file fail when they should, and no two of them are the same check.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `scripts/negative_controls.jl`, which breaks a copy of the emitted file in eight ways and reports which check notices, exiting nonzero if any goes unnoticed — nine controls, all behaving as expected: a corrupted equilibrium is caught by `case.z == z_hand` (NC1), a corrupted `alpha` or `beta` by the parameter match against `data/` (NC2, NC3), a dropped case by the case count (NC4), a corrupted *model assembly* with every parameter left intact by `Me == M` and by nothing else (NC8), and a corrupted equilibrium or parameter by the emitted file's own assertions with no repository beside it (NC6, NC7); the unmutated file fires none of them (NC0); the regime check catches a 1e-5 displacement off a complementarity bound and not a 1e-8 one (NC5)
- boundary: eight mutations, each a single-token change, so this establishes that each check is live and not that the set is complete — a mutation nobody thought of is still a mutation nobody has tried; the mutants are copies and no control here touches the repository, which also means none of them exercises `ci/gates/check_stale_generated.py`, whose own negative control was run separately by editing an engine source file and confirming the gate went red; NC5's floor is the case tolerance itself, so a solver whose regime error is smaller than the tolerance at which its point is accepted at all cannot be caught by that check and is not claimed to be; the controls run against CCOpt v0.1.0 and would need re-running, not merely re-reading, after a version move
- supersedes: none

Written because the self-review of Phase 2 found that none of the new checks had ever been
seen to fail, which by this repository's own standard (`research-guardrails/QUALITY.md`,
and the engine's F-0005, whose licence test was written only after both branches were run)
means none of them was yet known to be a check.

The result worth keeping is not that everything passed. It is **which** net caught what.
The round-trip test matches an emitted case to `data/` by its parameters and only then
compares matrices, so corrupting a parameter and corrupting the model code fail in
completely different places: the first makes a case unmatchable, the second leaves every
case matchable and moves `M`. NC8 is the control that separates them, and without it the
matrix comparison could have been deleted while every other control still passed. That is
the state a suite drifts into when its controls are never run, and it is why the script is
committed rather than run once and described.

NC5 is a measurement rather than a pass. Displacing `y_p^3` off its bound at the instance A
competitive equilibrium changes the segment from type (e) to type (c) as soon as the
displacement exceeds the tolerance, and not before:

| displacement of `y_p^3` | regime reported | caught |
|---|---|---|
| 1e-8, 1e-7, 1e-6 | a, c, e | no |
| 1e-5, 1e-4, 1e-2 | a, c, c | yes |

So the regime check discriminates at the tolerance, four orders finer than the O(0.1)
distance to the nearest genuine regime — and the tolerance is also its floor, which is the
honest reading of what F-0008 claims when it says a solver on the wrong side of a boundary
would fail it.

---

## What this does not establish

- **Nothing about the paper's numbers.** There are none in the edition held (F-0001).
  Instance A is constructed, the report says so, and no result here should be quoted as
  "Murphy and Smeers' equilibrium".
- **Nothing about the closed-loop model.** Phase 3. Its conditions are not an LCP (F-0003)
  and its equilibrium is not unique in general (paper §7); F-0004 and F-0005 say nothing
  about it beyond the ordering Theorem 7 states.
- **Nothing about either CCOpt method on a problem it might fail.** Both are now covered
  (F-0008), on four problems chosen because their answers are known — which is the same
  reason they are easy.
- **Nothing about CCOpt.jl on a hard case.** Both instances have a unique, strictly
  complementary solution, and that is the whole of what has been put to either method.
  Degenerate or multiple equilibria — the closed-loop case's territory — have not been.
- **Nothing about the upstream file being wanted.** It is generated, self-contained and
  passing (F-0009); no maintainer has been asked whether they want it.
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
2. ~~Phase 2, the rest: CCOpt's penalty route through a directly built `MPCCModel` (engine
   F-0004), checked against the JuMP route on all four cases; then the emitter and the
   round-trip check for the upstream test file.~~ Done — F-0008 and F-0009. Phase 2's
   deliverable, `upstream/test_murphy_smeers_lcp.jl` with the PR description beside it, is
   built and has not been offered to anyone.
3. ~~A second constructed instance.~~ Done — instance B (F-0006). Still uncovered: a peaker
   that does not invest, and a Cournot segment of type (d) or (e).
4. ~~Confirm the new checks fail when they should.~~ Done — F-0010, and the engine's
   F-0008 for the routes it owns.
5. Open the pull request against CCOpt.jl, or decide not to. The artifact stands on its own
   as a validation case either way (the plan's own framing), and the engine's F-0007 — the
   `RawStatusString` bug — is worth reporting with it.
6. Phase 3: the closed-loop model. Its conditions are not an LCP (F-0003), so neither the
   enumeration oracle nor `lcp_residual` carries over unchanged, and its equilibrium is not
   unique in general.
