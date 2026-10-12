# A hard case, and two things found on the way to it

*A note to accompany `hard_case_near_tie.jl` and `closed_loop_demonstration.jl`, written for François Pacaud
(`@frapac`) alongside the open-loop test case in `ISSUE.md`. Deliberately written so that
the argument survives without any economics: the phenomenon is about the shape of an
optimisation problem, not about electricity. Nothing here has been sent.*

---

## The short version

I have a small capacity-investment game whose equilibrium conditions form a complementarity
system. On two instances that system has **three solutions each. Only one of them is an
equilibrium.** The other two are perfectly good roots at which a player would in fact
prefer to do something completely different.

Two of the things below reflect well on CCOpt, one is awkward for the modelling rather than
for the solver, and the last is a problem I built specifically to be hard, on which both of
your methods get the answer right about half the time. That last one is the reason I am
writing; the rest is context for it.

CCOpt gets the economically meaningful part right at all three points, with both methods.
The trouble is not in the solver. It is that the system has a larger solution set than the
question it was written to answer, and no amount of solver accuracy closes that gap.

Then, while building the demonstration, a second thing fell out that I had not gone looking
for: **the two spurious roots are exactly the points where the output stage is degenerate**,
its dual an unbounded ray. That is also where the penalty method's residual is four orders
of magnitude worse than at the genuine equilibrium. There is a section on it below, and I
think it is the more useful half for you.

I think this is worth having as a documented case, because it is the kind of failure that
looks like success: converged status, tiny residual, plausible numbers, wrong answer.

## The setup, without economics

Two firms. Each first chooses a capacity, a single non-negative number. Then, with those
capacities fixed, they compete in several separate markets — think of them as several
independent copies of a small game, one per demand level.

The second stage is easy and completely well behaved. For fixed capacities it is a linear
complementarity problem with a unique solution. That is the part CCOpt does, and does
correctly everywhere I have looked.

The first stage is where it gets interesting. Each firm wants to pick the capacity that
maximises its profit, knowing that its choice changes the second-stage outcome. So the
first-stage objective is a function of capacity *composed with* the second stage's solution
map. That composition is what makes the problem hard, and it is what makes the equilibrium
condition a first-order condition rather than a characterisation.

## Where the first-order condition loses information

Write a firm's profit as a function of its own capacity, holding its rival fixed. It is
**piecewise quadratic**: as capacity grows, the pattern of which plants run in which markets
changes, and each change is a kink. The first-order condition is built from the derivative
of the output stage with respect to capacity, which is a piecewise-constant table indexed by
that pattern, and the source paper states the condition only where the output stage is
differentiable.

The corner solutions are not such points. A firm holding zero capacity produces zero, so in
every market its output sits on both of its bounds at once: it is idle, and it is at
capacity. The pattern is ambiguous. Read the firm as idle and its capacity earns nothing at
the margin, every derivative term vanishes, and the condition reduces to "capacity costs
something", which holds at zero. Read it as running at capacity and the derivative is the
true one-sided slope, which is steeply negative: the firm's very first unit of capacity
pays, at 18 per unit on the smaller instance, and the payoff keeps improving at least out
to two units on every corner I checked.

So the corner is not a local optimum that the derivative cannot see past. It is not a
minimum at all. It is a kink at which the condition is undefined, and evaluating it
mechanically, with the ambiguous constraints classified the natural way, returns a root
that is not an equilibrium.

The profit function is also only piecewise convex — across a kink the marginal cost can
jump downwards — so a genuine stationary point need not be the best response either. That
is a different failure from the corners, and the last section builds a case of it.

## What that looks like in numbers

On the two instances, `closed_loop_demonstration.jl` finds and checks these. Every row
satisfies the first-order condition to machine precision.

