# Three roots, one equilibrium

The second rung takes away uniqueness, and the equilibrium condition's claim to
characterise the equilibrium. In Murphy and Smeers' closed-loop game (section 6) each
player chooses capacity *first*, anticipating that output will then be the equilibrium of
the short-run game those capacities create. This chapter builds the game on instance A,
finds every root of its equilibrium condition without a solver, and shows that of the three
roots only one is an equilibrium. The other two are also exactly the points where the
problem degenerates.

```@example ch2
using CapacityEquilibriaBenchmarks, CapacityEquilibria
import TOML

datadir  = joinpath(pkgdir(CapacityEquilibriaBenchmarks), "data")
data     = load_ms_instance(joinpath(datadir, "ms2002_instance_a.toml"))
expected = joinpath(datadir, "ms2002_instance_a_expected.toml")
tol      = TOML.parsefile(expected)["tolerance"]

comp = ms_unpack(data, load_ms_expected(data, expected, :competitive))
ol   = ms_unpack(data, load_ms_expected(data, expected, :open_loop_cournot))
nothing # hide
```

## The game

Player ``i``'s long-run problem, (15) on p.24, is to choose ``x_i \ge 0`` to minimise its
capacity cost less its gross margin,

```math
K_i x_i + \sum_s \bigl[-\alpha^s + \beta\,(y_i^s(x) + y_{-i}^s(x)) + \nu_i\bigr]\, y_i^s(x),
```

where ``y(x)`` is the short-run Cournot equilibrium at capacities ``x``. Its first-order
condition, (16) on p.24, pairs each capacity with

```math
\xi_i = K_i + \sum_s \bigl[-\alpha^s + 2\beta y_i^s + \beta y_{-i}^s + \nu_i\bigr] B_i y_i^s
      + \sum_s \beta\, y_i^s\, B_i y_{-i}^s ,
\qquad 0 \le x_i \perp \xi_i \ge 0,
```

with ``B_i y_j = \partial y_j / \partial x_i``, the sensitivity of the short-run equilibrium
to capacity. That derivative is the whole difference between the open-loop and closed-loop
players: the first ignores it, the second exploits it.

## The second stage is already built

The short-run conditions (4), restated on p.24, are line for line the output and
capacity-dual rows of the open-loop Cournot LCP of chapter 1, with ``x`` moved out of the
variables and into the constant. So at the open-loop capacities the short-run equilibrium
must be the open-loop equilibrium's own outputs and duals:

```@example ch2
pt = ms_second_stage(data, ol.x)
@assert pt.y ≈ ol.y atol = tol
@assert pt.λ ≈ ol.λ atol = tol
(y = pt.y, λ = pt.λ)
```

Every tool from chapter 1 therefore applies to the second stage unchanged: PATH, both CCOpt
methods, the recomputed residual, and the enumeration oracle.

## The one new object is a table

Lemma 7, (14) on p.22, gives ``B_i y_j`` in closed form, and it is piecewise constant: it
depends on a segment only through which of the paper's five regimes the segment is in.

| regime | derivative |
|---|---|
| (a) both at capacity | ``B_i y_i = 1``, ``B_i y_{-i} = 0``, for both ``i`` |
| (b) both interior | all zero |
| (c) ``i`` at capacity, ``-i`` interior | ``B_i y_i = 1``, ``B_i y_{-i} = -1/2``, ``B_{-i} y = 0`` |
| (d) ``i`` idle, ``-i`` interior | all zero |
| (e) ``i`` idle, ``-i`` at capacity | ``B_{-i} y_{-i} = 1``, everything else zero |

So the closed-loop conditions are evaluated exactly, with no automatic differentiation and
no numerical derivative in the model. The table is the one piece asserted rather than
solved for, so it is checked against a forward difference of the second-stage solve:

```@example ch2
h = 1e-6
bumped = [ms_second_stage(data, ol.x .+ h .* (1:2 .== i)) for i in 1:2]
for s in 1:data.S, i in 1:2
    numeric = (bumped[i].y[:, s] .- pt.y[:, s]) ./ h
    @assert second_stage_jacobian(data, pt, s)[i, :] ≈ numeric atol = 1e-6
end
[segment_role(data, pt, s) for s in 1:data.S]
```

At the open-loop capacities the segments are types (a), (c) with the base player at
capacity, and (b). Evaluating (16) there:

