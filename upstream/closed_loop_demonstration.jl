# Three solutions, one equilibrium: a capacity game where the first-order conditions do not
# characterise the answer.
#
# GENERATED FILE — DO NOT EDIT. Produced by `scripts/emit_closed_loop_demo.jl` in
# CapacityEquilibriaBenchmarks.jl, which splices the model verbatim from the sources that
# repository tests and inlines the data from its `data/` directory.
#
# Run it with `julia --project=. closed_loop_demonstration.jl` in a project that has CCOpt,
# MPCCModels, NLPModels, MadNLP and Test. It prints a table and asserts every claim it makes.
#
# WHAT IT SHOWS. Two generators, a peaking plant and a base-load plant, first choose capacity
# and then compete on output in each of several demand blocks. Given the capacities, the
# output stage is a linear complementarity problem with a unique solution — CCOpt solves it,
# and this file checks that it does, at every point it examines, with both of CCOpt's
# methods. The capacity stage is the interesting one. Its equilibrium condition is a
# first-order condition: "no player gains from an infinitesimal change of capacity". On each
# of the two instances below, three capacity vectors satisfy it. Only one of them is an
# equilibrium. At the other two, a player gains a great deal by making a *large* change.
#
# WHY THAT CAN HAPPEN. A player's payoff as a function of its own capacity is piecewise
# quadratic and only piecewise convex, because changing capacity changes which plants are
# running in which demand blocks, and each such switch is a kink. A player holding no
# capacity faces a positive cost for its first unit, so no small increase pays — the
# first-order condition is satisfied — while a large increase crosses into a different
# operating pattern and pays handsomely. A condition built from derivatives cannot see
# across that gap.
#
# WHY IT MATTERS FOR A SOLVER. Nothing here is a defect in CCOpt, and this file is careful to
# demonstrate that: the solver is asked for the output-stage equilibrium at each of the three
# points and gets all of them right. The point is that a complementarity system can have a
# larger solution set than the problem it was written to represent. A solver that finds a
# root is correct; whether that root is an equilibrium is a separate question, answered
# outside the system by a deviation check.
#
# The source repository, with derivations, provenance for every number, and the same model
# validated against PATH and against exhaustive enumeration:
# https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl
#
# The model is Murphy, F. H. and Smeers, Y., "Generation Capacity Expansion in Imperfectly
# Competitive Restructured Electricity Markets", Operations Research 53(4), 646-661 (2005);
# the closed-loop Cournot model of its section 6. The paper publishes no numerical example,
# so the two instances here are constructed to satisfy its stated assumptions and no number
# in this file should be attributed to its authors.
module ClosedLoopDemonstration

using Test
import LinearAlgebra
import SparseArrays
import NLPModels
import MPCCModels
import CCOpt
import MadNLP

# ---------------------------------------------------------------------------------------
# 1. The output-stage problem as an NLP in the vertical form CCOpt's reformulations expect.
#    Copied verbatim from CapacityEquilibria.jl, `src/lcp_nlp.jl`.
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

# ---------------------------------------------------------------------------------------
# 2. The residual oracle. Copied verbatim from CapacityEquilibria.jl, `src/pairing.jl`.
#    It consults no solver: a returned point is judged by recomputing from the point alone.
# ---------------------------------------------------------------------------------------

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
# 3. The model. Copied verbatim from CapacityEquilibriaBenchmarks.jl,
#    `src/murphy_smeers_closed_loop.jl`. The output stage, the regime classification,
#    Lemma 7's closed-form sensitivity of the output stage to capacity, and equation (16).
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

**This is a first-order condition and not a characterisation of equilibrium.** The long-run
objective is only piecewise convex (Lemma 13, p.31) and its marginal cost can jump downwards
(Figure 4, p.32), so a capacity vector can satisfy this and still not be an equilibrium. On
both instances used in this programme it has three roots and only one is an equilibrium.
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


# ---------------------------------------------------------------------------------------
# 4. The cases: two constructed instances and, for each, every capacity vector satisfying
#    the first-order conditions, with what a deviating player could gain at it. Inlined by
#    the emitter; `deviation_gain` is the improvement available to the better-off deviator,
#    found by a global scan over that player's capacity in the source repository.
# ---------------------------------------------------------------------------------------

const CASES = (
    (name = "instance A",
     S = 3,
     beta = 1.0,
     alpha = [20.0, 15.0, 10.0],
     K = [2.0, 7.0],
     nu = [3.0, 1.0],
     roots = (
(x = [0.0, 6.5], deviation_gain = 31.951333,
 equilibrium = false),
(x = [5.0, 5.0], deviation_gain = 0.0,
 equilibrium = true),
(x = [7.5, 0.0], deviation_gain = 46.326319,
 equilibrium = false),
     )),
    (name = "instance B",
     S = 4,
     beta = 10.0,
     alpha = [150.0, 115.0, 100.0, 90.0],
     K = [24.0, 50.0],
     nu = [30.0, 18.0],
     roots = (
(x = [0.0, 4.475], deviation_gain = 187.851822,
 equilibrium = false),
(x = [3.030000000000006, 3.54], deviation_gain = 0.0,
 equilibrium = true),
(x = [4.8, 0.0], deviation_gain = 322.480018,
 equilibrium = false),
     )),
)

