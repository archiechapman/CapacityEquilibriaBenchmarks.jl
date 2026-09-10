# CapacityEquilibriaBenchmarks.jl — agent guide

Read first: `docs/ms_ccopt_replication_plan.md` (the phased implementation plan this repo executes, including
its phase gates) and `docs/REPLICATION_REPORT.md` (the authoritative results). Julia package depending on
`CapacityEquilibria.jl`; `julia --project -e 'using Pkg; Pkg.instantiate()'`. CCOpt.jl is bounded at `"0.1"` in
`Project.toml` and resolved exactly by the committed `Manifest.toml`; the plan called for a commit-SHA pin,
which turned out to be unnecessary once CCOpt.jl was found in the General registry (`D-0003`). The bound
moves deliberately, in a commit of its own, not incidentally.

If the code and this file disagree, the code is newer — but read the rationale in `DECISIONS.md` before
overturning anything. Most of what looks arbitrary here was argued once already.

## Where the authoritative answers live

`docs/REPLICATION_REPORT.md` is the authoritative synthesis: per case, the paper's published number, the PATH
solve, the CCOpt.jl solve, and the tolerance each comparison was made at. It supersedes any number appearing
in a docstring, a README, or a commit message.

A case is described as replicated only at the tier its ledger entry carries. Phase 1's gate is that both
open-loop cases match the paper within a stated tolerance. The closed-loop case has no unique ground truth at
all, so "validated" there means diagonalization-consistent and must be written that way, in the report and in
anything sent upstream.

`FINDINGS.md` is the claim ledger. Cite findings by id (`F-0007`), never by the wording of the claim.
`DECISIONS.md` is the decision log. Both are checked in CI; see the synced section below.

## Hard rules (enforce, don't just suggest)

- Every numeric parameter traces to a specific table and page of its source paper, recorded in `data/` next
  to the value. No parameter literals in model code. This is the single highest-risk point in the whole plan,
  because every later comparison is downstream of the transcription being right.
- Never adjust a transcribed parameter, a unit convention, or a solver setting to make a replication match. A
  mismatch is investigated — settings, then units, then transcription, then the paper's own ambiguity — and
  the explanation is recorded as a finding. Tuning until the numbers agree destroys the only thing this repo
  is for.
- The upstream-facing files in `upstream/` are generated, never hand-edited. There are two:
  `scripts/emit_upstream_test.jl` writes the open-loop regression test and
  `scripts/emit_closed_loop_demo.jl` writes the closed-loop demonstration. Both inline `data/` and
  splice the model itself out of `src/murphy_smeers.jl`, `src/murphy_smeers_closed_loop.jl` and the
  engine's `src/lcp_nlp.jl` and `src/pairing.jl` between `# emit:<tag>:begin`/`:end` markers. The
  `.md` files beside them are hand-written and are not generated. Moving or deleting a marker stops the emitter rather than shrinking
  its output. The artifact is registered in `generated.toml` and round-trip checked against the in-repo model
  by `test/runtests.jl`. Editing the artifact instead of the generator is how the copy CCOpt.jl's maintainers
  hold stops matching the model that validated it. See `D-0001` and `FINDINGS.md` F-0009.
- Nothing here depends on `AdequacyMechanismSandpit.jl`. Cases here are published models with published
  answers; if a case needs an unpublished mechanism to make sense, it belongs in the sandpit.
- Commit `Manifest.toml`. This is a reproducible study, not a library, and the CCOpt.jl pin is part of the
  result.

## Read before touching the data transcription in `data/`

Full detail: `data/PROVENANCE.md`

Short version, so the rule survives an unfollowed link:

- **Never** change a value in `data/` without updating its provenance entry in the same commit and re-running
  the full validation for every case that reads it. Both formulations and the emitters share these files,
  which is the point, and it also means one edit moves three results.
- **Always** record a parameter the paper under-specifies as a `CONFIRM` marker against an exploratory ledger
  entry, never as a silent choice. A reviewer checking the test case against the paper will hit the same
  ambiguity, and it needs to be findable when they do.