```@example ch2
ξ = ms_closed_loop_conditions(data, pt)
@assert abs(ξ[PLAYER_P]) < 1e-9
@assert ξ[PLAYER_B] ≈ -0.5 * data.beta * pt.y[PLAYER_B, 2]      # = -25/12
ξ
```

The peaker's condition holds; the base player's is strictly negative, ``-25/12``. The
algebra collapses to a line worth stating: ``\xi_i`` is the open-loop investment condition
plus ``-(\beta/2)`` times player ``i``'s output in each type-(c) segment where it is the one
at capacity. A negative ``\xi_b`` says the base player would gain by investing more, which is
the direction Theorem 5 (p.28) gives for closed-loop base capacity, and the reason Theorem
3 (p.26) says the open-loop point is not a closed-loop equilibrium.

## Every root, without a solver

Fix a complementarity pattern of the second-stage LCP. Within it, the second-stage solution
is affine in ``x``, every segment's regime is fixed, so Lemma 7's table is fixed, and so
``\xi(x)`` is affine too. Each pattern therefore induces a two-variable LCP
``0 \le x \perp \xi(x) \ge 0``, with four patterns of its own. Enumerating both layers,
``2^{12}`` second-stage patterns for instance A, finds every root of (16) at a point where
the second stage is differentiable. Each candidate is then re-solved with a real
second-stage solve and discarded unless it reproduces the regime it was derived under.

```@example ch2
roots = enumerate_closed_loop(data)
@assert length(roots.solutions) == 3
[(x = x, regimes = t) for (x, t) in zip(roots.solutions, roots.types)]
```

Three capacity vectors satisfy (16) on instance A: ``(7.5, 0)``, ``(0, 6.5)`` and ``(5, 5)``.
Their residuals are zero, not small.

## Which of them is an equilibrium

A root of a first-order condition is a candidate. The test that (16) cannot perform is to
ask whether either player could do better by moving its capacity anywhere at all, holding
the other's fixed. `best_response_gap` answers that by scanning each player's capacity on a
grid and re-solving the second stage at every point:

```@example ch2
gaps = [best_response_gap(data, x) for x in roots.solutions]
@assert count(g -> g.gap == 0.0, gaps) == 1
@assert all(g.gap > 1.0 for g in gaps if g.gap != 0.0)
[(x = x, deviation_gain = round(g.gap; digits = 2), better_capacities = g.best)
 for (x, g) in zip(roots.solutions, gaps)]
```

At ``(5, 5)`` neither player can gain. At each corner, the player holding nothing can gain
46.3 or 32.0 by building, on objective values of order 50. These are not near misses.

## Why the corners are roots

The natural guess is that a corner is a local optimum the first-order condition cannot see
past: no small investment pays, a large one does. That guess is in this repository's own
ledger, and it is wrong. Walk the base player's capacity out from the corner ``(7.5, 0)``:

```@example ch2
corner = roots.solutions[findfirst(x -> x[PLAYER_B] == 0.0, roots.solutions)]
walk = [0.0, 1e-6, 0.1, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 5.325, 6.0]
cost = [closed_loop_objective(data, PLAYER_B, [corner[PLAYER_P], v]) for v in walk]
@assert cost[2] < cost[1]                   # the very first unit pays
@assert minimum(cost) < cost[1] - 40
[(x_b = v, objective = round(c; digits = 6)) for (v, c) in zip(walk, cost)]
```

The objective falls from the first unit, at a slope of −18. That slope can be checked by
hand. With the base player absent, the peaker alone sets prices ``(12.5, 9, 6.5)``. A
base plant entering at a sliver of capacity runs flat out in all three segments, earning
those prices less its operating cost of 1, against a capacity cost of 7:
``7 + 3 \times 1 - (12.5 + 9 + 6.5) = -18``.

```@example ch2
slope = (cost[2] - cost[1]) / walk[2]
@assert isapprox(slope, 7 + 3 * 1 - (12.5 + 9 + 6.5); atol = 1e-4)
slope
```

So the corner is not a local optimum. Yet (16) holds there. Evaluated at the corner, it
gives the base player's capacity cost and nothing else:

```@example ch2
at_corner = ms_second_stage(data, corner)
ξ_corner = ms_closed_loop_conditions(data, at_corner)
@assert ξ_corner[PLAYER_B] == data.K[PLAYER_B]
(ξ = ξ_corner, regimes = [segment_role(data, at_corner, s) for s in 1:data.S])
```

