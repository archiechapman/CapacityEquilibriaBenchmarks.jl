# A hard MPCC: two optima a fifth of the domain apart, tied to fourteen significant figures.
#
# GENERATED FILE — DO NOT EDIT. Produced by `scripts/emit_hard_case.jl` in
# CapacityEquilibriaBenchmarks.jl, which splices the model verbatim from the sources that
# repository tests and inlines the data from its `data/` directory.
#
# THE PROBLEM. A firm chooses a capacity, then competes on output against a rival across
# several demand blocks. Given both capacities, the output stage is a linear complementarity
# problem with a unique solution. The firm's own problem — minimise its capacity cost less
# its gross margin, subject to that output-stage equilibrium — is an MPCC with a nonconvex
# objective: piecewise quadratic in its own capacity, with a well for each pattern of which
# plants run in which blocks.
#
# WHY IT IS HARD. At the rival capacity named `tie` below, two of those wells are exactly
# level: the capacities differ by around 20% of the domain and the objectives agree to
# fourteen significant figures. Perturb the rival's capacity by a thousandth and one well
# becomes strictly better; perturb it the other way and the *other* one does. So the answer
# flips discontinuously across a knife-edge, while the margin deciding it stays around 1e-4
# in relative terms.
#
# A method that keeps the well it started in returns the right answer on one side of the tie
# and the wrong answer on the other, with a converged status and a clean residual either way.
# Each problem below is posed from a start inside the *wrong* well, which is the honest way
# to ask whether a method can leave one.
#
# WHAT IS ASSERTED, AND WHAT IS NOT. The ground truth is asserted: both wells' objectives,
# the margin between them, and that whatever the solver returns is one of the two. Whether
# CCOpt finds the better one is *reported*, not asserted: on the runs behind this file it
# found the better well in 16 of 32, and the two methods failed on different problems with
# neither dominating. Freezing that as an expected value would turn a finding into a
# regression baseline, and the number depends on the starting point anyway.
#
# The right answers come from enumerating the objective's pieces and minimising each in
# closed form, and from PATH, independently of the solver under test. They are inlined
# rather than recomputed here, deliberately: these wells sit on regime boundaries, and there
# CCOpt's output stage lands about 2e-4 from PATH's, against about 1e-8 at an interior
# point. Establishing the answer with the solver being tested would be circular even where
# it is accurate, and here it is not accurate enough to resolve a margin of 4e-3. Derivations and provenance:
# https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl
#
# The model is the closed-loop Cournot game of Murphy, F. H. and Smeers, Y., "Generation
# Capacity Expansion in Imperfectly Competitive Restructured Electricity Markets",
# Operations Research 53(4), 646-661 (2005), section 6. The paper publishes no numerical
# example, so the parameters here are constructed to satisfy its assumptions and no number
# in this file should be attributed to its authors.
module HardCaseNearTie

using Test
import LinearAlgebra
import SparseArrays
import NLPModels
import MPCCModels
import CCOpt
import MadNLP

# ---------------------------------------------------------------------------------------
# 1. The output stage as an NLP in vertical form, and the residual oracle. Copied verbatim
#    from CapacityEquilibria.jl, `src/lcp_nlp.jl` and `src/pairing.jl`.
# ---------------------------------------------------------------------------------------

"""
    LCPVerticalModel(M, q) <: NLPModels.AbstractNLPModel

The LCP `0 ≤ x ⟂ Mx + q ≥ 0` as a feasibility NLP in `z = (x, w)`, `w − Mx = q`, `x, w ≥ 0`,
with a zero objective. The complementarity between `x[i]` and `w[i]` is *not* part of this
model; it is declared on top of it by `MPCCModels.MPCCModel(nlp, 1:n, n+1:2n)`.
"""
struct LCPVerticalModel{T, VT <: AbstractVector{T}} <: NLPModels.AbstractNLPModel{T, VT}
    n::Int
    A::SparseArrays.SparseMatrixCSC{T, Int}   # [−M  I], the constant Jacobian
    meta::NLPModels.NLPModelMeta{T, VT}
    counters::NLPModels.Counters
end

