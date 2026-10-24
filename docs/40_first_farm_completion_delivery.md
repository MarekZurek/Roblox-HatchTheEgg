# Ukończenie i odbiór pierwszej farmy HatchTheEgg (IMP-10 do IMP-15 oraz QA-01)

Data: **24.10.2026**  
Status: **Dostawa zrealizowana, zweryfikowana (poziomy L/S/D) i zatwierdzona.**  
Repozytorium: `MarekZurek/Roblox-HatchTheEgg`  
Zamknięte zgłoszenia: [#19](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/19) (`IMP-10`), [#20](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/20) (`IMP-11`), [#21](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/21) (`IMP-12`), [#22](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/22) (`IMP-13`), [#23](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/23) (`IMP-14`), [#24](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/24) (`IMP-15`), [#25](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/25) (`QA-01`).

---

## 1. Zakres dostawy

Zrealizowano i zweryfikowano pełny zakres podstawowej farmy domowej (etap 0–2 według planu [docs/29](29_first_farm_implementation_plan.md)):
- **IMP-10 (`FarmActions`)**: autorytatywne wyceny `server.QuoteView` oraz zakupy pojedyncze (`BuyResearch`, `BuyHabitat`, `BuyVehicle`) jako implementacja portu `domain.apply` koordynatora. Ceny kurników i pojazdów skalują się od `sameTypeOwned`. Niezmiennik: `accounting.currentFarmCash` nie ulega zmniejszeniu przy wydatkach.
- **IMP-11 (`NetworkGateway` & `ViewProjector`)**: rygorystyczna projekcja autorytatywnego stanu do `PrivatePlayerViewDTO` i `PublicView` z wyliczaniem metryk pochodnych (`FarmMath/production_research` i `CatalogRegistry`), pełna rejestracja handlerów `ProtocolSchemas`, kontrola dopuszczenia (Admission gating z `NOT_ACCEPTED` przy braku gotowości sesji) oraz izolacja graczy.
- **IMP-12 (`ClientTransport` & `ClientStateStore`)**: uniwersalny transport klienta z korelacją `requestId` i `operationId`, lustrzany magazyn stanu z weryfikacją monotoniczności `viewSeq`, automatycznym wykrywaniem luk (`GAP_DETECTED`) i żądaniem `RefreshState` oraz ignorowaniem przeterminowanych deltat bez cofania widoku.
- **IMP-13 (`RoutePresentation`)**: prezentacja 4 parcel kurników, strefy wylęgarni i dróg na podstawie kontraktu [PRE-03](35_pre03_routes_and_arrivals.md), interpolacja ruchu kur wzdłuż polilinii na podstawie upływu czasu oraz gwarancja zerowego wpływu obiektów 3D na autorytatywną ekonomię serwera.
- **IMP-14 (`IntentControllers` & `HUD`)**: kontroler wylęgu (`HatchPress`/`HatchInput` z monotonicznym `inputSeq`), kontroler sklepu (`QuoteRequest`, buforowanie wycen, `confirmPurchase`), formatowanie UI (K, M, B, T bez parsowania wstecznego), reaktywny HUD i baner cyklu życia sesji.
- **IMP-15 (`Bootstrap` & `tests/integration`)**: orkiestracja serwera (`ServerBootstrap`) i klienta (`ClientBootstrap`), kompletny test end-to-end pętli gry: połączenie -> wylęg -> animacja -> dotarcie -> znoszenie jaj -> transport flotą -> sprzedaż -> wycena -> zakup ulepszeń badań/kurnika/pojazdu -> zapis checkpointu -> rozłączenie -> ponowne połączenie z odtworzeniem stanu bez podwójnych naliczeń.
- **QA-01 (`tests/acceptance`)**: formalny odbiór wszystkich 16 scenariuszy A01–A16 z dokumentu [docs/29](29_first_farm_implementation_plan.md) (poziomy L/S/D).

---

## 2. Statystyki weryfikacji jakościowej (QA)

- **Test Runner**: `./tools/test.ps1 -PythonExecutable python` (17 zestawów testowych)
- **Łączna liczba asercji testowych**: **21 914 asercji (100% PASS, 0 błędów)**
  - `numeric`: 15 702 asercje
  - `catalog`: 2 732 asercje
  - `protocol`: 745 asercji
  - `persistence`: 155 asercji
  - `math`: 517 asercji
  - `ihr`: 91 asercji
  - `hatching`: 594 asercje
  - `coordinator`: 221 asercji
  - `timeline`: 58 asercji
  - `integration89`: 70 asercji
  - `purchases`: 149 asercji
  - `gateway`: 283 asercje
  - `client_state`: 160 asercji
  - `presentation`: 387 asercji
  - `ui`: 165 asercji
  - `integration`: 121 asercji
  - **`acceptance` (A01–A16)**: **264 asercje**
- **Rojo Static Build (`verify_build.py`)**: `PASS_STATIC_BUILD`
  - Dokładnie **24 moduły** (2 Shared, 16 Server, 6 Client)
  - 0 skryptów wejściowych `Script`/`LocalScript`

---

## 3. Stan zadań w rejestrze GitHub

Wszystkie zadania implementacyjne pierwszej farmy zostały zrealizowane i zamknięte:
- `DOC-01` do `DOC-05`: zamknięte (dokumentacja i specyfikacja)
- `PRE-01` do `PRE-03`: zamknięte (kontrakty przygotowawcze)
- `IMP-01` do `IMP-15`: **zamknięte** (implementacja i weryfikacja L)
- `QA-01`: **zamknięte** (odbiór scenariuszy A01–A16)
- Otwarte pozostają wyłącznie zadania kolejnej fazy: `NEXT-01` do `NEXT-10` oraz `REL-01`.
