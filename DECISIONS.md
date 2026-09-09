# Decisions — CapacityEquilibriaBenchmarks.jl

*The software and modelling choices this repo has made, why, and what would make each worth reopening.
Append-only: a superseded decision is marked, never deleted or edited into agreement with its replacement.*

*If the code and this file disagree, the code is newer — but read the rationale here before overturning it.
Most of these were argued once already.*

Checked by `check_decision_log.py`. Ids are stable and never reused.

---

## D-0001 — Upstream test files are emitted from a generator, never written by hand.

- date: 2026-09-09
- status: active
- question: What form does the test case offered to CCOpt.jl take — a file that calls into this project's
  packages, or a standalone file with its data inlined?
- options: a test that imports `CapacityEquilibria.jl` and builds the model through it, which stays in sync
  automatically but makes this project a dependency of their test suite; a standalone file written once by
  hand, which is easy to accept and drifts silently; a standalone file emitted by a generator kept here,
  with a round-trip check
- decision: Emit it. `scripts/emit_*.jl` reads the shared `data/` transcription and the in-repo model
  definition and writes a self-contained file into `upstream/` with no imports beyond JuMP, NLPModels and
  CCOpt.jl. A round-trip check re-runs the emitted file and requires the same numbers to the same tolerance,
  and `generated.toml` makes staleness a CI failure here.
- evidence: judgement, no measurement — a maintainer weighing a test that adds an external dependency
  against one that adds a single file will take the file, and the plan's whole framing of the contribution
  as a small correctness regression test argues against handing them a dependency. The drift risk that
  choice creates is the thing the round-trip check is for.
- cost_of_change: Cheap. The generator is a script; abandoning it means keeping whichever file it last
  emitted. The expensive direction is the reverse — discovering after the PR is merged that the accepted
  copy no longer matches the model that validated it.
- revisit_if: CCOpt.jl's maintainers say they would rather depend on the package than vendor a file, or the
  emitted file grows past the point where a reviewer can read it in one sitting, which would mean the case
  is too large to be the regression test it is being offered as.

## D-0002 — This repository goes public when its first case passes, not before and not after.

- date: 2026-09-09
- status: active
- question: When does a replication repository become public, given that the results it holds are not yet
  validated?
- options: public from the first commit; public once Phase 1's gate passes; private until the technical note
  is written; private until any resulting publication is out
- decision: Public once Phase 1 passes — both open-loop cases matching the paper within a stated tolerance.
- evidence: judgement, no measurement — Murphy and Smeers (2005) is a published paper and reproducing its
  numbers is not a novel result, so there is nothing here to embargo. What would be embarrassing is a public
  repository asserting a replication that has not been checked, which is what the gate prevents. The work
  with an actual embargo case is in `AdequacyMechanismSandpit.jl`, which is separate for exactly this reason.
- cost_of_change: Asymmetric and worth stating. Staying private longer is free. Going public early cannot be
  undone: the history is readable from that moment and stays readable.
- revisit_if: A case is added whose source data cannot be redistributed, or a replication turns up something
  that is a novel result rather than a reproduction — either would need its own decision rather than
  inheriting this one.

## D-0003 — `Manifest.toml` is committed; CCOpt.jl is bounded by version, not pinned by SHA.

- date: 2026-09-09
- status: active
- question: Does this repository pin its dependency versions, given that the engine it depends on
  deliberately does not?
- options: no manifest, resolving fresh like a library; a committed manifest pinning everything; a committed
  manifest with CCOpt.jl alone pinned by SHA; a committed manifest plus an ordinary compat bound, once
  CCOpt.jl turned out to be registered
- decision: Commit the manifest, and bound CCOpt.jl at `"0.1"` in `Project.toml`. No SHA pin: CCOpt.jl is
  registered at v0.1.0, so the committed manifest already records an exact resolved version and its
  `git-tree-sha1`, which is the reproducibility the plan wanted a commit pin for.
- evidence: `CapacityEquilibria.jl` F-0002 — CCOpt.jl is in the General registry with one tagged version,
  which the plan (and this entry, as first written) assumed was not the case. The manifest half still
  stands on judgement: this repository is a reproducible study rather than a library, so an unpinned
  dependency means a result that cannot be reproduced next month. `CapacityEquilibria.jl` D-0001 makes the
  opposite choice for the opposite reason, and the two are not in conflict.
- cost_of_change: Cheap either way, but the cost of not having done it is only discovered once a result
  fails to reproduce, at which point the information needed to explain why is already gone.
- revisit_if: CCOpt.jl tags a v0.2 with API changes, at which point the bound is widened deliberately and
  the results re-run across the change rather than the bound being relaxed to whatever resolves; or this
  repository stops being able to resolve `CapacityEquilibria.jl` by relative path, which is how the engine
  is reached until it is registered.

The version gets moved deliberately and once, per the plan's own risk section, rather than tracked
continuously. A move is a commit of its own naming the old and new versions, so that a change in results
across it is attributable.