function LCPVerticalModel(M::AbstractMatrix{T}, q::AbstractVector{T}) where {T}
    n = length(q)
    size(M) == (n, n) || throw(DimensionMismatch(
        "M is $(size(M)) but q has length $n; the LCP must be square"))
    A = SparseArrays.sparse([-Matrix{T}(M)  Matrix{T}(LinearAlgebra.I, n, n)])
    meta = NLPModels.NLPModelMeta{T, Vector{T}}(
        2n;
        x0 = zeros(T, 2n),
        lvar = zeros(T, 2n),
        uvar = fill(T(Inf), 2n),
        ncon = n,
        y0 = zeros(T, n),
        lcon = Vector{T}(q),
        ucon = Vector{T}(q),
        nnzj = SparseArrays.nnz(A),
        lin_nnzj = SparseArrays.nnz(A),
        nln_nnzj = 0,
        nnzh = 0,
        lin = collect(1:n),
        islp = true,
        minimize = true,
        name = "LCP, vertical form, n = $n",
    )
    return LCPVerticalModel{T, Vector{T}}(n, A, meta, NLPModels.Counters())
end

# --- objective: identically zero ------------------------------------------------------------

NLPModels.obj(::LCPVerticalModel{T}, ::AbstractVector) where {T} = zero(T)

function NLPModels.grad!(::LCPVerticalModel, ::AbstractVector, gx::AbstractVector)
    fill!(gx, 0)
    return gx
end

function NLPModels.objgrad!(nlp::LCPVerticalModel, x::AbstractVector, gx::AbstractVector)
    return NLPModels.obj(nlp, x), NLPModels.grad!(nlp, x, gx)
end

# --- constraints: c(z) = Az = w − Mx, all linear -------------------------------------------

NLPModels.cons!(nlp::LCPVerticalModel, z::AbstractVector, cz::AbstractVector) =
    LinearAlgebra.mul!(cz, nlp.A, z)
NLPModels.cons_lin!(nlp::LCPVerticalModel, z::AbstractVector, cz::AbstractVector) =
    LinearAlgebra.mul!(cz, nlp.A, z)
NLPModels.cons_nln!(::LCPVerticalModel, ::AbstractVector, cz::AbstractVector) = cz

function _lcp_jac_structure!(A::SparseArrays.SparseMatrixCSC, rows, cols)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        rows[k] = A.rowval[p]
        cols[k] = col
        k += 1
    end
    return rows, cols
end

function _lcp_jac_coord!(A::SparseArrays.SparseMatrixCSC, vals)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        vals[k] = A.nzval[p]
        k += 1
    end
    return vals
end

NLPModels.jac_structure!(nlp::LCPVerticalModel, rows::AbstractVector{<:Integer},
                         cols::AbstractVector{<:Integer}) =
    _lcp_jac_structure!(nlp.A, rows, cols)
NLPModels.jac_lin_structure!(nlp::LCPVerticalModel, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) =
    _lcp_jac_structure!(nlp.A, rows, cols)
NLPModels.jac_nln_structure!(::LCPVerticalModel, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) = (rows, cols)

NLPModels.jac_coord!(nlp::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) =
    _lcp_jac_coord!(nlp.A, vals)
NLPModels.jac_lin_coord!(nlp::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) =
    _lcp_jac_coord!(nlp.A, vals)
NLPModels.jac_nln_coord!(::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) = vals

NLPModels.jprod!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, nlp.A, v)
NLPModels.jprod_lin!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, nlp.A, v)
NLPModels.jprod_nln!(::LCPVerticalModel, ::AbstractVector, ::AbstractVector, Jv::AbstractVector) = Jv

NLPModels.jtprod!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(nlp.A), v)
NLPModels.jtprod_lin!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(nlp.A), v)
NLPModels.jtprod_nln!(::LCPVerticalModel, ::AbstractVector, ::AbstractVector, Jtv::AbstractVector) = Jtv

# --- Hessian of the Lagrangian: empty, everything is linear ---------------------------------

NLPModels.hess_structure!(::LCPVerticalModel, rows::AbstractVector{<:Integer},
                          cols::AbstractVector{<:Integer}) = (rows, cols)

