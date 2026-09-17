# Decoding Customer Value — A SQL-Driven Retention Strategy

**Customer Value Intelligence for a US-based D2C fashion brand — 3,900 customers, 27 engineered features, 12 SQL analyses, a 4-panel founder dashboard, and an executable retention playbook.**

`Python` · `SQL (MS SQL Server)` · `Power BI`

## The business problem

A direct-to-consumer fashion brand sells clothing, accessories, footwear and outerwear across the United States. No physical stores, no third-party retailers — every customer relationship is owned by the brand. It runs a promotional discount program and has grown steadily, but it has never built any structured intelligence on top of its own transaction data.

The founding team cannot answer the question its entire marketing budget depends on:

> **Is the discount program building a loyal customer base, or is it just renting volume from one-time bargain hunters?**

**The core constraint:** the dataset has **no loyalty score, no churn label and no timestamps**. Every concept used here — value, loyalty, promotion dependency, tenure — had to be *constructed and defended*, not assumed.

---

## Headline findings

| # | Finding | Evidence |
|---|---------|----------|
| 1 | **Discounting does not buy loyalty.** Organic customers out-score discount-receiving customers on loyalty at *every single value tier*. | Premium tier: Organic **0.491** vs Subscriber 0.367 vs Promo Opportunist 0.362 (Q-A2) |
| 2 | **Value is driven by repeat behaviour, not basket size.** Premium vs Low customers differ by only **$16** in average spend, but by **19 previous purchases** and a **144×** loyalty gap. | Premium $69 / 34 purchases / 0.433 loyalty vs Low $53 / 15 / 0.003 (Q-A1) |
| 3 | **Frequency × tenure is the strongest predictor of value.** Neither alone is sufficient. | Loyal + Weekly = **100% Premium**, loyalty 0.949. Loyal + Quarterly = **0% Premium** despite identical tenure (Q-C1) |
| 4 | **Occasional discount use ≠ disloyalty.** The Low-Dependency band has the highest loyalty in the entire base — higher even than pure Organic. | Low Dependency: 264 customers, **0.503** loyalty vs Organic 0.173 (Q-B2) |
| 5 | **There is a discount the brand can stop paying for today.** 38 Subscribers show 0.945 loyalty against **0.050** dependency — the discount is not what is retaining them. | Q-G1 → Phase 1 of the sunset plan |
| 6 | **Category and season are dead ends.** Loyalty varies by <0.01 across categories and <0.02 across seasons — behaviour beats merchandising as a segmentation axis. | Q-D1, Q-D2 |
| 7 | **Promotional strategy should be geographically differentiated.** Organic share ranges from 43.0% (Indiana) to 76.2% (Kansas). | Q-E1 |

---



---

## Method

### 1 · Data cleaning

| Issue found | Decision | Rationale |
|---|---|---|
| 37 missing `Review Rating` (0.95%) | Median imputation | Too small to drop rows; median is robust to rating outliers |
| `Promo Code Used` ≡ `Discount Applied` for every row | Dropped `Promo Code Used` | Perfectly redundant — would double-count in any composite feature |
| `Fortnightly`/`Bi-Weekly`, `Quarterly`/`Every 3 Months` | Consolidated labels | Required before numeric encoding |
| Binary categoricals stored as text | Encoded to 0/1 | Enables SQL aggregation and composite scoring |

Validation confirmed 3,900 **unique** Customer IDs (one row = one customer) and that every customer had ≥1 previous purchase — i.e. this is an existing-customer base, not an acquisition funnel.

### 2 · Feature engineering — from 17 attributes to 27

Every feature below exists to answer a question the brand actually asked. Metrics that sound analytical but don't lead to a decision were deliberately left out.

**`promo_persona`** — Subscription Status × Discount Applied →
`Subscriber` (enrolled, discounted) · `Promo Opportunist` (non-subscriber, buys only on discount) · `Organic` (buys with no incentive).
*Why:* this is the single feature that separates genuine brand pull from purchased volume. Everything downstream leans on it.

