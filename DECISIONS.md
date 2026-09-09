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
