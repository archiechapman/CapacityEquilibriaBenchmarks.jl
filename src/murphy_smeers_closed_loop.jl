# Murphy and Smeers, section 6: the closed-loop Cournot model.
#
# Page numbers cite the May 2002 working paper's printed pages (PDF page = printed + 2),
# as everywhere else in this repository.
#
# THE STRUCTURE, AND WHY IT IS NOT AS DIFFERENT AS FINDINGS.md F-0003 SUGGESTS.
#
# In the closed-loop game each player picks capacity `x_i` first, anticipating that
# second-stage output is the *equilibrium* of the short-run game played at those
# capacities, rather than a quantity it chooses freely. The long-run problem of player i
# is (15), p.24:
#
#     min_{x_i ≥ 0}  K_i x_i + Σ_s [−α^s + β(y_i^s(x) + y_{−i}^s(x)) + ν_i] y_i^s(x)
#
# where `y(x)` solves the short-run conditions (4), restated on p.24, for the given `x`:
#
#     0 ≤ y_i^s ⟂ −α^s + 2β y_i^s + β y_{−i}^s + ν_i + λ_i^s = ω_i^s ≥ 0
#     0 ≤ λ_i^s ⟂ x_i − y_i^s ≥ 0
#
# Those short-run conditions are, line for line, the `y` and `λ` rows of the open-loop
# Cournot LCP this repository already builds (`ms_lcp` with `:open_loop_cournot`). The two
# models share their entire second stage and differ in one place only: the condition paired
# with `x_i`. Open-loop has `K_i − Σ_s λ_i^s`. Closed-loop has (16), p.24:
#
#     0 ≤ x_i ⟂ ξ_i = K_i + Σ_s [−α^s + 2β y_i^s + β y_{−i}^s + ν_i] B_i y_i^s
#                          + Σ_s β y_i^s B_i y_{−i}^s  ≥ 0
#
# with `B_i y_j(x) = ∂y_j/∂x_i`, the sensitivity of the second-stage equilibrium to the
# first-stage capacity. That derivative is what the open-loop player ignores and the
# closed-loop player exploits, and it is the whole of the difference between the models.
#
# WHAT MAKES THIS TRACTABLE. Lemma 7 (14), p.22 gives `B_i y_j` in closed form, and it is
# *piecewise constant*: it depends on the segment only through which of the paper's five
# regime types (13), p.22 the segment is in. So evaluating (16) at a capacity vector needs
# one second-stage solve, a regime classification this repository already computes
# (`segment_type`), and a table lookup. There is no automatic differentiation and no
# numerical derivative anywhere in the equilibrium conditions.
#
# WHAT IS GENUINELY HARDER. Three things, and they are why Phase 3 needs its own notion of
# ground truth rather than inheriting D-0004's:
#
#   * The map is not affine in `x`, because the regime — and hence `B` — changes with `x`.
#     `ms_lcp` and the engine's `lcp_residual` do not apply to the first stage.
#   * `y(x)` is only piecewise differentiable (Lemma 2, p.19, gives left and right
#     derivatives), and (16) is stated only "at a point x such that the y_i^s(x) are
#     differentiable" (p.24). Equilibria can sit at kinks, where (16) is not the condition.
#   * The equilibrium need not be unique, and need not exist. Section 7 builds the
#     machinery for that question and Lemma 13, p.31 shows the objective is only piecewise
#     convex; Figure 4, p.32 shows the marginal cost curve can jump downwards.
#
# So nothing here claims to *find* the closed-loop equilibrium. This file supplies the
# second stage, the derivative table, and the residual of (16) — the pieces an equilibrium
# search needs and which can each be checked on their own.

# --- the second stage ------------------------------------------------------------------

"""
    MSSecondStageIndex

Positions in the second-stage vector `w = (y_p^1..S, y_b^1..S, λ_p^1..S, λ_b^1..S)`, of
length `4S`. Capacities are data here, not variables.
"""
struct MSSecondStageIndex
    S::Int
