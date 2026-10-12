# Engineering a hard case

The last rung takes away the margin. Everything the previous chapters put to CCOpt, it
solved: unique solutions, degenerate output stages, a nonconvex best response started at a
degenerate corner. A test nothing fails is a weak thing to offer a solver's author, so this
chapter builds a hard problem on purpose, keeping the one property that makes it a test
rather than a puzzle: the right answer is still known exactly.

```@example ch4
using CapacityEquilibriaBenchmarks, CapacityEquilibria

datadir = joinpath(pkgdir(CapacityEquilibriaBenchmarks), "data")
data    = load_ms_instance(joinpath(datadir, "ms2002_instance_a.toml"))
bases   = feasible_bases(data)      # every usable second-stage pattern, computed once
nothing # hide
```

## A row of wells

At a fixed rival capacity, a player's long-run objective is piecewise quadratic, one piece
per second-stage regime, so its landscape is a row of wells separated by kinks.
`best_response_wells` lists every local minimum by enumerating the pieces, and sorts them so
the global optimum comes first. Here is the peaking player's landscape when the base
player holds 7 units:

```@example ch4
wells = best_response_wells(data, PLAYER_P, [0.0, 7.0]; bases = bases)
[(x_p = round(w.x_i; digits = 4), objective = round(w.objective; digits = 4)) for w in wells]
```

As the rival's capacity moves, the wells rise and fall relative to one another. Somewhere
between "this well is deeper" and "that well is deeper" two of them must be exactly level.

## Finding the tie

`best_response_tie` finds that rival capacity: it scans for the smallest gap between the
two best local minima at least a given distance apart, then refines by golden section. The
tie used throughout this chapter, and in the standalone file, was located this way and
recorded as `7.254033307585`. Re-deriving it from nothing takes a few seconds:

```@example ch4
recorded = 7.254033307585
found = best_response_tie(data, PLAYER_P; separation = 0.4)
@assert found.found && abs(found.x_other - recorded) < 1e-9
(rival = found.x_other, wells = (found.best.x_i, found.alt.x_i), gap = found.gap)
```

At that rival capacity the peaker has two optima more than a unit apart, at 3.873 and at
5.000, whose objectives agree to about fourteen significant figures:

```@example ch4
tie = recorded
w = best_response_wells(data, PLAYER_P, [0.0, tie]; bases = bases)
a, b = w[1], w[2]
@assert abs(a.x_i - b.x_i) > 1.0
@assert abs(a.objective - b.objective) / abs(a.objective) < 1e-12
(wells = (a.x_i, b.x_i), objectives = (a.objective, b.objective),
 relative_difference = abs(a.objective - b.objective) / abs(a.objective))
```

The shape around them, sampled on a grid, shows two wells of equal depth with a ridge
between:

```@example ch4
grid = 3.0:0.25:6.0
vals = [closed_loop_objective(data, PLAYER_P, [v, tie]) for v in grid]
lo, hi = extrema(vals)
for (v, f) in zip(grid, vals)
    bar = repeat("█", round(Int, 40 * (f - lo) / (hi - lo)))
    println(rpad(v, 6), rpad(round(f; digits = 3), 10), bar)
end
```

## Off the tie, the answer flips

Exactly at the tie the question has no answer, so nothing is marked there. Move the
rival's capacity by a thousandth and one well becomes strictly better; move it the other
way and the *other* one does.

```@example ch4
offsets = (-0.01, -0.001, 0.001, 0.01)
problems = map(offsets) do δ
    g = best_response_gap_at(data, PLAYER_P, tie + δ; separation = 0.4, bases = bases)
    (offset = δ, rival = tie + δ, right = g.best.x_i, other = g.alt.x_i,
     margin = g.gap, relative = g.gap / abs(g.best.objective))
end
@assert problems[2].right < 4.0 && problems[3].right > 4.9     # the winner changes sides
@assert all(1e-5 < p.relative < 2e-3 for p in problems)          # by a sliver
[(offset = p.offset, right = round(p.right; digits = 4), other = round(p.other; digits = 4),
  relative_margin = round(p.relative; sigdigits = 2)) for p in problems]
```

So the same problem, perturbed in the fifth significant figure of one parameter, has two
right answers more than a unit apart, and the margin deciding between them is about one
part in ten thousand. A method biased towards where it starts gets exactly one side of the
tie wrong.

## CCOpt, started in the wrong well

Each problem is now posed from a start inside the *wrong* well, with every variable
consistent there, which is the honest way to ask whether a method can leave one. The right
answer is known from the enumeration above, independently of CCOpt.

```@example ch4
hits = 0
for p in problems, method in (:relaxation, :penalty)
    x = [0.0, p.rival]
    start = best_response_start(data, PLAYER_P, [p.other, p.rival])
    r = solve_best_response_mpcc(data, PLAYER_P, x; method = method, x0 = start)
    hit = abs(r.x_i - p.right) < 1e-3
    global hits += hit
    @assert r.feasibility < 1e-5
    println("offset ", rpad(p.offset, 8), rpad(method, 12), "-> x_p = ",
            rpad(round(r.x_i; digits = 4), 8),
            hit ? "found the better well" : "kept the worse well")
end
println("\nfound the better well in $hits of $(2 * length(problems)) solves")
```

The count is reported, not asserted, because it is a finding rather than an expected value,
and it moves with the starting point. Across all four ties of both instances, 32 problems,
CCOpt finds the better well in 16 when warm-started from its own output stage, as the
standalone file does, and 19 when warm-started from PATH's, as this page does
(`FINDINGS.md` F-0017). Both methods fail, on different problems, with neither dominating.

It is worth being exact about what a miss is. Every point returned is feasible and sits in
one of the two wells: a genuine local optimum. These are not convergence failures. They are
converged answers to a question with two nearly equal answers, and nothing in a residual or
a status distinguishes the wrong one from the right one.

## Why the file carries its own ground truth

The wells sit on regime boundaries, and there CCOpt's own output stage is less accurate
than at an interior point. Compare its short-run solution with PATH's at one of the wells
and at the closed-loop equilibrium of chapter 2:

```@example ch4
function stage_gap(x)
    M2, q2, _ = ms_second_stage_lcp(data, x)
    maximum(abs.(solve_complementarity(M2, q2, :ccopt_relaxation).x .-
                  solve_complementarity(M2, q2, :path).x))
end
accuracy = (at_a_well = stage_gap([problems[3].right, problems[3].rival]),
            at_the_equilibrium = stage_gap([5.0, 5.0]))
@assert accuracy.at_a_well > 100 * accuracy.at_the_equilibrium
accuracy
```

A solver cannot be its own oracle on a margin of a few thousandths when its own arithmetic
is uncertain at that scale, so the standalone file inlines the two wells and their margin,
computed here from the enumeration and PATH, rather than recomputing them with CCOpt.

## The standalone file

[`hard_case_near_tie.jl`](../generated/standalone/hard_case_near_tie.jl) is this chapter
for all four ties, both instances and both players, in one file that imports only CCOpt's
own test dependencies. It asserts the ground truth, that each problem's two wells are far
apart and nearly level and that whatever CCOpt returns is one of them, and it reports the
score without asserting it. Freezing the score would turn a finding into a regression
baseline.

## What this chapter does not establish

It is one mechanism for hardness, two quadratic pieces of one objective crossing, not a
survey of what makes an MPCC hard. And no other MPCC solver has been run on these problems,
so there is no basis yet for saying whether finding the better well half the time is good,
bad or ordinary. That comparison is what the standalone file is for.
