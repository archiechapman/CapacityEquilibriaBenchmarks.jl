# Data provenance

*Every numeric parameter used anywhere in this repository traces back to a specific table
and page in its source, recorded here alongside the value rather than in a commit message
or a comment that can drift out of sync with the code.*

`AGENTS.md` names this directory as the repository's one dangerous area, and the replication
plan calls the transcription "the single point of highest risk in the whole plan", because
every later comparison is downstream of these numbers being right. `test/runtests.jl` checks
that every `.toml` file in this directory is named in this document; it cannot check that
the numbers are right, which is what the rules below are for.

**Status: two constructed instances, no transcribed values.** The edition of Murphy and
Smeers in hand publishes no numbers, so the rule "every value traces to a table and a page"
has no table to trace to. What is transcribed is the model's *structure* and the
inequalities its parameters must satisfy; the values themselves are declared constructed,
and every file says so in its first lines. The published 2005 article has no numerical
example either (F-0002), so this is not a stopgap. See `FINDINGS.md` F-0001 and F-0002,
and `DECISIONS.md` D-0004, before treating any number here as the paper's.

## Rules

1. **One source per file, named in full.** A transcription file states its source paper, and
   every value in it names the table and page it came from. A value with no table and page
   is not transcribed, it is remembered — or, as here, constructed, in which case the file
   must say so and cite the assumption each value was chosen to satisfy.
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

### Murphy, F. H. and Smeers, Y. — working paper, May 2002

"Generation Capacity Expansion in Imperfectly Competitive Restructured Electricity Markets".
The edition in `../literature/` is the authors' working paper dated May 2002, 69 pages, the
pre-publication version of *Operations Research* 53(4), 646–661 (2005). Page numbers below
are the working paper's printed page numbers; PDF page = printed page + 2. The published
article was read by the repository owner and has no numerical results either
(`FINDINGS.md` F-0002); it may paginate and number equations differently, so citations
here follow the working paper.

**What the paper provides.** A model, not a dataset. Two players (`p` peaker, `b` base),
each specialising in one technology (p.12); `S` unit-width load segments with `s = 1` the
peak (p.11); affine inverse demand `pˢ = αˢ − β qˢ` with `β > 0` and `α¹ > … > αˢ` (p.12);
costs `K_i` per unit capacity and `ν_i` per unit output (p.11); the assumptions
`K_p + ν_p < K_b + ν_b` and `K_b + Sν_b < K_p + Sν_p` (p.11). The competitive equilibrium
conditions are equations (2)–(3) on p.14, the open-loop Cournot conditions (5)–(6) on p.16.
Those are transcribed into `src/murphy_smeers.jl`, each cited at the line that encodes it.

**What it does not provide.** Any value of `S`, `α`, `β`, `K` or `ν`. There is no
numerical example, table of parameters, or table of results anywhere in the 69 pages
(F-0001). The paper cites Stoft (2002, chapter 2-2) for "typical cost figures" but does not
reproduce them, and that book is not in hand, so no value here is attributed to it.

| File | Values | Source | Notes |
|---|---|---|---|
| `ms2002_instance_a.toml` | `S = 3`, `β = 1`, `α = (20, 15, 10)`, `K = (2, 7)`, `ν = (3, 1)` | **Constructed.** Chosen here subject to the paper's assumptions on pp.11–12, each cited beside the value | Chosen small and rational so both equilibria can be derived by hand. Implies `S_p = 2` (p.14) |
| `ms2002_instance_a_expected.toml` | The competitive and open-loop equilibria of instance A | **Hand-derived** in `docs/ms2002_instance_a_derivation.md` from equations (2)–(3), p.14 and (5)–(6), p.16 | Not the paper's numbers. One of three independent routes the tests compare (F-0004, F-0005) |
| `ms2002_instance_b.toml` | `S = 4`, `β = 10`, `α = (150, 115, 100, 90)`, `K = (24, 50)`, `ν = (30, 18)` | **Constructed.** Chosen here subject to the paper's assumptions on pp.11–12, each cited beside the value; the physical reasoning for each value is in the file | Units GW and $/MWh with quarter-year segments; `K` is the annualised cost per MW divided by the 2190 h segment, so the paper's unit-width equations apply unchanged. Implies `S_p = 2`. See F-0006 for the candidates rejected |
| `ms2002_instance_b_expected.toml` | The competitive and open-loop equilibria of instance B | **Hand-derived** in `docs/ms2002_instance_b_derivation.md` from the same equations, on the regime that exhaustive enumeration identifies | Not the paper's numbers. Exact rationals; checked by substitution (F-0006) |

### The closed-loop equilibria, added 2026-09-10

The `[closed_loop_cournot]` section of each `*_expected.toml` is the one place in `data/`
whose values were **not** derived by hand. They were found by `enumerate_closed_loop`,
which enumerates the second-stage complementarity patterns and solves the two-variable
problem each one induces, and they are recorded here so that the tests compare against a
committed number rather than recomputing one and agreeing with themselves.

That is a weaker provenance than the rest of this directory and it is labelled as such in
both files. What stands behind the numbers instead of a hand derivation:

1. the residual of equation (16), p.24, recomputed at the point;
2. a global best-response scan over each player's capacity, which finds no profitable
   deviation — this is what distinguishes the equilibrium from the two other points that
   satisfy (16) on each instance and are not equilibria (`FINDINGS.md` F-0013);
3. the paper's Theorems 4, 5, 6 and 7, Lemma 12 and Corollary 3, which relate any
   closed-loop equilibrium to the competitive and open-loop equilibria — both of which are
   in this directory, hand-derived, and validated at the `validated` tier.

Rule 2 of this document applies with particular force here. If a future correction moves
one of these numbers, it is investigated and recorded, never nudged: the closed-loop values
are the ones most likely to move and the least well anchored, and they are the reason
`DECISIONS.md` D-0006 refuses to call either of them "the" equilibrium.