NLPModels.hess_coord!(::LCPVerticalModel{T}, ::AbstractVector{T}, ::AbstractVector{T},
                      vals::AbstractVector{T}; obj_weight::Real = one(T)) where {T} = vals

function NLPModels.hprod!(::LCPVerticalModel{T}, ::AbstractVector{T}, ::AbstractVector{T},
                          ::AbstractVector{T}, Hv::AbstractVector;
                          obj_weight::Real = one(T)) where {T}
    fill!(Hv, 0)
    return Hv
end

"""
    lcp_residual(M, q, x) -> NamedTuple

Recompute how badly `x` fails to solve the LCP, from `x` alone. Returns the three ways it
can fail and the worst of them:

  - `primal`: violation of `x ≥ 0`
  - `dual`: violation of `F(x) ≥ 0`
  - `complementarity`: the largest `|xᵢ Fᵢ(x)|`
  - `worst`: the maximum of the three, which is the number to threshold on

Nothing here consults a solver, a status code, or a model object. That is the entire point:
this is the independent oracle a returned point is checked against, and a function that
asked the solver how it went would not be one (`QUALITY.md`, the `validated` tier).
"""
function lcp_residual(M::AbstractMatrix, q::AbstractVector, x::AbstractVector)
    F = M * x .+ q
    primal = maximum(max.(-x, 0.0))
    dual = maximum(max.(-F, 0.0))
    comp = maximum(abs.(x .* F))
    return (primal = primal, dual = dual, complementarity = comp,
            worst = max(primal, dual, comp))
end

# ---------------------------------------------------------------------------------------
# 2. The model. Copied verbatim from CapacityEquilibriaBenchmarks.jl,
#    `src/murphy_smeers_closed_loop.jl`.
# ---------------------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------------------
# 3. One firm's problem as an MPCC. Copied verbatim from
#    CapacityEquilibriaBenchmarks.jl, `src/best_response_mpcc.jl`.
# ---------------------------------------------------------------------------------------


"""
    BestResponseNLP(S, beta, alpha, K, nu, i, x_other; x0)

Player `i`'s long-run problem as an `NLPModels.AbstractNLPModel` in

    z = (x_i, y_p^1..S, y_b^1..S, lambda_p^1..S, lambda_b^1..S,
         omega_p^1..S, omega_b^1..S, u_p^1..S, u_b^1..S)

of length `1 + 8S`, with `4S` linear equality constraints and every variable nonnegative.
Player 1 is the peaking plant, 2 the base-load plant. `x_other` is data, not a variable:
this is one player's problem, not the game.
"""
struct BestResponseNLP{T} <: NLPModels.AbstractNLPModel{T, Vector{T}}
    S::Int
    i::Int
    beta::T
    alpha::Vector{T}
    K::Vector{T}
    nu::Vector{T}
    x_other::T
    A::SparseArrays.SparseMatrixCSC{T, Int}
    meta::NLPModels.NLPModelMeta{T, Vector{T}}
    counters::NLPModels.Counters
end

br_y(m::BestResponseNLP, j, s) = 1 + (j - 1) * m.S + s
br_λ(m::BestResponseNLP, j, s) = 1 + 2 * m.S + (j - 1) * m.S + s
br_ω(m::BestResponseNLP, j, s) = 1 + 4 * m.S + (j - 1) * m.S + s
br_u(m::BestResponseNLP, j, s) = 1 + 6 * m.S + (j - 1) * m.S + s

