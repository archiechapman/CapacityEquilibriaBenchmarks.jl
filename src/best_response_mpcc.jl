# Phase 4: a player's best response as a genuine MPCC, for CCOpt to solve.
#
# WHY NOT THE MONOLITHIC SYSTEM FIRST, AS THE PLAN ASKS.
#
# The plan describes Phase 4 as stacking every firm's first-order conditions into one system
# and calling it a mechanical reformulation of Phase 3. It is not mechanical, and the reason
# is `FINDINGS.md` F-0012: the first-stage condition (16), p.24 depends on `B_i y_j`, the
# sensitivity of the second-stage equilibrium to capacity, and Lemma 7 (14), p.22 gives that
# as a *piecewise constant* table indexed by which of five regimes each segment is in. The
# regime is determined by which complementarities are active. So (16) is not a smooth
# function of the variables, and there is no way to write it as one; a single smooth MPCC in
# `(x, y, λ)` whose stationarity conditions are (16) does not exist.
#
# There are two honest routes to a monolithic system, and both are more than a translation.
# One encodes the regime disjunctively, which leaves MPCC territory. The other stacks the
# KKT conditions of each player's *MPEC* — its own optimisation subject to the second-stage
# equilibrium — which is standard for an EPEC and comes with constraint qualifications that
# are known to fail generically at exactly the degenerate points F-0015 identifies.
#
# This file builds the piece both routes need and which is well posed on its own: one
# player's MPEC, as an MPCC. That is also the object whose global solution F-0014 showed the
# whole diagonalization scheme rests on, so it is the piece worth putting to a solver first.
#
# THE PROBLEM. For player `i`, with the rival's capacity `x_o` fixed:
#
#     min over (x_i, y, λ, ω, u)   K_i x_i + Σ_s [−α^s + β(y_p^s + y_b^s) + ν_i] y_i^s
#     s.t.  ω_j^s = −α^s + 2β y_j^s + β y_{−j}^s + ν_j + λ_j^s        for all j, s
#           u_j^s = x_j − y_j^s                                        for all j, s
#           0 ≤ y_j^s ⟂ ω_j^s ≥ 0,   0 ≤ λ_j^s ⟂ u_j^s ≥ 0            for all j, s
#           x_i ≥ 0
#
# The constraints are the second-stage equilibrium conditions (4), p.24, written in vertical
# form with explicit slacks so that every complementarity is between two variables. The
# objective is the long-run objective (15), p.24 — capacity cost minus gross margin, so
# minimising it maximises profit.
#
# It is genuinely nonconvex. The objective's Hessian on each segment's `(y_i, y_o)` block is
# `[2β β; β 0]`, whose determinant is `−β²`, so it is indefinite in every segment. That is
# not incidental: it is the same non-convexity that makes the first-order conditions admit
# roots that are not equilibria, seen from the other side.

using SparseArrays: sparse, SparseMatrixCSC, nnz

"""
    BestResponseMPCC(data, i, x_other)

Player `i`'s long-run problem as an `NLPModels.AbstractNLPModel` in

    z = (x_i, y_p^1..S, y_b^1..S, λ_p^1..S, λ_b^1..S, ω_p^1..S, ω_b^1..S, u_p^1..S, u_b^1..S)

of length `1 + 8S`, with `4S` linear equality constraints and every variable nonnegative.
Pair it with [`best_response_mpcc`](@ref), which declares the complementarities.

`x_other` is data, not a variable: this is one player's problem, not the game.
"""
struct BestResponseMPCC{T} <: NLPModels.AbstractNLPModel{T, Vector{T}}
    S::Int
    i::Int
    beta::T
    alpha::Vector{T}
    K::Vector{T}
    nu::Vector{T}
    x_other::T
    A::SparseMatrixCSC{T, Int}
    meta::NLPModels.NLPModelMeta{T, Vector{T}}
    counters::NLPModels.Counters
end

