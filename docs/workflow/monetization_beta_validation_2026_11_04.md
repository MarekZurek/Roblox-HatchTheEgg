# Nine approved offers: private Beta implementation and validation

Date: 2026-11-04. Scope: nine offers approved by the user, Epic direct purchases
only for levels costing 50–900 Diamonds. No changes to pets, their balance,
base research costs, farm production or deferred documents 17–21.

## Environment and configuration

Universe **10774701473**, place **110937489000525**, named **HatchTheEgg - Beta**.
Creator Hub retains a four-player limit. Tests used one Studio client/server,
the owner account 11647593962, and real DataStore
`HatchTheEgg_PlayerProfile_v1` / `player:11647593962` with memory mode disabled.
This is not a hosted Roblox Player or two-account purchase test.

| Catalog ID | Roblox ID | Base price | Contents / Diamond-cost band |
| --- | ---: | ---: | --- |
| pro_permit | 2069996186 | 499 R$ | Existing permanent PRO benefits |
| buy_max | 2070469851 | 149 R$ | Existing bulk research purchase convenience |
| double_cash | 2067026331 | 299 R$ | Existing permanent 2x egg Cash income |
| ge_pack_small | 3728329433 | 99 R$ | 1,000 Diamonds |
| ge_pack_large | 3728329472 | 799 R$ | 10,000 Diamonds |
| epic_upgrade_9 | 3728320227 | 9 R$ | One level costing 50–100 Diamonds |
| epic_upgrade_19 | 3728329222 | 19 R$ | One level costing 101–200 Diamonds |
| epic_upgrade_39 | 3728329301 | 39 R$ | One level costing 201–450 Diamonds |
| epic_upgrade_79 | 3728329363 | 79 R$ | One level costing 451–900 Diamonds |

All nine offers are on sale, managed pricing off. Platform GetProductInfo verified
their names and availability. Roblox Plus on the owner account lowers final prices
to 450 / 135 / 270 / 90 / 720 / 9 / 18 / 36 / 72 R$ respectively. Base prices are
unchanged; the native window is authoritative for the final account price.

`src/server/BetaProducts.luau` contains the durable mapping and enables it only
when both universe and place match Beta. Other environments keep Main's Number
attribute configuration. Fixtures 1001/2001 are not used for Beta offers.

## Runtime and store changes

- EpicPricing selects by actual Diamond cost, including ceil(reference/2).
  Server preparation rejects out-of-band direct purchases with DIAMONDS_ONLY;
  projection omits these offers, and UI explains DIAMONDS ONLY instead of SOON.
- Existing paid credits and historical pending intents are retained. Receipt
  fulfillment still honors a previously promised level even outside new bands.
- Large-package copy now states 23.9% more Diamonds per Robux at base prices.
  Pack descriptions advertise available Epic Research; boost purchases are SOON.
- Native receipts are normalized at Main's boundary to PlayerId, ProductId and
  PurchaseId. CurrencyType EnumItems and unrelated metadata do not enter JSON
  persistence/fingerprints. Reward amounts come from the server catalog.
- Trusted PlatformPurchase / GrantEntitlement jobs use the current revision when
  executed by the single writer. Remote player commands retain revision checks.
  A historical receipt rejected solely as STALE_REVISION uses a deterministic
  recovery operation while preserving its old record and receipt-token dedupe.
- Rejected purchase-domain operations retain the original profile, including the
  absence of optional ledgers; they cannot become UNKNOWN due to initialization
  side effects on a rejected draft.

## Fail → fix → pass evidence

All commands run from the repository root with pinned Lune 0.11.1.

| Regression | Observed failure | Corrected result |
| --- | --- | --- |
| `lune run tests/monetization_beta/run.luau` before band change | reference 98 (49 Diamonds) incorrectly offered Epic II | Boundary/eligibility tests PASS |
| Same suite with native CurrencyType | Main returned NotProcessedYet instead of PurchaseGranted | Native receipt-envelope tests PASS |
| Same suite with a receipt arriving during another write | Retrying stayed NotProcessedYet after durable STALE_REVISION | Concurrent write and historical recovery tests PASS |
| `lune run tests/persistence_startup/run.luau`, unavailable-product rejection | UNKNOWN instead of durable REJECTED due to mutated draft | 160 assertions PASS |

The new Beta suite has **122 assertions**, including all nine IDs/prices,
configuration isolation, both Diamond boundaries, cancellation callbacks,
native-type receipts, duplicate receipts, restart, historical intent fulfillment,
concurrency and recovery. Updated Epic suite has **138 assertions**, including
the real headless client/HUD path and disabled out-of-band Robux actions.