**`purchase_frequency_score`** — categorical frequency → annual purchase equivalent (Weekly = 52, Bi-Weekly = 26, Monthly = 12, Quarterly = 4, Annually = 1).
*Why:* ordinal ranking (1–5) would claim Weekly is 5× Annually. It is 52×. Preserving true magnitude matters for any composite.

**`tenure_tier`** — `Previous Purchases` → New / Growing / Established / Loyal, on **purchase-count quartiles**.
*Why:* quartiles are data-driven and balanced; arbitrary thresholds are unfalsifiable.

**`promo_dependency_score`** ∈ [0, 1]

```
dependency = Discount × (1 − 0.5·Frequency_norm − 0.5·Tenure_norm)
```

*Why:* receiving a discount is not the same as *needing* one. Dependency is the discount flag **discounted by the customer's own behavioural strength** — a frequent, long-tenured discount user scores low; an infrequent, new discount user scores near 1. Non-discounted customers score exactly 0. Min-max normalisation keeps frequency and tenure contributing equally despite different scales.

**`value_tier`** — CLV proxy, percentile-ranked into Low / Medium / High / Premium

```
raw_value = Purchase Amount × Previous Purchases × Purchase Frequency Score
```

*Why:* with no timestamps and no revenue history, value must be a composite of the three dimensions that survive: how much, how often, how long. Percentile ranking avoids arbitrary currency cutoffs and keeps tiers comparable.

**`loyalty_score`** — the project's principal metric

```
loyalty = Frequency_norm × Tenure_norm × (1 − dependency) × (1 + 0.2·Satisfaction)
```

*Why multiplicative, not additive:* loyalty requires **all** conditions simultaneously. An additive score would let a high-frequency discount addict average out to "loyal". The multiplicative form drives such a customer toward zero — which is the correct business answer. Satisfaction enters as a 20% modifier rather than a core term, because a good review without repeat behaviour is sentiment, not loyalty.

Supporting features: `satisfaction_flag` (rating ≥ 4.0), `age_group`, `is_premium_shipping` (price-insensitivity proxy), `is_digital_payer` (channel reachability proxy).

#### Choosing the loyalty definition

Two candidate definitions were considered:

| | Definition A — behavioural only | Definition B — behaviour net of promotion *(adopted)* |
|---|---|---|
| Formula | `Frequency_norm × Tenure_norm` | `Frequency_norm × Tenure_norm × (1 − dependency) × (1 + 0.2·Satisfaction)` |
| Treats a weekly discount-only buyer as | Highly loyal | Near zero |
| Answers the brand's actual question? | No — it measures *activity* | Yes — it measures *retention that survives discount withdrawal* |
| Internal consistency check | Ranks Subscribers and Organics identically at equal frequency/tenure (Q-B1 shows tenure ≈25–26 and frequency ≈16–17 across **all three** personas) | Correctly separates them: Organic 0.170 > Subscriber 0.128 > Promo Opportunist 0.113 |

Definition A fails the decisive test: because tenure and frequency are near-identical across all three personas, it would declare the three groups equally loyal and give the founding team no basis for any decision. Definition B is adopted.

### 3 · SQL analysis layer — 12 queries, 5 business questions

| Query | Business question |
|---|---|
| **A1** Customer pyramid | What separates high-value from low-value customers? |
| **A2** Persona × value tier | Are Premium customers organic or discount-driven? |
| **B1** Loyalty by persona | Who is genuinely loyal vs discount-triggered? |
| **B2** Dependency bands | How does loyalty move with promotional reliance? |
| **C1** Frequency–tenure matrix | Which behaviours predict long-term value? |
| **C2** Satisfaction vs loyalty | Does experience quality translate into retention? |
| **D1 / D2** Category & season | Are merchandising axes useful for segmentation? |
| **E1** Geographic opportunity | Which markets show organic demand vs discount-driven volume? |
| **E2** High-potential markets | Where should marketing spend expand? (spend > $60 **and** loyalty > 0.15) |
| **F1** Ideal customer profile | What does the best customer look like? |
| **G1** Promotion sunset | Which segments can lose the discount without losing the customer? |

