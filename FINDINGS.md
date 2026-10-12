# Findings — CapacityEquilibriaBenchmarks.jl

*Whether this Julia implementation reproduces Murphy and Smeers, and what "reproduces" can
mean given the edition in hand. Solver behaviour as such is the engine's ledger
(`CapacityEquilibria.jl/FINDINGS.md`); this one records model results.*

*Last updated 2026-09-11. Produced against Julia 1.11.3, CCOpt v0.1.0, MadNLP v0.10.1,
PATHSolver v1.7.9, JuMP v1.31.2, MathOptComplements v0.1.1, MPCCModels v0.1.0, on Windows 11,
with the Manifest committed alongside. Every number below traces
to a path named in its `evidence` field. The paper is cited by the printed page numbers of the
May 2002 working paper; PDF page = printed page + 2.*

Tiers are defined in `research-guardrails/QUALITY.md`. Statuses are `open`, `settled`,
`superseded`, `dead-end`. Ids are stable and never reused — cite `F-0001`, never the wording.

---

## F-0001 — The edition of Murphy and Smeers in hand contains no numerical example, so there is nothing to transcribe.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `../literature/Generation_Capacity_Expansion_in_Imperfe.pdf`, 69 pages, dated May 2002; read in full at the section level, and its extracted text searched for tables, "example", "numerical", currency and unit strings, and multi-digit numbers — every hit is a year, a page number, an equation number or a footnote address
- boundary: this edition only — the May 2002 working paper, not the *Operations Research* 53(4) article it became; assumes the PDF is complete, which its continuous printed pagination 1–66 plus front matter supports; the failure mode is a numerical example placed in an online supplement to the published version, which this edition would not show and which F-0002 leaves open
- supersedes: none

A replication would ordinarily begin by transcribing the paper's data: load-duration
blocks, firms and their technology portfolios, capacity and variable costs. The paper has
none of those. It is an analytical paper:
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
- evidence: the repository owner's reading of *Operations Research* 53(4), 646–661, on 2026-09-09, reported as "there are no numerical results"; independent of F-0001, which read the working paper
- boundary: one reading by one person of the article as published; assumes the reading covered the whole article and not the abstract, which the wording supports; the failure mode is a numerical example in an online supplement or appendix held separately from the article, not reported and not checked; nothing here says the two editions agree on anything other than the absence of numbers
- supersedes: none

As first written, this entry was a statement of ignorance: the published version was not
obtainable from this machine, and F-0001 showed the working paper has none, so
`data/ms2002_instance_a.toml` carried a `CONFIRM` marker against it. The marker is now
deleted and the entry settled. The consequence is that D-0004's reading of "matches the
paper" is not a stopgap pending a better edition; it is the only reading there is. Every instance in `data/` is constructed, and
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
returns, unchanged, for the closed-loop model.

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
to 1e-11. "Matching the paper within tolerance" is met in the sense D-0004 gives it, and
cannot be met in any other sense with this edition.

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

This is the solver-agreement question. The answer is the one D-0002 hoped for: on four
cases with known answers, CCOpt reaches them. It is a correctness regression result, not a
demonstration of scale.

Two things are worth stating. First, the tolerances. Instance A is judged at 1e-6 and
instance B at 1e-5, both set before CCOpt was run on them and both several hundred times
looser than what CCOpt achieves; the nearest wrong regime is O(1) away on A and O(0.1) on
B, so neither tolerance can admit a wrong answer. Second, the property checks are run on
CCOpt's point independently, not inherited from PATH's; a solver that landed near the right
point but on the wrong side of a complementarity boundary would fail `segment_type` and
the pricing-efficiency check even at a passing distance.

The penalty route and the emitted upstream file followed as F-0008 and F-0009.


## F-0008 — CCOpt's penalty method reaches all four equilibria too, and the MathOptComplements bridges change nothing.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `scripts/report_agreement.jl` and `test/runtests.jl`, the four "derivation, enumeration, PATH and CCOpt agree" testsets and the eight property testsets, 311 passing — the penalty method's recomputed residuals are 7.9e-8 and 5.2e-8 on instance A and 3.6e-7 and 3.9e-7 on instance B, at distances 5.8e-8, 2.7e-8, 3.3e-8 and 3.1e-8 from the hand-derived points, against tolerances of 1e-6 and 1e-5 set before it was run; the relaxation method reached through the engine's direct `MPCCModel` route returns the same residual and the same distance as the JuMP route on every case, and the two points are bitwise identical (max-norm difference exactly 0.0 on all four cases, asserted with `==`)
- boundary: CCOpt v0.1.0 over MadNLP v0.10.1, both methods at their default options apart from silence, on four linear complementarity problems of 14 and 18 variables, each with a unique strictly complementary solution — the easy case for either scheme, and the one that says least about a solver; the bitwise agreement of the two relaxation routes covers only what these problems ask the bridges to do, which is to lift an affine `[F; x]` pairing over nonnegative variables, and would break on any change to the bridges' variable ordering as well as on free variables or a nonlinear map; the regime check is run at the case tolerance rather than `segment_type`'s stricter 1e-7 default, which is the right tolerance for the claim but leaves it unable to detect a solver whose regime error is smaller than the tolerance at which its point is accepted at all; the penalty method's residuals run two to five times the relaxation method's and both are two to three orders behind PATH, which is the number to watch if a tolerance is ever loosened; the failure mode is a case where the two methods agree with each other and both are wrong, which nothing here would catch and which is why the hand derivation and the enumeration remain the oracles
- supersedes: none — extends F-0007 from one CCOpt method to both, and from two routes to four

