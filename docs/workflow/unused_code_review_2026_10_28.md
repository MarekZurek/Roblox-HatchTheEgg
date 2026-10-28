# Nieużywany i powielony kod — 28.10.2026

Przegląd statyczny read-only wykonany na zlecenie użytkownika przez subagenta, z celowanym sprawdzeniem przez root. Zakres: 41 plików src po wyłączeniu dwóch generowanych plików danych; deklaracje funkcji, odwołania w kodzie i testach oraz połączenia Main → Bootstrap → HUD/transport. Podstawa: HEAD 701d087 i bieżące lokalne zmiany Gemini oraz usunięcie VD. Numery linii dotyczą lokalnego drzewa, nie samego HEAD. Nie wykonano nowego Play, pomiaru CPU ani usuwania znalezionego kodu. Raport nie jest częścią commitu usunięcia podwajacza.

## Potwierdzone pozostałości

|Priorytet|Miejsce|Dowód i zalecenie|
|---|---|---|
|P3|src/server/world/FarmPlotBuilder.luau:155, lokalne cf|Wyłącznie deklaracja, brak eksportu lub przekazania jako callback. Można usunąć.|
|P3|src/server/NetworkGateway.luau:160, _nextStreamSerial|Brak wywołań w src i testach. registerPlayer inkrementuje self.streamSerial bezpośrednio. Usunąć martwą metodę; nie zastępować nią innych liczników o innym zakresie.|
|P3|src/client/HUD.luau:2060, _buildCloseButton|Brak wywołania produkcyjnego. Jedyny konsument to test ui:1433. Rzeczywiste okna używają StudUi:closeButton lub osobnego przycisku prestiżu. Usunąć helper i test helpera, zachowując testy rzeczywistych przycisków.|
|P3|HUD.luau:2264,4261,4306, dawny tier14 Epic|UI tworzy 13 tabów i osobny modal Epic, lecz zostawiono gałąź tab14. Nieosiągalna normalnym UI, ale publiczne selectResearchTier przyjmuje dowolny indeks. Najpierw uporządkować walidację/kontrakt, potem usunąć gałąź.|

## Duplikaty i ich skutki

1. **P2 — getEpicRobuxTier**, HUD:2415 i4633. Identyczne progi 50/200/1000 oraz wyniki 19/49/99/199 R$. Jeden helper może obsługiwać tworzenie i aktualizację kart. To nie naprawia niedokończonego nadania badania z #83 ani nie potwierdza prawdziwych cen Marketplace.
2. **P1/P2 — ekonomia odtworzona w HUD**, FV:747 i SE:4755, wobec autorytatywnego FarmMath/fv_se:85/152 i ProgressActions. To istniejące #86/#87, z już potwierdzonymi rozbieżnościami. UI powinno otrzymywać autorytatywny podgląd; nie utrzymywać drugiego uproszczonego wzoru.
3. **P2 — dwa źródła dźwięku nagrody**. Bootstrap klienta hitDrone:355 i claimOffer:377 odtwarzają pop/coin przed wynikiem, a Main.client:281 i gałąź OfferClaimedPopup odtwarzają je ponownie po potwierdzeniu. Main wiąże wystrzał z client:hitDrone (:445), paczkę z client:claimOffer (:430). Potwierdzona duplikacja ścieżek efektu; bez odsłuchu w nowym Play. Pozostawić jednego właściciela potwierdzonej nagrody. To nie dowód podwójnej wypłaty pieniędzy.
4. **P2 — ręczne katalogi prezentacji**, HUD:486 Epic, :673 boosty, :684 produkty, :725 jaja i progi tierów, wobec katalogów serwera. Część metadanych klienta jest potrzebna, ale ceny i efekty zapisane osobno już rozjechały się dla PRO/Epic. Wprowadzić kontrolowany kontrakt projekcji ofert; nie kopiować klientowi całej prywatnej konfiguracji serwera.

## Co celowo pozostaje

- activateVideoDoubler jako zgodne wywołanie zwracające FEATURE_REMOVED i dawne pola profilu — świadoma kompatybilność po usunięciu mechaniki.
- activateBoost — działająca funkcja domenowa i testy; brak integracji gracza z #92 nie uzasadnia skasowania funkcji.
- Publiczne API, gettery testowe, aliasy zapisu i mocki Roblox/Lune — brak wywołania z Main sam nie dowodzi zbędności.
- HUD:pressHatch i ClientBootstrap:hatchPress mają różnych konsumentów (przycisk ekranowy i prompt świata) oraz odmienną prezentację. Nie znaleziono dowodu dwóch serwerowych HatchPress z jednego kliknięcia.

Nie znaleziono potwierdzonej podwójnej definicji tej samej publicznej metody nadpisującej poprzednią w module. Lista nie gwarantuje braku innych nieużywanych ścieżek dynamicznych i nie dowodzi, że porządki usuną lagi. Najpierw naprawić duplikację obliczeń i właściciela dźwięków; małe martwe helpery mają niski priorytet. Bez zmian balansu docs17–21.