## Tests

`julia --project -e 'using Pkg; Pkg.test()'` runs the open-loop replication against the published numbers.
Set `RUN_CLOSED_LOOP=true` for the Phase 3 diagonalization suite (slow: one PATH solve per firm per
iteration, and it records convergence behaviour, not just the endpoint). After any model or data change, run `julia --project scripts/emit_upstream_test.jl` and
`julia --project scripts/emit_closed_loop_demo.jl`, then
`python ci/gates/check_stale_generated.py . --write`, then the gates below.

`julia --project scripts/negative_controls.jl` is the other half of the suite and is not run by
`Pkg.test()`. It corrupts a copy of the emitted file eight ways and fails if the checks that
should notice do not (`FINDINGS.md` F-0010). Run it after changing `test/runtests.jl`'s round-trip
testset, the emitter, or `segment_type` — those are the things it is a control for, and a check
that has never been seen to fail is not yet known to be a check.

`julia --project scripts/check_upstream_portable.jl` runs the emitted file in a throwaway project
built from CCOpt.jl's own `test/Project.toml` and nothing else (`FINDINGS.md` F-0011). Run it
after any change to the emitter's imports, and before offering the file to anyone: the offer is
that it adds no test dependency, and that is a claim about someone else's project.

**Nothing in `upstream/` has been sent anywhere.** `upstream/ISSUE.md` is a drafted note and
`scripts/share_upstream.sh` publishes the file as a public gist and prints the `gh` command that
would post it. Posting is outward-facing and is the repository owner's decision, not a step in
any workflow here.

<!-- guardrails:begin -->
## Portfolio conventions

*Synced from `research-guardrails`. Do not edit this block in place — that silently forks the portfolio's
conventions and `check_guardrails_sync.py` will fail. To change it, change it in `research-guardrails` and
re-run `sync/install.py` here. The version this block came from is in `.guardrails-pin`.*

**Before changing anything**, identify which contract in this repo the change touches, and search
`FINDINGS.md` for existing counterexamples and negative results first. A result someone already recorded as
a dead end is cheaper to read than to rediscover.

**Make the smallest change that answers the question.** Then run the ordinary tests, then run the applicable
guardrail gates, then report assumptions and unresolved boundaries explicitly rather than leaving them for a
reader to infer.

**Evidence tiers** (`research-guardrails/QUALITY.md`) — every entry in `FINDINGS.md` carries exactly one:

- `reproduced` — re-derived from source on a separate run, agreeing within a stated tolerance.
- `validated` — checked once against a named oracle independent of the thing being checked. A tool
  reporting its own success is not an oracle.
- `exploratory` — produced, not yet re-derived. The correct tier for most work in progress, and not an
  admission of sloppiness.

Every finding also states a **boundary**: its domain, its assumptions, and one known failure mode, as part
of the claim rather than a hedge appended to it. "Holds for radial topologies; here is what breaks in a
mesh" is a boundary. "Holds" is not.

**`CONFIRM` markers** flag a fact reconstructed from partial sources. Write them as
`CONFIRM(F-NNNN): what to verify`, pointing at an `exploratory` ledger entry. Resolving one means deleting
the marker *and* updating the entry — deleting the marker alone relocates the uncertainty somewhere harder
to see.

**Being wrong is recorded, not deleted.** A superseded finding keeps what was claimed, what is wrong with
it, what part still stands, and why it is being kept. The new entry cites the old by id.

**Graded refusal is success.** The gates report `passed`, `failed`, `inapplicable` or `indeterminate` (exit
0, 1, 2, 3). The last two are correct answers, not failures to be worked around. If a gate says
`indeterminate`, give it what it needs rather than making it stop asking.

**The gates**, in `ci/gates/`, each run standalone against the repo root:

```
python ci/gates/check_findings_ledger.py . --check
python ci/gates/check_confirm_markers.py . --check
python ci/gates/check_decision_log.py . --check
python ci/gates/check_stale_generated.py . --check
python sync/check_guardrails_sync.py . --check
```
<!-- guardrails:end -->