The answer is the same as F-0007's: on four problems with known answers, both of CCOpt's
documented methods reach them. That is a correctness regression result and not a
demonstration of scale.

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

Written because none of the round-trip checks had ever been seen to fail, which by this repository's own standard (`research-guardrails/QUALITY.md`,
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


## F-0011 — The emitted file runs in an environment holding only CCOpt.jl's own declared test dependencies.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `scripts/check_upstream_portable.jl`, which reads the dependency list out of the installed CCOpt's `test/Project.toml`, checks that every `using`/`import` in the emitted file names something in that list or CCOpt itself, then builds a throwaway project containing exactly those packages plus CCOpt v0.1.0 and runs the file there — 24 of 24 assertions pass, exit code 0, in a project with no JuMP, no PATHSolver, no `CapacityEquilibria`, no `CapacityEquilibriaBenchmarks`; the file's imports are `Test`, `LinearAlgebra`, `SparseArrays`, `NLPModels`, `MPCCModels`, `CCOpt` and `MadNLP`, and the set outside CCOpt's declaration is empty
- boundary: CCOpt v0.1.0's `test/Project.toml` as installed in this depot on 2026-09-10, resolved fresh, so this is a statement about that version's declared test environment and not about their CI matrix, their Julia version range, or any other platform — the run was on Julia 1.11.3 on Windows; the throwaway project is a superset of what the file imports, by design, since it mirrors theirs rather than the minimum, so this shows the file needs nothing they lack rather than establishing the minimal set; the failure mode it is built to catch is a package reached transitively, which passes a reading of the import list and fails a run, and the check would go red on that
- supersedes: none

The offer to CCOpt.jl is that the file adds no test dependency. Until this was run, that claim rested on reading someone else's
`Project.toml`, which is not the same thing: an import list can be complete and the file
still fail to load, if something it touches arrives transitively in the environment it was
developed in and not in theirs. It does not, and now that has been executed rather than
inferred.

Worth noting what the check does *not* remove. It runs one Julia version on one operating
system, and CCOpt's CI does not necessarily match either. If the file is offered and their
CI is the first thing to see it, that is where a platform difference would surface.


## F-0012 — The closed-loop model shares its entire second stage with the open-loop Cournot model, and its one extra ingredient is a closed-form derivative, not a differentiated solver.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `src/murphy_smeers_closed_loop.jl` for the transcription, each line cited to the May 2002 working paper; `test/runtests.jl`, the testset "closed loop: the second stage, Lemma 7, and equation (16)" and the testsets nested in it, 439/439 passing — at the open-loop capacities of both instances the second-stage LCP returns the open-loop equilibrium's own outputs and duals to 0.0 and 9.6e-15 with a recomputed residual of 0.0; Lemma 7's derivative table agrees with a forward difference of the second-stage solve to 1.5e-10 on every segment and both players; equation (16) built term by term agrees with an independent decomposition of it to better than 1e-9; at the open-loop point ξ_p is 0.0 and ξ_b is −25/12 on instance A and −271/9 on instance B, both matching a closed-form prediction computed outside the function under test
- boundary: two constructed instances, evaluated at one capacity vector each — the open-loop equilibrium — so this establishes that the pieces are transcribed correctly, not that any closed-loop equilibrium has been found; both instances have regimes (a), (c) and (b) only, so the derivative table's (d) and (e) rows are transcribed but unexercised, and an instance reaching them would be a real extension of this check; equation (16) is stated in the paper only at points where `y(x)` is differentiable, and nothing here detects a kink, so a candidate sitting on one would be silently mis-tested; the forward difference uses `h = 1e-6` at a point interior to its regime, and at a kink it would disagree with the analytic derivative for a correct reason rather than an incorrect one
- supersedes: none — refines F-0003

