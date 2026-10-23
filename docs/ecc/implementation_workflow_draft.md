# Proponowany proces realizacji HatchTheEgg

> **Aktualizacja procesu 23.10.2026:** ten dokument zachowuje wcześniejszy szkic ECC (H/P). Do planowania HatchTheEgg po porównaniu z workflow GrowASnack używać [etapów](../workflow/IMPLEMENTATION_STAGES.md) i [WORKFLOW](../workflow/WORKFLOW.md). Nie przenosić wcześniejszych bramek liczby ADR/terminów ani wydaniowych placeholderów. Materiały techniczne ECC pozostają referencjami P; nie uruchomiono żadnego etapu.

Data: 2026-10-23. Źródło wzorców: ECC (MIT, [affaan-m/ECC@90606c8](https://github.com/affaan-m/ECC/tree/90606c8315ee09cafc303515c5f33024db6b9882)). Nie rozpoczyna implementacji — to szkic procesu do przeglądu.

> [!IMPORTANT]
> Ten dokument opisuje **jak** organizować pracę, nie **co** implementować. Zasady adaptacji i zakres premiery są zatwierdzone zgodnie z `docs/CURRENT_SPEC.md` oraz dokumentami 22, 25 i 26. Bilans gry pozostaje **odłożony** — jego propozycje (w tym w dokumentach 17–21) nie są zatwierdzonymi parametrami produkcyjnymi i nie podlegają zmianom tutaj.

## Zasady procesu

1. **Vertical slices** — każdy etap daje działający kawałek gry od serwera po UI, nie "cały backend, potem cały frontend"
2. **Serwer-first** — logika ekonomii i zapisu na serwerze, klient dostaje gotowe wyniki
3. **Testy referencyjne** — porównanie z zapisanymi wynikami z docs (FV, SE, kalendarz), nie arbitralne 80% coverage
4. **Cold-start context** — każdy etap ma brief czytelny bez poprzedniego etapu (blueprint pattern)
5. **Istniejące docs jako source of truth** — CURRENT_SPEC.md, WORKING_CONTEXT.md, 22–26 rozstrzygają sprzeczności

*Wzorce 1–4 zaadaptowane z ECC `blueprint`, `story-lifecycle`, `planner` i `tdd-workflow`. Zasada 5 jest specyficzna dla HTE.*

## Faza 0 — przygotowanie (przed implementacją)

### 0.1 — Kontekst domeny
- [ ] Stworzyć `docs/CONTEXT.md` — glosariusz terminów gry → kod: Farm Value, Soul Eggs, prestiż, tier, wariant, itp.
- [ ] Zmapować terminologię docs → planowane nazwy modułów Luau

*Wzorzec: `context-and-decisions` — "co te pojęcia biznesowe znaczą".*

### 0.2 — Decyzje techniczne (ADR)
- [ ] ADR-0001: Format zapisu gracza (DataStore key structure, wersjonowanie schematu, token generacji blokady sesji D07)
- [ ] ADR-0002: Reprezentacja liczb, precyzja i zaokrąglenia (zakres double do 1.79e308 vs precyzja całkowitoliczbowa do 2^53-1 dla dokładnych liczników: GE, pity, ekwipunek; tolerancja zaokrągleń; zachowanie referencyjnego typu double dla SE i FV z kodu modelu referencyjnym bez zmiany wzorów)
- [ ] ADR-0003: Struktura modułów klient/serwer (ServerScriptService vs ReplicatedStorage vs Shared)
- [ ] ADR-0004: Framework testowy (TestEZ / własne asercje / runner Luau)
- [ ] ADR-0005: Wzorzec komunikacji klient↔serwer (RemoteEvent vs RemoteFunction, format odpowiedzi sieciowej)

*Wzorzec: `architecture-decision-records` — Context → Decision → Alternatives → Consequences.*

### 0.3 — Plan implementacji
- [ ] Podzielić zakres D06 na epiki i stories (format story-lifecycle)
- [ ] Stworzyć dependency graph między epikami
- [ ] Zidentyfikować minimalny vertical slice (Epic 1)

*Wzorzec: `blueprint` — Research → Design → Draft → Review → Register.*

### Kryterium przejścia do Fazy 1
- CONTEXT.md istnieje z min. 20 terminami
- Min. 3 ADR-y zatwierdzone (zapis, BigNum, moduły)
- Plan z epikami i stories istnieje w docs
- WORKING_CONTEXT.md zaktualizowany

## Faza 1 — rdzeń farmy (minimal vertical slice)

### Epic 1: Jedno jajo, badania, kurnik, transport

**Story 1.1 — Serwerowy model ekonomii**
- Moduł: `EconomyEngine` (ServerStorage)
- Zakres: mnożniki badań (Common), produkcja per kurnik, transport, ograniczenie sprzedaży
- Test: porównanie z wynikami FV z [02](../02_eggs_and_farm_value.md)
- Acceptance: `EconomyEngine.calculateIncome(state)` zwraca wartość zgodną z referencją ±ε

**Story 1.2 — Zapis gracza**
- Moduł: `PlayerDataStore` (ServerScriptService)
- Zakres: zapis/odczyt, wersjonowanie, migracja, jedna aktywna sesja (D07)
- Test: zapis → odczyt → porównanie, symulacja reconnect
- Acceptance: D07 spełnione — jedna sesja, brak duplikacji, idempotentny odbiór

**Story 1.3 — Klient: farma i UI**
- Zakres: rendering farmy, przyciski badań, kurnik, transport
- Server: RemoteFunction do kupna badań, RemoteEvent do aktualizacji stanu
- Acceptance: gracz widzi farmę, może kupić badanie, produkcja rośnie

**Story 1.4 — Symulacja offline**
- Moduł: `OfflineSimulation` (ServerScriptService)
- Zakres: away branch (>60s), kroki do 0.3s, ograniczenie silosami, dochód away 0.5/1
- Test: porównanie z wynikami [10](../10_verified_simulation_and_server_config.md)
- Acceptance: offline nalicza dochód zgodnie z potwierdzonymi regułami

### Kryterium przejścia
- Gracz może wejść, kupować badania, widzieć produkcję
- Offline nalicza poprawnie
- Zapis działa z jedną aktywną sesją
- Testy referencyjne FV i offline przechodzą

## Faza 2 — prestiż i jaja

### Epic 2: Soul Eggs, zmiana jaja, prestiż

**Story 2.1 — Soul Eggs (SE)**
- Moduł: `PrestigeEngine` (SharedModule → Server)
- Zakres: funkcja przedziałowa (wykładniki 0.15–0.21), Soul Beacon/Feather
- Test: porównanie z wynikami [05](../05_prestige_soul_eggs_and_boosts.md)

**Story 2.2 — Zmiana jaja i prestiż**
- Zakres: Common reset, Epic zachowane, boosty zachowane z czasem
- Test: scenariusz prestiż → nowa farma → wyposażenie poprawne

**Story 2.3 — 19 jaj**
- Zakres: pełna ścieżka jaj, Enlightenment z ograniczeniami D03
- Test: progresia przez min. 3 jaja z prestiżem

### Kryterium przejścia
- Prestiż działa, SE naliczane poprawnie
- Zmiana jaja resetuje właściwe rzeczy
- Enlightenment blokuje pety i boosty (D03)

## Faza 3 — boosty, drony, paczki, kalendarz

### Epic 3: Systemy wspierające

**Story 3.1 — Boosty**
- Sumowanie jednej kategorii, Beacony mnożące aktywne. Czas zużywany przez symulację
- D07: idempotentna aktywacja, czas nie cofa się

**Story 3.2 — Drony i paczki**
- D05: limit 2+1, stały wynik od utworzenia, brak wygaśnięcia
- Rozkłady z [06](../06_drones_silos_and_events.md) i [16](../16_pet_stacking_offline_and_package_schedule.md)

**Story 3.3 — Kalendarz**
- 28-dniowy cykl, min(cap, base×2^m), PE do 24 cykli
- Test: porównanie z tabelą [15](../15_calendar_gameplay_formula_and_roblox_scope.md)

**Story 3.4 — Podwajacz**
- D04: pierwszy darmowy/dzień UTC, następne GE. 2+0.5×level h (do 8h)
- Nadpisywanie terminu, odliczanie offline

### Kryterium przejścia
- Boosty sumują się poprawnie, czas upływa
- Drony spawn, paczki z limitem 2+1
- Kalendarz 28 dni z poprawnymi nagrodami
- Podwajacz ×2 z darmowym/płatnym dziennym

## Faza 4 — pety

### Epic 4: System petów

**Story 4.1 — Inkubacja i pozyskiwanie**
- Tier I–V, gatunki, inkubator
- Bez zatwierdzonych cen/czasów — placeholder values

**Story 4.2 — Wyposażenie i efekty**
- P[d] = 1 + sum(b_i[d]), Hawk → min(1, pBase×P)
- Przed zmianą zestawu rozliczyć czas starym wyposażeniem

**Story 4.3 — Łączenie (ewolucja)**
- D01: tier×cel, +10pp Pro, porażka→zachowaj bazowego, zużyj kopie, gwarancja
- D07: jedna trwała operacja, idempotentna

### Kryterium przejścia
- Pety mają efekt na ekonomię
- Łączenie zachowuje bazowego, zużywa materiały
- Gwarancja śledzi postęp

## Faza 5 — monetyzacja i produkty

### Epic 5: Pro, Buy MAX, GE

**Story 5.1 — Pro Permit (trwały GamePass)**
- Korzyści: silosy, pełna jakość offline, sloty boostów, sloty petów, +10 p.p. do łączenia (D01/D25)
- Sprawdzanie uprawnienia po stronie serwera przez `MarketplaceService:UserOwnsGamePassAsync` (nie przechodzi przez ProcessReceipt)
- D26: wariant A — +10 p.p. niedostępne dla kont nieuprawnionych, pozostałe korzyści Pro działają; jasny opis przed zakupem, bez zamiennika w v1

**Story 5.2 — Buy MAX (osobny trwały GamePass, poza Pro)**
- Szybki zakup maksymalnej dostępnej i opłacalnej liczby badań (nie daje darmowych poziomów)
- Sprawdzanie uprawnienia po stronie serwera przez `MarketplaceService:UserOwnsGamePassAsync`

**Story 5.3 — Pakiety GE i rozbicie Piggy (Developer Products — zakupy powtarzalne)**
- Realizowane wyłącznie przez serwerowy callback `MarketplaceService.ProcessReceipt`
- D07: unikalny identyfikator `PurchaseId`, atomowy zapis przyznania waluty w DataStore przed zwróceniem `PurchaseGranted`; zwrot `NotProcessedYet` przy błędzie lub niepewności

### Kryterium przejścia
- Trwałe GamePassy Pro Permit i Buy MAX weryfikowane poprawnie przez `UserOwnsGamePassAsync`
- Zakupy powtarzalne GE i Piggy rozliczane jednokrotnie przez `ProcessReceipt` z unikalnym `PurchaseId`
- Brak możliwości podwójnego naliczenia przy reconnectach (D07)

## Faza 6 — wydarzenia, trofea, samouczek, polish

### Epic 6: Systemy pozostałe D06

**Story 6.1 — Wydarzenia**
- Harmonogram serwera, typy z [11](../11_periodicals_calendar_events_and_boost_rules.md)
- Rozliczanie offline z faktycznym czasem wydarzenia

**Story 6.2 — Trofea**
- Progi populacji per jajo, nagrody jednorazowe
- Retroaktywne uznanie po samouczku

**Story 6.3 — Samouczek**
- Krótki czynnościowy: wylęg → badanie → kurnik → transport → dron → zmiana jaja → prestiż

**Story 6.4 — UI mobile i optymalizacja**
- Dotyk, scrollowanie, performance na mobilnym

---

## Wzorce pracy per story (zaadaptowane z ECC)

### Przed implementacją story
1. Przeczytaj brief story (cold-start) i powiązane docs
2. Sprawdź CURRENT_SPEC.md — co ma status N/S/R a co P
3. Sprawdź TODO.md — czy coś jest odłożone
4. Zidentyfikuj testy referencyjne z docs

### Podczas implementacji
1. **Serwer first** — logika w ServerScriptService/ServerStorage
2. **Walidacja wejść** — każdy RemoteEvent/RemoteFunction waliduje argumenty (adaptacja ECC security checklist)
3. **Result pattern** — `{ok, value}` / `{ok=false, error}` dla operacji serwerowych (adaptacja ECC error-handling)
4. **Małe pliki** — ModuleScripts 200-400 linii (adaptacja ECC coding-style)
5. **Immutability where practical** — nowe tabele zamiast mutacji state (adaptacja ECC immutability principle)

### Po implementacji story
1. Testy referencyjne przechodzą
2. Przegląd: walidacja wejść, idempotencja, brak hardcoded values
3. Zaktualizuj WORKING_CONTEXT.md i TODO.md
4. Zapisz handoff notes (co zrobiono, co dalej, otwarte kwestie)

*Wzorce: `verification-loop` (checklist), `delivery-gate` (end-of-story checklist), `unified-memory` (handoff format).*

### Handoff między sesjami/asystentami
```
## Handoff — [data]

### Stan
- Ukończone: [lista stories]
- W trakcie: [story ID] — co zrobiono, co zostało

### Decyzje podjęte w tej sesji
- [decyzja] — [uzasadnienie]

### Otwarte kwestie
- [kwestia] — [kontekst]

### Następna akcja
- [konkretny krok]

### Pliki zmienione
- [ścieżka] — [co zmieniono]
```

*Wzorzec: `unified-memory` — handoff body states: objective, evidence, files, remaining work, next action.*

## Czego ECC nie zapewnia — wymaga własnego projektu

| Obszar | Co trzeba zaprojektować od zera |
|---|---|
| Roblox DataStore | Wzorzec zapisu: klucze (max 50 znaków), payload JSON (do 4 MB), wersjonowanie schematu, obsługa dynamicznych budżetów zapytań per typ operacji (`GetRequestBudgetForRequestType`) i kolejek throttlingu |
| Duże liczby i precyzja w Luau | Rozróżnienie zakresu (double do ~1.79e308), precyzji całkowitej ($2^{53}-1$ dla dokładnych liczników: GE, pity, ekwipunek, txns), tolerancji zaokrągleń oraz ewentualnego zapisu dużej kwoty farmy |
| Symulacja offline | Algorytm kroków 0.3s z produkcją/transportem/silosami i oknem czasowym — specyfika HatchTheEgg |
| Klient↔serwer Roblox | Wzorzec RemoteEvent/RemoteFunction, ścisła walidacja typów i argumentów, serwerowy rate limiting |
| UI mobilne Roblox | Roblox GUI framework, obsługa dotyku, skalowanie ekranowe, optymalizacja pamięciowa |
| Ekonomia gry | Wszystkie zatwierdzone formuły FV, SE, boostów, petów i kalendarza — z istniejących dokumentów |
| Roblox Marketplace | Rozdzielenie: `UserOwnsGamePassAsync` dla trwałych GamePassów (Pro, Buy MAX) vs `ProcessReceipt` dla powtarzalnych Developer Products (GE, Piggy) |
| Idempotencja i Session Lock | Blokada sesji z unikalnym tokenem generacji, Compare-And-Swap w `UpdateAsync`, rejestr transakcji, deterministyczny czysty callback zapisu |
| Testy referencyjne Luau | Środowisko testowe Luau (TestEZ lub runner asercji) uruchamiające wektory z dokumentacji (statusy N, S, R) |
| Zabezpieczenia Roblox | Model zerowego zaufania do klienta, ochrona przed floodingiem RemoteEvent, brak danych biznesowych w ReplicatedStorage |
