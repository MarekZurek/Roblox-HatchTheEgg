# Diagnoza wydajności — 26.10.2026

## Zakres i wersja

Zlecenie: sprawdzić możliwości optymalizacji po zgłoszeniu lekkich lagów podczas testowania. Wykonano analizę kodu i krótkie pomiary lokalne; nie wdrażano optymalizacji, nie publikowano gry ani kodu. Bilans docs/17–21 i dane referencyjne bez zmian.

Repozytorium na początku: czyste `main`, HEAD `3284b5b1d5fbe8c8dcfd685e1a1a27e7247175ad`. Przeczytano WORKING_CONTEXT, CURRENT_SPEC, odłożenia TODO oraz workflow. Zastosowano skills hte-investigate-bug, hte-validate-studio, Studio rbx-perf-profiling i rbx-scene-analysis.

Studio: jedna połączona instancja `HatchTheEgg.rbxlx`, początkowo Edit, PlaceId=0, Main.UseLocalMemoryStore=true. Lighting: Soft, PrioritizeLightingQuality=false, GlobalShadows=true. Porównano długości i ważone sumy kontrolne wszystkich 41 źródeł Luau (normalizacja CRLF do LF) z lokalnym src: zgodne. To kontrola niekryptograficzna źródeł, nie pełne porównanie sceny z buildem.

Uruchomiono własny lokalny Play: jeden klient i serwer, tryb STUDIO_MEMORY, bez trwałego postępu i zakupów. Nie zmieniano źródeł Studio. Po pomiarach przywrócono widoczność panelu badań, wyłączono włączony na potrzeby diagnozy MicroProfiler i zakończono własny Play. Nie dodawano instancji diagnostycznych. Końcowy tryb sprawdzono osobno.

## Pomiary

Każda próbka poniżej trwała około 6 sekund. Czasy pochodzą z RenderStepped deltaTime, nie z czasu wykonania całego kodu gry. Pomiar stojącej postaci wykonano przed jawnym EnableProfiler(true); kolejne próbki przy włączonym profilerze. Są to krótkie obserwacje, bez kontrolowanego benchmarku A/B i bez testu osobnego klienta Roblox poza Studio.

| Scenariusz | Klatki | Średnia ms | Mediana ms | P95 ms | Maksimum ms | Klatki >33,33 ms |
|---|---:|---:|---:|---:|---:|---:|
| Stojąca postać, panele zamknięte | 315 | 19,10 | 18,82 | 21,10 | 42,22 | 1 |
| MoveTo o wektor (25,0,-20), potem postój po dotarciu | 322 | 18,71 | 18,45 | 21,39 | 27,46 | 0 |
| Widoczny panel badań, bez kupowania | 306 | 19,66 | 19,49 | 21,57 | 36,89 | 1 |

Odpowiada to około 51–53,5 FPS według średnich czasów klatki. MoveTo to polecenie ruchu w teście, nie odtworzenie ręcznego poruszania i obracania kamery. Widoczność ShopFrame ustawiono tymczasowo bez wywołania kliknięcia otwierającego panel; nie testuje to pełnej ścieżki otwarcia. W próbce panelu odebrano tylko 4 QuoteView, więc nie ma dowodu zalewania sieci wycenami w tym scenariuszu.

SceneAnalysisService, jeden bieżący punkt widzenia przy stojącej postaci:

- 27 draw calls, 25 575 trójkątów łącznie; z tego cienie 4 / 7792. Bez przebiegu cieni: 23 / 17 783.
- 3767 instancji w kategoriach usługi, w tym 2838 UI (również elementy silnika).
- Własny ScreenGui HatchTheEggHUD: 2601 potomków. Świat HatchTheEggWorld: 602 potomków w późniejszym odczycie runtime.
- Początkowa scena Edit miała 304 BasePart; scena runtime jest budowana również przez entrypoint.

Mikrobenchmark na aktualnym widoku pobranym standardowym RefreshState: 20 partii po 10 wywołań z yield między partiami. Snapshot JSON miał 8001 bajtów. Nie zmieniano sald ani reguł.

| Operacja | Mediana ms/wywołanie | P95 ms/wywołanie |
|---|---:|---:|
| ClientStateStore:getFarm(), pełna kopia widoku | 0,0948 | 0,1286 |
| GetDescendants świata + filtr TouchPlate/PadKind | 0,6214 | 0,9101 |

To koszt w syntetycznej partii na tym komputerze, nie gwarantowana oszczędność po zmianie. Alokacje i GC mogą zmieniać rezultat.

LibMP skonfigurowano na 128 klatek, ale dwa odczyty snapshotu ujawniły po jednej dostępnej klatce. Nie traktować ich jako wieloklatkowej statystyki. W klatkach ID=1/absolute=524912 i ID=650/absolute=525561 scope Script_Main na RBX Main trwał odpowiednio około 3,03 i 3,33 ms. Druga miała Present około 8,67 ms i sumę fillGuiVertices około 1,29 ms. Czasy scope są inclusive; nie sumować ich jako niezależnych kosztów i nie przypisywać całego Present pracy GPU. Te obserwacje nie rozstrzygają jednego dominującego ograniczenia CPU/GPU.