# Positions in z. Player 1 is the peaker, 2 the base plant, as everywhere else.
br_x(::BestResponseMPCC) = 1
br_y(m::BestResponseMPCC, j, s) = 1 + (j - 1) * m.S + s
br_λ(m::BestResponseMPCC, j, s) = 1 + 2 * m.S + (j - 1) * m.S + s
br_ω(m::BestResponseMPCC, j, s) = 1 + 4 * m.S + (j - 1) * m.S + s
br_u(m::BestResponseMPCC, j, s) = 1 + 6 * m.S + (j - 1) * m.S + s

function BestResponseMPCC(d::MSData, i::Int, x_other::Real; x0 = nothing)
    S = d.S
    n = 1 + 8 * S
    ncon = 4 * S
    T = Float64
    o = other(i)

    # Build the constraint matrix by writing into a dense scratch and sparsifying: n is at
    # most a few dozen here and the clarity is worth more than the allocation.
    A = zeros(T, ncon, n)
    b = zeros(T, ncon)
    yidx(j, s) = 1 + (j - 1) * S + s
    λidx(j, s) = 1 + 2 * S + (j - 1) * S + s
    ωidx(j, s) = 1 + 4 * S + (j - 1) * S + s
    uidx(j, s) = 1 + 6 * S + (j - 1) * S + s

    for j in 1:2, s in 1:S
        # ω_j^s − 2β y_j^s − β y_{−j}^s − λ_j^s = ν_j − α^s
        r = (j - 1) * S + s
        A[r, ωidx(j, s)] = 1.0
        A[r, yidx(j, s)] = -2 * d.beta
        A[r, yidx(3 - j, s)] = -d.beta
        A[r, λidx(j, s)] = -1.0
        b[r] = d.nu[j] - d.alpha[s]

        # u_j^s + y_j^s − x_j = 0, and x_j is a variable only for player i
        r = 2 * S + (j - 1) * S + s
        A[r, uidx(j, s)] = 1.0
        A[r, yidx(j, s)] = 1.0
        if j == i
            A[r, 1] = -1.0
            b[r] = 0.0
        else
            b[r] = Float64(x_other)
        end
    end
    Asp = sparse(A)

    start = x0 === nothing ? zeros(T, n) : collect(T, x0)
    meta = NLPModels.NLPModelMeta{T, Vector{T}}(
        n;
        x0 = start,
        lvar = zeros(T, n),
        uvar = fill(T(Inf), n),
        ncon = ncon,
        y0 = zeros(T, ncon),
        lcon = b,
        ucon = b,
        nnzj = nnz(Asp),
        lin_nnzj = nnz(Asp),
        nln_nnzj = 0,
        nnzh = 2 * S,
        lin = collect(1:ncon),
        minimize = true,
        name = "Murphy-Smeers best response, player $i, S = $S",
    )
    return BestResponseMPCC{T}(S, i, d.beta, collect(T, d.alpha), collect(T, d.K),
                               collect(T, d.nu), T(x_other), Asp, meta,
                               NLPModels.Counters())
end

# --- objective: K_i x_i + Σ_s (ν_i − α^s + β(y_p + y_b)) y_i^s ----------------------------

function NLPModels.obj(m::BestResponseMPCC{T}, z::AbstractVector) where {T}
    i, o = m.i, 3 - m.i
    v = m.K[i] * z[1]
    for s in 1:m.S
        yi = z[br_y(m, i, s)]
        yo = z[br_y(m, o, s)]
        v += (m.nu[i] - m.alpha[s] + m.beta * (yi + yo)) * yi
    end
    return v
end

function NLPModels.grad!(m::BestResponseMPCC{T}, z::AbstractVector, g::AbstractVector) where {T}
    fill!(g, zero(T))
    i, o = m.i, 3 - m.i
    g[1] = m.K[i]
    for s in 1:m.S
        yi = z[br_y(m, i, s)]
        yo = z[br_y(m, o, s)]
        g[br_y(m, i, s)] = m.nu[i] - m.alpha[s] + 2 * m.beta * yi + m.beta * yo
        g[br_y(m, o, s)] = m.beta * yi
    end
    return g
