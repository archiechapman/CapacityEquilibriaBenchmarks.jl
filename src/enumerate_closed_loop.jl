# A solver-free oracle for the closed-loop Cournot equilibrium.
#
# `enumerate_lcp.jl` finds every solution of a small LCP by trying all complementarity
# patterns. The closed-loop first stage is not an LCP, so that oracle does not apply to it
# directly — but the reason it does not apply is also the reason a variant of it does.
#
# Fix a complementarity pattern of the *second-stage* LCP. Within that pattern:
#
#   * the second-stage solution `(y, λ)` is an affine function of the capacities `x`,
#     because the pattern turns the LCP into a square linear system whose only
#     `x`-dependence is the capacity rows' right-hand side;
#   * the regime of every segment is fixed, so Lemma 7's derivative table is fixed;
#   * therefore `ξ(x)` from equation (16) is affine in `x` as well.
#
# So each second-stage pattern induces a two-variable LCP `0 ≤ x ⟂ ξ(x) ≥ 0`, which has
# four complementarity patterns of its own. Enumerating both layers gives every candidate
# closed-loop equilibrium at which the `y_i^s(x)` are differentiable, without a solver
# anywhere in the search.
#
# The search proposes; it does not decide. Every candidate is then put back through the
# real second-stage solve and required to reproduce the pattern it was derived under. A
# pattern that is not self-consistent at its own solution is discarded, which is what stops
# this from being an elaborate way of solving the wrong linear system.
#
# WHAT IT DOES AND DOES NOT SETTLE. It finds every equilibrium at a differentiable point.
# Equation (16) is stated only at such points (p.24), and the paper's section 7 shows the
# objective is merely piecewise convex (Lemma 13, p.31) with a marginal cost that can jump
# downwards (Figure 4, p.32). An equilibrium sitting exactly on a kink between regimes
# would not be found here, and this oracle cannot rule one out. `DECISIONS.md` D-0006 is
# why nothing here says "the" equilibrium.
#
# Cost is `2^(4S)` patterns, each a linear solve of size at most `4S`: 4096 for `S = 3` and
# 65536 for `S = 4`. Both are seconds, and both are hopeless by `S = 6`, which is the same
# wall `enumerate_lcp.jl` hits and for the same reason.

using LinearAlgebra: I as _I

"""
    closed_loop_affine(data, basis) -> Union{Nothing, NamedTuple}

The second-stage solution and the first-stage condition as affine functions of `x`, under
the assumption that `basis` is the set of second-stage variables allowed to be nonzero.

Returns `nothing` when the pattern is unusable: a singular basis matrix, or a segment whose
regime falls outside the paper's partition (13) so that Lemma 7 gives no derivative for it.
Otherwise returns

  - `y0`, `Y`: `y(x) = y0 + Y * x`, with `y0` a `2 × S` matrix and `Y` a `2 × S × 2` array
  - `xi0`, `Xi`: `ξ(x) = xi0 + Xi * x`
  - `types`: the regime of each segment under this pattern

The affine forms are built by evaluating the pattern's linear system at `x = 0`, `x = e_p`
and `x = e_b`, which is exact for an affine map and avoids a second hand-derivation of the
per-regime algebra.
"""
function closed_loop_affine(d::MSData, basis::Vector{Int})
    ix = MSSecondStageIndex(d.S)
    n = length(ix)
    M, q0, _ = ms_second_stage_lcp(d, [0.0, 0.0])

    # z(x) restricted to the basis solves M[B,B] z_B = -(q0_B + D_B x).
    isempty(basis) || rank(M[basis, basis]; atol = 1e-10) == length(basis) || return nothing

    function solve_at(x)
        z = zeros(n)
        if !isempty(basis)
            _, q, _ = ms_second_stage_lcp(d, x)
            z[basis] = M[basis, basis] \ (-q[basis])
        end
        return z
    end

    z0 = solve_at([0.0, 0.0])
    zp = solve_at([1.0, 0.0])
    zb = solve_at([0.0, 1.0])

    unpack(z) = [z[ix2_y(ix, i, s)] for i in 1:2, s in 1:d.S],
                [z[ix2_λ(ix, i, s)] for i in 1:2, s in 1:d.S]
    y0, λ0 = unpack(z0)
    yp, λp = unpack(zp)
    yb, λb = unpack(zb)
    Y = cat(yp .- y0, yb .- y0; dims = 3)          # Y[i, s, k] = ∂y_i^s/∂x_k
    Λ = cat(λp .- λ0, λb .- λ0; dims = 3)

    # The regime of each segment is fixed by the pattern, not by the numbers: a player is
    # at capacity when its λ is free, idle when its y is not, interior otherwise.
    types = Vector{Symbol}(undef, d.S)
    roles = Vector{Int}(undef, d.S)
    for s in 1:d.S
        status = map(1:2) do i
            ix2_y(ix, i, s) in basis || return :idle
            ix2_λ(ix, i, s) in basis ? :capacity : :interior
        end
        t, who = _regime_from_status(status)
        t === :other && return nothing
        types[s], roles[s] = t, who
    end

    # ξ(x) = K + Σ_s [(-α^s + 2β y_i + β y_-i + ν_i) B[i,i] + β y_i B[i,o]], affine in x.
    xi0 = zeros(2)
    Xi = zeros(2, 2)
    for i in 1:2
        xi0[i] = d.K[i]
        o = other(i)
        for s in 1:d.S
            B = _jacobian_from_regime(types[s], roles[s])
            xi0[i] += (-d.alpha[s] + 2 * d.beta * y0[i, s] + d.beta * y0[o, s] + d.nu[i]) * B[i, i]
            xi0[i] += d.beta * y0[i, s] * B[i, o]
            for k in 1:2
                Xi[i, k] += (2 * d.beta * Y[i, s, k] + d.beta * Y[o, s, k]) * B[i, i]
                Xi[i, k] += d.beta * Y[i, s, k] * B[i, o]
            end
        end
    end
    return (y0 = y0, Y = Y, lambda0 = λ0, Lambda = Λ, xi0 = xi0, Xi = Xi,
            types = types, roles = roles)
