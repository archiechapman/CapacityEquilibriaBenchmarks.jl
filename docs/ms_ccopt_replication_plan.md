# Murphy & Smeers replication and CCOpt.jl verification: an implementation plan

## Objective and scope

This plan directs the implementation of both models in Murphy, F. H. and Smeers, Y. (2005), "Generation Capacity Expansion in Imperfectly Competitive Restructured Electricity Markets," *Operations Research* 53(4): the open-loop equilibrium (perfectly competitive benchmark plus Cournot-in-quantity variant) and the closed-loop Cournot equilibrium (Cournot-in-capacity-and-quantity, solved as an EPEC). Both get built twice: once as a complementarity problem solved with PATH, treated as ground truth, and once reformulated for CCOpt.jl, treated as the object under test. The PATH solve and the paper's own published numbers together anchor correctness; the CCOpt.jl solve is checked against both.

The two outputs of this work are distinct and should stay distinct throughout. One is a faithful replication study: does this Julia implementation reproduce Murphy and Smeers' published results. The other is a validation contribution to CCOpt.jl: given a problem whose answer is already known and trusted, does CCOpt.jl reach it, and is the resulting case worth proposing as a permanent test in that repository. Keep the replication code and the CCOpt.jl-facing test code in separate, clearly labeled parts of the repository from the start, since they'll have different audiences (a technical note aimed at Pascal and the NEM research thread, versus a PR aimed at CCOpt.jl's maintainers).

## How the two work streams relate

Open-loop comes first and does most of the load-bearing work. It is a square complementarity problem with no nested optimization, small enough that PATH solves it without touching its free-tier limits, and it has published numbers to check against directly. It is the natural first CCOpt.jl test case precisely because it is easy: a small, well-documented, hand-checkable regression case with a known answer is valuable to a young solver project regardless of whether it stresses the solver's actual target class of large-scale problems. Treat it, and frame it to CCOpt.jl's maintainers, as exactly that: a correctness regression test, not a demonstration of why CCOpt.jl is needed.

Closed-loop comes second and is the more natural long-run fit for CCOpt.jl, because the Cournot-in-capacity equilibrium is a genuine nested equilibrium problem rather than a bare square system dressed up with a zero objective. It is also the harder half of this plan, because the standard solution method, diagonalization, is a heuristic fixed-point iteration over single-firm best responses rather than a single well-posed solve, so "ground truth" here means something weaker than it does for the open-loop case. Build and validate the open-loop model completely before starting the closed-loop model; nothing in Phase 3 or 4 should begin until Phase 1 and Phase 2 are both passing.

## Phase 0 — Repository and environment setup

Scaffold a Julia project with a conventional layout: `src/` for model code, `test/` for both the replication tests and the CCOpt.jl-facing test cases, `data/` for the transcribed paper parameters, and `docs/` for the write-up produced in Phase 5. Decide the repository's eventual home now rather than later, since Phase 5 assumes it already has a name and a place to live, whether that is a standalone public repo from the outset or something kept private until Phase 2 passes and only then made public ahead of a CCOpt.jl PR.

Set up dependencies: JuMP with native `MOI.Complements` support (not `Complementarity.jl`) for the PATH-solved models, since native MOI syntax is the better-maintained path and, more importantly, exercises the same complementarity-set machinery that a CCOpt.jl integration would eventually need to interoperate with, rather than a separate, older interface. Add `PATHSolver.jl` and register PATH's free academic license before writing any model code, not when a size limit is first hit. Add `CCOpt.jl` and `NLPModels.jl` as dependencies; since CCOpt.jl has no tagged releases at the time of writing, pin it to a specific commit SHA in the project's `Manifest.toml` rather than tracking `main`, and note that SHA explicitly in the README so the replication is reproducible even as CCOpt.jl's API continues to move. Confirm before proceeding that a trivial complementarity problem solves correctly through both PATH and CCOpt.jl in this environment; this is a five-minute smoke test that will save time later disentangling environment problems from model problems.

## Corrections found while executing Phase 0

*The plan above was written before any of it was run. These are the places it turned out to be wrong, kept
here rather than edited into it so that what was expected and what was found stay distinguishable. Each cites
the ledger entry that checked it.*

| The plan says | Phase 0 found |
|---|---|
| CCOpt.jl "has no tagged releases at the time of writing"; pin it to a commit SHA | It is in the General registry at v0.1.0. A compat bound plus the committed manifest gives exact reproducibility without a SHA (`CapacityEquilibria.jl` F-0002; D-0003 updated) |
| The upstream repository is `MadNLP/CCOpt.jl` | It is `madsuite-org/CCOpt.jl`. `MPCCModels.jl` is also `madsuite-org`, though CCOpt's own README still points at `MadNLP/MPCCModels.jl` (F-0002) |
| Declare pairs with `CCOpt.MPCCModelVarVar(nlp, ind_x1, ind_x2)` | No such name. It is `MPCCModels.MPCCModel(nlp, ind_x1, ind_x2)`, from a separate package, solved with `CCOpt.solve_homotopy!` (F-0003) |
| Build an `NLPModel` by hand as the CCOpt-side formulation | CCOpt has a JuMP path the plan does not mention — `MathOptComplements` bridges plus `CCOpt.Optimizer` — so one JuMP model can serve both solvers (F-0003) |
| Solve with both `RelaxationSolver` and `PenaltySolver` | Only the relaxation method is reachable through JuMP; CCOpt's MOI layer constructs it unconditionally. The penalty method needs the direct `MPCCModel` route (F-0004) |
| — (not mentioned) | The three-repository split means Phase 0 spans two repositories: the engine holds the plumbing and the smoke test, this one holds the data, the models and the upstream emitters |

The fourth row is the one that changes work rather than wording. The plan treats the CCOpt.jl formulation as
a hand-made translation of the PATH one and asks that they be kept identical by sharing `data/`. The JuMP
path makes them the same model, not two models with the same inputs, which removes the drift risk the plan
was managing rather than mitigating it. The fifth row then partly gives it back: the penalty run cannot use
that path, so Phase 2 has one formulation reached two ways and a second reached one way, and those two need
checking against each other rather than being assumed equivalent.

## Phase 1 — Open-loop replication in PATH (ground truth)

Transcribe the paper's data directly from its tables: the load-duration-curve blocks (Murphy and Smeers use discrete demand blocks rather than chronological hours, which keeps this small), the firms and their technology portfolios, capacity costs, variable costs, and whatever demand-elasticity or willingness-to-pay parameters the price-taking and Cournot formulations require. Put every one of these numbers in `data/`, and annotate each with the specific table and page it came from. This transcription is the single point of highest risk in the whole plan, since every later comparison depends on it being right; treat any parameter the paper states ambiguously as a flagged open question rather than a silent guess.

Formulate the perfectly competitive benchmark first: the complementarity conditions equating price to marginal cost with capacity and output as the paired variables, solved via PATH. This case has a closed-form intuition (it should reproduce the associated planner LP's dual prices) that makes it a good first check before moving to the Cournot case, where there is no such shortcut. Then formulate the open-loop Cournot variant, where each firm's first-order conditions embed its own residual-demand elasticity, still as a square complementarity system solved directly with PATH, not as a nested optimization.

Validate both against the paper's published capacities, output levels, and prices, to a stated numerical tolerance. Where a result doesn't match, work through solver settings, numeraire or unit conventions, and the transcription before concluding the paper itself is ambiguous; document whichever of these turns out to be the explanation rather than silently adjusting until the numbers agree. The gate for calling Phase 1 complete is both cases matching the paper within tolerance, with the mismatch investigation, if any was needed, written down.

## Corrections found while executing Phase 1

*Same convention as the Phase 0 corrections: the plan above is left as written, and what was
found is set beside it, citing the ledger entry that checked it.*

| The plan says | Phase 1 found |
|---|---|
| "Transcribe the paper's data directly from its tables: the load-duration-curve blocks … capacity costs, variable costs …" | The edition in hand — the May 2002 working paper, 69 pages — has no tables, no parameter values and no worked example. It is an analytical paper. There was nothing to transcribe except the model's structure and the inequalities on its parameters (F-0001) |
| "Validate both against the paper's published capacities, output levels, and prices, to a stated numerical tolerance" | No published capacities, outputs or prices exist in this edition. Validation is against the paper's *analytical* results instead: a hand derivation from its equilibrium conditions, an exhaustive enumeration of complementarity patterns, and each theorem, lemma and property the paper states, checked at the solver's point (D-0004, F-0004, F-0005) |
| "This transcription is the single point of highest risk in the whole plan" | The highest-risk point turned out to be the *construction*: an instance presented as the paper's when it is not. Every file, docstring and report line that carries a number now says it is constructed. The published 2005 version was then checked by the repository owner and has no example either (F-0002) |
| "it should reproduce the associated planner LP's dual prices" | The planner problem is a QP, not an LP — the utility under affine inverse demand is quadratic — and no QP solver was added to check it. The equivalent check made is the paper's own pricing-efficiency and investment-criterion properties (p.15), which are the planner's KKT conditions read player by player, plus the hand derivation |
| "a square complementarity system … PATH solves it without touching its free-tier limits" | Confirmed, and more so than expected: both open-loop cases are pure *linear* complementarity problems, n = 2 + 4S = 14 on instance A, so the engine's `lcp_model` and `lcp_residual` apply with no generalisation to mixed systems (F-0003) |
| "Where a result doesn't match, work through solver settings, numeraire or unit conventions, and the transcription …" | Not exercised. PATH agreed with both solver-free routes to 1e-11 on the first solve of each case. The investigation procedure stands, untested |
| — (not mentioned) | Uniqueness needed its own argument. Enumeration finds every solution in a nondegenerate pattern but cannot rule out a continuum through a degenerate one; for a monotone LCP a strictly complementary solution with a nonsingular basis is the only solution, and all three conditions are checked (`src/enumerate_lcp.jl`) |
| — (not mentioned) | The instance exhibits something the paper states only in words (p.16): under Cournot the peaker operates in a segment where it is not the efficient technology, while under competition it does not (F-0005) |
| — (not mentioned) | One hand-sized instance leaves most of the paper's segment regimes unexercised. A second, built to be reasonable rather than hand-solvable — GW, $/MWh, four quarter-year blocks — covers the regimes the first does not and was run through both solvers at the same time, which pulls Phase 2's solver-agreement question forward into Phase 1 (F-0006, F-0007) |

The first two rows change the meaning of the Phase 1 gate rather than the work. D-0004
records the reading adopted: PATH's point agrees with the hand derivation and the
enumeration within a stated tolerance, and every property the paper states holds at it.
Under that reading the gate is passed; under the plan's literal reading it cannot be passed
with this edition, and no amount of work here changes that. D-0002's trigger for making the
repository public is therefore a judgement for its owner rather than a mechanical
consequence of the tests passing.

## Phase 2 — Open-loop model as a CCOpt.jl test case

Reformulate the same complementarity system CCOpt.jl's way: build an `NLPModel` carrying the equilibrium residuals as constraints and a constant (zero) objective, then declare the complementary variable pairs with `CCOpt.MPCCModelVarVar(nlp, ind_x1, ind_x2)`. This is a mechanical translation of the Phase 1 model, not a new formulation, so keep the underlying data and equations identical between the two and share the `data/` transcription rather than re-deriving it.

Solve the resulting MPCC with both of CCOpt.jl's documented methods, `RelaxationSolver` and `PenaltySolver`, and check the result against both the PATH solve from Phase 1 and the paper's published numbers, so a discrepancy can be attributed correctly: CCOpt.jl versus PATH is a solver-agreement question, either versus the paper is a replication question. Before writing this up as a candidate contribution, look at CCOpt.jl's existing `test/` directory and mirror its conventions for naming, structure, and assertions, so a PR reads as a natural extension of the existing suite rather than an outside style. Also read through the repository's current open issues and pull requests at this point, not before, since by Phase 2 there will be a concrete artifact to offer and it will be a more useful conversation than raising it speculatively at Phase 0.

Emit the upstream-facing test file rather than writing it by hand. CCOpt.jl's maintainers are considerably more likely to accept a self-contained file, with the data inlined and no imports beyond JuMP, NLPModels and CCOpt.jl itself, than one that constructs its model by calling into this repository's own package, since taking the latter would make this repository a permanent dependency of their test suite. So keep the generator here rather than the artifact: a script that reads the shared `data/` transcription and the Phase 1 model definition and writes the standalone file, plus a round-trip check that the emitted file still reproduces the same numbers as the in-repo model to the same tolerance. That round-trip check is the part that matters, because it is what stops the emitted copy drifting silently once the model behind it is corrected; a file hand-copied once and then forgotten is otherwise exactly what this becomes. Register the emitted file as a generated artifact against its sources so that staleness surfaces as a CI failure here rather than as a discovery made by a maintainer reading a test that no longer matches the paper.

The deliverable from this phase is a self-contained test file plus a short PR description that frames the contribution honestly: a small, hand-verified, dual-sourced-ground-truth regression case, offered as a correctness check rather than a demonstration of scale. If the maintainers aren't interested in taking it upstream, it still stands on its own as a validation artifact for the rest of this plan and for anything built later on CCOpt.jl in the NEM work.

## Phase 3 — Closed-loop replication via diagonalization

Implement the closed-loop model, in which each firm chooses both capacity and output anticipating rivals' capacities as fixed, making this an EPEC rather than a single complementarity problem. Solve it by diagonalization: fix all firms' capacities except one, solve that firm's own optimization (a well-posed NLP or, in this formulation, tractable directly via PATH as a smaller complementarity problem) for its best response, move to the next firm, and iterate over the full set of firms until capacities stop moving between rounds.

Implement convergence diagnostics explicitly rather than trusting a fixed iteration count: track the norm of the capacity vector's change between rounds, and add cycling detection, since diagonalization is known to be sensitive to firm ordering and starting point and does not always converge cleanly. Validate against the paper's published closed-loop Cournot results, but document convergence behavior alongside the final numbers, not just the endpoint, since a matched final answer reached via a different convergence path is a weaker replication than one whose iteration behavior also looks like what the paper describes.

## Phase 4 — Closed-loop model as a CCOpt.jl MPCC test case

This is the more interesting half of the CCOpt.jl contribution, and the one worth a deliberate design decision before building rather than defaulting to the obvious approach. The diagonalization loop from Phase 3 can be reformulated as a single monolithic MPCC: stack every firm's KKT conditions together into one system and let CCOpt.jl solve the joint problem directly, rather than wrapping CCOpt.jl in an outer diagonalization loop of its own. That monolithic formulation is arguably a cleaner and more informative test of what CCOpt.jl actually does than reproducing the paper's own heuristic, since it tests the solver's core capability rather than an iteration scheme built around it. Note this choice, and the reasoning above, when raising it with Pascal, since it is a genuine fork in how this phase gets built rather than a detail.

Build the monolithic joint-KKT MPCC, solve it with CCOpt.jl, and compare the result to the diagonalization-based fixed point from Phase 3. Emit this one the same way as the open-loop case, from the same generator machinery, so the second proposal arrives in the shape the first one established. Frame the comparison correctly in whatever gets written up: this validates whether CCOpt.jl reaches a diagonalization-consistent solution, not whether it matches a unique closed-form correct answer, since the closed-loop case doesn't have one of those the way the open-loop case does. If the search turns up more than one solution, or the joint MPCC and the diagonalization loop converge to different fixed points depending on starting values, treat that as a genuine finding rather than a bug to chase away; it connects directly to the solution-multiplicity theme in Abada, de Maere d'Aertrycke and Smeers (2017) and is worth documenting as its own small result in Phase 5, separate from the pass/fail validation question.

## Phase 5 — Packaging, write-up, and outreach

Clean up the repository so the replication code, the data transcription, and the two CCOpt.jl test cases are each easy to find and run independently. Write a short technical note, separate from anything sent to CCOpt.jl, covering three things: how closely the Julia replication reproduces Murphy and Smeers' published numbers for both the open-loop and closed-loop cases, how closely CCOpt.jl agrees with PATH on both, and whatever solution-multiplicity behavior turned up in the closed-loop case. This is the document to share with Pascal.

Open the PR(s) or issue(s) to MadNLP/CCOpt.jl proposing the open-loop case as a first contribution, and, separately, the closed-loop monolithic MPCC as a second one once it is validated on its own terms. Keep these as two separate proposals rather than one large PR, since they carry different levels of confidence in their own "ground truth" and a maintainer should be able to accept one without being blocked by open questions in the other.

## Data provenance and engineering discipline

Every numeric parameter used anywhere in this repository should trace back to a specific table and page in the 2005 paper, recorded in `data/` alongside the value itself, not just in a commit message or a comment that can drift out of sync with the code. Keep the PATH-based and CCOpt.jl-based formulations, and the generator that emits the upstream test files, all reading from the same data files rather than each hard-coding its own copy of the parameters, so a later correction to the transcription automatically propagates to both, rather than risking the two silently diverging. Pin the CCOpt.jl commit SHA and revisit it deliberately rather than incidentally picking up upstream changes mid-project, given the package's current pace of change and lack of tagged releases.

## Risks and open decisions

CCOpt.jl's API may move under this work before Phase 5 is done, given it is pre-1.0 with no releases; budget time to re-sync against a newer commit once, deliberately, rather than chasing `main` continuously. The closed-loop case's lack of a unique ground truth is a real limitation of this plan, not a solvable problem, so the write-up needs to be honest about what "validated" means there. The paper's own tables may under-specify one or two parameters needed for an exact reproduction; if so, that becomes a documented assumption rather than a blocker, but it should be flagged prominently in both the technical note and any CCOpt.jl PR description, since a reviewer checking the test case against the paper will hit the same ambiguity. Finally, whether CCOpt.jl's maintainers want externally contributed test cases at all is still an open question as of this plan being written; Phase 2's read of the existing issues and PRs is the point at which that gets resolved, and the plan should be willing to stop at "validated, documented, and kept in this repository" if the answer is no.

## Sequencing summary

Phase 0 (setup) first and non-negotiable, since it fixes the PATH license and the CCOpt.jl pin before any model code depends on either. Then Phase 1 (open-loop PATH replication) as a hard gate: nothing in Phase 2 starts until Phase 1 matches the paper within tolerance. Then Phase 2 (open-loop CCOpt.jl test case), which is the first deliverable worth showing anyone outside this repository. Then Phase 3 (closed-loop PATH replication via diagonalization), then Phase 4 (closed-loop CCOpt.jl test case), with the monolithic-versus-diagonalization design decision in Phase 4 flagged for discussion with Pascal before committing to it. Phase 5 (write-up and outreach) last. Expect Phase 1's data transcription and Phase 4's design decision to be the two points most likely to slow this down; everything else is comparatively mechanical once the data and the modeling choice are settled.

## Note back to the NEM program

The open-loop model built in Phase 1, once validated, is the same non-stochastic Murphy and Smeers starting point already identified as the right first step before the two-stage stochastic equilibrium work on NEM resource adequacy. The JuMP/MOI.Complements code written here, not just the result, is directly reusable there: the same native-complementarity plumbing this plan exercises against PATH and CCOpt.jl is what the later stochastic extension will need. Worth flagging explicitly when this work is discussed with Pascal, since it means this isn't a detour from the NEM program but the first concrete piece of it.
