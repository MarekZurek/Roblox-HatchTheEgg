# Cztery wyspy i naprawa blokerów Studio — 04.11.2026

**Wynik: STUDIO-01 i STUDIO-02 naprawione i ponownie sprawdzone na dwóch klientach.** Dostawa na bazie `865e73534e299106325538e682ec63597fb674ad`; kod, testy i raporty objęte wspólnym commitem na zlecenie użytkownika. Bez publikacji Roblox. Ceny, katalogi, nagrody i odłożony bilans bez zmian.

## Zmiana

- `world/FarmWorld` tworzy wspólną wyspę centralną ze złotym jajem i cztery jednakowe farmy połączone mostami. Środki farm: (0,0,240), (240,0,0), (0,0,-240), (-240,0,0). W każdej 267 potomków w stanie początkowym. Lokalny podgląd przebudowano również w Edit i zapisano w `HatchTheEgg.rbxlx` przez Studio.
- Serwer rezerwuje oddzielny slot dla gracza, kieruje aktualizacje modeli do jego buildera, przypisuje RespawnLocation i obsługuje już istniejącą Character. Brak wolnego slotu odmawia wejścia zamiast współdzielić farmę. Wyjście zwalnia i odbudowuje tylko zajmowaną działkę.
- Wszystkie nowe części farmy, także geometria habitatów odbudowana po zakupie, uwzględniają początek wyspy. Klient używa wyłącznie własnych padów/prompts; serwer bada wyłącznie własną płytę gracza. Cudze prompts są lokalnie wyłączone.
- Wizualne trasy kur i prezenty są przesunięte na własną wyspę. Serwer przelicza rzeczywistą pozycję postaci na współrzędne lokalne przed odbiorem prezentu. Nie zmieniono dystansów/czasów domeny ani schematu profilu i protokołu.
- Rewards przeniesiono z obszaru czatu do prawego panelu. Zachowano badge i wyróżnienie celu tutorialu; panel jest przewijany i ograniczony wysokością okna, z przewinięciem do Rewards w kroku 4.

## Ponowny test Studio

Własna sesja `StudioTestService:ExecuteMultiplayerTestAsync(2, ...)`, jeden serwer i dwóch klientów. PlaceId=0, jawne STUDIO_MEMORY, płatności wyłączone. Przed testem porównano 49 źródeł z checkoutem. Tymczasowe, lokalne Script/LocalScript z BindableFunction odczytywały rzeczywiste instancje aplikacji; nie dodano testowego zdalnego ingressu. Tutorial bez przyznawania środków i bez diagnostycznego otwierania okien.

| Przypadek | Obserwacja i wynik |
|---|---|
| Oddzielne wejście | PASS: Player1 slot 1, spawn ok. (0,3.90,264); Player2 slot 2, spawn (240,3.90,24). |
| Wykluwanie pierwszego gracza | PASS: Player1 sequence=250, populacja i billboard 250/250; Player2 sequence=0, populacja i billboard 0/250. |
| Tutorial Player1 | PASS: fizyczna płyta → natywny zakup nutritional_sup → natywny zakup drugiego habitatu → natywne Rewards → natywny odbiór. GE 10→202, karta tutorialu znika, Shop dostępny, badge gaśnie. |
| Chat kontra Rewards | PASS: Chat włączony. Środek Rewards (808,435) w widoku 858×712; hit-test wskazuje ikonę/przycisk CalendarMenuButton i RightDock. Klik otwiera CalendarFrame. Przed naprawą ten sam krok zatrzymywał się na Chat.Scroller — STUDIO-01 FAIL→PASS. |
| Tutorial Player2 | PASS: ten sam zestaw wejść natywnych na drugiej wyspie; nagroda odebrana raz, GE=202, READY, tutorial ukryty, badge wyłączony. |
| Różne farmy widoczne u obu graczy | PASS: natywny awans habitatu Player1 daje 250/500, Player2 pozostaje 250/250. Później obaj klienty jednocześnie widzą Player1: 424/500 i 180/250; Player2: 250/250 i 0/250. STUDIO-02 FAIL→PASS, bez naprzemiennego nadpisania. |
| Odbudowana geometria | PASS: po zakupie/awansie habitat Player1 pozostaje przy (-35,205), drugi przy (35,205) w osiach X/Z; habitat Player2 przy (205,-35). Brak powrotu nowych modeli do początku mapy. |
| Cudza płyta | PASS: kontrolowane przesunięcie rzeczywistej Character Player1 na (240,4,37), płytę Player2. held=false dla obu, sequence obu pozostaje 250, mimo wolnej pojemności Player1. Powrót na własną płytę daje held=true i wzrost sequence; Player2 bez dodatkowego wylęgu. |
| Cudze interakcje | PASS: u Player1 wszystkie 10 prompts drugiej farmy wyłączone; własne wykrywane osobno. Lokalny handler dodatkowo sprawdza potomstwo ownFarm. |
| Trasy wizualne | PASS: Player1 start (0,0,285), koniec slotu1 (-30,0,210); Player2 start (240,0,45), koniec (210,0,-30). Zachowane czasy sprawdzono też w Lune. |
| Respawn | PASS: `LoadCharacterAsync` Player1 wraca na jego spawn około (0.21,3.90,263.93), slot=1; postęp farmy zachowany. |
| Prezenty | PASS w sprawdzonym przypadku: po kontrolowanym przesunięciu Character na naturalne miejsce lądowania własnej wyspy serwer wypłacił Player1 1247.7778869488529 cash; zachowany rekord `gift-1-1793815267141-27` ma ownerId=1001, lokalne (-12,1.15,18), claimed=true i tę samą kwotę. Nie używano żądania HitDrone ani przyznawania salda. |
| Wyjście | PASS: odłączono testowego Player1; Farm1 owner pusty i 0/250, Farm2 owner=1002 i nadal 250/250. |