F-0003 recorded that the closed-loop conditions are not an LCP. That stands for the first
stage and is wrong about the model as a whole. The short-run conditions (4), restated on
p.24, are line for line the `y` and `λ` rows of the open-loop Cournot LCP with `x` moved
out of the variables and into `q`. So the second stage is an LCP with a unique solution
(Lemma 2, p.19), and every tool this repository already has applies to it: PATH, both CCOpt
methods, `lcp_residual`, and the enumeration oracle.

What is new is one object: `B_i y_j = ∂y_j/∂x_i`, the sensitivity of the second-stage
equilibrium to first-stage capacity, which the open-loop player ignores and the closed-loop
player exploits. Lemma 7 (14), p.22 gives it in closed form, and it is piecewise constant —
it depends on the segment only through which of the five regimes of partition (13) the
segment is in. So the closed-loop conditions can be evaluated exactly, with no automatic
differentiation and no numerical derivative in the model itself.

The two transcriptions of (16) collapse to an identity worth stating, because it is the
entire difference between the models:

    ξ_i = [K_i − Σ_s λ_i^s] − (β/2) Σ_{s ∈ C_i} y_i^s

where `C_i` is the set of type-(c) segments in which player `i` is at capacity. The bracket
is the open-loop investment condition (6), p.16. Everything else in (16) cancels, because
the diagonal `B_i y_i` is 1 exactly where the player is at capacity and 0 exactly where its
`λ_i^s` is already 0.

Three of the paper's results are then visible rather than asserted. Theorem 2, p.25 says
the equilibria coincide when no segment is type (c), which is when the correction is empty.
Corollary 3 (18), p.28 says a closed-loop equilibrium with a type-(c) segment has
`K_b > Σ λ_b` and `K_p = Σ λ_p`, which is the correction falling on one player only. And at
the open-loop capacities of both instances `ξ_p` is exactly zero while `ξ_b` is strictly
negative, meaning the base player would gain by investing more — the direction Theorem 5,
p.28 gives for closed-loop base capacity, and the reason Theorem 3, p.26 says the open-loop
point is not a closed-loop equilibrium.


## F-0013 — Both instances have a closed-loop equilibrium, and on both, equation (16) has two further roots that are not equilibria.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `src/enumerate_closed_loop.jl`, which enumerates all `2^(4S)` second-stage complementarity patterns and the four first-stage patterns each induces, with no solver in the search; `test/runtests.jl`, testset "the closed-loop equilibrium, and the points that are not", 3.7 s and 7.2 s respectively — three roots of (16) on each instance, of which exactly one has a zero best-response gap; the equilibria are `x = (5, 5)` on instance A and `x = (3.03, 3.54)` on instance B, both with a recomputed (16) residual at or below 3.7e-13, recorded in `data/*_expected.toml` and re-derived by the test rather than read from it; the two other roots on each instance are corners at which one player invests nothing, and the other player can improve its objective by 46.3 and 32.0 on instance A and by 322.5 and 187.9 on instance B
- boundary: two constructed instances; the enumeration finds every root of (16) *at a differentiable point*, and an equilibrium sitting on a kink between regimes would be missed entirely, which this cannot rule out (Lemma 2, p.19 gives only left and right derivatives, and (16) is stated only where they agree); the best-response test is a scan on a 601-point grid per player, so it refutes a candidate decisively and certifies one only up to that grid — it cannot exclude a profitable deviation between grid points; `2^(4S)` is 4096 and 65536 here and hopeless by `S = 6`, the same wall `enumerate_lcp.jl` hits; nothing here establishes that the surviving point is the *only* equilibrium, and D-0006 forbids saying so
- supersedes: none

The central closed-loop result, and not the one expected.

**The equilibria.** Instance A settles at `x = (5, 5)` exactly, with prices `(10, 13/2, 14/3)`
and regimes (a), (c), (b). Instance B settles at `x = (3.03, 3.54)`, prices
`(84.3, 54.8, 148/3, 46)`, regimes (a), (c), (b), (b). Every comparative result the paper
states holds at both: total capacity exceeds the open-loop equilibrium's (Theorem 4, p.28),
base capacity likewise (Theorem 5), every price is below the open-loop price (Theorem 6),
total capacity falls between the open-loop and competitive equilibria (Theorem 7, p.29),
`λ_p` is identical to the open-loop and competitive values (Lemma 12, p.29), and the
investment criterion splits as Corollary 3 (18), p.28 requires, with `K_p = Σ λ_p` and
`K_b > Σ λ_b`.

**Equation (16) is necessary and not sufficient, and this is the demonstration.** On each
instance two further capacity vectors satisfy it: one where the base player invests nothing
and one where the peak player does. Both are genuine roots — the residual is zero, not
small — and both are refuted by a best-response scan, decisively, by margins of tens to
hundreds. They also violate Theorems 4, 6 and 7, which is the paper's own theory reporting
the same thing.

