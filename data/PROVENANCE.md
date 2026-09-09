# Data provenance

*Every numeric parameter used anywhere in this repository traces back to a specific table
and page in its source, recorded here alongside the value rather than in a commit message
or a comment that can drift out of sync with the code.*

`AGENTS.md` names this directory as the repository's one dangerous area, and the replication
plan calls the transcription "the single point of highest risk in the whole plan", because
every later comparison is downstream of these numbers being right. `test/runtests.jl` checks
that every `.toml` file in this directory is named in this document; it cannot check that
the numbers are right, which is what the rules below are for.

**Status: empty.** No parameter has been transcribed yet. Phase 1 is where that starts.

## Rules

1. **One source per file, named in full.** A transcription file states its source paper, and
   every value in it names the table and page it came from. A value with no table and page
   is not transcribed, it is remembered.
2. **Never adjust a value to make a result match.** A mismatch against a published number is
   investigated — solver settings, then unit and numeraire conventions, then the
   transcription, then the paper's own ambiguity — and the explanation is recorded as a
   finding. Tuning until the numbers agree destroys the only thing this repository is for.
3. **Ambiguity is recorded, not resolved silently.** Where the paper under-specifies a
   parameter, write a `CONFIRM` marker against an `exploratory` entry in `FINDINGS.md`
   rather than making a quiet choice. A reviewer checking a test case against the paper will
   hit the same ambiguity and needs to find your reading of it.
4. **One copy, three consumers.** The PATH formulation, the CCOpt.jl formulation and the
   generator that emits the upstream test files all read these files. That is deliberate —
   a correction propagates to all three — and it also means one edit moves three results, so
   an edit here re-runs the full validation for every case that reads it.

## Sources

*One section per paper, added as it is transcribed.*

### Murphy, F. H. and Smeers, Y. (2005)

"Generation Capacity Expansion in Imperfectly Competitive Restructured Electricity Markets",
*Operations Research* 53(4), 646–661.

Nothing transcribed yet. Expected: load-duration-curve blocks, the firms and their
technology portfolios, capacity costs, variable costs, and the demand parameters the
price-taking and Cournot formulations need.

| File | Values | Source | Notes |
|---|---|---|---|
| *(none yet)* | | | |
