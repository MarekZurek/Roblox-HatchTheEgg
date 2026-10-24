# IMP-04 — czysta produkcja i badania

Status: **INTERNAL_TEST_ONLY**, dane referencyjne bez zatwierdzenia konfiguracji produkcyjnej. Brak zmian bilansu.

Moduł `src/server/FarmMath/production_research.luau` tworzy API przez `new(codec, catalog, {mode="INTERNAL_TEST_ONLY"})`. Wymaga NumericCodec v1 i katalogu pierwszej farmy. Nie wykonuje zakupów, zapisu ani mutacji argumentów.

- `research(commonLevels)` składa siedem obsługiwanych badań. Brak poziomu oznacza zero. Zwraca punkty Common, tempo jaj/kura/s, wartość jaja, refill/s, pojemność wylęgarni, IHR/kurnik/min i mnożniki kurników oraz transportu.
- `tierUnlocked(levels,tierRaw)` używa inkluzywnego progu; `canResearch(levels,id)` rozdziela `TIER_LOCKED` i `MAX_LEVEL`. Cena nie jest wagą punktów. Epic nie są dopisywane do sumy Common.
- `capacities(levels,habitatTypes)` wymaga czterech slotów, `false` oznacza pusty; `ceil` stosowane osobno do każdego kurnika.
- `shippingPerSecond(levels,vehicleTypes)` przyjmuje do czterech pojazdów pierwszego zakresu i przelicza jaja/min na jaja/s.
- `productionStep(state,dt)` przyjmuje `commonLevels`, `habitatTypes`, `settledPopulation` (cztery kanoniczne teksty uint64), `vehicleTypes` i opcjonalny aktywny `rcbMultiplier` (domyślnie 1). `dt` mieści się w 0–0.3 s. Wynik zawiera produkcję, sprzedaż, dochód oraz ich tempa. Wyłącznie zasiedlona populacja produkuje. Przychód nie jest FV ani dopisaniem do salda.

Profil z jakimkolwiek nieobsługiwanym ID Common jest odrzucany, także przy poziomie zero. Moduł nie udaje obsługi wszystkich 56 badań. Epic oraz zaawansowane modyfikatory nie są parametrem tego wycinka. Populacja przechodzi jawne `ExactUInt.toSafeNumber` i musi mieścić się w wybranej pojemności; wynik deklaruje `EXACT_SAFE_INTEGER`. Obsługa szerszych profili i nadmiaru pojemności po zmianie wyposażenia pozostaje poza pierwszą farmą, bez kasowania kur i bez cichego przycięcia.

Źródła: [01](../01_upgrades_and_research.md), [03](../03_habitats_and_population.md), [04](../04_vehicles_and_shipping.md), [10](../10_verified_simulation_and_server_config.md), [27](../27_numbers_time_and_player_state_contract.md), [30](../30_first_farm_manifest_and_technical_choices.md), [31](../31_research_hatching_rcb_and_new_account.md). Bazy: jajo 0.25, znoszenie 1/30 s, refill 3/s, zapas 250. Poziom zerowy nie dodaje efektu. Ceny nie są obliczane w tym module.

Testy L: `tests/math/run.luau`; raport `build/math-results.json`. Oczekiwania z prostych rachunków i dokumentowanych wymiarów, bez użycia funkcji badanej do generowania wyniku. Testy obejmują każdy dozwolony poziom, progi 29/30/31 i 79/80/81, zaokrąglenia pojemności, transport, odrzucenie NaN/nieskończoności i niebezpiecznej konwersji populacji. Studio i DataStore nie są testowane. Kolejność produkcja → IHR i zegar należą do przyszłego koordynatora, nie do tej funkcji.
