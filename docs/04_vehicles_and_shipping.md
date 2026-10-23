# Pojazdy i przepustowość transportu

> **Status S/N:** dane i wykonania funkcji transportu; 12 typów pojazdów, do 17 miejsc floty. Pobór jaj na ewentualne ekspedycje petów pozostaje propozycją. [Statusy](CURRENT_SPEC.md).

Pojemności podano w jajach/minutę; w symulacji należy dzielić je przez 60. Tabele poniżej są danymi referencyjnymi, nie wynikami testów implementacji.

## Flota i pojemności

Limit floty i limit długości pociągu to osobne wymiary. Graviton Coupling nie dodaje slotów floty.

| Indeks silnika | Pojazd | Jaja/min przed badaniami |
|---:|---|---:|
| 0 | TRIKE | 5000 |
| 1 | TRANSIT VAN | 15000 |
| 2 | PICKUP | 50000 |
| 3 | 10 FOOT | 100000 |
| 4 | 24 FOOT | 250000 |
| 5 | SEMI | 500000 |
| 6 | DOUBLE SEMI | 1000000 |
| 7 | FUTURE SEMI | 5000000 |
| 8 | MEGA SEMI | 15000000 |
| 9 | HOVER SEMI | 30000000 |
| 10 | QUANTUM TRANSPORTER | 50000000 |
| 11 | HYPERLOOP TRAIN | 50000000 |

Suma przepustowości to suma pojemności zakupionych pojazdów. `GDR::modifiedVehicleCapacity` stosuje właściwe mnożniki do rodzaju pojazdu; nie należy mnożyć każdego pojazdu przez wszystkie kategorie bonusów. `getVehicleCapacity` mnoży wynik przez `trainLength` tylko dla pojazdu z flagą Hyperloop. Dla Hyperloop bazowe 50 000 000 jaj/min jest pojemnością jednego wagonu.

## Stacja i długość Hyperloop

`getHyperloopStationPrice()` zwraca dokładnie **50 000 GE**. Zakup stacji jest trwałym odblokowaniem. Zakup pociągu i kolejnych wagonów to osobne operacje.

Bazowy limit długości wynosi 5. Badanie **Graviton Coupling**, identyfikator `micro_coupling`, ma 5 poziomów po +1: limit 10. W tabeli konfiguracji referencyjnej `tier_raw=11`, czyli Tier 12 przy numeracji od 1. `attemptBuyTrainCar` odrzuca zakup, gdy bieżąca długość osiąga `GDR.hyperloopMaxTrainLength()`; samo wywołanie funkcji ceny nie sprawdza tego limitu.

## Cena następnego wagonu

```text
n = obecna długość wskazanego pociągu, przed zakupem
x = N10 + (N11 - N10) * (n / 11)
CarPrice(n+1) = 0.05 * PriceCurve.farmValue(0.6 * x)
               * VEHICLES[11].price_param * GDR.vehicleCostMult()
```

To wzór dla zwykłej farmy. `N10` i `N11` to referencyjne populacje z `calcVehiclePriceInfo()`, a nie liczba kur na farmie. W wariancie referencyjnym wynoszą odpowiednio **928 561 970** i **8 643 788 739**. Dzielnik 11 jest stały także przy limicie 5. Cena wagonu nie zależy od numeru slotu ani liczby innych pociągów.

Nie obowiązuje wcześniejsza formuła `0.05 * TrainCost(slot) * 3.2^(c-2)`. Cena nowego pojazdu używa innej gałęzi: współczynnika `(liczba już posiadanych pojazdów tego typu + 1)/(referencyjna liczba + 1)`. Nie można używać jej jako ceny wagonu.

`PriceCurve.farmValue` całkuje odcinkami liniową krzywą wartości kurczaka metodą trapezów. Współczynnik interpolacji wewnątrz odcinka jest zaokrąglany do float32. Obie referencyjne tablice punktów, referencyjne populacje oraz współczynnik pojazdu zapisano w dokumentacji referencyjnej. Nie zastępować tej krzywej pojedynczą potęgą lub zaokrąglonym cennikiem UI.

Wariant Virtue wybiera drugą krzywą, inny cache referencji i współczynnik 1 zamiast 0.6. Zwykłych cen nie stosować do Virtue.

### Wyniki funkcji referencyjnej bez zniżek

| Zakup wagonu | Cena w bocks |
|---:|---:|
| 2 | 1.95907204982e+36 |
| 3 | 1.52026422408e+37 |
| 4 | 6.61345205802e+37 |
| 5 | 2.0679404952e+38 |
| 6 | 5.22481999976e+38 |
| 7 | 1.1380977221e+39 |
| 8 | 2.22745225835e+39 |
| 9 | 4.10940858382e+39 |
| 10 | 7.20927722388e+39 |

30 wywołań funkcji referencyjnej dla długości 1–10 w slotach 0, 5 i 16 zgodziło się z modelem referencyjnym. Wartość ceny dla długości 10 służy testowi funkcji; zakup wagonu 11 jest zablokowany. To ceny wewnętrzne konfiguracji referencyjnej, bez formatowania UI.

## Ograniczenie transportu

W każdym kroku symulacji liczba sprzedanych jaj jest ograniczana przez przepustowość i przez jaja przeznaczone na inne cele. Bez paliwa/forge/tanku:

```text
shipped = min(population * eggLayingRatePerSecond * dt,
              totalShippingPerMinute / 60 * dt)
```

Usunięcie rakiet na rzecz petów jest zmianą projektu Roblox: należy jawnie określić, czy nadal istnieje pobór jaj na ekspedycje. Szczegóły offline: [10. Audyt zgodności](10_verified_simulation_and_server_config.md).

## Dane referencyjne w projekcie

Pełne 204 ceny pojazdów i populacje referencyjne: [infrastructure.json](reference_data/infrastructure.json). Obie tablice po 500 punktów: [price_curves.json](reference_data/price_curves.json). Nie zaokrąglać ich do skrótów UI.