end
Base.length(ix::MSSecondStageIndex) = 4 * ix.S
ix2_y(ix::MSSecondStageIndex, i, s) = (i - 1) * ix.S + s
ix2_λ(ix::MSSecondStageIndex, i, s) = 2 * ix.S + (i - 1) * ix.S + s

"""
    ms_second_stage_lcp(data, x) -> (M, q, ix)

The short-run Cournot equilibrium at fixed capacities `x`, as the LCP
`0 ≤ w ⟂ Mw + q ≥ 0` in `w = (y, λ)`. Equations (4), restated on p.24:

    0 ≤ y_i^s ⟂ −α^s + 2β y_i^s + β y_{−i}^s + ν_i + λ_i^s ≥ 0
    0 ≤ λ_i^s ⟂ x_i − y_i^s ≥ 0

The segments do not interact once `x` is fixed, so `M` is block diagonal with one 4×4
block per segment; it is assembled whole anyway, because the engine's `lcp_residual` and
the enumeration oracle both want the full system and `4S` is small.

Lemma 2, p.19: this has a unique solution for every `x`. The map is the open-loop Cournot
map with the capacity rows' `x_i` moved from a variable into `q`, which is why
`test/runtests.jl` can check this assembly against `ms_lcp` rather than trusting it.
"""
function ms_second_stage_lcp(d::MSData, x::AbstractVector)
    length(x) == 2 || throw(DimensionMismatch("x has length $(length(x)), expected 2"))
    ix = MSSecondStageIndex(d.S)
    n = length(ix)
    M = zeros(n, n)
    q = zeros(n)
    for i in (PLAYER_P, PLAYER_B), s in 1:d.S
        r = ix2_y(ix, i, s)
        q[r] = -d.alpha[s] + d.nu[i]
        M[r, ix2_y(ix, i, s)] = 2 * d.beta          # Cournot: the player sees its own effect
        M[r, ix2_y(ix, other(i), s)] = d.beta
        M[r, ix2_λ(ix, i, s)] = 1.0
        r = ix2_λ(ix, i, s)
        q[r] = x[i]
        M[r, ix2_y(ix, i, s)] = -1.0
    end
    return M, q, ix
end

"""
    ms_second_stage(data, x; backend = :path) -> MSPoint

Solve the short-run equilibrium at capacities `x` and return it in the same `MSPoint`
shape the open-loop models use, so that `segment_type`, `pricing_efficiency_gap` and the
rest apply to it unchanged. `pt.x` is the `x` that was passed in, not a solved quantity.

The residual is *not* checked here. Callers judge the point with `lcp_residual` on the
`(M, q)` this builds, which is the same contract as everywhere else in this programme
(`DECISIONS.md`, engine D-0002).
"""
function ms_second_stage(d::MSData, x::AbstractVector; backend::Symbol = :path)
    M, q, ix = ms_second_stage_lcp(d, x)
    w = solve_complementarity(M, q, backend).x
    y = [w[ix2_y(ix, i, s)] for i in 1:2, s in 1:d.S]
    λ = [w[ix2_λ(ix, i, s)] for i in 1:2, s in 1:d.S]
    demand = vec(sum(y; dims = 1))
    price = d.alpha .- d.beta .* demand
    return MSPoint(collect(Float64.(x)), y, λ, price, demand)
end

# --- the sensitivity of the second stage to capacity, Lemma 7 ----------------------------

"""
    segment_role(data, pt, s; tol) -> (type, distinguished)

The segment's regime type from partition (13), p.22, together with the player the paper's
statement of that case singles out as `i`:

  - `:c` — `i` is the player at capacity, the other is strictly interior
  - `:d`, `:e` — `i` is the idle player
  - `:a`, `:b` — symmetric in the two players, so `distinguished` is `0`

`segment_type` gives the type alone and is unchanged; this adds the role, which Lemma 7
needs because its `:c` and `:e` entries are not symmetric.
"""
function segment_role(d::MSData, pt::MSPoint, s::Int; tol = 1e-7)
    t = segment_type(d, pt, s; tol = tol)
    status(i) = pt.y[i, s] <= tol ? :idle :
                abs(pt.x[i] - pt.y[i, s]) <= tol ? :capacity : :interior
    if t === :c
        return t, status(PLAYER_P) === :capacity ? PLAYER_P : PLAYER_B
    elseif t === :d || t === :e
        return t, status(PLAYER_P) === :idle ? PLAYER_P : PLAYER_B
    elseif t === :a || t === :b
        return t, 0
    end
    return t, 0
