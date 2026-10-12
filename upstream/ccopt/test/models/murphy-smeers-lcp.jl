# Murphy and Smeers' open-loop capacity-expansion equilibria: four small linear
# complementarity problems with solutions known independently of any solver, as MPCCs.
#
# GENERATED FILE — DO NOT EDIT. Produced by `scripts/emit_upstream_test.jl` in
# CapacityEquilibriaBenchmarks.jl (https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl),
# which copies the model and the residual check from the sources that repository validates,
# formats them to CCOpt.jl's settings, and inlines the data. The derivations, the
# enumeration and the PATH results are there.
#
# Two constructed instances, each under price-taking and open-loop Cournot behaviour, give
# square LCPs `0 ≤ z ⟂ Mz + q ≥ 0` of 14 and 18 variables with monotone `M`. Each solution
# was derived by hand, is the only one an exhaustive enumeration of complementarity
# patterns finds, and is reached by PATH to 1e-9. The paper (F. H. Murphy and Y. Smeers,
# Operations Research 53(4), 646–661, 2005) publishes no numerical example, so the
# instances are constructed and no number here is the authors'.
#
# Everything is inside a module so that its helpers (`lcp_residual`, `build`, ...) cannot
# collide with names elsewhere in the suite; `test/solvers/murphy-smeers.jl` reaches them as
# `MurphySmeersLCP.<name>`.

"""
    MurphySmeersLCP

The four Murphy–Smeers cases as `CASES`, and `build(case)`, which returns `(M, q, mpcc, ix)`:
the LCP data, the case as an `MPCCModel`, and the indices of the LCP's `x` in a solver's
point. The LCP's `x` and its residual `w = Mx + q` are the two sides of each
complementarity, paired by index.
"""
module MurphySmeersLCP

import LinearAlgebra
import SparseArrays
import NLPModels
import MPCCModels

"""
    LCPVerticalModel(M, q) <: NLPModels.AbstractNLPModel

The LCP `0 ≤ x ⟂ Mx + q ≥ 0` as a feasibility NLP in `z = (x, w)`, `w − Mx = q`, `x, w ≥ 0`,
with a zero objective. The complementarity between `x[i]` and `w[i]` is *not* part of this
model; it is declared on top of it by `MPCCModels.MPCCModel(nlp, 1:n, n+1:2n)`.
"""
struct LCPVerticalModel{T,VT<:AbstractVector{T}} <: NLPModels.AbstractNLPModel{T,VT}
    n::Int
    A::SparseArrays.SparseMatrixCSC{T,Int}   # [−M  I], the constant Jacobian
    meta::NLPModels.NLPModelMeta{T,VT}
    counters::NLPModels.Counters
end

function LCPVerticalModel(M::AbstractMatrix{T}, q::AbstractVector{T}) where {T}
    n = length(q)
    size(M) == (n, n) || throw(
        DimensionMismatch("M is $(size(M)) but q has length $n; the LCP must be square"),
    )
    A = SparseArrays.sparse([-Matrix{T}(M) Matrix{T}(LinearAlgebra.I, n, n)])
    meta = NLPModels.NLPModelMeta{T,Vector{T}}(
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
    return LCPVerticalModel{T,Vector{T}}(n, A, meta, NLPModels.Counters())
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

function NLPModels.cons!(nlp::LCPVerticalModel, z::AbstractVector, cz::AbstractVector)
    return LinearAlgebra.mul!(cz, nlp.A, z)
end
function NLPModels.cons_lin!(nlp::LCPVerticalModel, z::AbstractVector, cz::AbstractVector)
    return LinearAlgebra.mul!(cz, nlp.A, z)
end
NLPModels.cons_nln!(::LCPVerticalModel, ::AbstractVector, cz::AbstractVector) = cz

function _lcp_jac_structure!(A::SparseArrays.SparseMatrixCSC, rows, cols)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col+1]-1)
        rows[k] = A.rowval[p]
        cols[k] = col
        k += 1
    end
    return rows, cols
end

function _lcp_jac_coord!(A::SparseArrays.SparseMatrixCSC, vals)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col+1]-1)
        vals[k] = A.nzval[p]
        k += 1
    end
    return vals
end

function NLPModels.jac_structure!(
    nlp::LCPVerticalModel,
    rows::AbstractVector{<:Integer},
    cols::AbstractVector{<:Integer},
)
    return _lcp_jac_structure!(nlp.A, rows, cols)
