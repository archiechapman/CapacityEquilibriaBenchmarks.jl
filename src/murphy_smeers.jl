# Murphy and Smeers (2002 working paper / 2005 OR): the two open-loop models, assembled as
# linear complementarity problems for the engine's `lcp_model`.
#
# Page numbers cite the working paper's printed pages (PDF page = printed + 2). The model
# structure transcribed here:
#
#   players     i ∈ {p, b}: p builds and runs only peakers, b only base plants   (p.12)
#   segments    s = 1..S, unit width, s = 1 the peak segment                    (p.11)
#   demand      pˢ = αˢ − β qˢ,  qˢ = yₚˢ + y_bˢ,  α¹ > … > αˢ,  β > 0          (p.12)
#   costs       Kᵢ per unit capacity, νᵢ per unit output                        (p.11)
#   variables   xᵢ ≥ 0 capacity;  yᵢˢ ≥ 0 output, yᵢˢ ≤ xᵢ;  λᵢˢ ≥ 0 capacity dual
#
# Competitive equilibrium, equations (2)–(3), p.14:
#   0 ≤ yᵢˢ ⟂ −αˢ + β yᵢˢ + β y₋ᵢˢ + νᵢ + λᵢˢ ≥ 0
#   0 ≤ λᵢˢ ⟂ xᵢ − yᵢˢ ≥ 0
#   0 ≤ xᵢ  ⟂ Kᵢ − Σₛ λᵢˢ ≥ 0
#
# Open-loop Cournot equilibrium, equations (5)–(6), p.16: identical except that the own-
# output coefficient in the first line is 2β rather than β (the player sees its effect on
# price). The paper writes both with ωᵢˢ as the slack of the first line; here ωᵢˢ is the
# residual F paired with yᵢˢ rather than a separate variable, which is the same system.
#
# Both are therefore square LCPs  0 ≤ z ⟂ Mz + q ≥ 0  in z = (x, y, λ). The paper itself
# notes the affine-VI structure in (7)–(11), pp.17–18. Nothing here is nonlinear, so the
# engine's `lcp_model` and `lcp_residual` apply unchanged (FINDINGS.md F-0003).

import TOML

const MS_VARIANTS = (:competitive, :open_loop_cournot)

"""
    MSData

One instance of the Murphy–Smeers model. Fields follow the paper's notation; `alpha[s]` is
αˢ, `K[i]` and `nu[i]` are indexed by player with `1 = p` (peaker) and `2 = b` (base).
"""
struct MSData
    name::String
    S::Int
    beta::Float64
    alpha::Vector{Float64}
    K::Vector{Float64}
    nu::Vector{Float64}
end

const PLAYER_P = 1
const PLAYER_B = 2

"""
    load_ms_instance(path) -> MSData

Read an instance from a `data/*.toml` file and check the paper's assumptions on it. The
assumptions are checked here, on load, so that no model can be built from parameters the
paper's results do not cover.
"""
function load_ms_instance(path::AbstractString)
    t = TOML.parsefile(path)
    inst = t["instance"]
    data = MSData(
        String(inst["name"]),
        Int(inst["S"]),
        Float64(inst["beta"]),
        Float64.(inst["alpha"]),
        [Float64(inst["peak"]["K"]), Float64(inst["base"]["K"])],
        [Float64(inst["peak"]["nu"]), Float64(inst["base"]["nu"])],
    )
    check_assumptions(data)
    return data
end

"""
    check_assumptions(data::MSData)

Throw unless `data` satisfies every assumption the paper states on its parameters:
`length(alpha) == S`; `β > 0` and `α¹ > … > αˢ` (p.12); `K_p + ν_p < K_b + ν_b` and
`K_b + S ν_b < K_p + S ν_p` (p.11). Returns `data` so it can be chained.
"""
function check_assumptions(d::MSData)
    length(d.alpha) == d.S || throw(ArgumentError(
        "alpha has $(length(d.alpha)) entries but S = $(d.S)"))
    d.beta > 0 || throw(ArgumentError("beta must be positive (p.12); got $(d.beta)"))
    all(d.alpha[s] > d.alpha[s+1] for s in 1:d.S-1) || throw(ArgumentError(
        "alpha must be strictly decreasing in s (p.12); got $(d.alpha)"))
    Kp, Kb = d.K[PLAYER_P], d.K[PLAYER_B]
    νp, νb = d.nu[PLAYER_P], d.nu[PLAYER_B]
    Kp + νp < Kb + νb || throw(ArgumentError(
        "peakers must be cheaper for one segment: K_p + ν_p < K_b + ν_b (p.11)"))
    Kb + d.S * νb < Kp + d.S * νp || throw(ArgumentError(
        "base plants must be cheaper for all S segments: K_b + Sν_b < K_p + Sν_p (p.11)"))
    return d
