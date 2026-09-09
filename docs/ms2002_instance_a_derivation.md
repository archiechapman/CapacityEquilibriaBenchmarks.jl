# Instance A: hand derivation of both open-loop equilibria

*The paper publishes no numbers (`FINDINGS.md` F-0001). This note derives, by hand, the
equilibria of the constructed instance in `data/ms2002_instance_a.toml` from the paper's
equilibrium conditions, and checks each by substitution. The results are recorded in
`data/ms2002_instance_a_expected.toml` and are one of the three independent routes the
tests compare — the others being exhaustive enumeration and PATH. Page numbers are the
working paper's printed pages.*

## The instance

| Symbol | Value | Constraint it satisfies |
|---|---|---|
| S | 3 | — |
| β | 1 | β > 0 (p.12) |
| α | (20, 15, 10) | α¹ > α² > α³ (p.12) |
| K_p, ν_p | 2, 3 | K_p + ν_p = 5 < 8 = K_b + ν_b (p.11) |
| K_b, ν_b | 7, 1 | K_b + Sν_b = 10 < 11 = K_p + Sν_p (p.11) |

Peakers are cost-effective for s ≤ S_p where K_p + S_p ν_p < K_b + S_p ν_b and the reverse at
S_p + 1 (p.14): 2 + 6 = 8 < 9 and 2 + 9 = 11 > 10, so S_p = 2.

## Competitive equilibrium (equations (2)–(3), p.14)

The conditions, for i = p, b and s = 1, 2, 3:

    0 ≤ y_i^s ⟂ −α^s + β(y_p^s + y_b^s) + ν_i + λ_i^s ≥ 0
    0 ≤ λ_i^s ⟂ x_i − y_i^s ≥ 0
    0 ≤ x_i  ⟂ K_i − Σ_s λ_i^s ≥ 0

Write p^s = α^s − β(y_p^s + y_b^s). Guess the regime that production efficiency (p.14)
suggests — peakers run in s = 1, 2 only, base at capacity in every segment, peaker at
capacity in s = 1 only — and solve, then verify every condition.

- s = 1: both at capacity. Peaker's λ_p¹ is its only positive scarcity rent, so K_p = λ_p¹
  gives λ_p¹ = 2 and p¹ = ν_p + λ_p¹ = 5.
- s = 2: peaker interior, so p² = ν_p = 3 and λ_p² = 0.
- s = 3: peaker idle, so p³ ≤ ν_p; base at capacity with p³ = ν_b + λ_b³.
- Base investment: K_b = Σ_s λ_b^s = (p¹ − ν_b) + (p² − ν_b) + (p³ − ν_b) = 4 + 2 + (p³ − 1),
  so p³ = 2. This satisfies p³ = 2 ≤ ν_p = 3 (peaker idle is consistent, with slack
  ω_p³ = ν_p − p³ = 1) and λ_b³ = 1 > 0.

Quantities from p^s = α^s − q^s: q = (15, 12, 8). Base capacity x_b = y_b³ = 8 (base at
capacity in s = 3 and, by Corollary 1, in s = 1, 2). Then y_p² = q² − x_b = 4, and
x_p = y_p¹ = q¹ − x_b = 7. Check y_p² = 4 < x_p = 7, so the peaker really is interior in s = 2.

**Solution.** x = (7, 8); y_p = (7, 4, 0); y_b = (8, 8, 8); λ_p = (2, 0, 0); λ_b = (4, 2, 1);
p = (5, 3, 2).

**Substitution.** Residuals of the first line: s = 1: −20 + 15 + 3 + 2 = 0 and
−20 + 15 + 1 + 4 = 0. s = 2: −15 + 12 + 3 + 0 = 0 and −15 + 12 + 1 + 2 = 0. s = 3: peaker
−10 + 8 + 3 = 1 ≥ 0 with y_p³ = 0; base −10 + 8 + 1 + 1 = 0. Capacity lines: x_p − y_p =
(0, 3, 7) against λ_p = (2, 0, 0); x_b − y_b = (0, 0, 0) against λ_b > 0. Investment:
2 − 2 = 0 and 7 − 7 = 0 with both x > 0. Every pair is strictly complementary.

**Properties.** Production efficiency: peakers run in s = 1, 2 = S_p only; base everywhere.
Pricing efficiency (p.15): p¹ = ν_p + λ_p¹, p² = ν_p, p^s = ν_b + λ_b^s for all s.
Investment criterion (p.15): Σ_s max(p^s − ν_p, 0) = 2 + 0 + 0 = K_p and
Σ_s max(p^s − ν_b, 0) = 4 + 2 + 1 = K_b.

## Open-loop Cournot equilibrium (equations (5)–(6), p.16)

Only the first line changes: the own-output coefficient becomes 2β.

    0 ≤ y_i^s ⟂ −α^s + 2β y_i^s + β y_{−i}^s + ν_i + λ_i^s ≥ 0

