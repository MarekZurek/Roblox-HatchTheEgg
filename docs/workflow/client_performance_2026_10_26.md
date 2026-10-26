# Optymalizacje klienta i porównanie — 26.10.2026

## Zmiany lokalne

Zlecone trzy optymalizacje wdrożono na bazie `3284b5b1d5fbe8c8dcfd685e1a1a27e7247175ad`. Początkowo obecny był nieśledzony raport [diagnozy](performance_investigation_2026_10_26.md) z poprzedniego zadania. Bez zmian serwera, zasad ekonomii, danych referencyjnych i docs/17–21; bez commitu, push lub publikacji Roblox.

- `Bootstrap.luau` przestał wywoływać HUD:update co klatkę i dublować subskrypcję HUD do zmian stanu. HUD aktualizuje się przez własne onStateChanged oraz interakcje UI. Lekkie HUD:tick utrzymuje odświeżanie wycen widocznego panelu, również po upływie ważności bez nowej delty. Zegar ticka uwzględniono przy ocenie świeżości wycen. Odnawianie hold oraz animacja tras pozostają w pętli klienta.
- `ClientStateStore:getPresentationFarm()` tworzy jedną rekurencyjnie zamrożoną kopię na przyjęty widok. Snapshot i delta unieważniają cache przed powiadomieniami. HUD, drony i dostępność ofert współdzielą tę kopię; getFarm zachowuje kontrakt odrębnej, mutowalnej kopii. Usunięto też drugi odczyt farmy w HUD:update. Nie udostępniono mutowalnej wewnętrznej tabeli.
- `Main.client.luau` indeksuje TouchPlate i widgety nagród przy podłączeniu świata. DescendantAdded/DescendantRemoving obsługują późne dodanie i usuwanie; przy wymianie świata stare połączenia są rozłączane i indeksy/cooldowny czyszczone. PadKind jest odczytywany przy użyciu, więc atrybut może nadejść po instancji. Płytki zakupowe są sprawdzane najwyżej 10 razy/s; cooldown 1,25 s zachowano. Płyta wylęgu zachowuje dotychczasową częstotliwość i odstęp 0,28 s. Cache nie śledzi zmiany nazwy istniejącej instancji; aktualny builder nadaje nazwy przed parentowaniem.

## Porównanie przed i po

Ta sama instancja Studio `HatchTheEgg.rbxlx`, PlaceId=0, jeden klient i serwer, STUDIO_MEMORY z UseLocalMemoryStore=true. Pomiary przed zmianami i po uruchomieniu zmienionych źródeł wykonano bez MicroProfilera, na pustej farmie, przed wylęgiem. W każdej sesji kolejność: postój 1 → widoczny panel badań → postój 2. Przed każdą próbką 2 s rozgrzewki, następnie 8 s zbierania RenderStepped deltaTime. Kamera nie była celowo przemieszczana; panel włączono przez Visible, bez kliknięcia otwierającego. Do UI użyto tych samych rozmiarów okna. Testy interakcji odbyły się dopiero po pomiarze.

| Próba | Klatki przed/po | Średnia ms przed/po | FPS ze średniej przed/po | P95 ms przed/po | Max ms przed/po | >33,33 ms przed/po |
|---|---:|---:|---:|---:|---:|---:|
| Postój 1 | 465 / 481 | 17,220 / 16,665 | 58,1 / 60,0 | 18,926 / 18,120 | 44,269 / 31,071 | 2 / 0 |
| Panel badań | 441 / 481 | 18,166 / 16,666 | 55,0 / 60,0 | 19,867 / 18,176 | 39,125 / 28,541 | 1 / 0 |
| Postój 2 | 420 / 481 | 19,068 / 16,665 | 52,4 / 60,0 | 20,899 / 19,093 | 43,678 / 39,090 | 1 / 1 |

Mediany ms przed/po: postój 1 17,033/16,703; badania 17,958/16,693; postój 2 18,890/16,639. W oknach pomiarowych sonda nie odebrała wiadomości serwera: pusta farma nie zmieniała prezentowanych sekcji. Nie jest to próba farmy w produkcji lub intensywnych zakupów.