end

"""
    second_stage_jacobian(data, pt, s; tol) -> Matrix{Float64}

`B[i, j] = ∂y_j^s/∂x_i` at the second-stage equilibrium, from Lemma 7 (14), p.22:

| regime | derivative |
|---|---|
| (a) both at capacity | `B_i y_i = 1`, `B_i y_{−i} = 0`, both `i` |
| (b) both interior | all zero |
| (c) `i` at capacity, `−i` interior | `B_i y_i = 1`, `B_i y_{−i} = −1/2`, `B_{−i} y_· = 0` |
| (d) `i` idle, `−i` interior | all zero |
| (e) `i` idle, `−i` at capacity | `B_{−i} y_{−i} = 1`, everything else zero |

Piecewise constant in `x`: the regime is the only thing it depends on. That is what makes
the closed-loop conditions evaluable in closed form rather than by differentiating a solver
(see the file header).

Throws on a regime outside the paper's five, since (14) says nothing about one and a
silently-zero derivative would be a wrong answer rather than a missing one.
"""
function second_stage_jacobian(d::MSData, pt::MSPoint, s::Int; tol = 1e-7)
    t, i = segment_role(d, pt, s; tol = tol)
    B = zeros(2, 2)
    if t === :a
        B[PLAYER_P, PLAYER_P] = 1.0
        B[PLAYER_B, PLAYER_B] = 1.0
    elseif t === :b || t === :d
        # every derivative is zero
    elseif t === :c
        o = other(i)
        B[i, i] = 1.0
        B[i, o] = -0.5
    elseif t === :e
        o = other(i)          # `i` is idle, `o` is at capacity
        B[o, o] = 1.0
    else
        throw(ArgumentError(
            "segment $s is regime $t, which is outside the paper's partition (13), p.22; " *
            "Lemma 7 gives no derivative for it"))
    end
    return B
end

# --- the closed-loop first-stage conditions, equation (16) --------------------------------

"""
    ms_closed_loop_conditions(data, pt; tol) -> Vector{Float64}

`ξ = (ξ_p, ξ_b)` from (16), p.24, evaluated at a second-stage equilibrium `pt`:

    ξ_i = K_i + Σ_s [−α^s + 2β y_i^s + β y_{−i}^s + ν_i] B_i y_i^s + Σ_s β y_i^s B_i y_{−i}^s

A closed-loop equilibrium at a point where the `y_i^s(x)` are differentiable satisfies
`0 ≤ x_i ⟂ ξ_i ≥ 0`. Two cautions the paper states and this function cannot enforce:
(16) holds only at differentiable points (p.24), and an equilibrium need not exist or be
unique (section 7). So a zero of this is a *candidate*, and the argument that it is the
equilibrium has to be made separately.

`pt` must be the second-stage solution at its own `pt.x`, which is what
[`ms_second_stage`](@ref) returns. Passing a point from somewhere else silently answers a
different question.
"""
function ms_closed_loop_conditions(d::MSData, pt::MSPoint; tol = 1e-7)
    ξ = zeros(2)
    for i in (PLAYER_P, PLAYER_B)
        acc = d.K[i]
        for s in 1:d.S
            B = second_stage_jacobian(d, pt, s; tol = tol)
            o = other(i)
            marginal = -d.alpha[s] + 2 * d.beta * pt.y[i, s] + d.beta * pt.y[o, s] + d.nu[i]
            acc += marginal * B[i, i] + d.beta * pt.y[i, s] * B[i, o]
        end
        ξ[i] = acc
    end
    return ξ