| Instance | Capacities | First-order condition | Output stage | A deviating firm gains |
|---|---|---|---|---|
| A | (0, 6.5) | satisfied | degenerate | 32.0 |
| A | (5, 5) | satisfied | nondegenerate | 0 — **the equilibrium** |
| A | (7.5, 0) | satisfied | degenerate | 46.3 |
| B | (0, 4.475) | satisfied | degenerate | 187.9 |
| B | (3.03, 3.54) | satisfied | nondegenerate | 0 — **the equilibrium** |
| B | (4.8, 0) | satisfied | degenerate | 322.5 |

The degeneracy column is not a coincidence and is the subject of a section below.

These are not near misses. At the corner solutions a firm improves its position by tens or
hundreds of units, on quantities of order ten. The gains are found by scanning that firm's
capacity globally and re-solving the second stage at each trial, so they are gains in the
true objective, not in an approximation of it.

The genuine equilibria are independently confirmed. Both satisfy every comparative result
the source paper proves relating this equilibrium to two others that are separately
validated, and a best-response iteration started anywhere — including started exactly at
the two spurious roots — converges to them and not to the corners.

## The second thing: the spurious roots are exactly the degenerate ones

This was not designed in, and I only noticed because the demonstration asserted something
and the assertion failed.

At a spurious root, one firm holds no capacity. Its output is therefore zero, and its
capacity constraint binds at zero. But *any* sufficiently large shadow price on that
constraint satisfies the conditions, because the constraint is slack by exactly nothing. So
the dual is not a point but an unbounded ray. The demonstration checks this directly: put
the firm's output exactly on its bound, add 1, then 1000, then 100000 to its capacity duals,
and the residual does not move.

Here is what the three solvers do at those points, and at the genuine equilibrium for
contrast. The primal is the part with economic content; the dual is the part the problem
declines to determine.

| Point | Outputs agree across solvers | Dual returned | Penalty residual |
|---|---|---|---|
| Equilibrium, instance A | to 1e-8 | pinned, max 2.0 | 4.7e-8 |
| Corner (7.5, 0) | to 1e-8 | not pinned; PATH 11.5, CCOpt 1e5 | 9.8e-4 |
| Equilibrium, instance B | to 1e-7 | pinned, max 24.0 | 3.1e-7 |
| Corner (4.8, 0) | to 1e-8 | not pinned; PATH 84, CCOpt 1e5 | 1.0e-3 |

Three observations, in increasing order of how much I think they matter to you.

**Everything with economic content is right.** Outputs, prices, and the regime of each
demand block agree across PATH and both CCOpt methods at every point, corner or not. The
first-order condition evaluated on CCOpt's own outputs gives the same answer as on PATH's.
Whatever is happening in the dual is not corrupting the answer.

**The residual stops being an accuracy measure when the dual is unbounded.** The penalty
method's 1e-3 at a corner is not a 1e-3 error in anything meaningful. It is the product of a
dual of order 1e5 with a primal error of order 1e-8. Snap the primal exactly onto its bound
and the residual collapses. So on a degenerate problem the usual pass criterion — recompute
the residual from the returned point and threshold it — reports a number that says more
about how far along the ray the solver stopped than about whether it solved anything. I do
not have a suggestion for what to use instead, and I would be interested in whether you do.

**Relaxation and penalty behave differently out there, and the difference is invisible in
the status.** Both report `SOLVE_SUCCEEDED`. Both walk out to a dual of about 1e5. But the
relaxation method's recomputed residual stays around 1e-7 while the penalty method's sits at
1e-3. On the nondegenerate points they are within a factor of ten of each other. If you
wanted a small, self-contained degenerate case to test against, this is one, and the source
repository can generate more of them.

I should be explicit that none of this is a bug report. The problem does not determine the
dual; a solver that returns a valid point on the ray has done what was asked. What I think
is worth having written down is that the standard way of checking a complementarity solve
does not distinguish these cases from a genuine loss of accuracy.

## The part I think is a test of the method, not just of the model

Here is what makes it more than a modelling curiosity.

There are two natural ways to attack this with CCOpt:

**Stack everything into one MPCC.** Take both firms' first-order conditions plus both
stages' complementarity conditions, write them as one system, and solve. This is the
formulation I was originally planning to offer as a second test case, and it is the one
that plays to a complementarity solver's strengths. Its solution set contains all three
points above. A solver that returns a corner has done nothing wrong.

