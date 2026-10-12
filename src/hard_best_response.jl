# Building a best-response problem that is hard on purpose.
#
# Everything CCOpt has been given in this programme so far, it has solved. The open-loop
# problems are strictly complementary with unique solutions (F-0007). The best-response
# MPCC has a nonconvex objective, but its global optimum is found from every start tried,
# including from the degenerate corners where a player holds nothing (F-0016) — which are
# not local optima at all, since the objective falls from them (F-0018). None of that
# discriminates,
# and a test that nothing fails is a weak thing to put in front of a solver's author.
#
# So this file goes looking for a hard case rather than hoping one turns up. The mechanism
# is a near-tie. Player i's long-run objective, at a fixed rival capacity, is piecewise
# quadratic with one piece per second-stage regime (see `best_response_mpcc.jl`). Each piece
# has its own minimiser, so the landscape is a row of wells separated by kinks. As the rival
# capacity varies, the depths of those wells move relative to one another, and somewhere
# between "well A is deeper" and "well B is deeper" they are exactly level.
#
# Near that crossing the problem is hard in a way that is easy to state and impossible to
# fudge:
#
#   * two widely separated capacities are almost equally good, so the answer is decided by a
#     margin of a fraction of a percent while the decisions differ by a factor of several;
#   * the global optimum switches discontinuously from one to the other as the rival's
#     capacity crosses the tie, so any method with a bias towards its starting point gets it
#     wrong on one side;
#   * and the right answer is known exactly, because the pieces can be enumerated and their
#     minimisers computed in closed form.
#
# That last point is what makes it a test rather than a puzzle. A hard problem with no known
# answer only tells you that solvers disagree.

"""
    feasible_bases(data) -> Vector{Vector{Int}}

Every second-stage complementarity pattern whose basis matrix has full rank, computed once.
The basis matrix depends on the instance and not on capacities, so this is the expensive
part of a landscape scan and it is shared across every point of one.
"""
function feasible_bases(d::MSData)
    n = 4 * d.S
    M, _, _ = ms_second_stage_lcp(d, [0.0, 0.0])
    out = Vector{Vector{Int}}()
    for mask in 0:(2^n - 1)
        basis = [k for k in 1:n if (mask >> (k - 1)) & 1 == 1]
        if isempty(basis) || rank(M[basis, basis]; atol = 1e-10) == length(basis)
            push!(out, basis)
        end
    end
    return out
end

"""
    best_response_wells(data, i, x; bases, tol, backend) -> Vector{NamedTuple}

Every local minimum of player `i`'s long-run objective at the rival capacity in `x`, found
by enumerating second-stage patterns rather than by searching.

Each pattern makes the objective quadratic on the interval of `x_i` where that pattern is
the second stage. Minimising each quadratic on its own interval gives a candidate;
evaluating the true objective at each and keeping the distinct ones gives the landscape,
sorted so the first entry is the global optimum.

Pass `bases` from [`feasible_bases`](@ref) when scanning many rival capacities.

Candidates are proposed by pattern algebra and judged by a real second-stage solve, the
same division of labour as in `enumerate_closed_loop`.
"""
function best_response_wells(d::MSData, i::Int, x::AbstractVector;
                             bases = nothing, tol = 1e-9, backend::Symbol = :path)
    o = other(i)
    x_o = Float64(x[o])
    bs = bases === nothing ? feasible_bases(d) : bases
    candidates = Float64[0.0]
    for basis in bs
        aff = _pattern_affine_in(d, basis, i, x_o)
        aff === nothing && continue
        lo, hi, c1, c2 = aff
        lo <= hi || continue
        push!(candidates, lo)
        isfinite(hi) && push!(candidates, hi)
        if c2 > tol
            v = -c1 / (2 * c2)
            lo <= v <= hi && push!(candidates, v)
        end
    end
    unique!(c -> round(c; digits = 10), candidates)
    filter!(c -> c >= -tol && isfinite(c), candidates)

    wells = NamedTuple{(:x_i, :objective), Tuple{Float64, Float64}}[]
    for c in sort(candidates)
        xi = max(c, 0.0)
        trial = collect(Float64.(x))
        trial[i] = xi
        v = closed_loop_objective(d, i, trial; backend = backend)
        idx = findfirst(w -> abs(w.x_i - xi) <= 1e-7, wells)
        if idx === nothing
            push!(wells, (x_i = xi, objective = v))
        elseif v < wells[idx].objective
            wells[idx] = (x_i = xi, objective = v)
        end
    end
    return sort(wells; by = w -> w.objective)