Wszystkie próbki po zmianach osiągnęły około 60 FPS. Spadek średniego czasu klatki wyniósł odpowiednio około 3,2%, 8,3% i 12,6%. Wyniki mają granice: tylko jedno przejście przed/po, krótkie próbki na tym komputerze, widoczny rozrzut baseline oraz limit około 60 FPS. Nie są dowodem stałego procentowego zysku na każdym urządzeniu ani braku rzadkich przycięć.

Dodatkowy mikrobenchmark aktualnego widoku runtime po wylęgu: 20 partii po 10 wywołań, yield między partiami, pierwsze utworzenie cache poza pomiarem. getFarm: mediana 0,04497 ms, P95 0,09353 ms. getPresentationFarm: mediana 0,000330 ms, P95 0,000470 ms. To porównanie odczytów tego samego widoku po zmianie, nie całego HUD; pokazuje usunięcie powtarzanego deepCopy. Potwierdzono tę samą referencję i zamrożenie tabel zagnieżdżonych.

## Weryfikacja lokalna

Wykonano `./tools/test.ps1 -PythonExecutable 'C:\Users\Marek\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'`:

- 39 zestawów Luau, łącznie **80 861 asercji PASS**, w tym nowy zestaw 23 regresji `tests/client_performance/run.luau`.
- 11 testów raportowania Python PASS; generatory i niezależne oracle PASS.
- Rojo build, sourcemap i statyczne mapowanie PASS: 39 modułów, 2 entrypointy.
- Na końcu pierwszego uruchomienia kontrola rejestracji zestawów nie rozpoznała literalnej ścieżki nowego zestawu. Poprawiono zapis rejestracji w tools/test.ps1 i uruchomiono ponownie tools/verify_release.py: PASS lokalnych kontroli, release NOT_APPROVED. Nie powtarzano niezmienionych testów domenowych po tej zmianie zapisu runnera.
- Self-review diffu i git diff --check; niezależnego review ani mutation checks w tym zadaniu nie wykonywano.

Nowe regresje sprawdzają: brak pełnych repaintów przez 120 niezmienionych klatek; jeden repaint przy snapshotcie zamiast dwóch; ponowne użycie i głęboką niemutowalność widoku; niezależność getFarm; unieważnienie snapshot/delta i stabilność zachowanej starej kopii; odnowienie wycen po 60 s bez delty; zakup badań; autorytatywny wylęg i repaint po jego delcie; odnowienie dzierżawy hold oraz brak odnowienia po stop. Istniejący integration smoke pokrywa również kupno kurnika i pojazdu.

## Celowane interakcje Studio po zmianie

Zsynchronizowano wyłącznie cztery zmienione skrypty klienta. Pierwsza próba przez lokalny HTTP zakończyła się timeoutem przed zapisem źródeł. Następnie użyto bezpośredniego multi_edit. Przed próbą potwierdzono wcześniejsze sumy czterech źródeł, a po synchronizacji długości i niekryptograficzne sumy z repo/Studio były zgodne:

| Źródło | Bajty po normalizacji CRLF→LF | Ważona suma modulo 2147483647 |
|---|---:|---:|
| Bootstrap | 18992 | 892220443 |
| ClientStateStore | 9279 | 1499275920 |
| HUD | 148992 | 646083205 |
| Main | 20336 | 249816198 |

Nie wnioskowano z tego o zgodności całej sceny z buildem.