end

"""
    peak_segments(data::MSData) -> Int

`S_p`, the number of segments in which peakers are the cost-effective technology: the
largest `s` with `K_p + s ν_p < K_b + s ν_b` (p.14, "Production Efficiency"). The paper's
competitive-case property is that peakers are built and operated only for `s ≤ S_p`.
Throws if the two costs tie at some `s`, since the paper's strict inequalities do not
cover that case.
"""
function peak_segments(d::MSData)
    Kp, Kb = d.K[PLAYER_P], d.K[PLAYER_B]
    νp, νb = d.nu[PLAYER_P], d.nu[PLAYER_B]
    Sp = 0
    for s in 1:d.S
        Kp + s * νp == Kb + s * νb && throw(ArgumentError(
            "K_p + sν_p = K_b + sν_b at s = $s; the paper's production-efficiency " *
            "property assumes strict inequalities"))
        Kp + s * νp < Kb + s * νb && (Sp = s)
    end
    return Sp
end

# --- variable layout -----------------------------------------------------------------------
#
# z = (x_p, x_b, y_p^1..S, y_b^1..S, λ_p^1..S, λ_b^1..S), n = 2 + 4S. The pairing is fixed
# by this layout and nowhere else: row k of F is paired with z[k]. `ms_lcp` builds M and q
# from the same three index functions that `ms_conditions` uses to write F directly, and
# the tests check that the two agree at arbitrary points.

"""
    MSIndex

Positions of the model's variables in the LCP vector `z`: `ix_x(ix, i)`, `ix_y(ix, i, s)`,
`ix_λ(ix, i, s)`.
"""
struct MSIndex
    S::Int
end
Base.length(ix::MSIndex) = 2 + 4 * ix.S
ix_x(ix::MSIndex, i) = i
ix_y(ix::MSIndex, i, s) = 2 + (i - 1) * ix.S + s
ix_λ(ix::MSIndex, i, s) = 2 + 2 * ix.S + (i - 1) * ix.S + s

other(i) = 3 - i

own_coefficient(variant::Symbol) =
    variant === :competitive ? 1.0 :
    variant === :open_loop_cournot ? 2.0 :
    throw(ArgumentError("unknown variant $variant; expected one of $MS_VARIANTS"))

"""
    ms_lcp(data::MSData, variant) -> (M, q, ix)

Assemble the LCP `0 ≤ z ⟂ Mz + q ≥ 0` for `variant ∈ (:competitive, :open_loop_cournot)`.
Feed `M, q` to the engine's `lcp_model` and `lcp_residual`; use `ix` to read the solution.
"""
function ms_lcp(d::MSData, variant::Symbol)
    c = own_coefficient(variant)
    ix = MSIndex(d.S)
    n = length(ix)
    M = zeros(n, n)
    q = zeros(n)
    for i in (PLAYER_P, PLAYER_B)
        # 0 ≤ x_i ⟂ K_i − Σ_s λ_i^s ≥ 0                 (3) p.14 / (6) p.16
        r = ix_x(ix, i)
        q[r] = d.K[i]
        for s in 1:d.S
            M[r, ix_λ(ix, i, s)] = -1.0
        end
        for s in 1:d.S
            # 0 ≤ y_i^s ⟂ −α^s + cβ y_i^s + β y_{−i}^s + ν_i + λ_i^s ≥ 0   (2) p.14 / (5) p.16
            r = ix_y(ix, i, s)
            q[r] = -d.alpha[s] + d.nu[i]
            M[r, ix_y(ix, i, s)] = c * d.beta
            M[r, ix_y(ix, other(i), s)] = d.beta
            M[r, ix_λ(ix, i, s)] = 1.0
            # 0 ≤ λ_i^s ⟂ x_i − y_i^s ≥ 0                 (2) p.14 / (5) p.16
            r = ix_λ(ix, i, s)
            M[r, ix_x(ix, i)] = 1.0
            M[r, ix_y(ix, i, s)] = -1.0
        end
    end
    return M, q, ix