end

"""
    best_response_gap_at(data, i, x_other; separation, bases, backend) -> NamedTuple

The two best local minima at least `separation` apart in capacity, and the objective gap
between them. `gap` is `NaN` when no second well that far away exists.
"""
function best_response_gap_at(d::MSData, i::Int, x_other::Real;
                              separation = 0.5, bases = nothing, backend::Symbol = :path)
    x = zeros(2)
    x[other(i)] = Float64(x_other)
    wells = best_response_wells(d, i, x; bases = bases, backend = backend)
    isempty(wells) && return (best = nothing, alt = nothing, gap = NaN)
    best = wells[1]
    for w in wells[2:end]
        if abs(w.x_i - best.x_i) >= separation
            return (best = best, alt = w, gap = w.objective - best.objective)
        end
    end
    return (best = best, alt = nothing, gap = NaN)
end

"""
    best_response_tie(data, i; separation, bracket, points, refine, backend) -> NamedTuple

The rival capacity at which player `i`'s two best, widely separated local minima come
closest to level: the hardest instance of the best-response problem this model admits.

At such a point two capacities differing by `separation` or more are almost equally good, so
the answer turns on a margin far smaller than the decision, and the global optimum switches
from one well to the other as the rival's capacity crosses it. That combination — a tiny
margin, a large difference in the answer, and a known right answer on each side — is what
makes it a test rather than a curiosity.

Found by scanning `points` rival capacities across `bracket` for the smallest gap, then
refining around the best two grid points by golden section.
"""
function best_response_tie(d::MSData, i::Int; separation = 0.5, bracket = (0.0, 12.0),
                           points::Int = 241, refine::Int = 60, backend::Symbol = :path)
    bases = feasible_bases(d)
    at(v) = best_response_gap_at(d, i, v; separation = separation, bases = bases,
                                 backend = backend)

    grid = collect(range(Float64(bracket[1]), stop = Float64(bracket[2]), length = points))
    gaps = [at(v).gap for v in grid]
    ok = findall(g -> !isnan(g), gaps)
    isempty(ok) && return (found = false, x_other = NaN, best = nothing, alt = nothing,
                           gap = NaN, bracket = (NaN, NaN))
    k = ok[argmin([gaps[j] for j in ok])]
    lo = grid[max(k - 1, 1)]
    hi = grid[min(k + 1, length(grid))]

    # Golden-section on the gap over the bracketing interval.
    φ = (sqrt(5.0) - 1) / 2
    a, b = lo, hi
    c, dd = b - φ * (b - a), a + φ * (b - a)
    fc, fd = at(c).gap, at(dd).gap
    for _ in 1:refine
        (isnan(fc) || isnan(fd)) && break
        if fc < fd
            b, dd, fd = dd, c, fc
            c = b - φ * (b - a)
            fc = at(c).gap
        else
            a, c, fc = c, dd, fd
            dd = a + φ * (b - a)
            fd = at(dd).gap
        end
        b - a < 1e-12 && break
    end
    x_star = (a + b) / 2
    r = at(x_star)
    return (found = r.alt !== nothing, x_other = x_star, best = r.best, alt = r.alt,
            gap = r.gap, bracket = (a, b))
end