This is Lemma 13, p.31 made concrete. The long-run objective is only piecewise convex, and
its marginal cost can jump downwards (Figure 4, p.32), so a player sitting at zero capacity
can face a positive marginal cost of the first unit — locally optimal — while a larger
investment that crosses into another regime is strictly better. A first-order condition
cannot see across that jump. Nothing in this repository will report a root of (16) as an
equilibrium without the best-response check, and D-0006 is amended to say so.

**One error this turned up.** `ms_closed_loop_conditions_decomposed` writes (16) as the
open-loop condition plus a type-(c) correction. That identity assumes a player's `λ_i^s` is
zero wherever it is not at capacity, which holds only when the player has invested
something: at `x_i = 0` the capacity constraint binds trivially and `λ_i^s` can be large. At
the corner roots the two transcriptions disagree by 25 and 168.5 on instance A. The
identity, its boundary, and a `valid` flag are now stated; the earlier version had been
checked only at points where both players invest, which is exactly where it happens to be
right. The primary transcription, built term by term from Lemma 7, was correct throughout.

*Corrected by F-0018, 2026-09-11.* The explanation in the paragraph beginning "This is Lemma
13, p.31 made concrete" is wrong at all four corners. The player at zero capacity does not
face a positive marginal cost for its first unit: the first unit is profitable, and each
corner is a kink at which the idle reading of a biactive pair makes (16) see no revenue at
all. The roots, the deviation gains and the equilibria stand.


## F-0014 — Diagonalization reaches the same closed-loop equilibria from every start tried, including from the roots of (16) that are not equilibria — and that robustness is a property of the best response, not of the loop.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `src/diagonalize_closed_loop.jl`; `test/runtests.jl`, testset "diagonalization reaches the same point" for the always-on part and "diagonalization from many starts and both orders" behind `RUN_CLOSED_LOOP=true` — 28 runs across two instances, two player orderings and seven starting points each, every one converging to the equilibrium already found by enumeration, none cycling and none hitting the iteration limit; started exactly at each of the four corner roots of (16) identified in F-0013, the loop leaves them and converges in 13 or 14 rounds; a single run costs 10.7 s on instance A and 17.6 s on instance B, a single best response 0.04 s and 0.67 s; step sizes decay geometrically after the first round, `7.5, 2.67, 0.139, 0.023, 0.0039, 0.00064` on instance A from the origin
- boundary: two constructed instances, two players, seven starting points and both of the two possible orderings, so "every start tried" is 28 runs and not a proof of global convergence; the best response is exact only up to the second-stage pattern enumeration being complete, which is `2^(4S)` and therefore the same wall as everywhere else in the closed-loop work; **the cycling detector has never fired**, because nothing in these instances cycles, so it is code that has not been seen to work and should be treated as untested until an instance exercises it; convergence is linear, and the tolerance is on the step rather than on distance to a fixed point, which is the usual overstatement in a convergence claim and is why the trajectory is returned rather than just the endpoint
- supersedes: none

Diagonalization is known to be sensitive to firm ordering and starting point and does not
always converge cleanly. On these two instances it is not sensitive to either. That is worth explaining rather than celebrating, because the
explanation says where the fragility actually lives.

**The corner roots are not fixed points of this loop.** F-0013 found that equation (16) has
three roots on each instance and that two are corners at which one player invests nothing.
Those corners are fixed points of the *first-order condition*. They are not fixed points of
a best-response map, because at a corner the rival's global best response is somewhere else
— which is precisely what the deviation gaps of 46, 32, 322 and 188 measured. Started at
one, diagonalization moves on the first round and converges to the equilibrium.

**So the subroutine carries the risk, not the iteration.** The best response here is
computed globally and exactly: for a fixed rival capacity each second-stage pattern makes
the objective quadratic on an interval, and the minimum over all such pieces is the global
minimum. Had it instead been a local solve from the current iterate, a corner would have
been a fixed point of the whole scheme, and diagonalization would have reported it as an
equilibrium with a clean convergence history. Nothing in the loop would have noticed.

*Corrected by F-0016, 2026-09-11.* The sentence above originally continued "— the obvious
implementation, and the one a solver-based approach invites —", implying that using a solver
for the inner problem would put you in that trap. That is wrong about CCOpt. Started exactly
at a corner, both of its methods leave and find the global best response, because their
homotopy loosens the complementarity before tightening it and the iterate can cross a regime
boundary while it is loose. The risk described here is real for a method that starts with
the complementarity tight; it is not a property of solver-based approaches in general.

*Corrected again by F-0018, 2026-09-11.* Both the sentence and the correction above assumed
the corner is a local optimum. It is not: the objective falls from the first unit of
capacity. A local best response started at a corner would not be trapped there, whatever
method computed it.