end

"""
    ms_conditions(data::MSData, variant, z) -> Vector

The equilibrium residuals F(z) written directly from the paper's equations, one formula per
row, without going through `M` and `q`. Exists so that the matrix assembly in `ms_lcp` can be
checked against a second transcription of the same equations; it is not used to solve.
"""
function ms_conditions(d::MSData, variant::Symbol, z::AbstractVector)
    c = own_coefficient(variant)
    ix = MSIndex(d.S)
    length(z) == length(ix) || throw(DimensionMismatch(
        "z has length $(length(z)), expected $(length(ix))"))
    F = zeros(Float64, length(ix))
    for i in (PLAYER_P, PLAYER_B)
        x = z[ix_x(ix, i)]
        F[ix_x(ix, i)] = d.K[i] - sum(z[ix_λ(ix, i, s)] for s in 1:d.S)
        for s in 1:d.S
            y, yo, λ = z[ix_y(ix, i, s)], z[ix_y(ix, other(i), s)], z[ix_λ(ix, i, s)]
            F[ix_y(ix, i, s)] = -d.alpha[s] + c * d.beta * y + d.beta * yo + d.nu[i] + λ
            F[ix_λ(ix, i, s)] = x - y
        end
    end
    return F
end

# --- reading a solution ---------------------------------------------------------------------

"""
    MSPoint

A point of the model unpacked into the paper's named quantities. `x[i]`, `y[i, s]`,
`λ[i, s]` with `i = 1` the peaker and `i = 2` the base player; `price[s]` is
`αˢ − β(yₚˢ + y_bˢ)`; `demand[s]` is `yₚˢ + y_bˢ`.
"""
struct MSPoint
    x::Vector{Float64}
    y::Matrix{Float64}
    λ::Matrix{Float64}
    price::Vector{Float64}
    demand::Vector{Float64}
end

function ms_unpack(d::MSData, z::AbstractVector)
    ix = MSIndex(d.S)
    x = [z[ix_x(ix, i)] for i in 1:2]
    y = [z[ix_y(ix, i, s)] for i in 1:2, s in 1:d.S]
    λ = [z[ix_λ(ix, i, s)] for i in 1:2, s in 1:d.S]
    demand = vec(sum(y; dims = 1))
    price = d.alpha .- d.beta .* demand
    return MSPoint(x, y, λ, price, demand)
end

"""
    ms_pack(data::MSData; x_p, x_b, y_p, y_b, lambda_p, lambda_b) -> Vector

The inverse of `ms_unpack`: build `z` from named quantities, e.g. from the hand-derived
solution in `data/*_expected.toml`.
"""
function ms_pack(d::MSData; x_p, x_b, y_p, y_b, lambda_p, lambda_b)
    ix = MSIndex(d.S)
    z = zeros(length(ix))
    z[ix_x(ix, PLAYER_P)] = x_p
    z[ix_x(ix, PLAYER_B)] = x_b
    for s in 1:d.S
        z[ix_y(ix, PLAYER_P, s)] = y_p[s]
        z[ix_y(ix, PLAYER_B, s)] = y_b[s]
        z[ix_λ(ix, PLAYER_P, s)] = lambda_p[s]
        z[ix_λ(ix, PLAYER_B, s)] = lambda_b[s]
    end
    return z
end

"""
    load_ms_expected(data::MSData, path, variant) -> Vector

Read a hand-derived solution from a `data/*_expected.toml` file into `z` layout.
"""
function load_ms_expected(d::MSData, path::AbstractString, variant::Symbol)
    t = TOML.parsefile(path)[String(variant)]
    return ms_pack(d; x_p = t["x_p"], x_b = t["x_b"], y_p = Float64.(t["y_p"]),
                   y_b = Float64.(t["y_b"]), lambda_p = Float64.(t["lambda_p"]),
                   lambda_b = Float64.(t["lambda_b"]))