"""Solve the output stage at `x` with `method`, and return the outputs and duals."""
function output_stage(case, x, method::Symbol)
    M, q = ms_second_stage_arrays(case.S, case.beta, case.alpha, case.K, case.nu, x)
    n = length(q)
    nlp = LCPVerticalModel(M, q)
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect(n+1:2n))
    solver = if method === :relaxation
        CCOpt.RelaxationSolver(mpcc;
            solver_opts = CCOpt.RelaxationOptions(print_level = MadNLP.ERROR),
            print_level = MadNLP.ERROR)
    else
        CCOpt.PenaltySolver(mpcc;
            solver_opts = CCOpt.PenaltyOptions{Float64}(print_level = MadNLP.ERROR),
            print_level = MadNLP.ERROR)
    end
    stats = CCOpt.solve_homotopy!(solver)
    w = stats.solution[1:n]
    S = case.S
    y = [w[(i - 1) * S + s] for i in 1:2, s in 1:S]
    return (status = stats.status, w = w, M = M, q = q, y = y)
end

"""
    snap_and_bump(case, x, w, bump) -> (residual, lambda_max)

Put the non-investing player's output exactly on its bound, add `bump` to that player's
capacity duals, and recompute the residual.

Snapping matters. At these points the player holds no capacity, so its output is zero and
its capacity constraint binds at zero, and *any* sufficiently large shadow price satisfies
the conditions. The dual is an unbounded ray. A solver's returned point sits somewhere out
along it with a small primal error, and the product of a large dual with a small primal
error is a large residual — which is why the residual is not a useful accuracy measure
here. Snapping removes the primal error so that the freedom in the dual can be seen on its
own.
"""
function snap_and_bump(case, x, w, bump)
    S = case.S
    idle = x[1] < 1e-9 ? 1 : 2
    w2 = copy(w)
    for s in 1:S
        w2[(idle - 1) * S + s] = 0.0                       # output exactly at its bound
        w2[2 * S + (idle - 1) * S + s] += bump             # dual pushed along the ray
    end
    M, q = ms_second_stage_arrays(case.S, case.beta, case.alpha, case.K, case.nu, x)
    return lcp_residual(M, q, w2).worst, maximum(w2[(2 * S + 1):(4 * S)])
end

@testset "Three solutions, one equilibrium" begin
    for case in CASES
        println()
        println("=== ", case.name, " ===")
        for root in case.roots
            corner = any(root.x .< 1e-9)
            ref = output_stage(case, root.x, :relaxation)

            for method in (:relaxation, :penalty)
                r = output_stage(case, root.x, method)
                @testset "$(case.name), x = $(root.x), $method output stage" begin
                    @test r.status == MadNLP.SOLVE_SUCCEEDED
                    # The outputs are pinned by the problem and every method finds them.
                    @test r.y ≈ ref.y atol = 1e-5
                    if corner
                        # The duals are not pinned: see the ray check below. So the only
                        # thing asserted here is that the point is feasible in the primal,
                        # and the residual is reported rather than thresholded, because far
                        # out along a ray it is a statement about where the solver stopped
                        # and not about whether it was right.
                        @test all(r.w .>= -1e-6)
                    else
                        @test lcp_residual(r.M, r.q, r.w).worst < 1e-5
                    end
                end
            end

            # The first-order condition of the capacity stage, at CCOpt's own outputs.
            types, roles = ms_regime(case.S, root.x, ref.y; tol = 1e-5)
            xi = ms_closed_loop_xi(case.S, case.beta, case.alpha, case.K, case.nu,
                                   ref.y, types, roles)
            @testset "$(case.name), x = $(root.x), first-order condition" begin
                @test all(xi .>= -1e-5)
                @test maximum(abs.(root.x .* xi)) < 1e-4
            end

            if corner
                # Why the duals are not pinned: adding an arbitrary amount to the
                # non-investing player's capacity duals leaves an exact solution. The
                # player holds nothing, so its capacity constraint binds at zero for any
                # shadow price high enough, and the problem never picks one.
                @testset "$(case.name), x = $(root.x), the dual is a ray" begin
                    base, _ = snap_and_bump(case, root.x, ref.w, 0.0)
                    for bump in (1.0, 1.0e3, 1.0e5)
                        moved, lam = snap_and_bump(case, root.x, ref.w, bump)
                        # However far the dual is pushed, the point stays a solution to
                        # the same accuracy. Nothing in the problem picks a value for it.
                        @test moved <= base + 1e-9
                        @test lam >= bump
                    end
                end
            end

            mark = root.equilibrium ? "equilibrium" : "not an equilibrium"
            deg = corner ? "degenerate: dual is a ray" : "nondegenerate"
            pen = output_stage(case, root.x, :penalty)
            println("  x = ", rpad(string(round.(root.x; digits = 4)), 22),
                    rpad(deg, 28),
                    "penalty residual ",
                    rpad(string(round(lcp_residual(pen.M, pen.q, pen.w).worst;
                                      sigdigits = 2)), 10),
                    rpad("deviation gain " * string(root.deviation_gain), 26), mark)
        end

        @testset "$(case.name): only one root is an equilibrium" begin
            @test count(r -> r.equilibrium, case.roots) == 1
            for root in case.roots
                root.equilibrium && continue
                @test root.deviation_gain > 1.0
                @test any(root.x .< 1e-9)      # each is a corner: a player holding nothing
            end
        end
    end
end

end # module ClosedLoopDemonstration