Every claim in the playbook is traceable to a named query — no assertion in this repo exists without a query behind it.

### 4 · Founder dashboard (Power BI)

Built for a **non-technical** founding team: four panels, no analyst required.

1. **Customer pyramid** — how value is distributed across the base
2. **Promo dependency vs retention** — who needs the discount and who doesn't, by segment
3. **Geographic opportunity map** — high spend × low dependency = genuine brand pull, not discount demand
4. **Category funnel** — entry-point vs retention categories by purchase history

---

## The retention playbook

### Promotional sunset plan

Loyalty and dependency move almost perfectly in opposite directions as tenure and frequency rise. That inverse relationship is the lever.

| Phase | Segment | Customers | Loyalty | Dependency | Action | Timeline |
|---|---|---|---|---|---|---|
| **1** | Loyal + Weekly | 38 | 0.945 | 0.050 | Remove standing discount, replace with non-monetary perk (early access, free shipping) | Weeks 1–4, monitor to Week 8 |
| **2** | Established + Weekly | 46 | 0.569 | 0.183 | Step down in 3 stages, not a cut | Weeks 5–11 |
| **3** | Loyal + Bi-Weekly | 70 | 0.320 | 0.314 | 20% reduction on a randomised half, control retained | Weeks 9–17 |
| **4** | Growing + Weekly | 40 | 0.280 | 0.312 | Same controlled pilot | Weeks 9–17 |
| **Hold** | New / Monthly / Quarterly / Annual | 700+ | ≤0.12 | 0.44–0.93 | Continue full discount support | Quarterly review |

**The trade-off, stated plainly:** Phase 1 recovers the highest margin per customer but carries the risk that the loyalty score overstated genuine attachment. The kill-switch is explicit — **if week-over-week purchase frequency drops more than 10–15%, or the cohort falls out of the Loyal tenure tier, the phase is paused.** Phases 3 and 4 sit at ~6× Phase 1's dependency, so they run as A/B pilots and only generalise if the test group stays within 5% of control.

### Ideal customer profile

Defined as the intersection of **Premium value tier** (top quartile of spend × tenure × frequency) and **Organic persona** (zero promotional dependency by construction) — commercially valuable *and* structurally loyal.

| Attribute | Finding |
|---|---|
| Age | 36–50 and 51–70 — mature bands outperform every younger cohort |
| Gender | Roughly even split across top micro-segments |
| Category | Accessories, Footwear, Clothing |
| Share of base | Premium = 25.0%; Organic = 57.0% |

**Top micro-segments by loyalty:** 36–50 F / Accessories (20 customers, 0.588) · 36–50 M / Footwear (11, 0.572) · 51–70 F / Outerwear (8, 0.557) · 51–70 F / Footwear (21, 0.556) · **51–70 M / Clothing (45, 0.555)**.

**The acquisition recommendation:** build lookalike audiences on **51–70 Male / Clothing** — the largest micro-segment above 0.5 loyalty, so it offers both scale and quality — and **do not lead acquisition creative with a discount code**. This profile is defined by the *absence* of promotional dependence; a discount-first funnel structurally recruits the opposite persona.

---

## What this project demonstrates

- Constructing defensible business metrics where none exist in the data, and justifying each one against a decision it enables
- Choosing between competing metric definitions on internal-consistency grounds rather than intuition
- Translating a 12-query SQL layer into a phased operating plan with named triggers, timelines, success metrics and stated downside risk
- Communicating to a non-technical audience without diluting the analytical basis

---