end

# --- the paper's stated properties, as checks on a point --------------------------------------
#
# Each function measures one property the paper states, so that a test can threshold it.
# They read a point, never a solver.

"""
    investment_criterion_gap(data, variant, pt::MSPoint) -> (p = Δ_p, b = Δ_b)

Per player, `|K_i − Σ_s max(pˢ − markup − ν_i, 0)|` where the markup is `0` in the
competitive case (p.15, "Investment Criterion") and `β x_i` in the open-loop Cournot case
(p.16, last display). The paper states this as an equality whenever the player invests;
for a player with `x_i = 0` it is not asserted and `NaN` is returned.
"""
function investment_criterion_gap(d::MSData, variant::Symbol, pt::MSPoint)
    gap = zeros(2)
    for i in 1:2
        if pt.x[i] <= 0
            gap[i] = NaN
            continue
        end
        markup = variant === :competitive ? 0.0 : d.beta * pt.x[i]
        gap[i] = abs(d.K[i] - sum(max(pt.price[s] - markup - d.nu[i], 0.0) for s in 1:d.S))
    end
    return (p = gap[PLAYER_P], b = gap[PLAYER_B])
end

"""
    pricing_efficiency_gap(data, pt::MSPoint; tol) -> Float64

Competitive case only (p.15, "Pricing Efficiency"): in every segment the price equals
`ν_p + λ_pˢ` when the peaker is at capacity, `ν_p` when it is strictly interior, and
`ν_b + λ_bˢ` for the base player in every segment where it produces. Returns the largest
violation across the segments where each clause applies.
"""
function pricing_efficiency_gap(d::MSData, pt::MSPoint; tol = 1e-7)
    worst = 0.0
    for s in 1:d.S
        yp, xp = pt.y[PLAYER_P, s], pt.x[PLAYER_P]
        if yp > tol && abs(xp - yp) <= tol
            worst = max(worst, abs(pt.price[s] - (d.nu[PLAYER_P] + pt.λ[PLAYER_P, s])))
        elseif yp > tol
            worst = max(worst, abs(pt.price[s] - d.nu[PLAYER_P]))
        end
        if pt.y[PLAYER_B, s] > tol
            worst = max(worst, abs(pt.price[s] - (d.nu[PLAYER_B] + pt.λ[PLAYER_B, s])))
        end
    end
    return worst
end

"""
    production_efficiency_holds(data, pt::MSPoint; tol) -> Bool

Competitive case only (p.14): peakers operate only in segments `s ≤ S_p` and base plants
operate in every segment.
"""
function production_efficiency_holds(d::MSData, pt::MSPoint; tol = 1e-7)
    Sp = peak_segments(d)
    peak_ok = all(pt.y[PLAYER_P, s] <= tol for s in Sp+1:d.S)
    base_ok = all(pt.y[PLAYER_B, s] > tol for s in 1:d.S)
    return peak_ok && base_ok
end

"""
    segment_type(data, pt::MSPoint, s; tol) -> Symbol

The segment's class in the paper's five-way partition (13), p.22: `:a` both players at
capacity, `:b` both strictly interior, `:c` one at capacity and the other interior, `:d`
one idle and the other interior, `:e` one idle and the other at capacity. Returns
`:other` for a pattern outside those five, such as both players idle.
"""
function segment_type(d::MSData, pt::MSPoint, s::Int; tol = 1e-7)
    status(i) = pt.y[i, s] <= tol ? :idle :
                abs(pt.x[i] - pt.y[i, s]) <= tol ? :capacity : :interior
    sp, sb = status(PLAYER_P), status(PLAYER_B)
    (sp, sb) == (:capacity, :capacity) && return :a
    (sp, sb) == (:interior, :interior) && return :b
    (:capacity, :interior) in ((sp, sb), (sb, sp)) && return :c
    (:idle, :interior) in ((sp, sb), (sb, sp)) && return :d
    (:idle, :capacity) in ((sp, sb), (sb, sp)) && return :e
    return :other
end