function BestResponseNLP(S::Integer, beta::Real, alpha::AbstractVector, K::AbstractVector,
                         nu::AbstractVector, i::Int, x_other::Real; x0 = nothing)
    T = Float64
    n = 1 + 8 * S
    ncon = 4 * S
    A = zeros(T, ncon, n)
    b = zeros(T, ncon)
    yidx(j, s) = 1 + (j - 1) * S + s
    λidx(j, s) = 1 + 2 * S + (j - 1) * S + s
    ωidx(j, s) = 1 + 4 * S + (j - 1) * S + s
    uidx(j, s) = 1 + 6 * S + (j - 1) * S + s

    for j in 1:2, s in 1:S
        # omega_j^s - 2 beta y_j^s - beta y_-j^s - lambda_j^s = nu_j - alpha^s
        r = (j - 1) * S + s
        A[r, ωidx(j, s)] = 1.0
        A[r, yidx(j, s)] = -2 * beta
        A[r, yidx(3 - j, s)] = -beta
        A[r, λidx(j, s)] = -1.0
        b[r] = nu[j] - alpha[s]
        # u_j^s + y_j^s - x_j = 0; x_j is a variable only for player i
        r = 2 * S + (j - 1) * S + s
        A[r, uidx(j, s)] = 1.0
        A[r, yidx(j, s)] = 1.0
        if j == i
            A[r, 1] = -1.0
        else
            b[r] = Float64(x_other)
        end
    end
    Asp = SparseArrays.sparse(A)
    start = x0 === nothing ? zeros(T, n) : collect(T, x0)
    meta = NLPModels.NLPModelMeta{T, Vector{T}}(
        n; x0 = start, lvar = zeros(T, n), uvar = fill(T(Inf), n),
        ncon = ncon, y0 = zeros(T, ncon), lcon = b, ucon = b,
        nnzj = SparseArrays.nnz(Asp), lin_nnzj = SparseArrays.nnz(Asp), nln_nnzj = 0,
        nnzh = 2 * S, lin = collect(1:ncon), minimize = true,
        name = "Murphy-Smeers best response, player $i, S = $S")
    return BestResponseNLP{T}(Int(S), i, T(beta), collect(T, alpha), collect(T, K),
                              collect(T, nu), T(x_other), Asp, meta, NLPModels.Counters())
end

function NLPModels.obj(m::BestResponseNLP{T}, z::AbstractVector) where {T}
    i, o = m.i, 3 - m.i
    v = m.K[i] * z[1]
    for s in 1:m.S
        yi, yo = z[br_y(m, i, s)], z[br_y(m, o, s)]
        v += (m.nu[i] - m.alpha[s] + m.beta * (yi + yo)) * yi
    end
    return v
end

function NLPModels.grad!(m::BestResponseNLP{T}, z::AbstractVector, g::AbstractVector) where {T}
    fill!(g, zero(T))
    i, o = m.i, 3 - m.i
    g[1] = m.K[i]
    for s in 1:m.S
        yi, yo = z[br_y(m, i, s)], z[br_y(m, o, s)]
        g[br_y(m, i, s)] = m.nu[i] - m.alpha[s] + 2 * m.beta * yi + m.beta * yo
        g[br_y(m, o, s)] = m.beta * yi
    end
    return g
end

NLPModels.objgrad!(m::BestResponseNLP, z::AbstractVector, g::AbstractVector) =
    (NLPModels.obj(m, z), NLPModels.grad!(m, z, g))

NLPModels.cons!(m::BestResponseNLP, z::AbstractVector, c::AbstractVector) =
    LinearAlgebra.mul!(c, m.A, z)
NLPModels.cons_lin!(m::BestResponseNLP, z::AbstractVector, c::AbstractVector) =
    LinearAlgebra.mul!(c, m.A, z)
NLPModels.cons_nln!(::BestResponseNLP, ::AbstractVector, c::AbstractVector) = c

function _br_jac_structure!(A, rows, cols)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        rows[k] = A.rowval[p]; cols[k] = col; k += 1
    end
    return rows, cols
end

function _br_jac_coord!(A, vals)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        vals[k] = A.nzval[p]; k += 1
    end
    return vals
end

NLPModels.jac_structure!(m::BestResponseNLP, rows::AbstractVector{<:Integer},
                         cols::AbstractVector{<:Integer}) = _br_jac_structure!(m.A, rows, cols)
NLPModels.jac_lin_structure!(m::BestResponseNLP, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) = _br_jac_structure!(m.A, rows, cols)
NLPModels.jac_nln_structure!(::BestResponseNLP, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) = (rows, cols)
NLPModels.jac_coord!(m::BestResponseNLP, ::AbstractVector, v::AbstractVector) =
    _br_jac_coord!(m.A, v)
