# When a solver is right and the answer is wrong

*A note to accompany `closed_loop_demonstration.jl`, written for François Pacaud
(`@frapac`) alongside the open-loop test case in `ISSUE.md`. Deliberately written so that
the argument survives without any economics: the phenomenon is about the shape of an
optimisation problem, not about electricity. Nothing here has been sent.*

---

## The short version

I have a small capacity-investment game whose equilibrium conditions form a complementarity
system. On two instances that system has **three solutions each. Only one of them is an
equilibrium.** The other two are perfectly good roots at which a player would in fact
prefer to do something completely different.

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

Write a firm's profit as a function of its own capacity, holding its rival fixed. Two facts
about that function:

1. It is **piecewise quadratic**. As capacity grows, the pattern of which plants run in
   which markets changes, and each change is a kink.
2. It is **only piecewise convex**. Across a kink the marginal cost can jump *downwards*.

The first-order condition says: no infinitesimal change of capacity improves the objective.
For a smooth convex problem that is the same as "no change improves it". Here it is not,
and the difference is exactly a jump.

The concrete case is a firm holding zero capacity. Its first unit of capacity is expensive
relative to what that one unit earns, because with one unit it barely participates. So no
small increase pays, and the first-order condition is satisfied at zero. But a *large*
increase changes which plants are running in which markets, moves the price, and pays very
well. The derivative at zero cannot see that. It is looking at a slope on the near side of
a cliff.

So the corner is a root of the equilibrium condition and is not an equilibrium.

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
Here the outcome depends entirely on how the inner optimisation is done. If the inner
best response is *global*, the corners are not fixed points at all, because the rival
strictly prefers to move away, and the loop converges to the true equilibrium from every
start I have tried. If the inner best response is a local solve from the current iterate —
which is the obvious implementation, and the one a solver naturally invites — then a corner
*is* a fixed point, and the whole scheme reports it as an equilibrium with a clean
convergence history and nothing anywhere to indicate a problem.

So the reliability sits in a place that is easy to overlook: not in the outer iteration, not
in the solver's accuracy, but in whether the innermost optimisation is global. That is a
property nobody checks by looking at residuals.

I do not think there is a fix inside a solver for this. The extra roots are really there in
the system. What a solver could plausibly offer is a way to find *several* of them, and what
a benchmark suite could offer is a case where finding one and stopping is visibly not enough.

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