end

NLPModels.objgrad!(m::BestResponseMPCC, z::AbstractVector, g::AbstractVector) =
    (NLPModels.obj(m, z), NLPModels.grad!(m, z, g))

# --- constraints: all linear ----------------------------------------------------------------

NLPModels.cons!(m::BestResponseMPCC, z::AbstractVector, c::AbstractVector) =
    LinearAlgebra.mul!(c, m.A, z)
NLPModels.cons_lin!(m::BestResponseMPCC, z::AbstractVector, c::AbstractVector) =
    LinearAlgebra.mul!(c, m.A, z)
NLPModels.cons_nln!(::BestResponseMPCC, ::AbstractVector, c::AbstractVector) = c

function _br_jac_structure!(A::SparseMatrixCSC, rows, cols)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        rows[k] = A.rowval[p]
        cols[k] = col
        k += 1
    end
    return rows, cols
end

function _br_jac_coord!(A::SparseMatrixCSC, vals)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        vals[k] = A.nzval[p]
        k += 1
    end
    return vals
end

NLPModels.jac_structure!(m::BestResponseMPCC, rows::AbstractVector{<:Integer},
                         cols::AbstractVector{<:Integer}) = _br_jac_structure!(m.A, rows, cols)
NLPModels.jac_lin_structure!(m::BestResponseMPCC, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) = _br_jac_structure!(m.A, rows, cols)
NLPModels.jac_nln_structure!(::BestResponseMPCC, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) = (rows, cols)
NLPModels.jac_coord!(m::BestResponseMPCC, ::AbstractVector, v::AbstractVector) =
    _br_jac_coord!(m.A, v)
NLPModels.jac_lin_coord!(m::BestResponseMPCC, ::AbstractVector, v::AbstractVector) =
    _br_jac_coord!(m.A, v)
NLPModels.jac_nln_coord!(::BestResponseMPCC, ::AbstractVector, v::AbstractVector) = v

NLPModels.jprod!(m::BestResponseMPCC, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, m.A, v)
NLPModels.jprod_lin!(m::BestResponseMPCC, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, m.A, v)
NLPModels.jprod_nln!(::BestResponseMPCC, ::AbstractVector, ::AbstractVector, Jv::AbstractVector) = Jv
NLPModels.jtprod!(m::BestResponseMPCC, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(m.A), v)
NLPModels.jtprod_lin!(m::BestResponseMPCC, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(m.A), v)
NLPModels.jtprod_nln!(::BestResponseMPCC, ::AbstractVector, ::AbstractVector, Jtv::AbstractVector) = Jtv

# --- Hessian of the Lagrangian: the objective's alone, since the constraints are linear -----
#
# Per segment, on the block (y_i^s, y_o^s): [2β β; β 0]. Lower triangle only, which is the
# NLPModels convention, so two entries per segment: the (y_i, y_i) diagonal and one cross
# term. The (y_o, y_o) entry is structurally zero and is not stored.

function NLPModels.hess_structure!(m::BestResponseMPCC, rows::AbstractVector{<:Integer},
                                   cols::AbstractVector{<:Integer})
    i, o = m.i, 3 - m.i
    for s in 1:m.S
        a, b = br_y(m, i, s), br_y(m, o, s)
        rows[2s - 1] = a
        cols[2s - 1] = a
        rows[2s] = max(a, b)
        cols[2s] = min(a, b)
    end
    return rows, cols
end

function NLPModels.hess_coord!(m::BestResponseMPCC{T}, ::AbstractVector{T},
                               ::AbstractVector{T}, H::AbstractVector{T};
                               obj_weight::Real = one(T)) where {T}
    for s in 1:m.S
        H[2s - 1] = 2 * m.beta * obj_weight
        H[2s] = m.beta * obj_weight
    end
    return H
end

