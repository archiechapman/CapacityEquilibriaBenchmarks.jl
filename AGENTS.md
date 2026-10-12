# CapacityEquilibriaBenchmarks.jl — agent guide

Read first: `docs/REPLICATION_REPORT.md` (the authoritative results) and `data/PROVENANCE.md` (where every
number comes from). Julia package depending on `CapacityEquilibria.jl`, reached by relative path;
`julia --project -e 'using Pkg; Pkg.instantiate()'`. CCOpt.jl is bounded at `"0.1"` in `Project.toml` and
resolved exactly by the committed `Manifest.toml` (D-0003). The bound moves deliberately, in a commit of its
own.

If the code and this file disagree, the code is newer, but read the rationale in `DECISIONS.md` before
overturning anything. Most of what looks arbitrary here was argued once already.

## Where the authoritative answers live

`docs/REPLICATION_REPORT.md` is the authoritative synthesis: per case, what the paper states, the PATH solve,
the CCOpt.jl solves, and the tolerance each comparison was made at. It supersedes any number in a docstring,
a README or a commit message.

A case is described as replicated only at the tier its ledger entry carries. The paper publishes no numbers,
so "validated" means what D-0004 says for the open-loop models and what D-0006 says for the closed loop, and
must be written that way in the report and in anything sent upstream.

`FINDINGS.md` is the claim ledger. Cite findings by id (`F-0007`), never by wording. `DECISIONS.md` is the
decision log. Both are checked by the gates in the synced section below.

## Hard rules (enforce, don't just suggest)

- Every numeric parameter traces to its source, recorded in `data/` next to the value; a constructed value
  says so and cites the assumption it satisfies. No parameter literals in model code. Every later comparison
  is downstream of the data being right.
- Never adjust a parameter, a unit convention, or a solver setting to make a result match. A mismatch is
  investigated (settings, then units, then transcription, then the paper's own ambiguity) and the
  explanation is recorded as a finding.
- The files in `upstream/` are generated, never hand-edited. `scripts/emit_upstream_test.jl`,
  `scripts/emit_closed_loop_demo.jl` and `scripts/emit_hard_case.jl` inline `data/` and splice the model out
  of `src/` and the engine's `src/lcp_nlp.jl` and `src/pairing.jl` between `# emit:<tag>:begin`/`:end`
  markers. Moving or deleting a marker stops the emitter rather than shrinking its output. Each file is
  registered in `generated.toml` and round-trip checked against the in-repository model by
  `test/runtests.jl` (D-0001, F-0009).
- Nothing here depends on an application repository. Cases here are published models; a case that needs an
  unpublished mechanism to make sense does not belong here.
- Commit `Manifest.toml`. This is a reproducible study, not a library, and the resolved versions are part of
  the result.

## Read before touching the data in `data/`

Full detail: `data/PROVENANCE.md`. The short version:

- **Never** change a value in `data/` without updating its provenance entry in the same commit and
  re-running the full validation for every case that reads it. The models and the emitters share these
  files, so one edit moves several results.
- **Always** record a parameter the paper under-specifies as a `CONFIRM` marker against an exploratory ledger
  entry, never as a silent choice.

## Tests

`julia --project -e 'using Pkg; Pkg.test()'` runs the full validation, including the three emitted files.
Set `RUN_CLOSED_LOOP=true` for the multi-start diagonalization study (slow: it records convergence behaviour,
not just the endpoint). After any model or data change, rerun the three emitters, then
`python ci/gates/check_stale_generated.py . --write`, then the gates below.

`julia --project scripts/negative_controls.jl` is the other half of the suite and is not run by
`Pkg.test()`. It corrupts a copy of the emitted test file eight ways and fails if the checks that should
notice do not (F-0010). Run it after changing the round-trip testset, an emitter, or `segment_type`.

`julia --project scripts/check_upstream_portable.jl` runs the emitted files in a throwaway project built from
CCOpt.jl's own `test/Project.toml` and nothing else (F-0011). Run it after any change to an emitter's imports.

Anything sent to CCOpt.jl's maintainers is the repository owner's decision, not a step in any workflow here.

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