NLPModels.jac_lin_coord!(m::BestResponseNLP, ::AbstractVector, v::AbstractVector) =
    _br_jac_coord!(m.A, v)
NLPModels.jac_nln_coord!(::BestResponseNLP, ::AbstractVector, v::AbstractVector) = v

NLPModels.jprod!(m::BestResponseNLP, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, m.A, v)
NLPModels.jprod_lin!(m::BestResponseNLP, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, m.A, v)
NLPModels.jprod_nln!(::BestResponseNLP, ::AbstractVector, ::AbstractVector, Jv::AbstractVector) = Jv
NLPModels.jtprod!(m::BestResponseNLP, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(m.A), v)
NLPModels.jtprod_lin!(m::BestResponseNLP, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(m.A), v)
NLPModels.jtprod_nln!(::BestResponseNLP, ::AbstractVector, ::AbstractVector, Jtv::AbstractVector) = Jtv

# The constraints are linear, so the Hessian of the Lagrangian is the objective's alone:
# per segment, on the (y_i, y_o) block, [2 beta, beta; beta, 0]. Lower triangle only.

function NLPModels.hess_structure!(m::BestResponseNLP, rows::AbstractVector{<:Integer},
                                   cols::AbstractVector{<:Integer})
    i, o = m.i, 3 - m.i
    for s in 1:m.S
        a, b = br_y(m, i, s), br_y(m, o, s)
        rows[2s - 1] = a; cols[2s - 1] = a
        rows[2s] = max(a, b); cols[2s] = min(a, b)
    end
    return rows, cols
end

function NLPModels.hess_coord!(m::BestResponseNLP{T}, ::AbstractVector{T},
                               ::AbstractVector{T}, H::AbstractVector{T};
                               obj_weight::Real = one(T)) where {T}
    for s in 1:m.S
        H[2s - 1] = 2 * m.beta * obj_weight
        H[2s] = m.beta * obj_weight
    end
    return H
end

function NLPModels.hprod!(m::BestResponseNLP{T}, ::AbstractVector{T}, ::AbstractVector{T},
                          v::AbstractVector{T}, Hv::AbstractVector;
                          obj_weight::Real = one(T)) where {T}
    fill!(Hv, zero(T))
    i, o = m.i, 3 - m.i
    for s in 1:m.S
        a, b = br_y(m, i, s), br_y(m, o, s)
        Hv[a] += obj_weight * (2 * m.beta * v[a] + m.beta * v[b])
        Hv[b] += obj_weight * m.beta * v[a]
    end
    return Hv
end

"""
    best_response_mpcc_arrays(S, beta, alpha, K, nu, i, x_other; x0) -> (mpcc, nlp)

Player `i`'s best-response problem as an `MPCCModels.MPCCModel`. The complementary pairs
are `(y_j^s, omega_j^s)` and `(lambda_j^s, u_j^s)`, declared by index. `x_i` is position 1
of the solution vector.
"""
function best_response_mpcc_arrays(S::Integer, beta::Real, alpha::AbstractVector,
                                   K::AbstractVector, nu::AbstractVector, i::Int,
                                   x_other::Real; x0 = nothing)
    nlp = BestResponseNLP(S, beta, alpha, K, nu, i, x_other; x0 = x0)
    cc1, cc2 = Int[], Int[]
    for j in 1:2, s in 1:S
        push!(cc1, br_y(nlp, j, s)); push!(cc2, br_ω(nlp, j, s))
        push!(cc1, br_λ(nlp, j, s)); push!(cc2, br_u(nlp, j, s))
    end
    return MPCCModels.MPCCModel(nlp, cc1, cc2), nlp
end