Here is why. With no capacity, the base player's output is zero, which is *both* idle and
at its capacity of zero: each of its capacity pairs is biactive. The regime classification
reads it as idle, so the segments are types (e) and (d) with the base player the idle one,
and Lemma 7 gives an idle player no derivative at all. Every revenue term in (16) is
multiplied by zero, and ``\xi_b = K_b > 0`` pairs happily with ``x_b = 0``.

Read the same point the other way, as a player at capacity, which is what it becomes the
moment it builds anything, and (16) returns the slope just measured:

```@example ch2
just_off = ms_second_stage(data, [corner[PLAYER_P], 1e-6])
types, roles = ms_regime(data.S, just_off.x, just_off.y)
ξ_right = ms_closed_loop_xi(data.S, data.beta, data.alpha, data.K, data.nu,
                            at_corner.y, types, roles)
@assert isapprox(ξ_right[PLAYER_B], slope; atol = 1e-4)
(regimes_just_off = collect(zip(types, roles)), ξ_b = ξ_right[PLAYER_B])
```

So the corners are kinks: points where the short-run solution is not differentiable, at
which (16) is not stated (p.24) and returns whichever one-sided answer the regime
classification happens to pick. The enumeration finds them because the pattern that reads
the pair as idle is a legitimate pattern at a degenerate point. This is exactly the failure
mode the ledger entry for the model's transcription named in advance: a candidate sitting
on a kink would be silently mis-tested (`FINDINGS.md` F-0012, corrected by F-0018). It is
also why no root of (16) is called an equilibrium here until the best-response scan has
been run on it (`DECISIONS.md` D-0006).

## The equilibrium, checked against the paper

The surviving root is checked against every comparative result the paper states, relating
it to the competitive and open-loop equilibria of chapter 1, both already validated:

```@example ch2
x_cl = roots.solutions[findfirst(g -> g.gap == 0.0, gaps)]
cl = ms_second_stage(data, x_cl)
dec = ms_closed_loop_conditions_decomposed(data, cl)

@assert sum(x_cl) >= sum(ol.x)                               # Theorem 4, p.28
@assert x_cl[PLAYER_B] >= ol.x[PLAYER_B]                     # Theorem 5, p.28
@assert all(cl.price .<= ol.price .+ tol)                    # Theorem 6, p.28
@assert sum(ol.x) <= sum(x_cl) <= sum(comp.x)                # Theorem 7, p.29
@assert cl.λ[PLAYER_P, :] ≈ ol.λ[PLAYER_P, :] atol = tol     # Lemma 12, p.29
@assert abs(dec.open_loop[PLAYER_P]) < tol && dec.open_loop[PLAYER_B] > tol   # Corollary 3, p.28
(x = x_cl, price = cl.price, total = (open_loop = sum(ol.x), closed_loop = sum(x_cl),
                                      competitive = sum(comp.x)))
```

Total capacity 10 sits between the open-loop 9.58 and the competitive 15, and every price is
below its open-loop value. Nothing here claims ``(5, 5)`` is the *only* equilibrium: the
enumeration finds roots at differentiable points, and an equilibrium sitting exactly on a
kink between regimes would be missed (`DECISIONS.md` D-0006).

## Diagonalization reaches the same point

The textbook route to an equilibrium like this is diagonalization: fix one player, replace
the other's capacity with its best response, alternate, and stop when nothing moves. Here
the best response is computed globally and exactly, by minimising the objective's quadratic
piece on each second-stage pattern's interval of validity:

```@example ch2
run = diagonalize(data; x0 = [0.0, 0.0])
@assert run.status === :converged && run.x ≈ x_cl atol = 1e-6
(status = run.status, rounds = run.iterations, steps = round.(run.steps[1:6]; sigdigits = 3))
```

Convergence is linear: after the first two rounds the step shrinks by a factor of about six
each round. Started at a corner root, the loop does not stay:

```@example ch2
from_corner = diagonalize(data; x0 = corner)
@assert from_corner.status === :converged && from_corner.x ≈ x_cl atol = 1e-6
(status = from_corner.status, rounds = from_corner.iterations, first_step = from_corner.trajectory[2])
```

The corners satisfy the first-order condition as evaluated, but they are not fixed points
of the best-response map: at a corner the idle player's best response is somewhere else,
and the first unit already says so. Any method that actually looks at the objective, rather
than at (16) read off the point, moves on. Chapter 3 hands that inner step to CCOpt.

