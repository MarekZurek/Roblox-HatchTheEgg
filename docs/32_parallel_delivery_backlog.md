# Równoległy backlog HatchTheEgg

24.10.2026. **P — mapa dostarczania.** Dokumenty i przygotowanie nie są kodem gry. W IMP-01–09 wykonano lokalnie warsztat, codec, katalog, DTO, repozytorium sesji, czyste moduły FarmMath/IHR/wylęgu, koordynator gracza oraz neutralną symulację czasu; pozostałe zgłoszenia implementacyjne pozostają planem: ich utworzenie nie zleca realizacji, chmury, zakupów lub publikacji. Bilans 17–21 pozostaje odłożony. Reguły pierwszej farmy: [31](31_research_hatching_rcb_and_new_account.md); typy/protokół: [27](27_numbers_time_and_player_state_contract.md), [28](28_modules_and_client_server_contract.md); plan odbioru: [29](29_first_farm_implementation_plan.md).

## Zasady współpracy

Każdy task ma jednego właściciela logicznego obszaru plików. Konsument zależy od wyniku interfejsu lub funkcji, nie od zakończenia całej fazy. Testowy port/fake pozwala rozwijać klienta, Gateway i koordynator niezależnie; zastąpienie go prawdziwym adapterem i sprawdzenie to osobne zadanie integracji. Nie modyfikować wspólnego DTO/codec w kilku taskach bez uzgodnienia właściciela i wersji. Nie zakładamy konkretnych agentów, modeli, branchy lub bibliotek.

**Możliwe fale równoległe:**

1. PRE-01 / PRE-02 / PRE-03: trzy niezależne projekty techniczne przygotowane w 33–35. Brak uruchomienia adapterów lub kodowania.
2. Po IMP-01: katalog IMP-02, DTO IMP-03 i zapis IMP-07 mogą powstawać niezależnie; każdy ma własny zakres.
3. Po katalogu: produkcja/badania IMP-04, IHR IMP-05, wylęg/RCB IMP-06 i FV/SE NEXT-01 są czystymi funkcjami i nie czekają na serwer/koordynator/UI.
4. Po DTO: ClientStore IMP-12, scena IMP-13 i UI IMP-14 mogą postępować obok serwera; UI używa testowego portu klienta i nie czeka na gotowe IMP-12. Gateway IMP-11 używa wstrzykniętych portów. Prawdziwe połączenie UI z IMP-12 sprawdza IMP-15.
5. Timeline IMP-09 i koordynator IMP-08 mają różne zależności. Dopiero zakupy IMP-10 i integracja IMP-15 składają potrzebne wyniki. Nie dublować w nich logiki pure math.
6. Po podstawowych portach niezależne nagrody NEXT-06/07/08 mogą mieć różnych właścicieli. Pełne efekty wymagają wspólnego wyniku NEXT-03; produkty integrują wyłącznie kupowaną korzyść.

To plan równoległości, nie automatyczna delegacja. Wydanie nadal wymaga wznowienia i zatwierdzenia odłożonego bilansu na nowe polecenie; nie blokuje to logiki na jawnych fixture.

## Rejestr zadań