"""
    best_response_start_arrays(S, beta, alpha, K, nu, i, x, y) -> Vector

A full starting vector consistent at capacities `x` with second-stage outputs `y`: the
duals and slacks implied by them, and `x_i` at its current value.

Its purpose is to pose a solve from a chosen point rather than the solver's default. Started
inside the worse of two wells of player `i`'s objective, a method that only moves downhill
has no reason to leave, and handing the solver exactly that point is the honest way to ask
whether it does. Started where player `i` holds nothing, every capacity pair is biactive and
the second stage is degenerate, which asks a different question: whether such a start stalls
the method.
"""
function best_response_start_arrays(S::Integer, beta::Real, alpha::AbstractVector,
                                    K::AbstractVector, nu::AbstractVector, i::Int,
                                    x::AbstractVector, y::AbstractMatrix)
    z = zeros(1 + 8 * S)
    z[1] = Float64(x[i])
    for j in 1:2, s in 1:S
        z[1 + (j - 1) * S + s] = y[j, s]
        # lambda is the shadow price of capacity: positive only where output is at capacity.
        λ = abs(Float64(x[j]) - y[j, s]) <= 1e-9 ?
            max(alpha[s] - 2 * beta * y[j, s] - beta * y[3 - j, s] - nu[j], 0.0) : 0.0
        z[1 + 2 * S + (j - 1) * S + s] = λ
        ω = -alpha[s] + 2 * beta * y[j, s] + beta * y[3 - j, s] + nu[j] + λ
        z[1 + 4 * S + (j - 1) * S + s] = max(ω, 0.0)
        z[1 + 6 * S + (j - 1) * S + s] = max(Float64(x[j]) - y[j, s], 0.0)
    end
    return z
end

"""
    solve_best_response_arrays(S, beta, alpha, K, nu, i, x, method; x0) -> NamedTuple

Hand player `i`'s best-response MPCC to CCOpt and report what came back: `x_i`, the
objective and complementarity recomputed from the returned point, the constraint violation,
and the solver's status. `method` is `:relaxation` or `:penalty`.

Nothing here treats the solver's own account of its success as evidence: the objective and
the complementarity are recomputed.
"""
function solve_best_response_arrays(S::Integer, beta::Real, alpha::AbstractVector,
                                    K::AbstractVector, nu::AbstractVector, i::Int,
                                    x::AbstractVector, method::Symbol; x0 = nothing)
    mpcc, nlp = best_response_mpcc_arrays(S, beta, alpha, K, nu, i, x[3 - i]; x0 = x0)
    level = MadNLP.ERROR
    solver = if method === :relaxation
        CCOpt.RelaxationSolver(mpcc;
            solver_opts = CCOpt.RelaxationOptions(print_level = level), print_level = level)
    elseif method === :penalty
        CCOpt.PenaltySolver(mpcc;
            solver_opts = CCOpt.PenaltyOptions{Float64}(print_level = level),
            print_level = level)
    else
        throw(ArgumentError("unknown method $method; expected :relaxation or :penalty"))
    end
    t = @elapsed stats = CCOpt.solve_homotopy!(solver)
    z = stats.solution
    comp = 0.0
    for j in 1:2, s in 1:S
        comp = max(comp, abs(z[br_y(nlp, j, s)] * z[br_ω(nlp, j, s)]))
        comp = max(comp, abs(z[br_λ(nlp, j, s)] * z[br_u(nlp, j, s)]))
    end
    return (x_i = z[1], objective = NLPModels.obj(nlp, z), status = stats.status,
            complementarity = comp,
            feasibility = maximum(abs.(nlp.A * z .- NLPModels.get_lcon(nlp))),
            solve_time = t, z = z)
end


# ---------------------------------------------------------------------------------------
# 4. The cases. `tie` is the rival capacity at which two wells are level; each problem is
#    that capacity perturbed by `offset`, with the right answer and the other well.
# ---------------------------------------------------------------------------------------