The full runner is `tools/test.ps1 -PythonExecutable
C:/Users/Marek/AppData/Local/Python/pythoncore-3.14-64/python.exe`.
It includes the new suite and the updated 49-module build boundary. Results and
remaining external gaps must not be promoted to blanket release approval.

## Actual Studio observations

1. Cold start resumed approximately 83 minutes of saved offline simulation. It
   eventually reached READY automatically, but took several minutes at the
   bounded simulation budget. This latency is a remaining UX/performance concern.
2. The native Roblox prompt explicitly stated that this was a test purchase and
   the account would not be charged. **No real Robux were spent.**
3. Canceling the small-package native prompt left GE=10 and no processed receipt.
   After the receipt-format fix, its normal shop button → terms preview → native
   purchase path awarded exactly 1,000 Diamonds (GE=1,010).
4. The large-package native test awarded exactly 10,000 more (GE=11,010).
5. All four Epic native test purchases awarded exactly one unselected credit in
   their respective bands. These prompts were opened by temporary client-only
   scripts calling MarketplaceService; they did not grant resources directly.
6. Clicking USE on Hatchery Turbocharger (`epic_clucking`) consumed the Epic I
   credit once and set level 1. GE remained 11,010. Credits became 0/1/1/1.
7. A further native Epic I prompt was canceled on the corrected build. No credit,
   level, Diamond balance or receipt count changed.
8. Stop → new Play restored GE=11,010, level 1, credits 0/1/1/1, all three owned
   passes, and exactly six successful processed receipts. Client showed READY.
9. After final Stop, uncached DataStore read confirmed the same values and a
   released lease: ownerToken="", endsAtMs=0, generation="15".

An initial native Epic attempt exposed the revision race and remained rejected
without a grant. It was a free Studio simulation, not a charged purchase. Recovery
of historical STALE_REVISION is covered by the headless regression; no manual
DataStore patch or invented payment was used to erase that failure.

Recorded snapshots: [Studio evidence JSON](monetization_beta_studio_evidence_2026_11_04.json).
The final reconnect log also contains a Studio publication network failure and an
avatar asset timeout; these are retained as observed environmental limitations.
Temporary `_BetaQASnapshot` observers were server-only, read-only and installed
after publication; all observers and client prompt scripts were removed before
final publication. Studio is left in Edit mode; sync helper processes are stopped.

## Remaining external checks

- Native purchase and native cancellation of **passes by an account that does not
  own them**: NOT RUN. Roblox reports all three owned by the creator. Ownership
  restore was verified; success/cancel handlers and persistence were exercised
  with controlled platform ports in Lune. These are different levels of evidence.
- Real charged purchases / platform retry delivery on a hosted server: NOT RUN.
  Studio native test receipts plus real DataStore do not establish that result.
- Independent read-only review: NOT RUN. Pass-price optimality and conversion
  remain NOT ASSESSED pending Beta telemetry.
- Long-offline CONNECTING latency needs attention before wider playtests.

## Final verification and delivery state

- **Published private version 8**, Creator Hub timestamp 2026-11-04 22:36
  Europe/Warsaw. Verified with the published-only version-history filter.
- Creator Hub Overview explicitly reports private game access and private audience;
  the place access form still shows four players after publication.
- Full `tools/test.ps1` runner **exit 0**, **59 Lune suites**, generation checks,
  Python regressions and final scoped release verification passed. The three
  checklist regressions also passed after the documentation update.
- Audit of all 485 active Epic levels passed against the approved configuration:
  146 direct Robux levels, 339 Diamonds-only; direct price is 1.08469–2.35802 times
  proportional Diamond value at the best base package rate.
- Final read-only source comparison: all **51 Lua source containers** match the
  filesystem exactly, zero temporary QA artifacts; Studio left in Edit.
- Source base commit and SHA256 of the seven changed runtime files are recorded
  in the evidence JSON. Working-tree changes are not committed or pushed in this
  task. No pet-balance files changed.
- Version 7 contained the successful final native purchase tests; version 8 also
  includes the rejected-draft preservation fix. Reconnect was tested on that final
  source before publication; observers were removed before the verified upload.
- A transient publication network failure was resolved by retrying the Studio
  Publish command. An immediate post-Stop cached lease observation was not treated
  as authoritative: the subsequent uncached read confirmed release.

Overall result: **implemented and verified within the recorded Studio + DataStore
scope; full external monetization sign-off remains incomplete** for the account
and hosted-server cases listed above.