function NLPModels.hprod!(m::BestResponseMPCC{T}, ::AbstractVector{T}, ::AbstractVector{T},
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

# --- the MPCC, and solving it ---------------------------------------------------------------

"""
    best_response_mpcc(data, i, x; x0) -> (mpcc, index)

Player `i`'s best-response problem as an `MPCCModels.MPCCModel`, with the rival's capacity
taken from `x[3 - i]`. The complementary pairs are `(y_j^s, ω_j^s)` and `(λ_j^s, u_j^s)`,
declared by index; `index.x` is the position of `x_i` in the solution vector.

Optionally give `x0`, a full starting vector in the same layout. The default is the origin,
which is a poor start on purpose: it is a corner, and F-0015 shows corners are where this
model is degenerate.
"""
function best_response_mpcc(d::MSData, i::Int, x::AbstractVector; x0 = nothing)
    nlp = BestResponseMPCC(d, i, Float64(x[other(i)]); x0 = x0)
    S = d.S
    cc1 = Int[]
    cc2 = Int[]
    for j in 1:2, s in 1:S
        push!(cc1, br_y(nlp, j, s)); push!(cc2, br_ω(nlp, j, s))
        push!(cc1, br_λ(nlp, j, s)); push!(cc2, br_u(nlp, j, s))
    end
    mpcc = MPCCModels.MPCCModel(nlp, cc1, cc2)
    return mpcc, (x = 1, y = [br_y(nlp, j, s) for j in 1:2, s in 1:S], nlp = nlp)
end

"""
    solve_best_response_mpcc(data, i, x; method, x0) -> NamedTuple

Hand player `i`'s best-response MPCC to CCOpt and report what came back: the capacity
`x_i`, the objective recomputed from the returned point, the solver's status, and the
largest complementarity violation, also recomputed.

`method` is `:relaxation` or `:penalty`. Nothing here reads the solver's own account of its
success as evidence (engine `DECISIONS.md` D-0002); the objective and the complementarity
are recomputed from the point.
"""
function solve_best_response_mpcc(d::MSData, i::Int, x::AbstractVector;
                                  method::Symbol = :relaxation, x0 = nothing)
    mpcc, idx = best_response_mpcc(d, i, x; x0 = x0)
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
    nlp = idx.nlp
    comp = 0.0
    for j in 1:2, s in 1:d.S
        comp = max(comp, abs(z[br_y(nlp, j, s)] * z[br_ω(nlp, j, s)]))
        comp = max(comp, abs(z[br_λ(nlp, j, s)] * z[br_u(nlp, j, s)]))
    end
    return (x_i = z[1], objective = NLPModels.obj(nlp, z), status = stats.status,
            complementarity = comp, feasibility = maximum(abs.(nlp.A * z .- nlp.meta.lcon)),
            solve_time = t, z = z)
end

"""
    best_response_start(data, i, x; backend) -> Vector

A full starting vector for player `i`'s MPCC that is consistent at capacities `x`: the
second stage solved there, its slacks computed, and `x_i` at its current value.

Its purpose is adversarial. Started at a capacity vector that is a *local* optimum for
player `i` but not a global one — which is what the corner roots of (16) are — a method
that only moves downhill has no reason to leave. Handing the solver exactly that point is
the sharpest test of whether it does (`FINDINGS.md` F-0016).
"""
function best_response_start(d::MSData, i::Int, x::AbstractVector; backend::Symbol = :path)
    S = d.S
    pt = ms_second_stage(d, x; backend = backend)
    z = zeros(1 + 8 * S)
    z[1] = Float64(x[i])
    for j in 1:2, s in 1:S
        z[1 + (j - 1) * S + s] = pt.y[j, s]
        z[1 + 2 * S + (j - 1) * S + s] = pt.λ[j, s]
        ω = -d.alpha[s] + 2 * d.beta * pt.y[j, s] + d.beta * pt.y[3 - j, s] +
            d.nu[j] + pt.λ[j, s]
        z[1 + 4 * S + (j - 1) * S + s] = max(ω, 0.0)
        z[1 + 6 * S + (j - 1) * S + s] = max(Float64(x[j]) - pt.y[j, s], 0.0)
    end
    return z
end