const CASES = (
    (name = "instance A, peaking player",
     S = 3, player = 1,
     beta = 1.0,
     alpha = [20.0, 15.0, 10.0],
     K = [2.0, 7.0],
     nu = [3.0, 1.0],
     tie = 7.254033307585,
     problems = (
(rival = 7.244033307585, offset = -0.01,
 right = 3.8779833462074995, right_objective = -28.92764372235161,
 other = 5.0, other_objective = -28.888888888888893,
 margin = 0.03875483346271835),
(rival = 7.2530333075849995, offset = -0.001,
 right = 3.8734833462075002, right_objective = -28.892762122235744,
 other = 5.0, other_objective = -28.888888888888893,
 margin = 0.0038732333468516345),
(rival = 7.255033307585, offset = 0.001,
 right = 5.0, right_objective = -28.888888888888893,
 other = 3.8724833462074977, other_objective = -28.88501615554333,
 margin = 0.0038727333455632618),
(rival = 7.264033307585, offset = 0.01,
 right = 5.0, right_objective = -28.888888888888893,
 other = 3.867983346207502, other_objective = -28.850184055427462,
 margin = 0.03870483346143061),
     )),
    (name = "instance A, base-load player",
     S = 3, player = 2,
     beta = 1.0,
     alpha = [20.0, 15.0, 10.0],
     K = [2.0, 7.0],
     nu = [3.0, 1.0],
     tie = 3.450296453109,
     problems = (
(rival = 3.440296453109, offset = -0.01,
 right = 4.7798517734455, right_objective = -59.13841039666464,
 other = 5.333333333333333, other_objective = -59.09619669452978,
 margin = 0.04221370213485898),
(rival = 3.449296453109, offset = -0.001,
 right = 4.7753517734455, right_objective = -59.05241356474261,
 other = 5.333333333333333, other_objective = -59.04819669452978,
 margin = 0.004216870212829349),
(rival = 3.451296453109, offset = 0.001,
 right = 5.333333333333333, right_objective = -59.03753002786311,
 other = 4.7743517734455, other_objective = -59.03331415764883,
 margin = 0.004215870214281381),
(rival = 3.4602964531089997, offset = 0.01,
 right = 5.333333333333333, right_objective = -58.98953002786311,
 other = 4.769851773445503, other_objective = -58.947416325726806,
 margin = 0.042113702136305164),
     )),
    (name = "instance B, peaking player",
     S = 4, player = 1,
     beta = 10.0,
     alpha = [150.0, 115.0, 100.0, 90.0],
     K = [24.0, 50.0],
     nu = [30.0, 18.0],
     tie = 5.317351598173,
     problems = (
(rival = 5.307351598173001, offset = -0.01,
 right = 2.433333333333333, right_objective = -167.43222222223474,
 other = 3.0, other_objective = -167.1888888888889,
 margin = 0.24333333334584495),
(rival = 5.316351598173, offset = -0.001,
 right = 2.433333333333333, right_objective = -167.21322222223475,
 other = 3.0, other_objective = -167.1888888888889,
 margin = 0.02433333334585086),
(rival = 5.318351598173001, offset = 0.001,
 right = 3.0, right_objective = -167.1888888888889,
 other = 2.433333333333333, other_objective = -167.16455555556809,
 margin = 0.024333333320811334),
(rival = 5.327351598173, offset = 0.01,
 right = 3.0, right_objective = -167.1888888888889,
 other = 2.433333333333333, other_objective = -166.94555555556812,
 margin = 0.243333333320777),
     )),
    (name = "instance B, base-load player",
     S = 4, player = 2,
     beta = 10.0,
     alpha = [150.0, 115.0, 100.0, 90.0],
     K = [24.0, 50.0],
     nu = [30.0, 18.0],
     tie = 4.292375886525,
     problems = (
(rival = 4.282375886525, offset = -0.01,
 right = 3.1333333333333333, right_objective = -322.8299999999944,
 other = 3.6333333333333333, other_objective = -322.5166666666667,
 margin = 0.3133333333277051),
(rival = 4.291375886525, offset = -0.001,
 right = 3.1333333333333333, right_objective = -322.5479999999945,
 other = 3.6333333333333333, other_objective = -322.5166666666667,
 margin = 0.031333333327779656),
(rival = 4.293375886525, offset = 0.001,
 right = 3.6333333333333333, right_objective = -322.5166666666667,
 other = 3.1333333333333333, other_objective = -322.4853333333278,
 margin = 0.031333333338920966),
(rival = 4.302375886525, offset = 0.01,
 right = 3.6333333333333333, right_objective = -322.5166666666667,
 other = 3.1333333333333333, other_objective = -322.2033333333278,
 margin = 0.31333333333890323),
     )),
)