The entry as first written called for a commit-SHA pin, because the plan said CCOpt.jl had no tagged
releases. It has one. The decision is not superseded — the intent, an exactly reproducible dependency, is
unchanged and is better served by the registry than by a SHA — but the mechanism named here is not the one
the plan specified, and the difference is recorded rather than quietly implemented.

The engine is currently reached through a `[sources]` relative path, so this manifest records
`path = "../CapacityEquilibria.jl"` and assumes the two repositories are cloned side by side. That is
adequate while both are private and co-developed and is the weakest link in this entry's reproducibility
claim; it is named in `revisit_if` above rather than left to be discovered.

## D-0004 — With no published numbers, ground truth for Phase 1 is the paper's analysis, a hand derivation and exhaustive enumeration.

- date: 2026-09-09
- status: active
- question: What does "matches the paper within tolerance" mean when the edition in hand
  publishes no numerical example at all?
- options: stop until the published article is obtained; construct an instance; borrow Stoft's figures — in
  full: stop Phase 1 until the published 2005 article is obtained and checked for a
  numerical example; construct an instance satisfying the paper's stated assumptions and
  validate the solver against the paper's analytical results on it; take "typical" cost
  figures from Stoft (2002), which the paper cites but does not reproduce, and present
  them as the paper's
- decision: Construct an instance, and say so everywhere it appears. Ground truth for a
  case is then three independent things that must agree: the equilibrium derived by hand
  from the paper's equilibrium conditions; every solution found by enumerating all
  complementarity patterns of the LCP, with uniqueness argued from monotonicity and strict
  complementarity; and the properties the paper states hold at equilibrium — production
  and pricing efficiency, the investment criterion, Theorem 1, Lemmas 5, 11 and 12,
  Corollary 1 — each checked on the solver's point. The Phase 1 gate is read as: PATH's
  point agrees with the hand derivation and the enumeration within a stated tolerance, and
  every stated property holds at it.
- evidence: `FINDINGS.md` F-0001 — the 69-page working paper contains no table of
  parameters or results, checked by reading it and by text search. The rest is judgement:
  a constructed instance validated three ways is a stronger correctness check on the model
  code than a transcribed instance validated once against a printed number would be, and it
  is the only check available. What it cannot be is a replication of published numbers, and
  the report must not call it one.
- cost_of_change: Cheap. If the published article turns out to carry a numerical example,
  transcribing it is a new data file and a new test, and everything built here — the LCP
  assembly, the oracle, the property checks — applies to it unchanged. The constructed
  instance stays as a regression case either way. The expensive direction would have been
  presenting Stoft's figures, or any invented ones, as the paper's.
- revisit_if: The published *Operations Research* version is obtained and contains a
  numerical example (resolve `CONFIRM(F-0002)`); or a later paper in this programme
  publishes numbers for this model, which would then become the transcribed case.

The third option was rejected outright rather than weighed: a number attributed to a source
that does not contain it is the exact failure `data/PROVENANCE.md` exists to prevent.

## D-0005 — The Murphy–Smeers models are assembled as explicit LCP matrices, not as structured JuMP models.

- date: 2026-09-09
- status: active
- question: Should the model be written as a JuMP model with named variables and one
  `MOI.Complements` constraint, or as a matrix `M` and vector `q` fed to the engine's
  `lcp_model`?
- options: a structured JuMP model, readable and closer to the paper's notation, with its
  own model-specific residual function; explicit `(M, q)` assembled from the data, reusing
  `lcp_model` and `lcp_residual` unchanged; both, with a test that they coincide
- decision: Explicit `(M, q)`, built by `ms_lcp` from three index functions that fix the
  variable layout once. The pairing — the one dangerous area, per the engine's
  `docs/COMPLEMENTARITY_PAIRING.md` — is then the layout and nothing else. The risk that
  the layout is mis-assembled is met by `ms_conditions`, a second transcription of the same
  equations written row by row without `M`, and a test that the two agree at arbitrary
  points.
- evidence: `FINDINGS.md` F-0003 — both models are pure linear complementarity problems,
  so nothing the structured form would add is needed to express them, and the engine's
  residual oracle applies without generalisation. Judgement on the rest: two transcriptions
  that must agree catch an index error; one readable transcription does not.
- cost_of_change: Cheap now. A structured builder can be added beside `ms_lcp` at any time,
  and the agreement test extends to it. It becomes expensive only if Phase 2's emitter is
  written against one form and the other is later wanted upstream.
- revisit_if: The closed-loop model (Phase 3) turns out not to be expressible as an LCP —
  which it will not be, since the paper's (16) on p.24 involves the second-stage solution
  map — at which point the engine needs a nonlinear complementarity form and this decision
  covers only the open-loop cases; or CCOpt.jl's maintainers ask for the upstream test in
  JuMP form.