end
function NLPModels.jac_lin_structure!(
    nlp::LCPVerticalModel,
    rows::AbstractVector{<:Integer},
    cols::AbstractVector{<:Integer},
)
    return _lcp_jac_structure!(nlp.A, rows, cols)
end
function NLPModels.jac_nln_structure!(
    ::LCPVerticalModel,
    rows::AbstractVector{<:Integer},
    cols::AbstractVector{<:Integer},
)
    return (rows, cols)
end

function NLPModels.jac_coord!(nlp::LCPVerticalModel, ::AbstractVector, vals::AbstractVector)
    return _lcp_jac_coord!(nlp.A, vals)
end
function NLPModels.jac_lin_coord!(
    nlp::LCPVerticalModel,
    ::AbstractVector,
    vals::AbstractVector,
)
    return _lcp_jac_coord!(nlp.A, vals)
end
NLPModels.jac_nln_coord!(::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) = vals

function NLPModels.jprod!(
    nlp::LCPVerticalModel,
    ::AbstractVector,
    v::AbstractVector,
    Jv::AbstractVector,
)
    return LinearAlgebra.mul!(Jv, nlp.A, v)
end
function NLPModels.jprod_lin!(
    nlp::LCPVerticalModel,
    ::AbstractVector,
    v::AbstractVector,
    Jv::AbstractVector,
)
    return LinearAlgebra.mul!(Jv, nlp.A, v)
end
function NLPModels.jprod_nln!(
    ::LCPVerticalModel,
    ::AbstractVector,
    ::AbstractVector,
    Jv::AbstractVector,
)
    return Jv
end

function NLPModels.jtprod!(
    nlp::LCPVerticalModel,
    ::AbstractVector,
    v::AbstractVector,
    Jtv::AbstractVector,
)
    return LinearAlgebra.mul!(Jtv, transpose(nlp.A), v)
end
function NLPModels.jtprod_lin!(
    nlp::LCPVerticalModel,
    ::AbstractVector,
    v::AbstractVector,
    Jtv::AbstractVector,
)
    return LinearAlgebra.mul!(Jtv, transpose(nlp.A), v)
end
function NLPModels.jtprod_nln!(
    ::LCPVerticalModel,
    ::AbstractVector,
    ::AbstractVector,
    Jtv::AbstractVector,
)
    return Jtv
end

# --- Hessian of the Lagrangian: empty, everything is linear ---------------------------------

function NLPModels.hess_structure!(
    ::LCPVerticalModel,
    rows::AbstractVector{<:Integer},
    cols::AbstractVector{<:Integer},
)
    return (rows, cols)
end

function NLPModels.hess_coord!(
    ::LCPVerticalModel{T},
    ::AbstractVector{T},
    ::AbstractVector{T},
    vals::AbstractVector{T};
    obj_weight::Real = one(T),
) where {T}
    return vals
end

function NLPModels.hprod!(
    ::LCPVerticalModel{T},
    ::AbstractVector{T},
    ::AbstractVector{T},
    ::AbstractVector{T},
    Hv::AbstractVector;
    obj_weight::Real = one(T),
) where {T}
    fill!(Hv, 0)
    return Hv
end