## The corners are exactly the degenerate points

At a corner one player holds no capacity. It produces nothing, its capacity constraint
binds at zero, and any sufficiently large shadow price on that constraint satisfies the
conditions. The second stage stops being strictly complementary, and its dual stops being a
point:

```@example ch2
M2, q2, _ = ms_second_stage_lcp(data, corner)
S = data.S
duals(w) = w[2S+1:4S]                   # λ_p then λ_b, per segment
outputs(w) = w[1:2S]

stage = Dict(b => solve_complementarity(M2, q2, b).x
             for b in (:path, :ccopt_relaxation, :ccopt_penalty))
@assert !strictly_complementary(M2, q2, stage[:path])
for b in (:path, :ccopt_relaxation, :ccopt_penalty)
    w = stage[b]
    println(rpad(b, 18),
            "outputs within ", rpad(round(maximum(abs.(outputs(w) .- outputs(stage[:path]))); sigdigits = 2), 9),
            "of PATH's   largest dual ", rpad(round(maximum(duals(w)); sigdigits = 3), 10),
            "residual ", round(lcp_residual(M2, q2, w).worst; sigdigits = 2))
    @assert maximum(abs.(outputs(w) .- outputs(stage[:path]))) < 1e-7
end
```

The outputs agree across all three solvers to 1e-8. The duals do not: PATH returns the
vertex of the ray and both CCOpt methods walk far out along it. And the penalty method's
recomputed residual is about 1e-3, four orders of magnitude worse than at the equilibrium,
although its primal is as accurate as anyone's. Push the base player's capacity duals
further along the ray, with its outputs placed exactly on their bound, and the residual
does not move:

```@example ch2
w = copy(stage[:path])
w[S+1:2S] .= 0.0                                   # the base player's outputs, exactly zero
for bump in (1.0, 1e3, 1e5)
    v = copy(w); v[3S+1:4S] .+= bump               # the base player's capacity duals
    @assert lcp_residual(M2, q2, v).worst == lcp_residual(M2, q2, w).worst
end
lcp_residual(M2, q2, w).worst
```

So at these points the residual measures how far along the ray a solver stopped, not
whether it solved anything. That is a limit on the pass criterion this whole programme
rests on, recorded against the engine's `DECISIONS.md` D-0002; the engine's documentation
has the same thing in two variables. And it is no coincidence that the spurious roots and
the degenerate points are the same points. They are one biactive pair seen twice: as
degeneracy it leaves the shadow price undetermined and makes the dual a ray, and as an
ambiguous regime it lets the classification choose the reading on which the corner is a
root.

## Instance B

The same structure appears on the realistic instance, over ``2^{16}`` second-stage
patterns:

```@example ch2
data_b = load_ms_instance(joinpath(datadir, "ms2002_instance_b.toml"))
roots_b = enumerate_closed_loop(data_b)
gaps_b = [best_response_gap(data_b, x).gap for x in roots_b.solutions]
@assert length(roots_b.solutions) == 3 && count(==(0.0), gaps_b) == 1
[(x = round.(x; digits = 3), deviation_gain = round(g; digits = 1))
 for (x, g) in zip(roots_b.solutions, gaps_b)]
```

Three roots, one equilibrium at ``(3.03, 3.54)`` GW, and two corners at which the player
holding nothing could gain 322.5 or 187.9 by building.

## The standalone file

[`closed_loop_demonstration.jl`](../generated/standalone/closed_loop_demonstration.jl)
packages this chapter for someone who has CCOpt and nothing else. It solves every output
stage with both CCOpt methods, evaluates (16) at each root, pushes the dual along the ray
at each corner, and asserts that exactly one root is an equilibrium: 82 assertions in about
thirty seconds. It is not a regression test and is not offered as one. Its subject is that
a complementarity system can have a larger solution set than the problem it represents, so
the right assertion about a solver is "it returned one of these points", followed by a
separate check of which.

## What this chapter does not establish

The enumeration evaluates (16) under every pattern, including patterns at kinks where (16)
does not apply, so its roots are candidates and some are artefacts; an equilibrium sitting
on a kink could equally be missed. The best-response scan runs on a grid, so it refutes the
corners decisively and certifies the equilibrium only up to the grid. Nothing here says
``(5, 5)`` is the only equilibrium. And the degeneracy seen here arises one way only, from a
player holding no capacity.
