# Dostawa kandydata wydania HatchTheEgg (REL-01 / #36): integracja i jawne bramki

Data: **24.10.2026**  
Status: **Kandydat wydania (Release Candidate) zrealizowany, zweryfikowany na poziomie L i zatwierdzony.**  
Repozytorium: `MarekZurek/Roblox-HatchTheEgg`  
Zgłoszenie nadrzędne: [#1](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/1) (`[PLAN] HatchTheEgg — mapa zadań i równoległych ścieżek`)  
Zamknięte zgłoszenie: [#36](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/36) (`[REL-01] Kandydat wydania: integracja i jawne bramki`)

---

## 1. Zakres i cel kandydata wydania

Zadanie `REL-01` stanowi zwieńczenie i integrację całego 36-zadaniowego backlogu implementacyjnego gry HatchTheEgg:
- **Etap Podstawowy (Farma Domowa)**: `DOC-01..05`, `PRE-01..03`, `IMP-01..15`, `QA-01` (#2–#25) — udokumentowane w [docs/40](40_first_farm_completion_delivery.md).
- **Etap Rozszerzeń Domenowych (NEXT-01..10)**:
  - `NEXT-01` (#26): Farm Value & Soul Eggs (`FarmMath/fv_se.luau`)
  - `NEXT-02` (#27): Zmiana jaja, prestiż i księgowanie sesji (`ProgressActions.luau`)
  - `NEXT-03` (#28): Pełne offline, boosty, Video Doubler i historia (`EffectsManager.luau`, `TimelineSimulation.luau`)
  - `NEXT-04` (#29): Ekwipunek petów, wyposażenie i składanie efektów (`pets/equipment.luau`)
  - `NEXT-05` (#30): Łączenie petów, ochrona slotów/locków i trwała gwarancja (`pets/fusion.luau`)
  - `NEXT-06` (#31): Autorytatywne drony, walka, nagrody GE/Cash i pojedynczy claim (`rewards/drones.luau`)
  - `NEXT-07` (#32): Kanały dostaw 2+1, darmowe odrzucenie, dzienny bonus i rezerwacje (`rewards/offers.luau`)
  - `NEXT-08` (#33): Skalowanie kalendarza 28 dni, konwersje nagród i 19 trofeów jaj (`rewards/calendar.luau`, `rewards/trophies.luau`)
  - `NEXT-09` (#34): Adapter produktów Pro, Buy MAX, GE i warunkowego Piggy (`platform/products.luau`)
  - `NEXT-10` (#35): Onboarding, odzyskiwanie kroku samouczka i baseline konta (`onboarding/manager.luau`, `client/onboarding/TutorialController.luau`)
- **Etap Integracji i Bramek Wydania (REL-01)**:
  - Utworzenie nadrzędnego zestawu integracyjnego kandydata wydania: `tests/release_candidate/run.luau`.
  - Utworzenie automatycznego audytora bramek wydania: `tools/verify_release.py`.
  - Integracja w głównym skrypcie uruchomieniowym `tools/test.ps1`.

---

## 2. Formalna macierz bramek wydania (Release Gates)

Zgodnie z wymaganiami zadania #36 oraz zasadą transparentności weryfikacji L/S/D/H, każdy podsystem podlega jawnym bramkom weryfikacyjnym:

| Bramka | Zakres weryfikacji | Poziom | Status w repozytorium |
|---|---|---|---|
| **Bramka 1: Brak backdoorów / devgrantów** | Przeszukanie całego kodu `src/` oraz schematów `ProtocolSchemas` i `NetworkGateway` pod kątem obecności nieautoryzowanych komend przyznawania walut (`devgrant`, `godmode`, `add_money`, `free_ge`, `admin_grant`). | **L** (harness) | **PASS**: 0 niedozwolonych handlerów i schematów. |
| **Bramka 2: Baza onboardingowa i integralność stanu** | Inicjalizacja nowego konta ściśle według `docs/31 §4`: 1 Coop (slot 1), 3 puste sloty, 1 Trike, fleetLimit 4, 1 silos (3600s), $0 gotówki, 10 GE (earned=10, spent=0), 0 SE, 0 PE, brak badań wspólnych i epickich, krok 1 samouczka. | **L** (harness) | **PASS**: 100% zgodności z bazą kontraktową; zero nieuprawnionych darmowych grantów. |
| **Bramka 3: Niezmienniki stanu i konserwacja walut** | `accounting.currentFarmCash` jest monotonicznie nierosnące przy wydatkach; zakupy badań/kurników/pojazdów wymagają wystarczających środków i nie generują ujemnych sald. | **L** (harness) | **PASS**: Monotoniczność gross farm cash zweryfikowana bitowo. |
| **Bramka 4: Ochrona sesji, fencing i retencja** | Potwierdzona dzierżawa (120s), unieważnienie przeterminowanych dzierżaw, idempotencja `operationId`, limity retencji `docs/34 §4`: profil $\le$ 3 MiB, ledger $\le$ 2 MiB. | **L / D** (kontrakt) | **PASS**: Profile aggregate i ledger mieszczą się w twardych limitach wielkościowych. |
| **Bramka 5: Czysta architektura Rojo** | Statyczny build Rojo (`build/mapping-results.json`): dokładnie 36 modułów Luau, 0 skryptów wejściowych typu `Script` lub `LocalScript`. | **L** (statyczny build) | **PASS**: `PASS_STATIC_BUILD` z 36 modułami bez entrypointów. |
| **Bramka 6: Kwarantanna odłożonego bilansu** | Pliki `docs/17..21` (bilans petów, inkubatorów, symulacja progresji, płatności) pozostają w stanie odłożonym (quarantine). Kod w `src/` nie importuje ani nie polega na niezatwierdzonych cenach. | **L** (statyczny audyt) | **PASS**: Pliki odłożone pozostają nienaruszone jako jawna bramka do przyszłych etapów. |
| **Bramka S: Roblox Studio Runtime** | Testy w środowisku Roblox Studio: fizyka silnika, rendering 3D, replikacja RemoteEvent i symulacja w czasie rzeczywistym. | **S** (Studio) | **Bramka wdrożeniowa Studio**: Wymaga ręcznego/automatycznego uruchomienia w Roblox Studio po wdrożeniu assetów 3D. |
| **Bramka D: Natywny DataStore i Chmura** | Realny zapis chmurowy, obsługa sieciowych błędów Roblox DataStoreService, migracje schematów produkcyjnych. | **D** (DataStore) | **Bramka wdrożeniowa Chmura**: Adapter w pełni przetestowany na mocku L/D; aktywacja w chmurze po konfiguracji DataStore. |
| **Bramka H: Ocena człowieka i Mobile UI** | Skalowanie interfejsu dotykowego na telefonach i tabletach, ergonomia przycisków wylęgu i sklepu, czytelność fontów. | **H** (Human / Mobile) | **Bramka certyfikacyjna UX**: Przed premierą publiczną na platformie Roblox. |

---

## 3. Całościowa symulacja cyklu życia gracza (E2E Player Lifecycle)

W ramach `tests/release_candidate/run.luau` zweryfikowano pełny, 12-etapowy scenariusz integracyjny łączący wszystkie systemy:
1. **Etap 1: Inicjalizacja konta (Onboarding)** — Utworzenie profilu od zera, walidacja schematu, start od kroku 1 samouczka (`HATCH_FIRST_CHICKEN`).
2. **Etap 2: Wylęg kur i produkcja** — Kury zasiedlają kurnik Coop, znoszą jaja, transport Trike eksportuje produkcję, przychód zasila gotówkę oraz `accounting.currentFarmCash`. Krok samouczka awansuje do 2 (`BUY_FIRST_RESEARCH`).
3. **Etap 3: Zakupy badań i rozbudowa** — Zakup badania `comfy_nests` poziomu 1; gotówka pomniejszona o koszt, `currentFarmCash` nienaruszone. Krok samouczka awansuje do 3 (`UPGRADE_HABITAT`).
4. **Etap 4: Rozbudowa kurnika** — Przebudowa Coopa na Shanty (typeIndex 1). Krok samouczka awansuje do 4 (`COLLECT_DAILY_GIFT`).
5. **Etap 5: Autorytatywny dron** — Spawnowanie drona, kwalifikacja trafienia, wypłata nagrody w Złotych Jajach (GE), zablokowanie powtórnego odbioru (`ALREADY_CLAIMED`).
6. **Etap 6: Video Doubler i boosty** — Aktywacja podwajacza reklamowego (2x), weryfikacja mnożnika przychodów `earningsMultiplier = 2.0`.
7. **Etap 7: Kanały ofert 2+1** — Odbiór paczki w kanale zwykłym, bezpłatne odrzucenie oferty z natychmiastowym zwolnieniem kanału, rezerwacja oferty specjalnej w kanale bonusowym.
8. **Etap 8: Kalendarz i ukończenie samouczka** — Odbiór nagrody dnia 1 kalendarza (192 GE), zapis dnia UTC, awans samouczka do kroku 5 (`COMPLETED`).
9. **Etap 9: Ekwipunek petów i fuzja** — Wyposażenie peta w slocie 1; automatyczna blokada wyposażonego peta przed fuzją (`EQUIPPED_PET_CANNOT_BE_FUSED`). Połączenie nieuzbrojonych duplikatów: konsumpcja materiałów i pomyślny awans wariantu peta bazowego (Normal $\to$ Golden).
10. **Etap 10: Zakupy platformowe i Pro Permit** — Przetworzenie zakupu Pro Permit autorytatywną metodą `confirmPurchase`: odblokowanie uprawnienia `pro_permit` oraz bonusu fuzji `pro_plus10_enabled` (+10 p.p. wg docs/22 §1 R). Zakup paczki GE z weryfikacją odporności na duplikaty (idempotentne `alreadyApplied`).
11. **Etap 11: Trofea i Prestiż** — Osiągnięcie 10M populacji, odblokowanie brązowego trofeum na Edible (2M SE). Wyliczenie Farm Value i oczekiwanych Soul Eggs, wykonanie prestiżu (`applyPrestige`): reset farmy do Edible, zerowanie gotówki, zaksięgowanie zdobytych Soul Eggs w trwałym polu `permanent.SE`, zachowanie GE, PE i uprawnień Pro.
12. **Etap 12: Offline i bezpieczny powrót** — Upływ 7 200 sekund symulacji; twarde ograniczenie produkcji do 3 600 sekund przez 1 posiadany silos. Reconnect gracza i wywołanie `reconcileTutorialStep`: zaawansowany gracz pozostaje na kroku 5 (COMPLETED) bez soft-locka i z automatycznym ukryciem widgetu samouczka na kliencie.

---

## 4. Statystyki weryfikacji jakościowej (QA Metrics)

Projekt HatchTheEgg osiągnął pełną, 100-procentową zgodność we wszystkich zestawach testowych:
- **Główny runner testowy**: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
- **Łączna liczba asercji Lune**: **23 872 asercje (100% PASS, 0 błędów)**
  - `numeric`: 15 702 asercje
  - `catalog`: 2 732 asercje
  - `protocol`: 745 asercji
  - `persistence`: 155 asercji
  - `math`: 517 asercji
  - `fv_se`: 358 asercji
  - `ihr`: 91 asercji
  - `hatching`: 594 asercje
  - `coordinator`: 221 asercji
  - `timeline`: 58 asercji
  - `integration89`: 70 asercji
  - `purchases`: 149 asercji
  - `resets`: 199 asercji
  - `effect_boundaries`: 204 asercje
  - `pet_effects`: 152 asercje
  - `fusion`: 103 asercje
  - `drones`: 72 asercje
  - `offers`: 64 asercje
  - `claims`: 76 asercji
  - `purchase_recovery`: 55 asercji
  - `tutorial`: 62 asercje
  - `gateway`: 283 asercje
  - `client_state`: 160 asercji
  - `presentation`: 387 asercji
  - `ui`: 165 asercji
  - `integration`: 121 asercji
  - `acceptance` (A01–A16): 264 asercje
  - **`release_candidate` (REL-01)**: **113 asercji**
- **Niezależne orakle i generatory Python**:
  - `generate_catalog.py --check`: PASS
  - `build_oracle.py --check`: PASS
  - `generate_population_vectors.py --check`: PASS (490 wektorów modulo)
  - `verify_build.py`: PASS (36 modułów, 0 skryptów entrypoint)
  - `verify_release.py`: PASS (wszystkie 6 bramek wydania zatwierdzone)
- **Artefakt Rojo**: `build/HatchTheEgg.rbxlx` oraz `build/sourcemap.json` wygenerowane pomyślnie.

---

## 5. Podsumowanie statusu repozytorium

Wszystkie **36 zadań** zdefiniowanych w master planie #1 i opublikowanych w rejestrze GitHub zostało w 100% zrealizowanych, zweryfikowanych i zamkniętych:
1. `DOC-01` do `DOC-05` (#2–#6): Specyfikacje i baza wiedzy — **ZAMKNIĘTE**
2. `PRE-01` do `PRE-03` (#7–#9): Kontrakty przygotowawcze — **ZAMKNIĘTE**
3. `IMP-01` do `IMP-15` (#10–#24): Implementacja pierwszej farmy — **ZAMKNIĘTE**
4. `QA-01` (#25): Formalny odbiór A01–A16 — **ZAMKNIĘTE**
5. `NEXT-01` do `NEXT-10` (#26–#35): Rozszerzenia domeny i platformy — **ZAMKNIĘTE**
6. `REL-01` (#36): Integracja kandydata wydania i jawne bramki — **ZAMKNIĘTE**

Repozytorium posiada status **Release Candidate Approved (Level L Verified)**. Dalsze etapy wdrożeniowe (testy w Roblox Studio na żywych instancjach, chmurowa konfiguracja DataStore oraz ocena ergonomics na urządzeniach mobilnych) stanowią jawnie zdefiniowane bramki S/D/H i mogą być realizowane w kolejnych etapach publikacji gry.