That is the finding worth carrying forward. Stacking every player's first-order conditions
into one monolithic MPCC for CCOpt.jl to solve gives a system with all three roots on each
instance, and a solver that finds one is behaving correctly on the
problem it was given. Whatever is offered upstream has to carry the deviation check with it,
or say plainly that its solution set is larger than its equilibrium set.

Two smaller observations. Convergence is linear with a ratio near 1/6 on both instances
after the first couple of rounds, so the loop is cheap in iterations and expensive per
iteration. And the endpoint agrees with the enumeration to better than 1e-6 on both
instances, which is two independent routes to the same point: the enumeration never solves
an optimisation, and the diagonalization never enumerates first-stage patterns.


## F-0015 — The roots of (16) that are not equilibria are exactly the points where the second stage is degenerate, and there the recomputed residual stops measuring accuracy.

- tier: validated
- status: settled
- date: 2026-09-11
- evidence: `upstream/closed_loop_demonstration.jl` and its round-trip testset, 82 assertions passing in a project holding only CCOpt's declared test dependencies — at each of the four corner roots the second-stage LCP has three or four biactive complementarity pairs, is not strictly complementary, and its basis is singular, while at the two equilibria it has none and is strictly complementary; adding 1, 1e3 and 1e5 to the non-investing player's capacity duals, with its output snapped exactly onto its bound, leaves the recomputed residual unchanged, so the dual is an unbounded ray; PATH returns the vertex of that ray (max dual 11.5, 75.2, 84) and both CCOpt methods walk out to about 1e5; the primal agrees across all three solvers to between 2.5e-9 and 1.0e-8 at every corner, as do the regimes and the value of (16); the penalty method's recomputed residual at the corners is 9.8e-4 and 1.0e-3 against 4.7e-8 and 3.1e-7 at the equilibria, while the relaxation method's stays near 1e-7 throughout
- boundary: two constructed instances and four corner points, all of the same kind — one player holding no capacity — so this says nothing about degeneracy arising any other way; the 1e5 figure is where these solvers happened to stop on this problem at their default options and is not a property of either method; the claim that the primal is unaffected rests on the primal agreeing with PATH, which is itself only the vertex solution, so what is established is agreement and not correctness of the primal independent of PATH; `enumerate_lcp_solutions` reports one solution at these points and the solution set is a ray, which is consistent with its documented behaviour of skipping rank-deficient bases but means its count is a lower bound there and should not be read as uniqueness
- supersedes: none

Found by accident, and by an assertion failing rather than passing. The demonstration
written for `upstream/` asserted that both CCOpt methods reach the second stage to 1e-5 at
every one of the six points. That is false at the four corners, and chasing why produced a
better result than the one it was written to show.

**The two phenomena coincide.** F-0013 found that (16) has three roots per instance and
that two are corners where one player invests nothing. Those corners are exactly the points
where the second-stage problem is degenerate. The reason is the same fact in both cases: a
player holding no capacity produces nothing and its capacity constraint binds at zero, so
its own first-order term vanishes *and* any sufficiently large shadow price satisfies the
conditions. The economics and the numerics degenerate together.

**The residual stops being an accuracy measure.** The penalty method's 9.8e-4 at a corner is
not an error of that size in anything meaningful. It is the product of a dual of order 1e5,
which the problem does not determine, with a primal error of order 1e-8, which is the actual
accuracy. Snapping the primal onto its bound collapses the residual. So on this class of
problem the pass criterion this whole programme rests on — recompute the residual from the
returned point and threshold it (engine D-0002) — reports a number that says more about
where along the ray a solver stopped than about whether it solved anything.

That is worth stating plainly because it is a limit of this repository's own method, not
just of a solver's. The programme's answer to "did the solver work" has always been the
recomputed residual, and here is a case where it is the wrong question. What survived
was the primal: outputs, prices, regimes and the value of (16) agree across PATH and both
CCOpt methods everywhere, and it is that agreement, not the residual, that carries the
result.

**It is also the hard case the open-loop work explicitly lacked.** F-0007's boundary said
that both instances there are strictly complementary with a unique solution, "the easy case
for a relaxation scheme", and that nothing had been put to either method on a degenerate
problem. This is that problem, it arrived from the model rather than being constructed, and
the two methods behave differently on it in a way their termination status does not show.

*Refined by F-0018, 2026-09-11.* The coincidence is tighter than this entry puts it. A corner
is a root of (16) because the idle player's biactive pairs are read as idle, which gives it
a zero derivative in every segment; its "own first-order term" vanishes because of that
reading, not because of the economics. The degeneracy and the spurious root are one
biactive pair seen twice.


## F-0016 — CCOpt reaches the global best response on every case tried, including when started exactly at a local optimum that is not global.

