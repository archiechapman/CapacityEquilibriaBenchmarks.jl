# The best response as an MPCC

The third rung takes away convexity, and turns the problem from a square system into an
optimisation. Chapter 2 found that the closed-loop game's first-order conditions admit
roots that are not equilibria, and that diagonalization is not fooled by them because its
inner step, one player's best response, looks at the objective itself. This chapter writes
that best response as a genuine MPCC and hands it to CCOpt. Its global optimum is known
exactly from the pattern enumeration, so CCOpt can be marked against a right answer,
including from the degenerate corners of chapter 2.

```@example ch3
using CapacityEquilibriaBenchmarks, CapacityEquilibria
import NLPModels, MPCCModels
using LinearAlgebra: eigvals

datadir  = joinpath(pkgdir(CapacityEquilibriaBenchmarks), "data")
data     = load_ms_instance(joinpath(datadir, "ms2002_instance_a.toml"))
expected = joinpath(datadir, "ms2002_instance_a_expected.toml")
x_star   = load_ms_expected(data, expected, :closed_loop_cournot)[1:2]   # (5, 5), chapter 2
nothing # hide
```

## Why this, and not the whole game at once

The obvious formulation stacks every player's first-order conditions into one monolithic
MPCC. That turns out not to be a reformulation. Condition (16) depends on
Lemma 7's derivative table, which is piecewise constant and indexed by which
complementarities are active, so (16) is not a smooth function of the variables and no
single smooth MPCC has it as its stationarity conditions. The two honest routes to a
monolithic system are a disjunctive encoding, which leaves MPCC territory, and stacking
each player's own MPEC optimality conditions, whose constraint qualifications fail at
exactly the degenerate corners of chapter 2. Neither is built. The piece both routes need,
and which is well posed on its own, is one player's problem.

## The problem

Player ``i``, with the rival's capacity ``x_{-i}`` fixed, chooses its capacity and, through
it, the short-run equilibrium:

```math
\begin{aligned}
\min_{x_i,\,y,\,\lambda,\,\omega,\,u \;\ge 0}\quad
  & K_i x_i + \sum_s \bigl[-\alpha^s + \beta\,(y_p^s + y_b^s) + \nu_i\bigr]\, y_i^s \\
\text{s.t.}\quad
  & \omega_j^s = -\alpha^s + 2\beta y_j^s + \beta y_{-j}^s + \nu_j + \lambda_j^s,
    \qquad u_j^s = x_j - y_j^s, \\
  & 0 \le y_j^s \perp \omega_j^s \ge 0, \qquad 0 \le \lambda_j^s \perp u_j^s \ge 0
    \qquad \text{for both players } j \text{ and every } s .
\end{aligned}
```

The constraints are the short-run conditions (4) of p.24 with explicit slacks, so that
every complementarity is between two variables, which is the form CCOpt takes. The
objective is the long-run objective (15). For instance A that is ``1 + 8S = 25`` variables,
``4S = 12`` linear equalities and 12 complementary pairs:

```@example ch3
mpcc, idx = best_response_mpcc(data, PLAYER_B, x_star)
nlp = idx.nlp
@assert NLPModels.get_nvar(nlp) == 25 && NLPModels.get_ncon(nlp) == 12
@assert MPCCModels.get_ncc(mpcc) == 12
(variables = NLPModels.get_nvar(nlp), equalities = NLPModels.get_ncon(nlp),
 pairs = MPCCModels.get_ncc(mpcc))
```

It is genuinely nonconvex. On each segment's block of the two players' outputs the
objective's Hessian is ``[2\beta\ \ \beta;\ \beta\ \ 0]``, whose determinant is ``-\beta^2``:

```@example ch3
β = data.beta
@assert minimum(eigvals([2β β; β 0])) < 0
eigvals([2β β; β 0])
```

It is why a best response is a search over a row of quadratic wells, one per regime,
rather than a single smooth descent, and chapter 4 turns that into a hard case.

## The right answer, found without CCOpt

For a fixed rival capacity, each second-stage complementarity pattern makes the second
stage affine in the player's own capacity, so the objective is a quadratic on the interval
where that pattern holds. Minimising each quadratic on its own interval, and taking the
best over all patterns, gives the global optimum. `best_response` does that, and then
re-evaluates each candidate with a real second-stage solve. At the equilibrium each
player's best response is its own capacity:

