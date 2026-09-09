# CapacityEquilibriaBenchmarks.jl — agent guide

Read first: `docs/ms_ccopt_replication_plan.md` (the phased implementation plan this repo executes, including
its phase gates) and `docs/BRIEF.md`. Julia package depending on `CapacityEquilibria.jl`;
`julia --project -e 'using Pkg; Pkg.instantiate()'`. The CCOpt.jl commit SHA is pinned in `Manifest.toml` and
restated in the README — it is pinned deliberately, not incidentally.

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
- The upstream-facing test files in `upstream/` are generated, never hand-edited. They are produced by
  `scripts/emit_*.jl` from the same `data/` and model definitions, registered in `generated.toml`, and
  round-trip checked against the in-repo model. Editing the artifact instead of the generator is how the copy
  CCOpt.jl's maintainers hold stops matching the model that validated it. See `D-0001`.
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
iteration, and it records convergence behaviour, not just the endpoint). After any model or data change, run
`julia --project scripts/emit_all.jl` and then the stale-artifact gate below.

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
