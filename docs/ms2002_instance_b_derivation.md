# Instance B: derivation of both open-loop equilibria

*Instance B (`data/ms2002_instance_b.toml`) is the "reasonable" benchmark: four quarter-year
load blocks, a gas peaker against a combined-cycle plant, GW and $/MWh. It is too large to
guess the segment regime by hand with confidence, so the regime is taken from the exhaustive
enumeration in `src/enumerate_lcp.jl`, which finds exactly one solution for each model, and
the equilibrium is then derived from the paper's conditions on that regime and checked by
substitution. Fractions are exact. The results are in `data/ms2002_instance_b_expected.toml`.
Page numbers are the working paper's printed pages.*

## The instance

| Symbol | Value | Constraint it satisfies |
|---|---|---|
| S | 4 | — |
| β | 10 $/MWh per GW | β > 0 (p.12) |
| α | (150, 115, 100, 90) $/MWh | strictly decreasing (p.12) |
| K_p, ν_p | 24, 30 $/MWh | K_p + ν_p = 54 < 68 = K_b + ν_b (p.11) |
| K_b, ν_b | 50, 18 $/MWh | K_b + Sν_b = 122 < 144 = K_p + Sν_p (p.11) |

S_p = 2: peakers are cost-effective for s ≤ 2 (54 < 68, 84 < 86) and not for s = 3
(114 > 104), with no tie.

## Competitive equilibrium (equations (2)–(3), p.14)

Enumeration gives the regime: s = 1 both at capacity (type a); s = 2 peaker interior, base
at capacity (c); s = 3 peaker idle, base at capacity (e); s = 4 peaker idle, base interior
(d). Derive from it:

- s = 1: the peaker's only scarcity rent, so λ_p¹ = K_p = 24 and p¹ = ν_p + λ_p¹ = 54,
  hence q¹ = (150 − 54)/10 = 9.6.
- s = 2: peaker interior, p² = ν_p = 30, q² = (115 − 30)/10 = 8.5.
- s = 4: base interior, p⁴ = ν_b = 18, q⁴ = y_b⁴ = (90 − 18)/10 = 7.2, λ_b⁴ = 0.
- s = 3: base at capacity, p³ = ν_b + λ_b³. Base investment: K_b = Σ_s λ_b^s =
  (54 − 18) + (30 − 18) + λ_b³ + 0 = 48 + λ_b³, so λ_b³ = 2, p³ = 20, and
  x_b = q³ = (100 − 20)/10 = 8.
- Then y_p² = q² − x_b = 0.5, x_p = y_p¹ = q¹ − x_b = 1.6, and the peaker is idle in s = 3
  with slack ν_p − p³ = 10 and in s = 4 with slack 12.

**Solution.** x = (8/5, 8); y_p = (8/5, 1/2, 0, 0); y_b = (8, 8, 8, 36/5);
λ_p = (24, 0, 0, 0); λ_b = (36, 12, 2, 0); p = (54, 30, 20, 18).

**Substitution.** First line, s = 1: −150 + 96 + 30 + 24 = 0; −150 + 96 + 18 + 36 = 0.
s = 2: −115 + 85 + 30 = 0; −115 + 85 + 18 + 12 = 0. s = 3: peaker −100 + 80 + 30 = 10 ≥ 0
with y_p³ = 0; base −100 + 80 + 18 + 2 = 0. s = 4: peaker −90 + 72 + 30 = 12 ≥ 0; base
−90 + 72 + 18 = 0 with y_b⁴ = 7.2 < 8 and λ_b⁴ = 0. Capacity: x_p − y_p = (0, 1.1, 1.6, 1.6)
against λ_p = (24, 0, 0, 0); x_b − y_b = (0, 0, 0, 0.8) against λ_b = (36, 12, 2, 0).
Investment: 24 − 24 = 0, 50 − 50 = 0. Strictly complementary throughout.

**Properties.** Production efficiency (p.14): peakers only in s ≤ 2. Pricing efficiency
(p.15): p¹ = ν_p + λ_p¹, p² = ν_p, p^s = ν_b + λ_b^s for all s. Investment criterion (p.15):
Σ max(p^s − 30, 0) = 24 = K_p; Σ max(p^s − 18, 0) = 36 + 12 + 2 + 0 = 50 = K_b.