"""Solve the output stage at capacities `x` with PATH-free arithmetic: enumeration is not
available here, so the reference outputs come from CCOpt's relaxation method, which is
reliable at these nondegenerate points and is checked against a recomputed residual."""
function output_stage(case, x)
    M, q = ms_second_stage_arrays(case.S, case.beta, case.alpha, case.K, case.nu, x)
    n = length(q)
    nlp = LCPVerticalModel(M, q)
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect(n+1:2n))
    solver = CCOpt.RelaxationSolver(mpcc;
        solver_opts = CCOpt.RelaxationOptions(print_level = MadNLP.ERROR),
        print_level = MadNLP.ERROR)
    stats = CCOpt.solve_homotopy!(solver)
    w = stats.solution[1:n]
    S = case.S
    y = [w[(j - 1) * S + s] for j in 1:2, s in 1:S]
    return (y = y, residual = lcp_residual(M, q, w).worst)
end

"""Player `case.player`'s objective at its own capacity `xi`, rival held at `rival`."""
function objective_at(case, rival, xi)
    x = zeros(2)
    x[3 - case.player] = rival
    x[case.player] = xi
    r = output_stage(case, x)
    return ms_long_run_objective(case.S, case.beta, case.alpha, case.K, case.nu,
                                 case.player, xi, r.y), r.residual
end

found_global = 0
total = 0

@testset "A hard MPCC: two optima, tied" begin
    for case in CASES
        println()
        println("=== ", case.name, " — tie at rival capacity ", case.tie, " ===")
        for p in case.problems
            # The landscape, asserted from the inlined values alone. They are ground
            # truth: they come from PATH and from an exact enumeration of the objective's
            # pieces, not from the solver under test. Recomputing them here with CCOpt
            # would be circular, and would also fail — these wells sit on regime
            # boundaries, where CCOpt's output stage is about 2e-4 from PATH's rather than
            # the 1e-8 it achieves at an interior point.
            @testset "$(case.name), offset $(p.offset): the landscape" begin
                @test p.margin > 0                        # the right answer really is better
                @test p.other_objective - p.right_objective ≈ p.margin atol = 1e-12
                @test abs(p.right - p.other) > 0.4        # and the two are far apart
                @test abs(p.margin / p.right_objective) < 2e-3   # by a very small margin
            end

            # What the solver's own arithmetic makes of the two wells, reported rather than
            # asserted, for the same reason.
            vr, resr = objective_at(case, p.rival, p.right)
            vo, _ = objective_at(case, p.rival, p.other)
            @testset "$(case.name), offset $(p.offset): the output stage solves" begin
                @test resr < 1e-5
            end

            # The solver, started inside the wrong well.
            x = zeros(2); x[3 - case.player] = p.rival
            start = copy(x); start[case.player] = p.other
            z0 = best_response_start_arrays(case.S, case.beta, case.alpha, case.K,
                                            case.nu, case.player, start,
                                            output_stage(case, start).y)
            for method in (:relaxation, :penalty)
                r = solve_best_response_arrays(case.S, case.beta, case.alpha, case.K, case.nu,
                                               case.player, x, method; x0 = z0)
                global total += 1
                hit = abs(r.x_i - p.right) < 1e-3
                hit && (global found_global += 1)
                @testset "$(case.name), offset $(p.offset), $method" begin
                    @test r.feasibility < 1e-5
                    # Whatever it returns is one of the two wells: it found *a* local
                    # optimum, which is all a local method promises.
                    @test min(abs(r.x_i - p.right), abs(r.x_i - p.other)) < 1e-3
                end
                println("  offset ", rpad(string(p.offset), 8),
                        rpad(string(method), 12),
                        "-> x_i = ", rpad(string(round(r.x_i; digits = 6)), 12),
                        rpad(hit ? "found the better well" : "kept the worse well", 24),
                        "margin ", round(p.margin; sigdigits = 3),
                        "  (solver's own view of it: ",
                        round(vo - vr; sigdigits = 3), ")")
            end
        end
    end
end

println()
println("found the better well in ", found_global, " of ", total, " solves")

end # module HardCaseNearTie