**Wrap the solver in a best-response loop.** Fix one firm, optimise the other, alternate.
Here the outcome depends on what the inner step computes. If it genuinely optimises, the
corners are not fixed points at all, because the firm holding nothing strictly prefers to
build, and the loop converges to the true equilibrium from every start I have tried. A
*local* optimisation leaves the corners too, since the payoff improves from the first unit.
If instead the inner step solves the firm's first-order condition — which is what "stack
the KKT conditions" amounts to, one firm at a time — then a corner *is* a fixed point, and
the whole scheme reports it as an equilibrium with a clean convergence history and nothing
anywhere to indicate a problem. A local optimisation has a trap of its own, a firm sitting
in the worse of two genuine wells, and that is the case the last section builds.

**And here CCOpt comes out well, which I want to say as plainly as the awkward part.** I
wrote each firm's best response as an MPCC — a nonconvex quadratic objective over the
output-stage complementarity conditions — and handed it to CCOpt. Its global optimum is
known exactly for this family, so this is a case where a solver can be marked against a
right answer rather than against another method's fixed point.

Both methods found the global optimum on all 32 solves I tried. Eight of them were started
exactly at a corner: the firm holding nothing, every variable consistent, the output stage
degenerate and its dual out on the ray described above. Both methods left, every time, and
found improvements worth 32, 46, 188 and 322.

I do not want to oversell those eight. The corner is not a local optimum, so a method that
only moves downhill has somewhere to go from it. What they show is that a degenerate start —
every capacity constraint of one firm active from both sides, and a dual the problem does
not pin down — stalls neither method. Whether CCOpt can climb out of a genuine well is a
different question, and the last section is built to ask it.

So the reliability sits in a place that is easy to overlook: not in the outer iteration and
not in the solver's residual, but in the innermost step being an optimisation rather than a
root-find of the first-order condition. A root-find accepts the corners; an optimisation,
even a local one, leaves them.

I do not think there is a fix inside a solver for this. The extra roots are really there in
the system. What a solver could plausibly offer is a way to find *several* of them, and what
a benchmark suite could offer is a case where finding one and stopping is visibly not enough.

One more thing I should flag, having tried to build the monolithic version. It is not the
mechanical translation I had assumed. The capacity-stage condition depends on how the output
stage responds to capacity, and that response is a piecewise-constant table indexed by which
constraints are active, so the condition is not a smooth function of the variables and no
single smooth MPCC has it as stationarity conditions. The routes I can see are a disjunctive
encoding, which leaves MPCC territory, or stacking each firm's MPEC-KKT conditions, whose
constraint qualifications fail generically and demonstrably fail at the degenerate corners
above. I have not built either, and I would rather hear what you think before I do.

## What I am actually proposing

Nothing yet — I would rather ask first.

The open-loop case in the other note is a straightforward regression test: known unique
answers, both methods reach them, and it is ready to drop into `test/`. I am happy for this
second one to be anything you find useful, including nothing:

- a documentation example about the difference between solving a complementarity system and
  solving the problem it came from;
- a test case, if the monolithic MPCC formulation is interesting to you, in which case the
  right assertion is probably "the solver returns one of these three points" plus a separate
  check of which;
- or just this note, filed and forgotten.

The one thing I would gently push back on, having been through it, is offering the
monolithic MPCC as a plain regression test with a single expected answer. It would look like
one and would not be one, and whichever root the solver happened to land on would become the
expected value by accident.

If you did want a test out of this, the best-response MPCC is the better candidate: a
genuine nonconvex MPCC, small, self-contained, with an exactly known global optimum and a
degenerate starting point. It is packaged, and the hardened version of it, started inside a
genuine wrong well, is the next section.

## The one I think is actually worth your time

Everything above, and everything else I threw at CCOpt, it solved. That is a weak thing to
offer, so I went looking for a case that would be hard, and the search itself turned out to
be the interesting part.