- **Płyta wylęgu:** przesunięcie postaci na istniejącą płytę na 5 s dało 18 ACCEPTED HatchPress. Projekcja serwera pokazała najpierw 5 kurczaków w kurniku i 13 w drodze, później 18 w kurniku. Zapasu nie przyznawano diagnostycznie.
- **Przytrzymanie HUD:** rzeczywiste mouse down/up na HatchButton. Niezależna sonda ServerToClient widziała ACCEPTED; sonda OnServerEvent zarejestrowała `start, refresh, refresh, refresh, refresh, stop`. Po zwolnieniu i dodatkowych 0,7 s nie przybyły dalsze wejścia. Brak Epic Hold-to-Hatch na koncie oznacza, że ten test dowodzi ścieżki wejść/dzierżawy, nie automatycznego przyrostu dla posiadacza tego badania; reguły hold pokrywają istniejące testy L.
- **Cache płytek:** własna tymczasowa Part TouchPlate pod postacią, atrybuty dodane 0,2 s po parentowaniu. Obserwowano QuoteView nutritional_sup po dodaniu, brak nowych przez 1,6 s po usunięciu i nową odpowiedź po ponownym dodaniu. Płytkę zniszczono. Następnie tymczasowa wymiana obiektu HatchTheEggWorld również dała oczekiwane żądanie; usunięto zamiennik i przywrócono oryginał. Testuje to obsługę intencji, nie pozytywny zakup nieposiadanego badania.
- **Badania HUD:** rzeczywiste kliknięcie ResearchMenuButton i BuyButton comfy_nests. Po checkpointcie serwera otrzymano CommandResult APPLIED z level=1, a karta zmieniła tekst na `★ POZ. 1/50`. Przed checkpointem ujawniono opisany niżej istniejący błąd. Nie deklarować pełnego PASS zakupów za świeży dochód.

## Ujawniony istniejący błąd zakupów — bez naprawy w tym zakresie

Przed automatycznym zapisem zakup był odrzucany jako INSUFFICIENT_CASH pomimo dostępnej wyceny i wystarczającego salda projekcji. Po 300-sekundowym autosave ten sam przycisk poprawnie kupił poziom 1. Dwie wcześniejsze próby HUD zakończyły się REJECTED; nie pominięto ich w ocenie.

Zawężono przyczynę na **niezmienionych modułach serwera**, bez udziału HUD lub cache. Lokalna reprodukcja: fixture 18 kurczaków, zero gotówki, 40 ticków po 0,5 s. Wycena comfy_nests jest dostępna, cena 0,50260546768497227, gotówka projekcji 2,999999999999996. Zakup zwraca REJECTED/INSUFFICIENT_CASH. Po `checkpointPlayer` ponowienie jako nowa operacja zwraca APPLIED przy tej samej gotówce wejściowej. Diagnostyczny skrypt pozostawiono wyłącznie jako ignorowany build/perf_buy_repro.luau; trwałe kroki reprodukcji są tutaj.

Przepływ: PlayerCoordinator oblicza candidate na stanie working; FarmActions.apply zwraca validator z kontrolą freshProfile.farm.cash. SessionRepository uruchamia ten validator na bieżącym trwałym rekordzie **przed** nałożeniem zmian kandydata, więc świeży dochód nie jest jeszcze w saldzie walidowanym. To problem integracji symulacji z transakcją, obecny również bez trzech optymalizacji klienta. Nie zmieniano walidatora, checkpointów ani zasad zapisu w ramach optymalizacji. Nie obchodzić go grantem lub wyłączeniem kontroli salda. Wymaga osobnej naprawy i regresji dla dochodu od ostatniego checkpointu.

## Stan końcowy i granice

Własny Play zakończony; Studio sprawdzone w Edit, UseLocalMemoryStore nadal true, Lighting Soft/quality=false/shadows=true. Rozłączono sondy, usunięto własne płytki/zamiennik świata i przywrócono pozycję postaci przed Stop. Lokalny serwer synchronizacji zakończył pracę. Źródła klienta w otwartej sesji Studio są zmienione; nie zapisywano pliku place na dysk ani nie publikowano go. Repo zawiera zmiany lokalne do review.

Testy były lokalne: bez Robux, trwałego DataStore, dodatkowych graczy, mobilnego H i oddzielnego klienta Roblox. STUDIO_MEMORY blokuje zakupy platformowe, ale pozwala testować badania za gotówkę gry. Celowane kontrole Studio nie zaliczają pełnego S/D/H i nie zatwierdzają wydania.
