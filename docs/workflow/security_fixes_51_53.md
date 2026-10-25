# Poprawki bezpieczeństwa #51–53 — 25.10.2026

Zakres: granica wejścia klienta dla inkubacji, dronów i ofert; trwałe wystawienie oraz jednokrotny odbiór nagród. Bez zmian bilansu, dokumentów 17–21 i danych referencyjnych. Pozostałe ustalenia audytu #54–61 nie są zamknięte przez tę dostawę.

## Zachowanie

- Main.server przekazuje te trzy rodzaje wiadomości do wspólnego handleRewardRequest. Dozwolone są wyłącznie krótkie identyfikatory i metadane intencji; cena, reward, roll, variantRoll, konfiguracja spawnu i UID peta od klienta są odrzucane. Nie ma domyślnego ID drona lub oferty.
- Inkubacja bez jawnej konfiguracji testowej zwraca FEATURE_UNAVAILABLE bez kosztu, losowania lub wpisu operacji. To świadome zamknięcie niezatwierdzonej ścieżki, nie wybór ceny produkcyjnej. Istniejące pety nie są usuwane. Komunikat klienta nie reklamuje już domyślnych 100 GE.
- Na potrzeby testów można jawnie przekazać fabryce petHatchTestPolicy={mode="INTERNAL_TEST_ONLY",costGE=...,draw=...}. Cena musi być dodatnia, los i UID pochodzą z serwera. Stałe testowe receptury i rozkłady nie uzyskały zatwierdzenia produkcyjnego. Main nie przekazuje tej konfiguracji.
- Pet ma zapisany licznik inventory.petSequence; nowy UID nie pochodzi z wiadomości. Koszt, pet, licznik i wynik operacji trafiają do jednego commita. Powtórzony operationId lub requestId pakietu zwraca zapisany wynik bez ponownego kosztu i losowania.
- Dron musi istnieć w rewards.droneSpawns danego gracza, należeć do niego, być aktywny i nieodebrany. Warunki czasu są sprawdzane ponownie na świeżym profilu podczas zapisu. Wynik i claimed są utrwalone razem z ekonomią.
- Oferta musi istnieć w rewards.offers. Brak wpisu oznacza OFFER_NOT_FOUND; nie tworzy nagrody 50 000 ani nowej oferty. Stan kanałów, prawo darmowego odbioru, koszt i wynik są częścią tego samego agregatu. Zmiana stanu nie następuje już w osobnym playerSession.offersState przed zapisem.
- Nieznane ID są odrzucane przed utworzeniem ekonomicznej operacji, więc nie zajmują ledger i nie rezerwują przyszłych praw do odbioru. Przy nieznanym wyniku zapisu obowiązują istniejące UNKNOWN/fencing/replay; patch nie próbuje przyznawać kompensacji.

## Porty zaufanego hosta i granice

issueDrone(playerId,id,terms) i issueOffer(playerId,id,channel,reward,costGE?) wystawiają zapisany rekord przez koordynatora. Nie są handlerami Remote/Gateway. Parametry nagrody pochodzą z hosta serwera, nigdy z wiadomości odbioru. terms wymaga jawnych farmValue i curve0FarmValue; nie przywrócono poprzednich wymyślonych wartości zastępczych. getOffersState zwraca kopię trwałego stanu, nie mutowalny obiekt sesji.

Zwykłe oferty są bezpłatne. W kanale bonusowym zachowano prawo pierwszego odbioru dnia; kolejne wymagają ceny zapisanej przez hosta przy wystawieniu. Bez takiej ceny ścieżka płatna zwraca FEATURE_UNAVAILABLE, zamiast używać domyślnych 10 GE lub kwoty klienta.

**Aktualne, generowane lokalnie wizualizacje dronów i paczek same nie uprawniają do wypłaty.** Produkcyjny harmonogram wystawiania i dystrybucja autorytatywnych ID do prezentacji wymagają osobnego podłączenia do tych portów. Patch nie dopisuje częstotliwości, nagród ani nie zatwierdza wartości testowych. Inkubacja produkcyjna pozostaje niedostępna do rozstrzygnięcia jej odłożonej konfiguracji. Nie należy traktować tej poprawki jako ukończenia całego systemu nagród lub zamknięcia pozostałych uwag integracyjnych audytu.

## Weryfikacja

[tests/reward_security/run.luau](../../tests/reward_security/run.luau): **174 asercje PASS L** przez ten sam ingress co Main. Przypadki: wymuszanie kosztu/wyniku/UID, brak konfiguracji, poprawna ścieżka testowa, powtórki, cudze i nieznane ID, wygaśnięcie przed odbiorem i w trakcie zapisu, odrzucenie ceny klienta, brak środków, pełny kanał, kopia stanu, restart sesji, ponowienia transformacji i timeout przed/po zapisie.

Dotychczasowe testy Bootstrap w drones i pet_effects wystawiają teraz jawne rekordy przed odbiorem; cena inkubacji jest przekazywana wyłącznie jako konfiguracja testu. Nie usunięto testów pozytywnej wypłaty i potrącenia kosztu. W runnerze zarejestrowano nowy zestaw. [Raport wyników i hashy](security_fixes_51_53_verification.json).

Pełny runner: **67 794 asercje, 29 zestawów**, statyczny build Rojo 38 ModuleScript i 2 entrypointy. To dowód lokalny i statyczny, nie Studio, realny DataStore lub test płatności. Deklaracje starego verify_release nie podnoszą poziomu tej weryfikacji; ich osobna korekta pozostaje w #60.