```@example ch3
exact = [best_response(data, i, x_star) for i in (PLAYER_P, PLAYER_B)]
@assert all(isapprox(exact[i].x_i, x_star[i]; atol = 1e-6) for i in 1:2)
exact
```

## CCOpt reaches it

```@example ch3
for i in (PLAYER_P, PLAYER_B), method in (:relaxation, :penalty)
    r = solve_best_response_mpcc(data, i, x_star; method = method)
    @assert r.feasibility < 1e-6
    @assert isapprox(r.x_i, exact[i].x_i; atol = 1e-4)
    @assert isapprox(r.objective, exact[i].objective; atol = 1e-4)
    println(i == PLAYER_P ? "peaker     " : "base-load  ", rpad(method, 12),
            "x_i = ", rpad(round(r.x_i; digits = 6), 11),
            "objective ", round(r.objective; digits = 6),
            "   (exact ", round(exact[i].objective; digits = 6), ")")
end
```

Both players, both methods, the global optimum. That is reassuring and not yet a test:
nothing about this start made the answer hard to find.

## Starting at a corner

Chapter 2's corner roots give a harder start. At the corner ``(7.5, 0)`` the base player
holds nothing, the first-order condition read at that point tells it not to invest, and
its global best response is 5.33 away and worth 46.3. The corner is not a local optimum,
since the first unit already pays, but it is a degenerate place to start: every one of the
player's capacity pairs is biactive and its capacity duals lie on a ray.

`best_response_start` builds a full starting vector at that point, with every variable
consistent: outputs from the second-stage solution, duals and slacks implied by them, and
the player's capacity at zero.

```@example ch3
roots   = enumerate_closed_loop(data)
corners = [x for x in roots.solutions if any(x .== 0.0)]
@assert length(corners) == 2

corner = corners[findfirst(x -> x[PLAYER_B] == 0.0, corners)]
z0 = best_response_start(data, PLAYER_B, corner)
_, cidx = best_response_mpcc(data, PLAYER_B, corner)
@assert maximum(abs.(cidx.nlp.A * z0 .- NLPModels.get_lcon(cidx.nlp))) < 1e-8   # feasible
(corner = corner, capacity_at_start = z0[1], objective_at_start = NLPModels.obj(cidx.nlp, z0))
```

Now hand CCOpt both corners, each from that start, with both methods:

```@example ch3
for c in corners
    i = c[PLAYER_P] == 0.0 ? PLAYER_P : PLAYER_B
    truth = best_response(data, i, c)
    start = best_response_start(data, i, c)
    for method in (:relaxation, :penalty)
        r = solve_best_response_mpcc(data, i, c; method = method, x0 = start)
        @assert isapprox(r.x_i, truth.x_i; atol = 1e-4)      # it left, and found the global answer
        println("corner ", rpad(c, 12), rpad(method, 12), "started at 0.0  ->  x_i = ",
                rpad(round(r.x_i; digits = 6), 10), "(global optimum ", round(truth.x_i; digits = 6),
                ", worth ", round(-truth.objective; digits = 2), ")")
    end
end
```

Both methods leave, on both corners, and find the global answer. `FINDINGS.md` F-0016
records 32 solves of this kind across both instances, 8 of them from a corner, and all 32
reach the global optimum.

## What those corner solves do and do not show

They show CCOpt coping with a degenerate start: biactive pairs and a dual on a ray, from
which both methods reach the global optimum rather than stalling. They do not show CCOpt
escaping a trap, and this repository's ledger once said they did. F-0016 described the
corner as "a local optimum that is not global" and credited CCOpt's homotopy, which
tightens the complementarity gradually and so lets an iterate cross between regimes, with
the escape. The walk out from the corner in chapter 2 refutes the premise: the objective
falls from the first unit, so the MPCC itself has a feasible descent path from the start,
and a method that only ever moved downhill would leave too. F-0018 records the correction,
and it came from this tutorial's own assertions failing when the site was first built.

A genuine trap needs two optima that are both local minima, with the start in the worse
one. That is what the next chapter builds.

## What this chapter does not establish

"Global" here means agreement with the pattern enumeration, which is exact for this family
of problems and is not a general certificate. The nonconvexity is mild and structured: a
row of quadratic wells, one per regime. Nothing here says CCOpt finds global optima in
general, which would be false, and the next chapter builds a version of this same problem
on which it does not.