Przesunięcia Character do cudzej/własnej płyty, prezentów i wymuszony respawn są kontrolowanymi wejściami testowymi, nie dowodem naturalnego przejścia wszystkimi mostami. Walidację źródeł, stan autorytatywny i odczyty obu klientów zapisano w [dowodach JSON](farm_islands_2026_11_04.evidence.json).

## Regresje i testy lokalne

- `tests/farm_islands/run.luau`: 64 asercje — lokalizacja Rewards, badge, różni właściciele, aktualizacje świata przez rzeczywisty Main, cztery sloty i brak piątego, zwolnienie/ponowne wykorzystanie, przesunięcia tras i prezentów, niezmienione czasy.
- Dwa semantyczne błędy w **izolowanych kopiach** src/tests wykryte przez ten sam test: CalendarMenuButton przypięty z powrotem do root → FAIL `Rewards is in the right dock`; Main aktualizujący zawsze farmę gracza 1 → FAIL `second Bootstrap cannot write first world`. Oba exit=1; poprawna wersja PASS. Szczegóły w JSON.
- Dotychczasowy MainHarness korzysta z rzeczywistego przydziału FarmWorld i kontrolowanego adaptera świata. Testy odbioru prezentu uwzględniają przesuniętą Character. Kontrole buildu wymagają nowego prywatnego modułu FarmWorld: 47 modułów i dwa entrypointy.
- Komenda pełnego runnera: `./tools/test.ps1 -PythonExecutable C:/Users/Marek/AppData/Local/Python/pythoncore-3.14-64/python.exe`. **PASS, exit=0: 56 zestawów Lune, testy Python, build/sourcemap i końcowy verify_release.** Log w JSON. Wcześniejsze uruchomienia ujawniły stare oczekiwania liczby modułów (46 zamiast 47) i brak nowego adaptera w MainHarness; zostały poprawione, bez wyciszania błędów.

## Granice i cleanup

- Bez testu rzeczywistego DataStore i zakupów, bez publikacji, pełnej sesji czterech klientów, odbioru mobilnego oraz pełnego playtestu wszystkich mostów. Cztery sloty/odmowę piątego/ponowne użycie sprawdzono lokalnie w Lune; w Studio aktywne były dwa klienty.
- W logach obu klientów były błędy Roblox CoreGui `Invalid value for enum CreatorType` i kaskada ładowania TopBar/PlayerList w lokalnym place. Nie kwalifikujemy ich jako błędu modułów HatchTheEgg ani jako PASS całego CoreGui. Diagnostyka miała też błędne wywołanie `getRoutePresentation`; poprawiono je na istniejące `getPresentation` przed użyciem wyników tras. Logi zachowane w JSON.
- Zakończono własny serwer/klienty przez EndTest; pozostało jedno Studio w Edit. Przywrócono Main, usunięto probe/atrybuty i ponownie porównano **49 źródeł: zero rozbieżności, zero obiektów __HTEQA**. HttpEnabled=true i UseLocalMemoryStore=true zgodne ze stanem początkowym. Podgląd czterech pustych farm nie zawiera profili testowych.
- Zaktualizowano CURRENT_SPEC, WORKING_CONTEXT i TODO. To scoped PASS obu zleconych poprawek, bez akceptacji całego wydania. Ceny i balans pozostają bez zmian.