end

"""
    ms_closed_loop_residual(data, x; backend, tol) -> NamedTuple

How badly capacities `x` fail to be a closed-loop equilibrium: solve the second stage at
`x`, evaluate (16), and report the complementarity failure of `0 ≤ x_i ⟂ ξ_i ≥ 0` the same
way `lcp_residual` does for an LCP.

Returns `ξ`, the second-stage point, and

  - `primal`: violation of `x ≥ 0`
  - `dual`: violation of `ξ ≥ 0`
  - `complementarity`: the largest `|x_i ξ_i|`
  - `worst`: the maximum of the three
  - `second_stage`: the recomputed residual of the second-stage LCP at its own solution,
    which is what says the `y` and `λ` this was all built on are themselves a solution

The engine's `lcp_residual` answers the second-stage half and nothing else; this is the
first-stage oracle, and it is model-specific, which is why it lives here rather than in
the engine (`docs/BOUNDARY.md`).
"""
function ms_closed_loop_residual(d::MSData, x::AbstractVector;
                                 backend::Symbol = :path, tol = 1e-7)
    M, q, _ = ms_second_stage_lcp(d, x)
    sol = solve_complementarity(M, q, backend)
    inner = lcp_residual(M, q, sol.x).worst
    pt = ms_second_stage(d, x; backend = backend)
    ξ = ms_closed_loop_conditions(d, pt; tol = tol)
    xv = collect(Float64.(x))
    primal = maximum(max.(-xv, 0.0))
    dual = maximum(max.(-ξ, 0.0))
    comp = maximum(abs.(xv .* ξ))
    return (ξ = ξ, point = pt, primal = primal, dual = dual, complementarity = comp,
            worst = max(primal, dual, comp), second_stage = inner)
end

"""
    ms_closed_loop_conditions_decomposed(data, pt; tol) -> (xi, open_loop, manipulation)

The same `xi` as [`ms_closed_loop_conditions`](@ref), written a second way, as the open-loop
condition plus a correction. It exists to check the first transcription, in the way
`ms_conditions` checks `ms_lcp` (`DECISIONS.md` D-0005), and it is never used to compute.

The identity is worth stating, because it is the whole difference between the two models:

    xi_i = [K_i - sum_s lambda_i^s]  -  (beta/2) * sum_{s in C_i} y_i^s

where `C_i` is the set of segments of type (c) in which player `i` is the one at capacity.
The first bracket is exactly the open-loop investment condition, equation (6), p.16, so the
second term is the entire value of being able to move the short-run market by investing.

Why the rest collapses, **and when it does not**. In Lemma 7 (14) the diagonal `B_i y_i` is
`1` precisely when player `i` is at capacity in that segment and `0` otherwise. Where it is
`0` that player is idle or strictly interior, so its `lambda_i^s` is `0` and the term would
have vanished anyway — *provided the player has invested something*. A player with
`x_i = 0` produces `y_i^s = 0 = x_i`, so its capacity constraint binds and `lambda_i^s` can
be strictly positive while `B_i y_i` is `0`, and the identity fails. The returned `valid`
flag is that condition, and it is false at exactly the corner points where equation (16)
has spurious roots (`FINDINGS.md` F-0013). This was found by enumeration rather than by
inspection: the original statement of this docstring was checked only at points where both
players invest, and was wrong everywhere else. The bracket `[-alpha^s + 2*beta*y_i^s + beta*y_-i^s + nu_i]` is `omega_i^s -
lambda_i^s` by the second-stage condition, and `omega_i^s = 0` wherever `y_i^s > 0`. So the
diagonal part of (16) sums to `-sum_s lambda_i^s` in every regime. The off-diagonal
`B_i y_-i` is nonzero, equal to `-1/2`, in one regime only: type (c), and only for the
player at capacity.

Three of the paper's results read straight off this:

  * **Theorem 2, p.25.** With no type (c) segment the correction is empty, `xi` is the
    open-loop condition, and the two equilibria coincide.
  * **Corollary 3 (18), p.28.** With a type (c) segment the correction is strictly negative
    for the player at capacity there, so at a closed-loop equilibrium that player has
    `K_i > sum_s lambda_i^s` while the other keeps equality.
  * **Theorem 5, p.28.** A negative `xi_b` at the open-loop capacities says the base player
    would gain by investing more, which is the direction in which closed-loop base capacity
    exceeds open-loop base capacity.

Deliberately written without Unicode in the prose above: this docstring is the one place in
the file where the mathematics is restated rather than transcribed, and it has already been
corrupted once by a shell that treated its backticks as command substitution.
"""
function ms_closed_loop_conditions_decomposed(d::MSData, pt::MSPoint; tol = 1e-7)
    open_loop = [d.K[i] - sum(pt.λ[i, s] for s in 1:d.S) for i in 1:2]
    manipulation = zeros(2)
    for s in 1:d.S
        t, i = segment_role(d, pt, s; tol = tol)
        t === :c || continue
        manipulation[i] -= 0.5 * d.beta * pt.y[i, s]
    end
    # The identity needs every player's capacity constraint to be slack wherever it is not
    # at capacity, which fails when a player invests nothing.
    valid = all(pt.x .> tol)
    return (xi = open_loop .+ manipulation, open_loop = open_loop,
            manipulation = manipulation, valid = valid)
