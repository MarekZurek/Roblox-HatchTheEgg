# Beta: balance of nine monetization offers

Date: 2026-11-04. Status: **PROPOSAL â€” NOT APPLIED**.

User scope: balance the nine monetization offers first. Farm progression, pets,
research costs in Diamonds and deferred balance documents 17â€“21 remain outside scope.

## Reproducible evidence

Run `.tools/lune-0.11.1/lune.exe run tools/audit_monetization.luau` from the repository root.
The audit reads the actual EpicPricing module, FeatureAvailability and research
reference data, then compares them against
`monetization_beta_candidate_2026_11_04.json`. Detailed results are written to
`build/monetization-balance-audit.json`.

The run passed for all **485 levels across 16 available Epic researches**.
Assertions check that every proposed direct offer costs at least the proportional
value of its Diamonds at the best proposed package rate, and at most 2.5 times it.
This is an offer consistency audit, not an end-to-end purchase test.

## Current problem

Using the proposed Diamond packages (1,000 for 99 R$, 10,000 for 799 R$), the best
rate is 0.0799 R$/Diamond. The current direct Epic offers range from 0.03955 to
112.64080 times that proportional value. For example, a 25,000-Diamond level can
be bought directly for 79 R$, approximately 25.3 times cheaper than its proportional
Diamond value. A 1-Diamond level also costs 9 R$, approximately 112.6 times its
proportional value. These are rate comparisons, not claims that fractional packages
can be purchased. Current bands depend on reference prices, while Diamond costs
are calculated separately.

The large Diamond package gives **23.9% more Diamonds per Robux** than the small
package. Store copy must use that figure, not a claim of 50% extra value.

## Approved nine offers

| Catalog ID | Beta price | Benefit / eligibility |
| --- | ---: | --- |
| pro_permit | 499 R$ | Existing PRO benefits; no increase in multipliers |
| buy_max | 149 R$ | Existing bulk-purchase convenience; upgrades still consume Cash |
| double_cash | 299 R$ | Existing permanent 2x egg Cash income |
| ge_pack_small | 99 R$ | 1,000 Diamonds |
| ge_pack_large | 799 R$ | 10,000 Diamonds |
| epic_upgrade_9 | 9 R$ | One eligible Epic level costing 50â€“100 Diamonds |
| epic_upgrade_19 | 19 R$ | One eligible Epic level costing 101â€“200 Diamonds |
| epic_upgrade_39 | 39 R$ | One eligible Epic level costing 201â€“450 Diamonds |
| epic_upgrade_79 | 79 R$ | One eligible Epic level costing 451â€“900 Diamonds |

Epic levels below 50 or above 900 Diamonds would be **Diamonds only**; the
researches themselves remain available. This product-rule change was explicitly approved by the user before implementation.
Keeping four fixed prices for single-level credits across the entire current cost
range cannot eliminate both extreme overpricing and extreme discounts.

The proposed direct offers cover **146 levels**: 11 / 18 / 47 / 70 levels in
the four respective bands. The other **339 levels** use Diamonds. The measured
direct-price ratio becomes **1.08469â€“2.35802** times the best package rate.
These consistency targets are proposed design choices, not existing approved KPIs.

Pass prices are a Beta hypothesis within the previously documented ranges, not
validated optimal prices. There is no conversion, retention or willingness-to-pay
telemetry. PRO is already strong: with constant farm production and 20 minutes of
daily activity, its existing offline rules produce an illustrative 5.5x daily Cash
ratio with one session, or 3.79x with two evenly spaced sessions. This excludes
growth, caps other than offline duration, and progression effects. Double Cash
can further multiply income. These figures do not justify increasing PRO benefits.

## Implementation scope

1. Update shared Epic offer selection by actual Diamond cost; keep base costs intact.
2. Update server eligibility and client display for Diamonds-only levels. Do not
   display SOON for an available research merely lacking a direct Robux offer.
3. Preserve already purchased credits, persisted intents and receipt deduplication;
   do not discard paid value when the active offer changes.
4. Add boundary/available-catalog tests and regressions for receipts, cancellation,
   persistence and reconnect. Update store descriptions and release documentation.
5. Configure and connect the nine products in private Beta, then validate purchase,
   cancellation and reconnect. Actual charged purchases require a spending limit;
   do not describe simulated tests as actual purchases.

## Cloud state and remaining validation

All nine offers now exist in universe 10774701473 / place 110937489000525,
**HatchTheEgg - Beta**. IDs and base prices are recorded in the candidate JSON
and the server-only `src/server/BetaProducts.luau` module. Managed pricing is off.
Roblox Plus account discounts may still reduce the final platform price; a 10%
discount was observed on the test account without changing approved base prices.

Configuration and test evidence, publication version and remaining limitations
are maintained in [the implementation report](monetization_beta_validation_2026_11_04.md).
Pass-price optimality remains NOT ASSESSED pending Beta telemetry.