**How to make this problem hard on purpose.** A firm's payoff as a function of its own
capacity is piecewise quadratic, one piece per pattern of which plants run in which blocks.
So the landscape is a row of wells. As the *rival's* capacity moves, those wells rise and
fall relative to one another. Somewhere between "well A is deeper" and "well B is deeper"
they are exactly level. Tuning the rival's capacity to that point is a one-dimensional root
find, and it costs nothing.

At that rival capacity, on my two instances:

| Instance | Firm | Two optima at | Apart by | Objectives agree to |
|---|---|---|---|---|
| A | peaking | 5.000 and 3.873 | 1.127 | 1.7e-14 relative |
| A | base-load | 5.333 and 4.775 | 0.559 | 3.0e-15 |
| B | peaking | 2.433 and 3.000 | 0.567 | 2.4e-14 |
| B | base-load | 3.633 and 3.133 | 0.500 | 9.5e-15 |

Exactly at the tie the question has no answer, so nothing can be marked there. Move the
rival's capacity by a thousandth and one well becomes strictly better by a relative margin
of about 1e-4. Move it a thousandth the other way and the *other* well wins. So the answer
flips across a knife-edge while the two candidate answers stay a fifth of the domain apart.

**The test.** Thirty-two problems: four ties, four perturbations each, two methods. Each is
posed from a starting point inside the *wrong* well, which is the honest way to ask whether
a method can leave one. The right answer is known exactly, from enumerating the pieces and
minimising each in closed form, so this is marked against a right answer and not against
another solver.

`hard_case_near_tie.jl` reports **the better well found in 16 of 32**. Both methods fail,
on different problems, neither dominating. On instance A's peaking firm the relaxation
method keeps the worse well in all four perturbations while the penalty method escapes in
two; on instance B's peaking firm that reverses at two of the four.

I want to be careful about what that is and is not. Every returned point is a genuine local
optimum and every one is feasible. These are not convergence failures. They are converged
answers to a question with two nearly equal answers, and no residual distinguishes them —
the wrong answer looks exactly as good as the right one from inside the solver. I also have
no comparison: I have not run another MPCC solver on this, so I cannot tell you whether half
is good, bad or ordinary. That is partly why I am sending it.

**One thing I noticed while building it, which may matter more than the score.** These wells
sit on regime boundaries. There CCOpt's *output-stage* solution is about 2e-4 from PATH's,
against about 1e-8 at an interior point. That is a different degradation from the unbounded
dual described earlier — here the primal itself is less accurate — and it is why the file
inlines its ground truth rather than recomputing it. A solver cannot be its own oracle on a
margin of 4e-3 when its own arithmetic is uncertain at 2e-4.

The file is here: HARD_URL

```
curl -O HARD_RAW_URL
```

It imports only `NLPModels`, `MPCCModels`, `MadNLP`, `CCOpt` and `Test`, runs in about half
a minute, asserts the ground truth and that every returned point is one of the two optima,
and reports the score. It does not assert the score, because that would freeze a finding as
an expected value, and because the number moves with the starting point — an in-repository
run warm-started from PATH gave 19 of 32 rather than 16.

If a hard case is useful to you, I can make more of these cheaply: the tie search is generic
and the instances are constructed, so the mechanism generalises to bigger problems and to
whatever margin you want to test at.

## Reproducing it

`closed_loop_demonstration.jl` is self-contained and imports only `NLPModels`, `MPCCModels`,
`MadNLP`, `CCOpt` and `Test`. It solves every output stage with both of CCOpt's methods,
checks the outputs against a reference, evaluates the first-order condition at each of the
three roots, demonstrates the dual ray at the corners by pushing the dual along it, and
asserts that exactly one root is an equilibrium. 82 assertions, about thirty seconds,
all passing on CCOpt v0.1.0. I ran it in a throwaway project built from your
`test/Project.toml` plus CCOpt and nothing else, so it should need no new dependency.

The derivations, the provenance of every parameter, the enumeration that proves there are
exactly three roots, and the same model cross-checked against PATH are in
<https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl>, which I can open up or
send.
