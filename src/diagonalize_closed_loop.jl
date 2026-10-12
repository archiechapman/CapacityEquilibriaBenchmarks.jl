# Diagonalization for the closed-loop Cournot model.
#
# Fix one player's capacity, solve the other's long-run problem for its best response, swap,
# and repeat until nothing moves. It is the standard way to attack an EPEC.
#
# It is built *after* `enumerate_closed_loop.jl` has already found the equilibria, and
# deliberately so. With the answer in hand from a solver-free enumeration, diagonalization
# is an independent route whose behaviour, not just its endpoint, can be compared against a
# known destination.
#
# WHY THE BEST RESPONSE IS NOT A SOLVER CALL. Player i's long-run objective (15), p.24 is
# piecewise quadratic in its own capacity and, by Lemma 13, p.31, only piecewise *convex*.
# Its marginal cost can jump downwards (Figure 4, p.32). A local method can therefore stop
# in a well that is not the best response, and `FINDINGS.md` F-0017 builds cases where two
# wells are level to fourteen figures and a solver started in the worse one often stays.
# A best response computed from the first-order condition (16) would be worse still: F-0013's
# corner roots satisfy (16) although the objective falls from them (F-0018), so a root-find
# would accept a point that even a local method leaves.
#
# So the best response here is computed globally and exactly. For a fixed rival capacity,
# each second-stage complementarity pattern makes the second-stage solution affine in the
# player's own capacity, hence the objective quadratic on the interval where that pattern
# is valid. Minimising each quadratic on its own interval and taking the best over all
# patterns gives the global minimum, up to the enumeration being complete. Every candidate
# is then re-evaluated with a real second-stage solve, so the pattern algebra proposes and
# the actual model disposes — the same division as in the equilibrium enumerator.

"""
    best_response(data, i, x; backend, tol) -> (x_i, objective, candidates)

Player `i`'s globally optimal capacity given the other player's, which is read from `x[3-i]`.

Returns the best capacity found, the objective there, and how many candidate capacities
were examined. Candidates are the stationary points and interval endpoints of the
piecewise-quadratic objective, generated from the second-stage pattern enumeration and then
evaluated with a real second-stage solve.
"""
function best_response(d::MSData, i::Int, x::AbstractVector;
                       backend::Symbol = :path, tol = 1e-9)
    o = other(i)
    x_o = Float64(x[o])
    n = 4 * d.S
    M, _, ix = ms_second_stage_lcp(d, [0.0, 0.0])

    candidates = Float64[0.0]                       # the corner is always worth testing
    for mask in 0:(2^n - 1)
        basis = [k for k in 1:n if (mask >> (k - 1)) & 1 == 1]
        aff = _pattern_affine_in(d, basis, i, x_o)
        aff === nothing && continue
        lo, hi, c1, c2 = aff
        lo <= hi || continue
        push!(candidates, lo)
        isfinite(hi) && push!(candidates, hi)
        if c2 > tol                                  # a genuine interior minimum
            v = -c1 / (2 * c2)
            lo <= v <= hi && push!(candidates, v)
        end
    end

    unique!(c -> round(c; digits = 10), candidates)
    filter!(c -> c >= -tol && isfinite(c), candidates)
    best_x, best_v = 0.0, Inf
    for c in candidates
        trial = collect(Float64.(x))
        trial[i] = max(c, 0.0)
        v = closed_loop_objective(d, i, trial; backend = backend)
        if v < best_v - 1e-12
            best_x, best_v = max(c, 0.0), v
        end
    end
    return (x_i = best_x, objective = best_v, candidates = length(candidates))
end