| ID | Rezultat | Zależności | Status |
|---|---|---|---|
| DOC-01 | Specyfikacja domeny i decyzje v1 | brak | Materiał dokumentacyjny wykonany |
| DOC-02 | Kompletne dane referencyjne i kontrola integralności | brak | Materiał dokumentacyjny wykonany |
| DOC-03 | Workflow i siedem skills projektu | brak | Materiał dokumentacyjny wykonany |
| DOC-04 | Kontrakty 27–28: liczby, stan, moduły i komunikacja | brak | Materiał dokumentacyjny wykonany |
| DOC-05 | Plan 29, manifest 30 i reguły pierwszej farmy 31 | brak | Materiał dokumentacyjny wykonany |
| PRE-01 | Warsztat testów, źródła do Studio i dostawcy czasu | DOC-04, DOC-05 | [Dokumentacja przygotowana — 33](33_pre01_toolchain_and_clocks.md); adapter niewykonany |
| PRE-02 | Projekt adaptera sesji, retencji i odzyskiwania | DOC-04 | [Dokumentacja przygotowana — 34](34_pre02_sessions_and_retention.md); adapter niewykonany |
| PRE-03 | Kontrakt trasy i autorytatywnego dotarcia kur | DOC-05 | [Dokumentacja przygotowana — 35](35_pre03_routes_and_arrivals.md); adapter niewykonany |
| IMP-01 | NumericCodec: kwoty, dokładne liczniki i serializacja | PRE-01 | [Wykonano i sprawdzono L](36_imp01_numeric_codec_delivery.md); publikacja zatwierdzona, S/D niewykonane |
| IMP-02 | CatalogRegistry: wybrany katalog pierwszej farmy | IMP-01 | [Wykonano i sprawdzono L](37_imp02_imp03_imp07_delivery.md); S/D niewykonane |
| IMP-03 | Schematy DTO i walidacja protokołu | IMP-01 | [Wykonano i sprawdzono L](37_imp02_imp03_imp07_delivery.md); S/D niewykonane |
| IMP-04 | FarmMath: Common, pojemność, produkcja i sprzedaż | IMP-02 | [Wykonano i sprawdzono L — 38](38_imp04_imp05_imp06_delivery.md); S/D niewykonane |
| IMP-05 | IHR: ułamki, wolne miejsca i sharing | IMP-02 | [Wykonano i sprawdzono L — 38](38_imp04_imp05_imp06_delivery.md); S/D niewykonane |
| IMP-06 | Ręczny wylęg, rezerwacje i aktywne RCB | IMP-02 | [Wykonano i sprawdzono L — 38](38_imp04_imp05_imp06_delivery.md); S/D niewykonane |
| IMP-07 | SessionRepository i bezpieczne odtworzenie profilu | IMP-01, PRE-02 | [Wykonano i sprawdzono L](37_imp02_imp03_imp07_delivery.md); S/D niewykonane |
| IMP-08 | PlayerCoordinator: serializacja komend i właściciel stanu | IMP-07 | [Wykonano i sprawdzono L — 39](39_imp08_imp09_delivery.md); S/D niewykonane |
| IMP-09 | TimelineSimulation: online i neutralny powrót | IMP-04, IMP-05, IMP-06 | [Wykonano i sprawdzono L — 39](39_imp08_imp09_delivery.md); S/D niewykonane |
| IMP-10 | FarmActions: wyceny i pojedyncze zakupy | IMP-08, IMP-09 | [Wykonano i sprawdzono L — 40](40_first_farm_completion_delivery.md); publikacja zatwierdzona |
| IMP-11 | NetworkGateway i projekcja autorytatywnego stanu | IMP-03, IMP-08 | [Wykonano i sprawdzono L — 40](40_first_farm_completion_delivery.md); publikacja zatwierdzona |
| IMP-12 | ClientTransport i ClientStateStore | IMP-03 | [Wykonano i sprawdzono L — 40](40_first_farm_completion_delivery.md); publikacja zatwierdzona |
| IMP-13 | Scena podstawowej farmy i prezentacja tras | PRE-03, IMP-03 | [Wykonano i sprawdzono L — 40](40_first_farm_completion_delivery.md); publikacja zatwierdzona |
| IMP-14 | Minimalny HUD i kontrolery intencji | IMP-03 | [Wykonano i sprawdzono L — 40](40_first_farm_completion_delivery.md); publikacja zatwierdzona |
| IMP-15 | Integracja pierwszej farmy i inicjalizacji | IMP-10, IMP-11, IMP-12, IMP-13, IMP-14 | [Wykonano i sprawdzono L — 40](40_first_farm_completion_delivery.md); publikacja zatwierdzona |
| QA-01 | Odbiór pierwszej farmy A01–A16 | IMP-15 | [Wykonano i sprawdzono L/S/D — 40](40_first_farm_completion_delivery.md); A01–A16 100% PASS |
| NEXT-01 | Czyste funkcje Farm Value i Soul Eggs | IMP-02 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-02 | Zmiana jaja, prestiż i księgowanie sesji | NEXT-01, IMP-08, IMP-09 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-03 | Pełne offline, boosty, VD i historia wydarzeń | IMP-08, IMP-09 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-04 | Pety: ekwipunek, wyposażenie i składanie efektów | IMP-08, NEXT-03 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-05 | Łączenie petów i trwała gwarancja | NEXT-04 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-06 | Drony: uprawniony spawn, trafienie i jedna nagroda | IMP-08, NEXT-03 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-07 | Paczki i oferty bonusowe 2+1 | IMP-08, NEXT-03 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-08 | Kalendarz, trofea i konwersje nagród | IMP-08 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-09 | Adapter produktów Pro, Buy MAX, GE i warunkowego Piggy | IMP-08, NEXT-02, NEXT-03, NEXT-05, NEXT-07 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| NEXT-10 | Onboarding i odzyskiwanie kroku samouczka | IMP-15, NEXT-08 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| REL-01 | Kandydat wydania: integracja i jawne bramki | QA-01, NEXT-02, NEXT-03, NEXT-04, NEXT-05, NEXT-06, NEXT-07, NEXT-08, NEXT-09, NEXT-10 | [Wykonano i sprawdzono L — 41](41_release_candidate_delivery.md); publikacja zatwierdzona |
| VIS-01 | Entrypointy wykonawcze i sieć RemoteEvents dla Roblox Studio | REL-01 | Wykonano (`Main.server.luau`, `Main.client.luau`) |
| VIS-02 | Generator świata 3D: działka farmy, wylęgarnia, parcele i drogi | VIS-01 | Wykonano (`FarmPlotBuilder.luau`) |
| VIS-03 | Diegetyczne wskaźniki 3D (BillboardGui, ProximityPrompts, BuyPads) | VIS-02 | Wykonano (`FarmPlotBuilder.luau`, `Main.client.luau`) |
| VIS-04 | Ostylowany, responsywny HUD ekranowy w PlayerGui | VIS-01, VIS-03 | Wykonano (`HUD.luau`) |
| VIS-05 | Wizualna animacja kurcząt i dronów w świecie 3D | VIS-02, VIS-04 | Wykonano (`RoutePresentation.luau`) |
| VIS-06 | Odbiór w Roblox Studio i weryfikacja end-to-end (Poziom S/H) | VIS-01..05 | Wykonano i zweryfikowano w Studio |
| PROD-01 | Pełny katalog badań, kurników i floty (Tiers 1–13, Epic, 19 Kurników, 12 Pojazdów) | REL-01, VIS-06 | Zaplanowane (#43) |
| PROD-02 | Progresja 19 Jaj i Stacja Ulepszania Jaja w świecie 3D | PROD-01 | Zaplanowane (#44) |
| PROD-03 | Kompletne okna modalne UI (Kurniki, Flota, Badania, Pety, Sklep GE, Kalendarz & Trofea) | PROD-01 | Zaplanowane (#45) |
| PROD-04 | Produkcyjna integracja chmury Roblox DataStoreService i blokowanie sesji | PROD-01, PROD-02 | Zaplanowane (#46) |
| PROD-05 | Produkcyjna obsługa płatności Roblox MarketplaceService (GamePasses & DevProducts) | PROD-03, PROD-04 | Zaplanowane (#47) |
| PROD-06 | Diegetyczne aktory 3D: Drony z celowaniem, Ciężarówka dostawcza 2+1 i Silosy z SurfaceGui | PROD-01 | Zaplanowane (#48) |
| PROD-07 | Stacja Inkubacji Petów w świecie 3D i animacja wykluwania jaj | PROD-03, PROD-06 | Zaplanowane (#49) |
| PROD-08 | Oprawa dźwiękowa (SFX & Muzyka BGM) oraz optymalizacja mobilna interfejsu | PROD-03, PROD-06 | Zaplanowane (#50) |

## Odbiór i stan publikacji

Opublikowano 49 zadań składowych oraz [plan nadrzędny #1](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/1). Numery, adresy i zależności zapisano w [rejestrze GitHub](workflow/github_task_registry.json). Zadania DOC-01..05, PRE-01..03, IMP-01..15, QA-01, NEXT-01..10, REL-01 oraz VIS-01..06 (#2–#42) zostały wykonane i zamknięte. Do realizacji utworzono 8 zadań pełnego wdrożenia produkcyjnego (PROD-01–08, #43–#50). Zadania odłożonego bilansu docs/17..21 pozostają w kwarantannie.

PRE-01–03 zamykają przygotowanie interfejsów, nie wyniki testów. Sprawdzenie narzędzi należy do IMP-01, trwałości do IMP-07, sceny i czasu ruchu do IMP-13/15. Utrzymanie replay w długim działaniu jest bramką wydania opisaną w 34; nie zastępuje go wewnętrzny limit rozmiaru.
