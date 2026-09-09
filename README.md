# CapacityEquilibriaBenchmarks.jl

Published capacity-expansion equilibrium models with published answers, built twice each:
once as a complementarity problem solved with PATH, treated as ground truth, and once as an
MPCC for CCOpt.jl, treated as the object under test.

Two outputs, deliberately kept distinct: a replication study (does this Julia implementation
reproduce the paper's numbers), and a validation contribution to CCOpt.jl (given a problem
whose answer is known, does CCOpt.jl reach it).

**Status: Phase 0 complete.** The project resolves, reaches the engine, and drives both
backends. There is no Murphy and Smeers model and no transcribed data yet — Phase 1 is where
those arrive. See `docs/ms_ccopt_replication_plan.md`, and its Phase 0 corrections section
for the five places the plan turned out to be wrong.

## Layout

| Path | What it is |
|---|---|
| `data/` | Transcribed paper parameters, every value tracing to a table and page. See `data/PROVENANCE.md` — this is the repository's one dangerous area. |
| `src/` | Model construction. Reads `data/`, builds against `CapacityEquilibria.jl`. |
| `test/` | The replication assertions against published numbers. |
| `scripts/` | The emitters that generate the upstream test files. |
| `upstream/` | Generated, never hand-edited. Self-contained files offered to CCOpt.jl. |
| `docs/` | The plan, and the replication report once there is one. |

## Getting set up

This project reaches the engine by relative path, so clone both side by side:

```
Code dev/CapacityEquilibria/
  ├── CapacityEquilibria.jl
  └── CapacityEquilibriaBenchmarks.jl
```

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

`Manifest.toml` is committed here, unlike in the engine: this is a reproducible study rather
than a library, and the resolved dependency versions are part of the result (`DECISIONS.md`,
D-0003). PATH's licence setup is in the engine's README.

## The rules that matter most

**Every parameter traces to a table and a page**, recorded in `data/` beside the value. The
plan calls this the single highest-risk point in the whole exercise, because every later
comparison is downstream of the transcription being right.

**Never adjust a value to make a result match.** A mismatch is investigated — solver
settings, then units, then transcription, then the paper's own ambiguity — and the
explanation is recorded as a finding. Tuning until the numbers agree destroys the only thing
this repository is for.

**`upstream/` is generated.** Edit the emitter in `scripts/`, never the artifact. The
round-trip check is what stops the copy CCOpt.jl's maintainers hold from drifting away from
the model that validated it.

## Documents

- `AGENTS.md` — the agent guide, and the hard rules
- `docs/ms_ccopt_replication_plan.md` — the phased plan, and its corrections
- `data/PROVENANCE.md` — where every number came from
- `DECISIONS.md` — the decision log (`FINDINGS.md` starts when there is a finding)