end

"""Regime and distinguished player from the two players' statuses, partition (13), p.22."""
function _regime_from_status(status)
    p, b = status[PLAYER_P], status[PLAYER_B]
    (p, b) == (:capacity, :capacity) && return :a, 0
    (p, b) == (:interior, :interior) && return :b, 0
    p === :capacity && b === :interior && return :c, PLAYER_P
    b === :capacity && p === :interior && return :c, PLAYER_B
    p === :idle && b === :interior && return :d, PLAYER_P
    b === :idle && p === :interior && return :d, PLAYER_B
    p === :idle && b === :capacity && return :e, PLAYER_P
    b === :idle && p === :capacity && return :e, PLAYER_B
    return :other, 0
end

"""Lemma 7 (14), p.22, from a regime and its distinguished player rather than from a point."""
function _jacobian_from_regime(t::Symbol, i::Int)
    B = zeros(2, 2)
    if t === :a
        B[PLAYER_P, PLAYER_P] = 1.0
        B[PLAYER_B, PLAYER_B] = 1.0
    elseif t === :c
        B[i, i] = 1.0
        B[i, other(i)] = -0.5
    elseif t === :e
        B[other(i), other(i)] = 1.0
    end        # types :b and :d are identically zero
    return B
end

"""
    enumerate_closed_loop(data; tol, feas_tol, backend) -> NamedTuple

Every capacity vector satisfying the closed-loop conditions (16) at a point where the
second-stage solution is differentiable, found by enumerating second-stage complementarity
patterns and, within each, the four patterns of the induced two-variable problem.

Each candidate is verified independently of the pattern it came from: the second stage is
re-solved at it with `backend`, the recomputed LCP residual must be small, the regimes must
be the ones assumed, and `ms_closed_loop_conditions` must give a `ξ` that is complementary
to `x`. Only candidates surviving all of that are returned.

Returns `solutions` (deduplicated), `types` (the regime of each, aligned with `solutions`),
`singular` (patterns whose basis was rank deficient) and `unclassified` (patterns implying
a regime outside the paper's five).
"""
function enumerate_closed_loop(d::MSData; tol = 1e-7, feas_tol = 1e-7,
                               backend::Symbol = :path)
    n = 4 * d.S
    n <= 20 || throw(ArgumentError("n = $n is too large to enumerate 2^n patterns"))
    solutions = Vector{Vector{Float64}}()
    regimes = Vector{Vector{Symbol}}()
    singular = 0
    unclassified = 0

    for mask in 0:(2^n - 1)
        basis = [i for i in 1:n if (mask >> (i - 1)) & 1 == 1]
        aff = closed_loop_affine(d, basis)
        if aff === nothing
            # A rank-deficient basis and an unclassifiable regime are different refusals;
            # separating them keeps the counts honest about which happened.
            isempty(basis) || rank((ms_second_stage_lcp(d, [0.0, 0.0])[1])[basis, basis];
                                   atol = 1e-10) == length(basis) ?
                (unclassified += 1) : (singular += 1)
            continue
        end
        for xmask in 0:3
            free = [i for i in 1:2 if (xmask >> (i - 1)) & 1 == 1]
            x = zeros(2)
            if !isempty(free)
                A = aff.Xi[free, free]
                rank(A; atol = 1e-10) == length(free) || continue
                x[free] = A \ (-aff.xi0[free])
            end
            any(x .< -feas_tol) && continue
            ξ_lin = aff.xi0 .+ aff.Xi * x
            any(ξ_lin .< -feas_tol) && continue
            maximum(abs.(x .* ξ_lin)) > feas_tol && continue
            _verified(d, x, aff.types; tol = tol, feas_tol = feas_tol, backend = backend) || continue
            any(norm(x - s, Inf) <= feas_tol for s in solutions) && continue
            push!(solutions, x)
            push!(regimes, copy(aff.types))
        end
    end
    return (solutions = solutions, types = regimes, singular = singular,
            unclassified = unclassified)
end

"""Re-solve the second stage at `x` and require it to reproduce the assumed regimes."""
function _verified(d::MSData, x, types; tol, feas_tol, backend)
    M, q, _ = ms_second_stage_lcp(d, x)
    sol = solve_complementarity(M, q, backend)
    lcp_residual(M, q, sol.x).worst <= feas_tol || return false
    pt = ms_second_stage(d, x; backend = backend)
    [segment_type(d, pt, s; tol = tol) for s in 1:d.S] == types || return false
    ξ = ms_closed_loop_conditions(d, pt; tol = tol)
    all(ξ .>= -feas_tol) || return false
    maximum(abs.(collect(Float64.(x)) .* ξ)) <= feas_tol || return false
    return true
end
