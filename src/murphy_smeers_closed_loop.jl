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


# --- the closed-loop core, spliced verbatim into upstream/ --------------------------------
#
# Everything between the markers takes plain numbers and depends on nothing else in this
# package: no `MSData`, no `MSPoint`, no constant, no import. That is what lets
# `scripts/emit_closed_loop_demo.jl` copy it into a self-contained file rather than
# reimplementing it there (DECISIONS.md D-0001). The `MSData` methods further down are
# wrappers over these and add nothing but unpacking.
#
# emit:closed_loop_core:begin

"""
    ms_second_stage_arrays(S, beta, alpha, K, nu, x) -> (M, q)

The short-run Cournot equilibrium at fixed capacities `x`, as the LCP
`0 <= w  perp  Mw + q >= 0` in `w = (y_p^1..S, y_b^1..S, lambda_p^1..S, lambda_b^1..S)`.
Equations (4) of Murphy and Smeers, restated on p.24 of the May 2002 working paper:

    0 <= y_i^s  perp  -alpha^s + 2 beta y_i^s + beta y_-i^s + nu_i + lambda_i^s >= 0
    0 <= lambda_i^s  perp  x_i - y_i^s >= 0

Player 1 is the peaking plant, player 2 the base-load plant. Segments do not interact once
`x` is fixed, so `M` is block diagonal with one 4x4 block per segment. Lemma 2, p.19: the
solution is unique for every `x`.

This is the open-loop Cournot model's own `y` and `lambda` rows with `x` moved out of the
variables and into `q`; the two models share their entire second stage.
"""
function ms_second_stage_arrays(S::Integer, beta::Real, alpha::AbstractVector,
                                K::AbstractVector, nu::AbstractVector, x::AbstractVector)
    length(alpha) == S || throw(DimensionMismatch("alpha has $(length(alpha)) entries but S = $S"))
    length(x) == 2 || throw(DimensionMismatch("x has length $(length(x)), expected 2"))
    iy(i, s) = (i - 1) * S + s
    il(i, s) = 2 * S + (i - 1) * S + s
    n = 4 * S
    M = zeros(n, n)
    q = zeros(n)
    for i in 1:2, s in 1:S
        r = iy(i, s)
        q[r] = -alpha[s] + nu[i]
        M[r, iy(i, s)] = 2 * beta                 # Cournot: the player sees its own effect
        M[r, iy(3 - i, s)] = beta
        M[r, il(i, s)] = 1.0
        r = il(i, s)
        q[r] = x[i]
        M[r, iy(i, s)] = -1.0
    end
    return M, q
end

"""
    ms_regime(S, x, y; tol) -> (types, roles)

Each segment's regime in the paper's five-way partition (13), p.22, and the player that
statement of the case singles out as `i`.

  - `:a` both at capacity, `:b` both strictly interior — symmetric, role `0`
  - `:c` one at capacity and one interior — role is the player at capacity
  - `:d` one idle and one interior, `:e` one idle and one at capacity — role is the idle one

Returns `:other` for a pattern outside the five, such as both players idle, for which
Lemma 7 gives no derivative.
"""
function ms_regime(S::Integer, x::AbstractVector, y::AbstractMatrix; tol = 1e-7)
    types = Vector{Symbol}(undef, S)
    roles = Vector{Int}(undef, S)
    for s in 1:S
        st = map(1:2) do i
            y[i, s] <= tol ? :idle : (abs(x[i] - y[i, s]) <= tol ? :capacity : :interior)
        end
        p, b = st[1], st[2]
        if (p, b) == (:capacity, :capacity)
            types[s], roles[s] = :a, 0
        elseif (p, b) == (:interior, :interior)
            types[s], roles[s] = :b, 0
        elseif p === :capacity && b === :interior
            types[s], roles[s] = :c, 1
        elseif b === :capacity && p === :interior
            types[s], roles[s] = :c, 2
        elseif p === :idle && b === :interior
            types[s], roles[s] = :d, 1
        elseif b === :idle && p === :interior
            types[s], roles[s] = :d, 2
        elseif p === :idle && b === :capacity
            types[s], roles[s] = :e, 1
        elseif b === :idle && p === :capacity
            types[s], roles[s] = :e, 2
        else
            types[s], roles[s] = :other, 0
        end
    end
    return types, roles