"""
    _pattern_affine_in(data, basis, i, x_o) -> Union{Nothing, Tuple}

For a second-stage pattern and a fixed rival capacity, the interval of `x_i` on which the
pattern is the second-stage solution, and the linear and quadratic coefficients of player
`i`'s objective on it. Returns `nothing` for a rank-deficient pattern.

The interval comes from requiring every basic variable to be nonnegative and every nonbasic
row to be nonnegative, each of which is affine in `x_i`.
"""
function _pattern_affine_in(d::MSData, basis::Vector{Int}, i::Int, x_o::Float64)
    o = other(i)
    n = 4 * d.S
    M, _, ix = ms_second_stage_lcp(d, [0.0, 0.0])
    isempty(basis) || rank(M[basis, basis]; atol = 1e-10) == length(basis) || return nothing

    # z(x_i) = z0 + z1 x_i, from two evaluations of the pattern's linear system.
    function z_at(xi)
        z = zeros(n)
        if !isempty(basis)
            xv = zeros(2); xv[i] = xi; xv[o] = x_o
            _, q, _ = ms_second_stage_lcp(d, xv)
            z[basis] = M[basis, basis] \ (-q[basis])
        end
        return z
    end
    z0 = z_at(0.0)
    z1 = z_at(1.0) .- z0

    # F(x_i) = M z + q, also affine.
    xv0 = zeros(2); xv0[o] = x_o
    _, q0, _ = ms_second_stage_lcp(d, xv0)
    xv1 = zeros(2); xv1[i] = 1.0; xv1[o] = x_o
    _, q1, _ = ms_second_stage_lcp(d, xv1)
    F0 = M * z0 .+ q0
    F1 = (M * (z0 .+ z1) .+ q1) .- F0

    lo, hi = 0.0, Inf
    for k in 1:n
        a, b = (k in basis) ? (z0[k], z1[k]) : (F0[k], F1[k])
        if abs(b) <= 1e-12
            a < -1e-9 && return nothing              # infeasible for every x_i
        elseif b > 0
            lo = max(lo, -a / b)
        else
            hi = min(hi, -a / b)
        end
    end
    lo <= hi + 1e-12 || return nothing

    # The objective, quadratic in x_i on this interval.
    c1 = d.K[i]
    c2 = 0.0
    for s in 1:d.S
        ai = z0[ix2_y(ix, i, s)];  bi = z1[ix2_y(ix, i, s)]
        ao = z0[ix2_y(ix, o, s)];  bo = z1[ix2_y(ix, o, s)]
        A = d.nu[i] - d.alpha[s] + d.beta * (ai + ao)
        B = d.beta * (bi + bo)
        c1 += A * bi + B * ai
        c2 += B * bi
    end
    return (lo, hi, c1, c2)
end

"""
    diagonalize(data; x0, order, maxiter, tol, backend) -> NamedTuple

Diagonalization over the two players: repeatedly replace each player's capacity with its
best response to the current rival capacity, in `order`, until the capacity vector stops
moving.

Returns

  - `x`: the capacity vector at the end
  - `status`: `:converged`, `:cycled` or `:iteration_limit`
  - `iterations`: rounds completed
  - `trajectory`: the capacity vector after each round, starting with `x0`
  - `steps`: the max-norm change in the capacity vector at each round
  - `period`: the cycle length when `status` is `:cycled`, otherwise `0`

Convergence is judged by the step size, never by a round count, and a repeat of an earlier
iterate is detected and reported rather than run out to the limit. Both matter:
diagonalization is sensitive to ordering and starting point and does not always converge,
so a result reported without its convergence behaviour is a weaker claim than one with it.
"""
function diagonalize(d::MSData; x0 = [0.0, 0.0], order = [PLAYER_P, PLAYER_B],
                     maxiter::Int = 100, tol = 1e-9, backend::Symbol = :path)
    x = collect(Float64.(x0))
    trajectory = [copy(x)]
    steps = Float64[]
    for k in 1:maxiter
        previous = copy(x)
        for i in order
            x[i] = best_response(d, i, x; backend = backend).x_i
        end
        push!(trajectory, copy(x))
        step = maximum(abs.(x .- previous))
        push!(steps, step)
        if step <= tol
            return (x = x, status = :converged, iterations = k, trajectory = trajectory,
                    steps = steps, period = 0)
        end
        # A repeat of any earlier iterate other than the immediately preceding one is a
        # cycle: the map is deterministic, so it will repeat for ever.
        for j in 1:(length(trajectory) - 2)
            if maximum(abs.(x .- trajectory[j])) <= tol
                return (x = x, status = :cycled, iterations = k, trajectory = trajectory,
                        steps = steps, period = length(trajectory) - j)
            end
        end
    end
    return (x = x, status = :iteration_limit, iterations = maxiter,
            trajectory = trajectory, steps = steps, period = 0)
end