## Open-loop Cournot equilibrium (equations (5)–(6), p.16)

Enumeration gives the regime: s = 1 both at capacity (a); s = 2 and s = 3 base at capacity,
peaker interior (c); s = 4 both interior (b). Derive from it, writing the own-output
coefficient 2β = 20:

- s = 4, both interior: −90 + 20y_p + 10y_b + 30 = 0 and −90 + 20y_b + 10y_p + 18 = 0, i.e.
  2y_p + y_b = 6 and y_p + 2y_b = 7.2, so y_p⁴ = 8/5, y_b⁴ = 14/5.
- s = 2, peaker interior against base at capacity x_b: y_p² = (85 − 10x_b)/20;
  λ_b² = 97 − 20x_b − 10y_p² = 109/2 − 15x_b.
- s = 3, likewise: y_p³ = (70 − 10x_b)/20; λ_b³ = 82 − 20x_b − 10y_p³ = 47 − 15x_b.
- s = 1, both at capacity: λ_p¹ = K_p = 24 gives −150 + 20x_p + 10x_b + 30 + 24 = 0, so
  2x_p + x_b = 48/5; and λ_b¹ = 132 − 20x_b − 10x_p.
- Base investment: K_b = λ_b¹ + λ_b² + λ_b³ = 467/2 − 50x_b − 10x_p = 50. Substituting
  10x_p = 48 − 5x_b gives 371/2 − 45x_b = 50, so **x_b = 271/90** and
  **x_p = (48/5 − 271/90)/2 = 593/180**.

Then y_p² = (85 − 271/9)/20 = 247/90, y_p³ = (70 − 271/9)/20 = 359/180,
λ_b¹ = 132 − 542/9 − 593/18 = 233/6, λ_b² = 109/2 − 271/6 = 28/3, λ_b³ = 47 − 271/6 = 11/6.
Consistency: y_p² = 2.744 and y_p³ = 1.994 are below x_p = 3.294; y_p⁴ = 1.6 < x_p and
y_b⁴ = 2.8 < x_b = 3.011; all λ ≥ 0; λ_b sums to 233/6 + 56/6 + 11/6 = 300/6 = 50.

**Solution.** x = (593/180, 271/90); y_p = (593/180, 247/90, 359/180, 8/5);
y_b = (271/90, 271/90, 271/90, 14/5); λ_p = (24, 0, 0, 0); λ_b = (233/6, 28/3, 11/6, 0);
p = (1565/18, 517/9, 899/18, 46).

**Substitution.** Done in exact rational arithmetic on the assembled LCP: every residual is
zero, every variable and residual nonnegative, every product zero; the Float64 point in the
expected file is within 7e-15 of the exact one. Strictly complementary throughout.

**Properties.** Theorem 1 (p.19): x_b > 0. Investment criterion (p.16):
Σ max(p^s − 10x_p − 30, 0) = (1565/18 − 593/18 − 30) = 972/18 − 30 = 24 = K_p, the other
segments negative; Σ max(p^s − 10x_b − 18, 0) = 233/6 + 28/3 + 11/6 + 0 = 50 = K_b. Lemma 5
(p.21): in s = 4, y_p = 1.6 < 2.8 = y_b. Lemma 11 (p.27): the peaker is at capacity only in
s = 1, where the base is too. Corollary 1 (p.20): the base is at capacity in s = 1, 2, 3.
Lemma 12 (p.29): λ_p = (24, 0, 0, 0) in both equilibria. The peaker runs in s = 3 and 4,
beyond S_p = 2, as p.16 allows; under competition it is idle in both.

## Comparison

| | Competitive | Open-loop Cournot |
|---|---|---|
| x_p, x_b (GW) | 1.6, 8.0 | 3.29, 3.01 |
| Total capacity (GW) | 9.6 | 6.31 |
| Prices ($/MWh) | 54, 30, 20, 18 | 86.9, 57.4, 49.9, 46.0 |
| Peaker share of capacity | 17% | 52% |

Cournot withholds a third of the capacity, raises the peak price by 60% and the base price
by 155%, and shifts the mix toward the peaker: the base player, whose withholding moves
prices in every segment, has more to gain from being small.