end

"""
    closed_loop_objective(data, i, x; backend) -> Float64

Player `i`'s long-run objective (15), p.24, at capacities `x`:

    K_i x_i + sum_s [-alpha^s + beta (y_i^s(x) + y_-i^s(x)) + nu_i] y_i^s(x)

The bracket is `nu_i - p^s`, so this is capacity cost minus gross margin: the player's
negative profit, which it minimises. The second stage is re-solved at `x`, which is what
makes this the *closed-loop* objective rather than the open-loop one.
"""
function closed_loop_objective(d::MSData, i::Int, x::AbstractVector; backend::Symbol = :path)
    pt = ms_second_stage(d, x; backend = backend)
    return d.K[i] * x[i] + sum((d.nu[i] - pt.price[s]) * pt.y[i, s] for s in 1:d.S)
end

"""
    best_response_gap(data, x; grid, backend) -> NamedTuple

How much either player could gain by unilaterally changing its capacity, found by scanning
rather than by differentiating.

For each player in turn, `closed_loop_objective` is evaluated on `grid` values of that
player's capacity with the other's held at `x`, and the best value found is compared with
the value at `x`. Returns `gap` (the largest improvement available to either player, zero
when neither can improve), `best` (each player's best capacity found) and `objective` (each
player's objective at `x`).

This is the test that equation (16) cannot perform. (16) is a first-order condition at a
differentiable point, and Lemma 13, p.31 says the objective is only piecewise convex, so a
point can satisfy (16) and still be a local minimum that is not global — the downward jump
in Figure 4, p.32. A scan is crude, and it can only refute an equilibrium or fail to refute
one; it cannot certify a global optimum between grid points. It is nevertheless decisive in
the direction that matters here, because a candidate it refutes is not an equilibrium.
"""
function best_response_gap(d::MSData, x::AbstractVector;
                           grid = range(0.0, stop = 3.0 * max(1.0, maximum(x)), length = 601),
                           backend::Symbol = :path)
    gap = 0.0
    best = zeros(2)
    obj = zeros(2)
    for i in 1:2
        here = closed_loop_objective(d, i, x; backend = backend)
        obj[i] = here
        bestval, bestx = here, Float64(x[i])
        for v in grid
            trial = collect(Float64.(x))
            trial[i] = Float64(v)
            val = closed_loop_objective(d, i, trial; backend = backend)
            if val < bestval - 1e-12
                bestval, bestx = val, Float64(v)
            end
        end
        best[i] = bestx
        gap = max(gap, here - bestval)
    end
    return (gap = gap, best = best, objective = obj)
end