- tier: validated
- status: settled
- date: 2026-09-11
- evidence: `src/best_response_mpcc.jl` builds one player's long-run problem as an MPCC — a nonconvex quadratic objective over the second-stage complementarity conditions, `1 + 8S` variables, `4S` linear equalities, `4S` complementary pairs — and `test/runtests.jl`, testset "the best response as an MPCC for CCOpt"; 24 solves over two instances, three rival capacity vectors, both players and both CCOpt methods all return the global best response known exactly from the closed-loop enumeration, to within 1.3e-6 in the objective; the sharper test is 8 further solves started with every variable consistent at a corner root of (16), where the player holds nothing and is at a local optimum, and all 8 leave it and reach the global answer, worth 31.95 and 46.33 on instance A and 187.85 and 322.52 on instance B
- boundary: two constructed instances and one problem family; "global" means agreement with the closed-loop pattern enumeration, which is exact for this family and not a general certificate; both CCOpt methods at default options, where the relaxation homotopy begins with a loosened complementarity and the penalty method with a small penalty, and it is that loosening which plausibly does the escaping — a method started with the complementarity already tight would have no such mechanism and this result should not be read as covering one; the objective's Hessian is indefinite on every segment but the nonconvexity here is mild and structured, one downward jump per regime boundary, so nothing here speaks to a badly nonconvex MPCC; no claim is made that CCOpt finds global optima in general, which would be false
- supersedes: none — corrects an inference drawn in F-0014

The first MPCC result, and it corrects something this ledger said a day earlier.

F-0014 observed that diagonalization's robustness rests on the best response being computed
globally, and reasoned that "with a local best response a corner would have been a fixed
point of the whole scheme, and the loop would have reported it as an equilibrium with a
clean convergence history". That reasoning is sound for a method that only moves downhill
from its starting point. It does not describe CCOpt. Handed the best-response MPCC and
started exactly at the corner, both of CCOpt's methods leave and find the global answer, on
every one of the eight cases tried. A diagonalization loop built on CCOpt would therefore
not have been trapped, and the pessimism in F-0014 was about a hypothetical solver rather
than this one.

The mechanism is almost certainly the homotopy. Both methods begin with the complementarity
conditions relaxed — a positive relaxation parameter in one case, a small penalty in the
other — and tighten them over a sequence of subproblems. While they are loose the iterate
can cross a regime boundary, which is exactly the barrier a fixed-complementarity local
method cannot cross. That is a property of the method rather than of the problem, and it is
the most useful thing this programme has found out about CCOpt so far.

What this does not do is make the monolithic joint system well posed. That
remains blocked on the fact recorded in `src/best_response_mpcc.jl`: equation (16) depends
on a piecewise-constant derivative table, so it is not a smooth function of the variables
and no single smooth MPCC has it as stationarity conditions. The two honest routes are a
disjunctive encoding, which leaves MPCC territory, and stacking each player's MPEC-KKT
conditions, whose constraint qualifications are known to fail generically and which F-0015
shows do fail at the degenerate corners of this very problem. Neither is a translation, and
neither has been built.

*Corrected by F-0018, 2026-09-11.* The 8 corner starts were not at a local optimum. At each
corner the objective falls from the first unit of capacity, so the start admits a feasible
descent path and a method that only moves downhill would leave it too. The 32 solves
reaching the global best response stand; the reading of the 8 as the sharper test, and the
homotopy mechanism offered to explain them, do not.


## F-0017 — A best-response problem can be built whose two optima are tied to fourteen figures and far apart, and on it CCOpt returns the better one about half the time.

- tier: validated
- status: settled
- date: 2026-09-11
- evidence: `src/hard_best_response.jl` locates the ties by golden section on the gap between the two best widely separated local minima; `upstream/hard_case_near_tie.jl` is the generated artifact and reports 16 of 32 solves finding the better well, run in a project holding only CCOpt's declared test dependencies; the four ties, one per instance and player, are at rival capacities 7.254033307585, 3.450296453109, 5.317351598173 and 4.292375886525, where the competing objectives agree to relative 1.7e-14, 3.0e-15, 2.4e-14 and 9.5e-15 with the capacities 1.127, 0.559, 0.567 and 0.500 apart; perturbing the rival capacity by ±0.001 gives margins between 3.9e-3 and 3.1e-2, relative 7e-5 to 1.5e-4, and flips which well is better; an independent in-repository run from PATH-built starting points gave 19 of 32
- boundary: two constructed instances and four ties, all of the same kind — two quadratic pieces of one player's objective crossing — so this is one mechanism for hardness and not a survey; the count depends on the starting point, which is why the artifact reports it rather than asserting it, and the two runs recorded here differ (16 and 19 of 32) purely because one warm-starts from CCOpt's output stage and the other from PATH's; the wells sit on regime boundaries where CCOpt's own output stage is about 2e-4 from PATH's against 1e-8 at an interior point, so the artifact takes its ground truth from the inlined values and does not recompute it; nothing here says CCOpt is worse than any other method on this problem, because no other MPCC solver was run on it
- supersedes: none