## Ustalenia i proponowana kolejność zmian

### 1. Usunąć pełną aktualizację HUD z każdej klatki

`Main.client.luau:498` wywołuje `ClientBootstrap:update()` przez RenderStepped. `Bootstrap.luau:455` bezwarunkowo wywołuje HUD:update. Jednocześnie HUD ma już subskrypcję onStateChanged (`HUD.luau:3018`). `HUD:update` aktualizuje teksty, karty badań, pojazdy i wyliczenie FV panelu jaja, również przy ukrytych panelach. Aktualizacje paneli nie sprawdzają ich Visible na wejściu.

Propozycja: odświeżać wartości i karty po zmianie stanu; ukryte panele odświeżać przy otwieraniu, a widoczny panel również po istotnej zmianie. Oddzielić od tego wygasanie/odnawianie wycen i odświeżanie dzierżawy hold. Aktualnie requestQuotesForCurrentTier korzysta z wywołań HUD:update, więc proste usunięcie jednego wywołania bez zachowania tego mechanizmu grozi ponownym zepsuciem zakupów. Animacje tras pozostawić płynne.

### 2. Ograniczyć kopie widoku farmy

`ClientStateStore.luau:109` zwraca recursive deepCopy. W standardowej klatce co najmniej cztery odczyty: _syncIssuedDrones, dwa w HUD:update i getOrdinaryOffers z Main. Przy 60 FPS to co najmniej 240 pełnych kopii na sekundę, mimo znacznie rzadszych zmian widoku. W mikrobenchmarku cztery takie kopie to około 0,38 ms; nie jest to pomiar całego HUD.

Propozycja: jedna bezpieczna kopia na zmianę widoku, przekazywana do prezentacji, albo jawny niemutowalny snapshot/read-only selektory. Zachować ochronę stanu klienta przed przypadkową mutacją; nie zastępować API samym zwracaniem mutowalnej wewnętrznej tabeli.

### 3. Usunąć skan całego świata z każdej klatki

`Main.client.luau:547` wywołuje GetDescendants i przegląda cały świat, aby znaleźć kilka TouchPlate. Osobny skan reward widgets przy linii 510 jest już uzależniony od zmiany obiektu świata i nie ma tej samej częstotliwości.

Propozycja: przechowywać listę płytek aktualizowaną przez dodanie/usunięcie instancji i wymianę świata; kontakty sprawdzać poza RenderStepped np. 10 razy/s. Zachować cooldown 1,25 s i responsywność wylęgu oraz obsługę późno replikowanych/odbudowanych instancji. Przy cache uwzględnić usuwanie obiektów i rozłączanie połączeń.

### 4. Dopiero potem zmniejszać koszt tworzenia UI i wizualnych kurczaków

2601 potomków HUD powstaje od razu, choć większość paneli jest zamknięta. Można tworzyć rzadziej używane panele przy pierwszym otwarciu. Dla nasilonych lagów podczas długiego wylęgu warto osobno zmierzyć aktywne grupy/instancje i koszty tworzenia modeli; obecny limit to 5 wizualizacji na grupę, nie globalnie. Pooling lub globalny limit wizualny to dalszy kandydat, bez ograniczania autorytatywnej liczby kurczaków. Ten scenariusz nie był w tym zadaniu zmierzony. _completedGroups rośnie do destroy; wymaga osobnego sprawdzenia retencji przy długiej sesji, nie jest tu potwierdzonym źródłem przycięć.

## Wniosek i weryfikacja kolejnego kroku

Najlepiej uzasadniony pierwszy zakres to klient: HUD na zdarzenia, mniej kopii i cache płytek. W obecnej próbce nie ma podstaw, aby jako pierwszą zmianę upraszczać farmę lub ponownie zmieniać gotowe oświetlenie. Niewielka liczba draw calls z jednego widoku nie wyklucza innych problemów GPU/Studio.

Po implementacji porównać te same scenariusze w podobnych warunkach, dodać osobne scope HUD/odczyty/płytki/animacje i sprawdzić: zakup badań po zmianie tieru/wygaśnięciu wyceny, otwarcie wcześniej ukrytych paneli, hold start/refresh/stop, odbudowę świata oraz długi wylęg. Potrzebna również próbka z obracaniem kamery i osobny klient Roblox dla rozdzielenia narzutu Studio. Nie obiecywać konkretnego wzrostu FPS bez A/B.

Analiza nie zmieniła źródeł, więc nie uruchamiano ponownie pełnego runnera ani statycznego buildu. Dowody nie stanowią odbioru S/D/H ani zatwierdzenia wydania.

Oficjalne zalecenia Roblox wspierają ograniczenie deep cloning i drogich operacji wykonywanych co klatkę: [Improve performance](https://create.roblox.com/docs/performance-optimization/improve), [Task scheduler](https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler).