"""
    ms_lcp_arrays(S, beta, alpha, K, nu, variant) -> (M, q)

Murphy and Smeers' open-loop capacity-expansion equilibrium as a linear complementarity
problem `0 ≤ z ⟂ Mz + q ≥ 0`, from the paper's parameters as plain numbers.

  - `S` load segments of unit width, `s = 1` the peak (p.11)
  - `alpha[s]`, `beta`: inverse demand `pˢ = αˢ − β qˢ`, `α¹ > … > αˢ`, `β > 0` (p.12)
  - `K[i]`, `nu[i]`: capacity and output cost of player `i`, `1 = p` peaker, `2 = b` base (p.11)
  - `variant`: `:competitive` (equations (2)–(3), p.14) or `:open_loop_cournot` ((5)–(6), p.16),
    which differ only in the own-output coefficient, `β` against `2β`

The variable layout is `z = (x_p, x_b, y_p^1..S, y_b^1..S, λ_p^1..S, λ_b^1..S)`, so
`n = 2 + 4S`, and row `k` of `F(z) = Mz + q` is the condition paired with `z[k]`.
"""
function ms_lcp_arrays(
    S::Integer,
    beta::Real,
    alpha::AbstractVector,
    K::AbstractVector,
    nu::AbstractVector,
    variant::Symbol,
)
    c =
        variant === :competitive ? 1.0 :
        variant === :open_loop_cournot ? 2.0 :
        throw(
            ArgumentError(
                "unknown variant $variant; expected :competitive or :open_loop_cournot",
            ),
        )
    length(alpha) == S ||
        throw(DimensionMismatch("alpha has $(length(alpha)) entries but S = $S"))
    ix_x(i) = i
    ix_y(i, s) = 2 + (i - 1) * S + s
    ix_λ(i, s) = 2 + 2 * S + (i - 1) * S + s
    n = 2 + 4 * S
    M = zeros(n, n)
    q = zeros(n)
    for i in 1:2
        # 0 ≤ x_i ⟂ K_i − Σ_s λ_i^s ≥ 0                 (3) p.14 / (6) p.16
        r = ix_x(i)
        q[r] = K[i]
        for s in 1:S
            M[r, ix_λ(i, s)] = -1.0
        end
        for s in 1:S
            # 0 ≤ y_i^s ⟂ −α^s + cβ y_i^s + β y_{−i}^s + ν_i + λ_i^s ≥ 0   (2) p.14 / (5) p.16
            r = ix_y(i, s)
            q[r] = -alpha[s] + nu[i]
            M[r, ix_y(i, s)] = c * beta
            M[r, ix_y(3 - i, s)] = beta
            M[r, ix_λ(i, s)] = 1.0
            # 0 ≤ λ_i^s ⟂ x_i − y_i^s ≥ 0                 (2) p.14 / (5) p.16
            r = ix_λ(i, s)
            M[r, ix_x(i)] = 1.0
            M[r, ix_y(i, s)] = -1.0
        end
    end
    return M, q
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
    return (
        primal = primal,
        dual = dual,
        complementarity = comp,
        worst = max(primal, dual, comp),
    )
end

# The cases, with each equilibrium in the layout
# `z = (x_p, x_b, y_p^1..S, y_b^1..S, λ_p^1..S, λ_b^1..S)`.
const CASES = (
    (
        name = "instance A, competitive",
        S = 3,
        beta = 1.0,
        alpha = [20.0, 15.0, 10.0],
        K = [2.0, 7.0],
        nu = [3.0, 1.0],
        variant = :competitive,
        tol = 1.0e-6,
        z = [7.0, 8.0, 7.0, 4.0, 0.0, 8.0, 8.0, 8.0, 2.0, 0.0, 0.0, 4.0, 2.0, 1.0],
    ),
    (
        name = "instance A, open-loop Cournot",
        S = 3,
        beta = 1.0,
        alpha = [20.0, 15.0, 10.0],
        K = [2.0, 7.0],
        nu = [3.0, 1.0],
        variant = :open_loop_cournot,
        tol = 1.0e-6,
        z = [
            5.416666666666667,
            4.166666666666667,
            5.416666666666667,
            3.9166666666666665,
            1.6666666666666667,
            4.166666666666667,
            4.166666666666667,
            3.6666666666666665,
            2.0,
            0.0,
            0.0,
            5.25,
            1.75,
            0.0,
        ],
    ),
    (
        name = "instance B, competitive",
        S = 4,
        beta = 10.0,
        alpha = [150.0, 115.0, 100.0, 90.0],
        K = [24.0, 50.0],
        nu = [30.0, 18.0],
        variant = :competitive,
        tol = 1.0e-5,
        z = [
            1.6,
            8.0,
            1.6,
            0.5,
            0.0,
            0.0,
            8.0,
            8.0,
            8.0,
            7.2,
            24.0,
            0.0,
            0.0,
            0.0,
            36.0,
            12.0,
            2.0,
            0.0,
        ],
    ),
    (
        name = "instance B, open-loop Cournot",
        S = 4,
        beta = 10.0,
        alpha = [150.0, 115.0, 100.0, 90.0],
        K = [24.0, 50.0],
        nu = [30.0, 18.0],
        variant = :open_loop_cournot,
        tol = 1.0e-5,
        z = [
            3.2944444444444443,
            3.011111111111111,
            3.2944444444444443,
            2.7444444444444445,
            1.9944444444444445,
            1.6,
            3.011111111111111,
            3.011111111111111,
            3.011111111111111,
            2.8,
            24.0,
            0.0,
            0.0,
            0.0,
            38.833333333333336,
            9.333333333333334,
            1.8333333333333333,
            0.0,
        ],
    ),
)

function build(case)
    M, q = ms_lcp_arrays(case.S, case.beta, case.alpha, case.K, case.nu, case.variant)
    n = length(q)
    nlp = LCPVerticalModel(M, q)
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect((n+1):2n))
    return M, q, mpcc, 1:n
end

end # module MurphySmeersLCP