Try the competitive regime first: it fails. With base at capacity and the peaker idle in
s = 3, the base line gives λ_b³ = 9 − 2x_b ≥ 0, so x_b ≤ 4.5, while the peaker's line
requires −10 + x_b + 3 ≥ 0, so x_b ≥ 7. Contradiction. With the peaker idle and the base
interior in s = 3, y_b³ = 4.5 and the peaker's residual is −10 + 4.5 + 3 < 0, so the peaker
wants to produce. Hence the peaker operates in s = 3 — which the paper says can happen in
this model (p.16: "Peak plants may indeed operate in time segments s > S_p").

Both interior in s = 3: 2y_p + y_b = 7 and y_p + 2y_b = 9, so y_p³ = 5/3, y_b³ = 11/3, and
λ³ = 0 for both; this needs x_p > 5/3 and x_b > 11/3.

Both interior in s = 2 would give y_p² = 10/3, y_b² = 16/3, so it needs x_b > 16/3. Try
instead both at capacity in s = 1 and only there: K_b = λ_b¹ gives 2x_b + x_p = 12 and
K_p = λ_p¹ gives 2x_p + x_b = 15, so x_b = 3 — below 16/3 and below 11/3, contradicting
both s = 2 and s = 3. So the base is at capacity in s = 2 as well, and λ_b¹ + λ_b² = 7.

- s = 1, both at capacity: peaker λ_p¹ = K_p = 2 gives 2x_p + x_b = 15; base
  λ_b¹ = 19 − 2x_b − x_p.
- s = 2, peaker interior, base at capacity: y_p² = (12 − x_b)/2 and
  λ_b² = 14 − 2x_b − y_p² = 8 − 3x_b/2.
- K_b: λ_b¹ + λ_b² = 27 − 7x_b/2 − x_p = 7, so x_p + 7x_b/2 = 20. With
  x_p = (15 − x_b)/2 this gives 3x_b = 25/2, so **x_b = 25/6** and **x_p = 65/12**.

Consistency: x_b = 25/6 > 11/3 (base interior in s = 3), x_p = 65/12 > 5/3 (peaker
interior in s = 3); y_p² = (12 − 25/6)/2 = 47/12 < 65/12 (peaker interior in s = 2);
λ_b² = 8 − 25/4 = 7/4 > 0; λ_b¹ = 19 − 25/3 − 65/12 = 63/12 = 21/4 > 0; λ_b¹ + λ_b² = 7.

**Solution.** x = (65/12, 25/6); y_p = (65/12, 47/12, 5/3); y_b = (25/6, 25/6, 11/3);
λ_p = (2, 0, 0); λ_b = (21/4, 7/4, 0); p = (125/12, 83/12, 14/3).

**Substitution.** s = 1: peaker −20 + 130/12 + 50/12 + 3 + 2 = −20 + 15 + 5 = 0; base
−20 + 100/12 + 65/12 + 1 + 21/4 = −20 + 165/12 + 25/4 = −20 + 13.75 + 6.25 = 0. s = 2: peaker
−15 + 94/12 + 50/12 + 3 = −15 + 12 + 3 = 0; base −15 + 100/12 + 47/12 + 1 + 7/4 =
−15 + 12.25 + 2.75 = 0. s = 3: −10 + 10/3 + 11/3 + 3 = 0; −10 + 22/3 + 5/3 + 1 = 0. Capacity:
x_p − y_p = (0, 3/2, 15/4) against λ_p = (2, 0, 0); x_b − y_b = (0, 0, 1/2) against
λ_b = (21/4, 7/4, 0). Investment: 2 − 2 = 0, 7 − 7 = 0. Every pair is strictly
complementary.

**Properties.** Theorem 1 (p.19): x_b > 0. Investment criterion (p.16):
Σ_s max(p^s − βx_p − ν_p, 0) = (125/12 − 65/12 − 3) + 0 + 0 = 2 = K_p and
Σ_s max(p^s − βx_b − ν_b, 0) = 21/4 + 7/4 + 0 = 7 = K_b. Lemma 5 (p.21): in s = 3, where
base capacity is slack, y_p³ = 5/3 < 11/3 = y_b³. Lemma 11 (p.27): the peaker is at capacity
only in s = 1, where the base is too. Lemma 12 (p.29): λ_p = (2, 0, 0) in both equilibria.
Segment types in the partition (13) of p.22: s = 1 type (a), s = 2 type (c), s = 3 type (b).

## Comparison

| | Competitive | Open-loop Cournot |
|---|---|---|
| x_p, x_b | 7, 8 | 5.4167, 4.1667 |
| Total capacity | 15 | 9.5833 |
| Prices | 5, 3, 2 | 10.4167, 6.9167, 4.6667 |
| Peaker in s = 3 | idle | 1.6667 |

Cournot withholds capacity and raises every price, as the paper's Theorem 7 (p.29) has it
for the competitive–open-loop pair, and the open-loop peaker runs in the base segment
where the competitive one does not.