end

"""
    ms_regime_jacobian(t, i) -> Matrix

`B[i, j] = d y_j / d x_i` at the second-stage equilibrium, from Lemma 7 (14), p.22. It is
piecewise constant: the regime is the only thing it depends on.

| regime | derivative |
|---|---|
| (a) both at capacity | `B_i y_i = 1`, `B_i y_-i = 0`, both `i` |
| (b) both interior | all zero |
| (c) `i` at capacity, `-i` interior | `B_i y_i = 1`, `B_i y_-i = -1/2`, `B_-i y_. = 0` |
| (d) `i` idle, `-i` interior | all zero |
| (e) `i` idle, `-i` at capacity | `B_-i y_-i = 1`, everything else zero |

This closed form is what makes the closed-loop conditions evaluable exactly. No automatic
differentiation and no numerical derivative appears anywhere in the model.
"""
function ms_regime_jacobian(t::Symbol, i::Int)
    B = zeros(2, 2)
    if t === :a
        B[1, 1] = 1.0
        B[2, 2] = 1.0
    elseif t === :c
        B[i, i] = 1.0
        B[i, 3 - i] = -0.5
    elseif t === :e
        B[3 - i, 3 - i] = 1.0
    elseif t === :b || t === :d
        # identically zero
    else
        throw(ArgumentError("regime $t is outside partition (13), p.22; Lemma 7 gives " *
                            "no derivative for it"))
    end
    return B
end

"""
    ms_closed_loop_xi(S, beta, alpha, K, nu, y, types, roles) -> Vector

`xi = (xi_p, xi_b)` from equation (16), p.24, at a second-stage equilibrium `y`:

    xi_i = K_i + sum_s [-alpha^s + 2 beta y_i^s + beta y_-i^s + nu_i] B_i y_i^s
                + sum_s beta y_i^s B_i y_-i^s

A closed-loop equilibrium at a point where the second-stage solution is differentiable
satisfies `0 <= x_i  perp  xi_i >= 0`.

**This is a first-order condition and not a characterisation of equilibrium.** It is stated
only where the second-stage solution is differentiable (p.24), and here it is evaluated under
whatever regimes `types` and `roles` name. At a kink the regime is ambiguous, and the choice
decides which one-sided derivative comes out. On both instances used in this programme it
has three roots and only one is an equilibrium. The other two are corners where a player
holds nothing, so each of its capacity pairs is biactive, idle and at capacity at once. Read
as idle, every derivative term is zero and `xi_i = K_i > 0`, a root. Read as at capacity,
the same pairs give the true right derivative, which is negative: the first unit of capacity
pays. Separately, the long-run objective is only piecewise convex (Lemma 13, p.31), so even
a genuine stationary point need not be a global best response.
"""
function ms_closed_loop_xi(S::Integer, beta::Real, alpha::AbstractVector,
                           K::AbstractVector, nu::AbstractVector, y::AbstractMatrix,
                           types::AbstractVector, roles::AbstractVector)
    xi = zeros(2)
    for i in 1:2
        o = 3 - i
        acc = K[i]
        for s in 1:S
            B = ms_regime_jacobian(types[s], roles[s])
            marginal = -alpha[s] + 2 * beta * y[i, s] + beta * y[o, s] + nu[i]
            acc += marginal * B[i, i] + beta * y[i, s] * B[i, o]
        end
        xi[i] = acc
    end
    return xi
end

"""
    ms_long_run_objective(S, beta, alpha, K, nu, i, x_i, y) -> Float64

Player `i`'s long-run objective (15), p.24, at capacity `x_i` and second-stage outputs `y`:

    K_i x_i + sum_s [-alpha^s + beta (y_p^s + y_b^s) + nu_i] y_i^s

The bracket is `nu_i - p^s`, so this is capacity cost minus gross margin: the negative
profit that the player minimises.
"""
function ms_long_run_objective(S::Integer, beta::Real, alpha::AbstractVector,
                               K::AbstractVector, nu::AbstractVector, i::Int,
                               x_i::Real, y::AbstractMatrix)
    v = K[i] * x_i
    for s in 1:S
        v += (-alpha[s] + beta * (y[1, s] + y[2, s]) + nu[i]) * y[i, s]
    end
    return v