Built because the repository had nothing hard. F-0007's problems are strictly complementary
with unique solutions, F-0016's best responses were solved globally from every start tried,
and a test that nothing fails is a weak thing to put in front of a solver's author. So this
was searched for rather than hoped for.

**The mechanism.** A player's long-run objective at a fixed rival capacity is piecewise
quadratic, one piece per second-stage regime, so the landscape is a row of wells. As the
rival's capacity moves, the wells rise and fall relative to one another, and somewhere two
widely separated wells are exactly level. `best_response_tie` finds that capacity by golden
section on the gap.

At the tie the problem is genuinely ambiguous and a solver cannot be marked. Just off it
there is a definite right answer, the margin is 1e-4 in relative terms, and *which* well is
right flips as the rival's capacity crosses the tie. So the same problem perturbed in the
fifth decimal place of one parameter has two answers a fifth of the domain apart. Every
problem in the artifact is posed from a start inside the wrong well, which is the honest way
to ask whether a method can leave one.

**The result.** CCOpt finds the better well in about half of them. Both methods fail, on
different problems, with neither dominating: on instance A's peaking player the relaxation
method keeps the worse well in all four, while the penalty method escapes in two; on
instance B's peaking player the pattern reverses at two of the four offsets. Every returned
point is a genuine local optimum and every one is feasible; the failures are not
convergence failures but a converged answer to a question with two nearly equal answers.

**Why this is the useful artifact of the three.** The open-loop case checks that a solver
reaches a known unique answer. The closed-loop demonstration shows a formulation admitting
answers that are not equilibria. This one asks whether a method can tell two nearly-tied
optima apart when started at the wrong one, which is the question the whole diagonalization
scheme of F-0014 silently depends on. It also puts a number on how hard that is: a margin of
1e-4 relative is enough to make it a coin flip.

**One thing found while building it.** These wells sit on regime boundaries, and there
CCOpt's second-stage solution is about 2e-4 from PATH's, against about 1e-8 at an interior
point. That is a different degradation from F-0015's, which was about an unbounded dual; here
the primal itself is less accurate. It is the reason the artifact inlines its ground truth
rather than recomputing it, since a solver cannot be its own oracle on a margin of 4e-3 when
its own arithmetic is uncertain at 2e-4.


## F-0018 — The corner roots of (16) are kinks, not local optima: the player holding nothing gains from its first unit, and (16) reads zero revenue there only because a biactive pair is classified as idle.

- tier: validated
- status: settled
- date: 2026-09-11
- evidence: found by the documentation build, whose tutorial asserted that the first step out of a corner does not pay, and failed (`docs/src/tutorials/2_closed_loop.md`); then `closed_loop_objective` evaluated at the four corner roots of F-0013 with the idle player's capacity raised to 1e-7 — right slopes −18.0 and −16.5 on instance A, −177.5 and −144.5 on instance B, with the objective falling monotonically out to two units of capacity at all four; the instance A base-player slope checked by hand as `K_b + Σ_s (ν_b − p^s) = 7 + 3 − 28 = −18`, where `p = (12.5, 9, 6.5)` are the peaker's prices alone at `x_p = 7.5`; `ms_closed_loop_conditions` at each corner returns `ξ_i = K_i` exactly (7, 2, 50 and 24), which is (16) with every derivative term zero; and `ms_closed_loop_xi` evaluated at the same corner outputs under the regimes the second stage takes just off the corner returns −18 on instance A, the right slope, both asserted in the tutorial
- boundary: the four corners of F-0013 on two constructed instances, all of one kind, a player holding no capacity; the objective values and best-response gaps of F-0013 come from real second-stage solves and not from (16), so they stand, as does the equilibrium; what this changes is the explanation of why the corners satisfy (16), and every inference that rested on the corners being local optima; the failure mode is a corner on some other instance that is a genuine local optimum, which the paper's Lemma 13 does not exclude and which none of these four is
- supersedes: none — corrects the explanation in F-0013 and F-0015, and the premise of F-0016's corner starts

F-0013 explained the corner roots by the paper's Lemma 13: the long-run objective is only
piecewise convex, so "a player sitting at zero capacity can face a positive marginal cost
of the first unit — locally optimal — while a larger investment that crosses into another
regime is strictly better". At all four corners the first half is false. The first unit is
profitable, strictly, and the objective falls from zero capacity at a steep constant slope.
None of the corners is a local optimum.

