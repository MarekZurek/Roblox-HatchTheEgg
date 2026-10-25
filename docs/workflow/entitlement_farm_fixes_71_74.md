# Nadania uprawnień i reguły farmy — #71–74

Stan: 25.10.2026. Naprawa istniejących reguł według 01, 02, 25–28 i 31. Bez zmian danych referencyjnych, bilansu 17–21 lub konfiguracji produktów.

## #71 — potwierdzone posiadanie passa po rozliczeniu offline

Sesja zachowuje zaufaną intencję nadania Pro lub Buy MAX, gdy budżet rozliczenia czasu nie wystarcza. Tick kończy wcześniejszy okres według wcześniejszych praw i dopiero potem ponawia nadanie przez koordynator oraz repozytorium. Nie ustawia flag poza transakcją i nie przyznaje nowego Pro wstecz za całą nieobecność. Zachowane Pro nadal działa w kolejnej sesji.

Nieznany wynik zapisu zachowuje ID operacji. Odczyt ledger może potwierdzić wykonanie, ale sam nie odmraża właściciela; przed udostępnieniem stanu trzeba odzyskać sesję. Próby odzyskania pozostają ograniczone istniejącą dzierżawą. Potwierdzone niewykonanie pozwala ponowić nadanie, trwałe odrzucenie wymaga nowego ID. Po sukcesie intencja znika. Nie ma ponawiania klientów ani ponownych zakupów.

Kolejka jest lokalna dla aktualnej sesji i obejmuje wyłącznie dwa zaufane gamepassy. Ponowne wejście ponownie potwierdza własność platformową. Odpowiedź wcześniejszego asynchronicznego sprawdzenia nie może nadać prawa nowemu obiektowi gracza lub następnej sesji. Dostępność +10 p.p. nadal zależy od aktualnej polityki, niezależnie od bazowego Pro.

## #72 — maksimum RCB w FV

Wejście researchMaxRCBBase jest sumą istniejących addytywnych onscreenChickenMultMax Common i Epic Multiplier. Baza 5 nie jest liczona dwukrotnie. researchMaxRCBMult pozostaje 1: obecny katalog nie dostarcza odrębnego mnożnika tego maksimum. Epic Clucking zmienia wzrost aktywnego RCB, nie maksimum we wzorze FV.

Dla pustego Coop bez innych bonusów FV wynosi 13732.00679132647. Coordinated Clucking 50 dodaje 10 do limitu, więc człon R to 11^0.25, a FV 25008.185426951717. Bieżący runningCount, wyposażenie i boosty nie zastępują wejść badań. Ten sam adapter zasila próg awansu, podgląd kalendarza i wypłatę procentową.

Niezależny test pełnych cykli kalendarza uwzględnia teraz +2 maksimum na poziom Epic Multiplier otrzymany w 11. dniu. Nie zmieniono referencyjnego kalendarza lub kwot.

## #73 — rzeczywisty koszt po zniżkach Epic

Wspólna funkcja odczytuje istniejące researchCostMult, habCostMult i vehicleCostMult z Cheaper Research, Cheaper Contractors i Bust Unions. Quote i pobranie gotówki używają tej samej zniżki; świeży callback odrzuca zmianę efektu jako QUOTE_CHANGED. Wydatek nie pomniejsza accounting.currentFarmCash.

Fabryka FarmActions zachowuje ostatnie 64 wystawione wyceny dla gracza wraz z rodzajem operacji, generacją i mnożnikiem kosztu. Zmiana efektu między wystawioną wyceną a przygotowaniem zakupu odrzuca starą wycenę; wyparte ID w aktywnym cache też są nieaktualne. Wyjście usuwa cache. To nietrwały kontekst wyceny, nie ledger transakcji; wyniki wykonanych operacji nadal odtwarza koordynator przed domeną. Czysty statyczny port FarmActions.apply nadal liczy aktualną cenę i dostarcza walidator świeżego stanu; sam nie jest repozytorium wycen ani samodzielnym publicznym endpointem.

## #74 — intencja hold a granica resetu

Przygotowanie domenowej operacji nie zmienia runtime hold. Host porównuje tożsamość zatwierdzonej farmy (licznik prestiżów i indeks jaja) po dispatch/tick oraz przed kolejną symulacją. Dopiero rzeczywista zmiana kończy hold i zeruje jego akumulator. Odrzucony prestiż, w tym zmiana eventu przy zapisie, zachowuje jeszcze ważną intencję. Replay starszego sukcesu nie zatrzymuje nowego hold.

UNKNOWN nadal blokuje symulację. Po odzyskaniu stanu potwierdzony reset kończy dawną intencję; również zwykłe wygaśnięcie jej technicznej dzierżawy pozostaje skuteczne. Nie usunięto walidacji eventu ani nie wydłużono 2000 ms ważności.

## Dowody i ograniczenia

Nowy zestaw [regresji](../../tests/entitlement_farm_regressions/run.luau) wykonuje rzeczywisty Bootstrap/Gateway, a dla własności również Main.server z kontrolowanymi usługami. Obejmuje online/away/silosy, kolejność policy/ownership, reconnect i spóźnioną odpowiedź, zapis UNKNOWN przed i po utrwaleniu, niezależny wzór FV, próg jaja i kalendarz, poziomy zniżek 0/1/10, dokładną dostępność, replay i świeży stan, odrzucony/udany reset oraz timeout hold.

Wyniki końcowe i sumy plików: [raport weryfikacji](entitlement_farm_fixes_71_74_verification.json). Wyłącznie lokalne L i statyczny build. Nie uruchamiano Studio, chmurowego DataStore ani realnych zakupów. S/D/H pozostają niezaliczone; releaseCandidateReady=false. Ta dostawa nie kończy pozostałej integracji premiery lub konfiguracji odłożonego bilansu.
