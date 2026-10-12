# An equilibrium you can solve by hand

The first rung is the easy case, on purpose. Under perfect competition, and again under
open-loop Cournot competition, Murphy and Smeers' equilibrium conditions form a square
linear complementarity problem with a unique solution. That solution can be found without
any solver, three different ways, and so a solver can be marked against it rather than
against another solver. This chapter builds both models on instance A, finds the answer
three ways, and then checks four solver routes against it.

## Instance A, and the paper's assumptions

```@example ch1
using CapacityEquilibriaBenchmarks, CapacityEquilibria
import TOML

datadir  = joinpath(pkgdir(CapacityEquilibriaBenchmarks), "data")
data     = load_ms_instance(joinpath(datadir, "ms2002_instance_a.toml"))
expected = joinpath(datadir, "ms2002_instance_a_expected.toml")
data
```

Three segments, ``\beta = 1``, ``\alpha = (20, 15, 10)``; the peaker has ``K_p = 2`` and
``\nu_p = 3``, the base plant ``K_b = 7`` and ``\nu_b = 1``. `load_ms_instance` checks every
assumption the paper states on its parameters before returning, so that no model is ever
built from values its theorems do not cover. Swap the operating costs and it refuses:

```@example ch1
swapped = MSData("swapped", 3, 1.0, [20.0, 15.0, 10.0], [2.0, 7.0], [1.0, 3.0])
msg = try
    check_assumptions(swapped); "accepted"
catch err
    sprint(showerror, err)
end
@assert startswith(msg, "ArgumentError")
msg
```

The paper's production-efficiency property (p.14) says a competitive peaker is built and
run only in the first ``S_p`` segments, where ``K_p + s\nu_p < K_b + s\nu_b``. Here
``2 + 3s < 7 + s`` holds for ``s \le 2``:

```@example ch1
@assert peak_segments(data) == 2
peak_segments(data)
```

## The equilibrium conditions as an LCP

The competitive equilibrium, equations (2)–(3) on p.14, pairs each variable with one
condition. For each player ``i`` and segment ``s``:

```math
\begin{aligned}
0 \le y_i^s       &\;\perp\; -\alpha^s + \beta\,(y_i^s + y_{-i}^s) + \nu_i + \lambda_i^s \ge 0
    && \text{output against price} \\
0 \le \lambda_i^s &\;\perp\; x_i - y_i^s \ge 0
    && \text{capacity dual against capacity} \\
0 \le x_i         &\;\perp\; K_i - \textstyle\sum_s \lambda_i^s \ge 0
    && \text{capacity against its scarcity rents}
\end{aligned}
```

The open-loop Cournot equilibrium, (5)–(6) on p.16, is identical except that the
coefficient on a player's own output in the first line is ``2\beta``: a Cournot player sees
its own effect on the price. Everything is affine and every variable is nonnegative, so
both are LCPs ``0 \le z \perp Mz + q \ge 0`` in ``z = (x, y, \lambda)``, of size
``n = 2 + 4S = 14``.

```@example ch1
M, q, ix = ms_lcp(data, :competitive)
@assert size(M) == (14, 14)
@assert is_monotone(M)          # Lemma 1, p.18 proves it for the Cournot map; this one likewise
size(M)
```

The pairing is the variable layout and nothing else: row ``k`` of ``Mz + q`` is the
condition paired with ``z_k``. Because a mis-assembled row would converge quietly to the
answer to a different problem, the assembly is checked against a second transcription of
the same equations, written row by row without ``M``, at a point with all-distinct
coordinates:

```@example ch1
z_probe = [k / 3 for k in 1:14]
@assert M * z_probe .+ q ≈ ms_conditions(data, :competitive, z_probe)
maximum(abs.(M * z_probe .+ q .- ms_conditions(data, :competitive, z_probe)))
```

## Three answers that consult no solver

**By hand.** The derivation, in the Results section, guesses the regime that production
efficiency suggests, solves the resulting linear equations, and checks every condition by
substitution. The answer is recorded in `data/ms2002_instance_a_expected.toml`:

```@example ch1
z_hand = load_ms_expected(data, expected, :competitive)
hand = ms_unpack(data, z_hand)
@assert lcp_residual(M, q, z_hand).worst < 1e-12
(x = hand.x, price = hand.price, residual = lcp_residual(M, q, z_hand).worst)
```

