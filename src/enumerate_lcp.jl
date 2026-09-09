# An exhaustive oracle for small linear complementarity problems.
#
# For 0 ≤ z ⟂ Mz + q ≥ 0 with n variables, every solution has a complementarity pattern:
# a set B of indices where z is free (and F must vanish) and its complement N where z is
# zero (and F must be nonnegative). Trying all 2ⁿ patterns and solving the linear system
# each one implies finds every solution of a nondegenerate LCP without consulting any
# solver. That is what makes it usable as an oracle here: it is independent of PATH, of
# CCOpt and of the hand derivation, and it also answers the uniqueness question directly by
# returning how many distinct solutions there are.
#
# It is exponential and meant for n of a few tens at most. Instance A has n = 14.

using LinearAlgebra: norm, rank, pinv, eigmin, Symmetric

"""
    enumerate_lcp_solutions(M, q; tol = 1e-9, feas_tol = 1e-7) -> NamedTuple

Enumerate all complementarity patterns of the LCP `0 ≤ z ⟂ Mz + q ≥ 0`. Returns

  - `solutions`: distinct solutions found (deduplicated at `feas_tol`), each with residual
    `worst < feas_tol` as recomputed by the same arithmetic `lcp_residual` uses;
  - `singular`: the number of patterns whose basis matrix `M[B,B]` was rank-deficient with
    a consistent right-hand side. Such a pattern's linear system is underdetermined and is
    not searched for feasible points, so this count is reported for information and is
    not itself evidence for or against a continuum of solutions.

A pattern with a singular basis and an inconsistent right-hand side has no solution and is
simply skipped.

Uniqueness is therefore not decided by this function alone. For a monotone LCP (`M`
positive semidefinite) the argument is elementary: any two solutions `z, z'` satisfy
`zᵀF(z') = z'ᵀF(z) = 0`, so if a solution `z` is strictly complementary its support forces
`z'` into the same pattern, whose nonsingular basis then gives `z' = z`. The tests check
those three conditions — monotone, strictly complementary, nonsingular basis — with
`is_monotone` and `strictly_complementary`, and read `solutions` for the point.
"""
function enumerate_lcp_solutions(M::AbstractMatrix, q::AbstractVector;
                                 tol = 1e-9, feas_tol = 1e-7)
    n = length(q)
    size(M) == (n, n) || throw(DimensionMismatch("M is $(size(M)), q has length $n"))
    n <= 30 || throw(ArgumentError("n = $n is too large to enumerate 2^n patterns"))
    solutions = Vector{Vector{Float64}}()
    singular = 0
    for mask in 0:(2^n - 1)
        B = [i for i in 1:n if (mask >> (i - 1)) & 1 == 1]
        z = zeros(n)
        if !isempty(B)
            MBB = M[B, B]
            qB = q[B]
            if rank(MBB; atol = tol) < length(B)
                # Rank-deficient: either no solution, or a continuum. Test consistency with
                # a least-squares solve; count it if consistent, skip either way.
                zB = pinv(MBB) * (-qB)
                norm(MBB * zB + qB) <= feas_tol && (singular += 1)
                continue
            end
            z[B] = MBB \ (-qB)
        end
        F = M * z .+ q
        any(z .< -feas_tol) && continue
        any(F .< -feas_tol) && continue
        maximum(abs.(z .* F)) > feas_tol && continue
        any(norm(z - s, Inf) <= feas_tol for s in solutions) && continue
        push!(solutions, z)
    end
    return (solutions = solutions, singular = singular)
end

"""
    is_monotone(M; tol = 1e-10) -> Bool

Whether `M` is positive semidefinite, i.e. whether `F(z) = Mz + q` is a monotone map. The
smallest eigenvalue of the symmetric part `(M + Mᵀ)/2` must be at least `-tol`. The
paper's Lemma 1 (p.18) asserts this for the open-loop Cournot map; the competitive map is
monotone by the same argument with the own-output coefficient halved.
"""
is_monotone(M::AbstractMatrix; tol = 1e-10) = eigmin(Symmetric((M + M') / 2)) >= -tol

"""
    strictly_complementary(M, q, z; tol = 1e-7) -> Bool

Whether at `z` every complementary pair has exactly one member strictly positive: for all
`i`, `z[i] > tol` xor `F[i] > tol`. A strictly complementary solution of a monotone LCP is
its only solution, provided its basis is nonsingular (see `enumerate_lcp_solutions`).
"""
function strictly_complementary(M::AbstractMatrix, q::AbstractVector, z::AbstractVector;
                                tol = 1e-7)
    F = M * z .+ q
    return all(xor(z[i] > tol, F[i] > tol) for i in eachindex(z))
end

"""
    basis_nonsingular(M, z; tol = 1e-7, rank_tol = 1e-9) -> Bool

Whether `M[B, B]` has full rank for `B = {i : z[i] > tol}`, the support of `z`.
"""
function basis_nonsingular(M::AbstractMatrix, z::AbstractVector; tol = 1e-7, rank_tol = 1e-9)
    B = [i for i in eachindex(z) if z[i] > tol]
    isempty(B) && return true
    return rank(M[B, B]; atol = rank_tol) == length(B)
end