**Why (16) holds there anyway.** At `x_i = 0` the idle player's output is `0 = x_i` in every
segment, so each of its capacity pairs is biactive: it is idle and at capacity at once.
`ms_regime` tests `y ≤ tol` first and reads it as idle, which puts every segment in regime
(d) or (e) with that player idle, and Lemma 7 gives `B_i y_i = 0` there. With every
derivative term zero, (16) reduces to `ξ_i = K_i > 0`, complementary to `x_i = 0`: a root.
Read the same pairs as at capacity and the segments are in regimes (a) and (c), where
`B_i y_i = 1`, and (16) evaluates to the right derivative, which is negative. So the
corners are points where the second-stage solution is not differentiable, and (16) is
stated only where it is (p.24). F-0012's boundary named exactly this failure mode — "nothing
here detects a kink, so a candidate sitting on one would be silently mis-tested" — and two
of the three roots on each instance are candidates of that kind. The enumeration of
`enumerate_closed_loop` finds them because the pattern with the output nonbasic and the
capacity dual basic is a legitimate pattern at a degenerate point, and it carries the idle
reading with it.

**This sharpens F-0015 rather than weakening it.** The spurious roots and the degenerate
points coincide because they are the same biactive pair seen twice: as degeneracy it makes
the dual a ray, and as an ambiguous regime it lets the classification choose the branch on
which the corner is a root.

**What stands.** The corners are not equilibria, by the same margins; `best_response_gap`
never consulted (16). The equilibria are unchanged. D-0006's requirement of a best-response
check before a root is called an equilibrium is, if anything, more necessary: the roots it
refutes are not even stationary. F-0015's dual ray and its limit on the residual criterion
are unaffected. So is F-0016's headline: all 32 solves reached the global best response.

**What falls.** F-0016 described its 8 corner starts as "a local optimum that is not
global", and read CCOpt's leaving them as evidence that the homotopy lets an iterate cross a
regime boundary. The start is not a local optimum of the MPCC either: the path
`x_i = t` with the second stage re-solved at each `t` is feasible for the MPCC and lowers the
objective at the right slope from `t = 0`. A method that only moves downhill would leave the
corner too, so those 8 solves are a degenerate start rather than a trap, and the homotopy
inference loses its support without being refuted. F-0014's original sentence, that a local
best response would have sat at a corner, and the correction F-0016 appended to it, both
rested on the corner being a local optimum. Neither stands in the form written: a local best
response started at a corner is not trapped, for the simpler reason that the corner is not a
minimum. The trap test this programme has is F-0017's, where both wells are verified local
minima on both sides.

The wrong explanation also appeared in `docs/REPLICATION_REPORT.md`; in the header of the
generated `upstream/closed_loop_demonstration.jl`, through `scripts/emit_closed_loop_demo.jl`;
in the docstrings of `ms_closed_loop_xi`, `best_response_gap` and
`best_response_start_arrays`, the first and last of which are spliced into the generated
files; in the headers of `diagonalize_closed_loop.jl` and `hard_best_response.jl`; and in a
testset of the corner starts. All are corrected alongside this entry. The
testset, now "CCOpt leaves a degenerate corner it is started at", also asserts the premise it
rests on: that the objective falls from the corner.

---

## What this does not establish

- **Nothing about the paper's numbers.** There are none in the edition held (F-0001).
  Instance A is constructed, the report says so, and no result here should be quoted as
  "Murphy and Smeers' equilibrium".
- **Nothing about the closed-loop equilibrium being unique.** Its conditions are not an
  LCP (F-0003) and its equilibrium is not unique in general (paper §7); D-0006 forbids
  calling the one found *the* equilibrium.
- **Little about CCOpt.jl on hard problems.** The open-loop problems are all strictly
  complementary with unique solutions, which is why their answers are known and why they
  are easy. The closed-loop corners are degenerate with an unbounded dual ray (F-0015), and
  F-0017 is one constructed near-tie. That is a handful of points, not a study.
- **Nothing about how CCOpt compares with anything else.** F-0017 is hard enough that
  CCOpt gets it right about half the time, but no other MPCC solver has been run on it, so
  there is no basis for saying whether that is good, bad or ordinary.
- **Nothing about any upstream artifact being wanted.** All three are generated,
  self-contained, passing and portable to CCOpt's own test environment (F-0009, F-0011,
  F-0015, F-0017). Whether CCOpt.jl's maintainers want any of them is theirs to say.
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

1. An open-loop instance with a peaker that does not invest, or a Cournot segment of type
   (d) or (e); neither regime set is covered.
2. A closed-loop instance whose equilibrium sits on a kink, which the enumeration would miss
   and which would test the boundary F-0013 states.
3. A closed-loop instance whose diagonalization cycles, which would exercise a detector
   that has never fired (F-0014).
4. The monolithic joint system, if wanted. `src/best_response_mpcc.jl` records why it is
   not a mechanical translation of (16), and F-0014 why it cannot be offered upstream
   without the deviation check attached.
5. Offer the upstream files to CCOpt.jl, with the engine's F-0007, the `RawStatusString`
   bug, reported alongside.