end

# emit:closed_loop_core:end

# --- the same things, as methods over this repository's own types --------------------------

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

[`ms_second_stage_arrays`](@ref) over an `MSData`, returning the index helper alongside.
"""
function ms_second_stage_lcp(d::MSData, x::AbstractVector)
    M, q = ms_second_stage_arrays(d.S, d.beta, d.alpha, d.K, d.nu, x)
    return M, q, MSSecondStageIndex(d.S)
end

"""
    ms_second_stage(data, x; backend = :path) -> MSPoint

Solve the short-run equilibrium at capacities `x` and return it in the `MSPoint` shape the
open-loop models use, so `segment_type` and the property checks apply unchanged. `pt.x` is
the `x` that was passed in, not a solved quantity.

The residual is not checked here; callers judge the point with `lcp_residual` on the
`(M, q)` this builds, as everywhere else in this programme (engine `DECISIONS.md` D-0002).
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

"""
    segment_role(data, pt, s; tol) -> (type, distinguished)

[`ms_regime`](@ref) for one segment. `segment_type` gives the type alone and is unchanged;
this adds the role, which Lemma 7 needs because its `:c` and `:e` entries are not symmetric.
"""
function segment_role(d::MSData, pt::MSPoint, s::Int; tol = 1e-7)
    types, roles = ms_regime(d.S, pt.x, pt.y; tol = tol)
    return types[s], roles[s]
end

"""
    second_stage_jacobian(data, pt, s; tol) -> Matrix{Float64}

[`ms_regime_jacobian`](@ref) at the regime of segment `s`. Throws on a regime outside the
paper's five, since a silently-zero derivative would be a wrong answer rather than a
missing one.
"""
function second_stage_jacobian(d::MSData, pt::MSPoint, s::Int; tol = 1e-7)
    t, i = segment_role(d, pt, s; tol = tol)
    return ms_regime_jacobian(t, i)
end

"""
    ms_closed_loop_conditions(data, pt; tol) -> Vector{Float64}

[`ms_closed_loop_xi`](@ref) at a second-stage equilibrium `pt`, which must be the solution
at its own `pt.x` — what [`ms_second_stage`](@ref) returns. Passing a point from elsewhere
silently answers a different question.

Two cautions the paper states and this cannot enforce: (16) holds only at differentiable
points (p.24), and an equilibrium need not exist or be unique (section 7). A zero of this
is a *candidate*; `best_response_gap` is what decides (`FINDINGS.md` F-0013).
"""
function ms_closed_loop_conditions(d::MSData, pt::MSPoint; tol = 1e-7)
    types, roles = ms_regime(d.S, pt.x, pt.y; tol = tol)
    return ms_closed_loop_xi(d.S, d.beta, d.alpha, d.K, d.nu, pt.y, types, roles)
end

"""
    ms_closed_loop_residual(data, x; backend, tol) -> NamedTuple

How badly capacities `x` fail to satisfy the closed-loop first-order conditions: solve the
second stage at `x`, evaluate (16), and report the complementarity failure of
`0 ≤ x_i ⟂ ξ_i ≥ 0` the way `lcp_residual` does for an LCP.

Returns `ξ`, the second-stage `point`, `primal`, `dual`, `complementarity`, `worst`, and
`second_stage` — the recomputed residual of the second-stage LCP at its own solution, which
is what says the `y` and `λ` this rests on are themselves a solution.

A `worst` of zero does **not** mean `x` is an equilibrium. See F-0013.
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
    return ms_long_run_objective(d.S, d.beta, d.alpha, d.K, d.nu, i, x[i], pt.y)
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

This is the test that equation (16) cannot perform. (16) is a first-order condition, stated
only at differentiable points, and evaluated at a kink it can hold where the objective is not
even locally minimal — the corner roots of F-0013 are such points (F-0018). Away from kinks,
Lemma 13, p.31 says the objective is only piecewise convex, so a genuine local minimum need
not be global either — the downward jump in Figure 4, p.32. A scan is crude, and it can only refute an equilibrium or fail to refute
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