Capacities ``x = (7, 8)`` and prices ``(5, 3, 2)``, with residual zero: the fractions are
exact.

**By enumeration.** Every solution of an LCP has a complementarity pattern, a choice for
each pair of which member may be nonzero. Fixing a pattern turns the problem into a linear
system. Trying all ``2^{14}`` patterns and keeping the solutions that are feasible finds
every solution in a nondegenerate pattern, and no solver is involved:

```@example ch1
en = enumerate_lcp_solutions(M, q)
@assert length(en.solutions) == 1
@assert en.solutions[1] ≈ z_hand atol = 1e-9
(solutions = length(en.solutions), distance_from_hand = maximum(abs.(en.solutions[1] .- z_hand)))
```

**By argument.** Enumeration skips rank-deficient patterns, so on its own it cannot rule
out a continuum of solutions hiding in one. Uniqueness needs an argument. For a monotone
LCP, a solution that is strictly complementary, one member of every pair strictly positive,
and whose basis matrix is nonsingular, is the only solution:

```@example ch1
@assert is_monotone(M) && strictly_complementary(M, q, z_hand) && basis_nonsingular(M, z_hand)
(monotone = is_monotone(M), strict = strictly_complementary(M, q, z_hand),
 nonsingular = basis_nonsingular(M, z_hand))
```

Three routes, none of which consults another, and they agree. That is the ground truth
the solvers are now marked against.

## Four solver routes

The tolerance comes from the data file. It was fixed before either CCOpt method was run on
this problem, and the nearest wrong regime is a distance of order one away, so it cannot
admit a wrong answer.

```@example ch1
tol = TOML.parsefile(expected)["tolerance"]
backends = (:path, :ccopt, :ccopt_relaxation, :ccopt_penalty)
sols = Dict(b => solve_complementarity(M, q, b) for b in backends)

for b in backends
    r = lcp_residual(M, q, sols[b].x).worst
    d = maximum(abs.(sols[b].x .- z_hand))
    println(rpad(b, 18), "residual ", rpad(round(r; sigdigits = 2), 10),
            "distance from hand ", round(d; sigdigits = 2))
    @assert r < tol && d < tol
end
```

PATH lands on the answer to within rounding; both CCOpt methods land within about 1e-7,
the penalty method a little further out than the relaxation method. The two relaxation
routes, one through JuMP and its bridges and one through a model the engine builds by
hand, return the same vector bit for bit:

```@example ch1
@assert sols[:ccopt].x == sols[:ccopt_relaxation].x
sols[:ccopt].x == sols[:ccopt_relaxation].x
```

## The paper's theorems, at every solver's point

Agreement with the derived point is one check. The other is that everything the paper
proves about the competitive equilibrium holds at each solver's point, checked
independently rather than inherited from PATH's. The regime check matters most. It
classifies each segment into the paper's five-way partition (13), p.22, and it is what
separates a solver that is merely *near* the equilibrium from one on the right side of
every complementarity boundary.

```@example ch1
for b in backends
    pt = ms_unpack(data, sols[b].x)
    gap = investment_criterion_gap(data, :competitive, pt)
    @assert production_efficiency_holds(data, pt)                  # p.14
    @assert pricing_efficiency_gap(data, pt) < tol                 # p.15
    @assert gap.p < tol && gap.b < tol                             # p.15
    @assert [segment_type(data, pt, s; tol = tol) for s in 1:3] == [:a, :c, :e]
end
[segment_type(data, ms_unpack(data, sols[:path].x), s) for s in 1:3]
```

Segment 1 has both players at capacity (type a). Segment 2 has the base plant at capacity
and the peaker running below it (type c). Segment 3 has the peaker idle and the base plant
at capacity (type e): at a price of 2 the peaker, with an operating cost of 3, does not
run. Each player's capacity cost equals the scarcity rents it earns over the year, which is
the investment criterion of p.15.

## The Cournot equilibrium

Changing one coefficient gives the open-loop Cournot model. The same three routes find its
answer:

```@example ch1
Mo, qo, _ = ms_lcp(data, :open_loop_cournot)
z_ol = load_ms_expected(data, expected, :open_loop_cournot)
en_ol = enumerate_lcp_solutions(Mo, qo)
@assert lcp_residual(Mo, qo, z_ol).worst < 1e-12
@assert length(en_ol.solutions) == 1 && en_ol.solutions[1] ≈ z_ol atol = 1e-9
@assert strictly_complementary(Mo, qo, z_ol) && basis_nonsingular(Mo, z_ol)

ol = ms_unpack(data, z_ol)
(x = ol.x, price = ol.price)
```

Capacities ``(65/12, 25/6)`` and prices ``(125/12, 83/12, 14/3)``, and both CCOpt methods
reach them:

```@example ch1
for b in (:path, :ccopt_relaxation, :ccopt_penalty)
    s = solve_complementarity(Mo, qo, b)
    @assert lcp_residual(Mo, qo, s.x).worst < tol && maximum(abs.(s.x .- z_ol)) < tol
end
```

Three things the paper says about this equilibrium are visible in it.

```@example ch1
comp = ms_unpack(data, z_hand)
@assert sum(ol.x) < sum(comp.x) && all(ol.price .> comp.price)   # Theorem 7, p.29
@assert ol.y[PLAYER_P, 3] > tol                                  # p.16
@assert ol.λ[PLAYER_P, :] ≈ comp.λ[PLAYER_P, :]                  # Lemma 12, p.29
(total_capacity = (competitive = sum(comp.x), cournot = sum(ol.x)),
 peaker_output_in_segment_3 = (competitive = comp.y[PLAYER_P, 3], cournot = ol.y[PLAYER_P, 3]))
```

Cournot players withhold capacity: total capacity falls from 15 to about 9.6 and every
price rises. The Cournot peaker runs in segment 3, beyond ``S_p = 2``, where it is not the
efficient technology, because the base player's withholding leaves the price above the
peaker's operating cost; the paper says in words that this can happen (p.16), and here it
does. And the peak capacity's scarcity rents are ``(2, 0, 0)`` in both equilibria even
though nothing else is the same, which is Lemma 12.

## Instance B

Instance B is the same model at a more realistic scale: gigawatts, \$/MWh, four
quarter-year blocks, ``n = 18``. Its enumeration runs over ``2^{18}`` patterns and lives in
the test suite rather than here; the comparison with the hand derivation is cheap:

```@example ch1
data_b = load_ms_instance(joinpath(datadir, "ms2002_instance_b.toml"))
expected_b = joinpath(datadir, "ms2002_instance_b_expected.toml")
tol_b = TOML.parsefile(expected_b)["tolerance"]

for variant in MS_VARIANTS
    Mb, qb, _ = ms_lcp(data_b, variant)
    zb = load_ms_expected(data_b, expected_b, variant)
    for b in (:path, :ccopt_relaxation, :ccopt_penalty)
        s = solve_complementarity(Mb, qb, b)
        @assert lcp_residual(Mb, qb, s.x).worst < tol_b && maximum(abs.(s.x .- zb)) < tol_b
    end
    pt = ms_unpack(data_b, zb)
    println(rpad(variant, 20), "x = ", round.(pt.x; digits = 3), " GW   regimes ",
            [segment_type(data_b, pt, s) for s in 1:4])
end
```

Between them the two instances reach competitive regimes (a), (c), (d), (e) and Cournot
regimes (a), (b), (c), so a solver that mishandles one branch of the complementarity has
somewhere to show it.

## The standalone file

Everything in this chapter that concerns CCOpt is packaged as
[`test_murphy_smeers_lcp.jl`](../generated/standalone/test_murphy_smeers_lcp.jl): the four
problems, the four known answers, and both CCOpt methods, in one file that imports only
CCOpt.jl's own test dependencies. It is not a copy of the code above. The model assembly,
the NLP and the residual oracle are spliced into it verbatim from the sources this chapter
ran, and the test suite rebuilds its matrices and requires them to be `==` to the ones
built here. [The standalone files](@ref) has the details.

## What this chapter does not establish

All four problems have a unique, strictly complementary solution with a nonsingular basis.
That is exactly why their answers could be known in advance, and it is also the easiest
case for every method: a relaxation or penalty scheme has nothing to choose between. This
chapter shows that CCOpt gets the easy case right. The next one takes uniqueness away.
