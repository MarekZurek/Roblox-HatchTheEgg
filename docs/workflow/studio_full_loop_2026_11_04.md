# Pełna pętla gry — Studio, 2026-11-04

**Wynik: wymaga poprawy przed wydaniem.** Przeprowadzono rzeczywisty lokalny test jednego serwera i dwóch klientów na commicie `865e73534e299106325538e682ec63597fb674ad` (`feat/modern-sim-hud`). Dwa znalezione problemy blokują uznanie pętli za gotową do release.

## Środowisko i metoda

- Własna sesja `StudioTestService:ExecuteMultiplayerTestAsync(2, ...)`, Player1 i Player2 na jednym serwerze. PlaceId=0, CreatorId=0, `UseLocalMemoryStore=true`, zakupy platformowe wyłączone.
- Przed uruchomieniem zsynchronizowano i porównano 48 źródeł z checkoutem. Wszystkie zgodne; wcześniej otwarte Studio zawierało starsze źródła.
- Sterowanie ruchem, myszą i klawiaturą przez Studio MCP; wyniki potwierdzane w autorytatywnych profilach i w prywatnym HUD klienta. Tymczasowe lokalne Script/LocalScript i BindableFunction udostępniały diagnostykę rzeczywistych instancji aplikacji. Nie dodawano testowych RemoteEvent ani RemoteFunction.
- Po zablokowaniu natywnego wejścia do kalendarza otwarto ten modal diagnostycznie; samo odebranie nagrody wykonano myszą. Nie jest to PASS całego natywnego tutorialu.
- Wczesna progresja i pierwszy prestiż bez przyznawania środków. Dla Buy MAX jawny fixture Player1: cash=1e12, currentFarmCash=1e12, buy_max=true; dla późnego progu jajka dodatkowo SE=1e6. Nie jest to pomiar tempa ani balansu progresji.

## Wyniki

| Przypadek | Wynik i dowód |
|---|---|
| Bootstrap obu klientów | PASS: oba READY, osobne profile 1001/1002. |
| Wykluwanie na fizycznej płycie | PASS: Player1 sequence 0→250, populacja docelowo 250, transport kończy się; Player2 sequence=0, populacja=0. Zejście z płyty zatrzymuje wykluwanie; stock odnawia się do 250. |
| Produkcja i sprzedaż | PASS w sprawdzonym stanie: klient raportował 8.333 jaj/s, cash narastał na serwerze. |
| Badania, klik i przytrzymanie | PASS: pojedynczy natywny klik wysłał jeden BuyResearch; przytrzymanie wysyłało powtórzenia i nie wysłało dodatkowego zakupu na Activated po puszczeniu. Żądane przez narzędzie 320 ms trwało faktycznie 603 ms; zarejestrowano trzy zakupy, zgodne z rzeczywistym czasem wejścia. |
| Rozbudowa infrastruktury | PASS: zakup drugiego COOP za 29.12425183994392 oraz drugiego TRIKE za 22.414486035289428. Prywatny HUD odzwierciedlił zakupy, shipping 5000→10000/min. |
| Tutorial — wejście do Rewards | FAIL: domyślny Chat przechwytuje klik; szczegóły poniżej. |
| Nagroda dzienna | PASS po diagnostycznym otwarciu modala: natywny odbiór GE 10→202, numDaily=1, badge znika, tutorial ukończony. Powtórne żądanie odrzucone ALREADY_CLAIMED_TODAY, bez kolejnej wypłaty. Dzień 28 wyświetla Mystery. |
| Naturalny prestiż | PASS: natywny przycisk, prestigeCount 0→1, SE 0→3.5194819102155974; cash/populacja/badania/infrastruktura resetowane, GE=202 i postęp kalendarza zachowane. Player2 bez prestiżu i badań. |
| Buy MAX | PASS na jawnym fixture: natywny MAX podniósł nutritional_sup do 40. Klient F2P otrzymał BUY_MAX_REQUIRED, poziom pozostał 0; po synchronizacji READY. |
| Stacja jajka i próg FV | PASS: natywny prompt G otwiera modal; przy FV ok. 74.26K i wymaganym 250M zakup nieaktywny. |
| Zmiana jajka | PASS na jawnym fixture SE: FV ok. 60.42B; natywny zakup Regular→Duck, eggIndex 0→1, cash=0, badania wyczyszczone, GE=202 i fixture SE=1e6 zachowane. Następnie ponowne fizyczne wykluwanie: sequence 250→500, populacja 250, cash narasta. |
| Izolacja danych graczy | PASS dla sprawdzonych zakupów/resetów i populacji. Player2 sam zbierał naturalne prezenty przy spawn: jego cash/GE zmieniały się z tego powodu; nie traktowano ich jako transferu od Player1. |
| Modele świata w multiplayer | FAIL: wspólne modele/etykiety nadpisywane stanem drugiego gracza; szczegóły poniżej. |

## Blokery

### STUDIO-01 — Chat zasłania Rewards i blokuje tutorial

Repro: nowy Player1 → wykluj → kup badanie → rozbuduj habitat/pojazd → kliknij Rewards w kroku 4. Przy widoku klienta 858×712 środek przycisku to (50,130). Kalendarz pozostaje zamknięty.

`PlayerGui:GetGuiObjectsAtPosition(50,130)` zwraca przed CalendarMenuButton aktywny `Chat.Frame.ChatChannelParentFrame.Frame_MessageLogDisplay.Scroller` i pozostałe elementy Chat. Zrzut ekranu potwierdził panel czatu na Rewards/FarmBadge. `GetCoreGuiEnabled(Chat)=true`.

Oczekiwane: Rewards dostępne natywnym kliknięciem bez manipulacji diagnostycznej. Do poprawy: układ HUD względem CoreGui/chat oraz ponowny test początku gry z otwartym czatem.

### STUDIO-02 — jeden wspólny świat prezentuje różne prywatne farmy

Repro: na dwóch klientach Player1 ma populację 250 i kupiony drugi COOP, Player2 pozostaje z pustą farmą. Prywatny HUD i profil Player1 są poprawne, lecz w jego Workspace etykieta pierwszego habitatu pokazuje `0 / 250 🐔`, a drugiego `Buy on adjacent pad!`.

Przyczyna potwierdzona w źródłach: `src/server/Main.server.luau:95` tworzy jeden `FarmPlotBuilder`; `syncWorldAndDelta` (linia 134, aktualizacja 146) i inne ścieżki aktualizują nim ten sam Workspace dla kolejnych graczy. `src/server/world/FarmPlotBuilder.luau:1661` aktualizuje współdzielone obiekty z prywatnego FarmView.

Oczekiwane: widok farmy zgodny z właścicielem; osobne działki albo prywatna prezentacja. Ten test potwierdza błędne modele świata, nie wyciek lub nadpisanie sald w profilach. Zmiana architektury wymaga osobnego zakresu naprawy.

## Logi, granice i zakończenie

- Serwer: wyłącznie komunikat o pamięci lokalnej i wyłączeniu zakupów. Player2: pusta konsola przy odczycie. Player1: błąd Roblox `ChatScript:116`, `CoreGuiChatConnections has not been registered by the CoreScripts`; wymaga ponownego sprawdzenia po uporządkowaniu czatu. Nie stwierdzono błędu stosu modułów HatchTheEgg w odczytanych logach.
- Statyczna kontrola `tools/verify_build.py`: PASS_STATIC_BUILD, 46 modułów i dwa entrypointy. Własne remotes gry w sesji: wyłącznie ClientToServer i ServerToClient. Nie jest to potwierdzenie konfiguracji faktycznie opublikowanej gry.
- Nie sprawdzono: trwałości DataStore/chmury, ponownego wejścia na opublikowany serwer, prawdziwych zakupów Robux/receiptów, pełnego zakresu petów/fuzji/boostów/offline, urządzeń mobilnych i długiego soak testu. Próba dojścia do konkretnego wygasającego prezentu zakończyła się po terminie; nie jest dowodem pełnej ścieżki jego odbioru.
- Zakończono własną sesję przez EndTest, oba klienty i serwer zamknięte. Przywrócono źródła Main, usunięto probe i atrybuty diagnostyczne. Końcowe porównanie: 48 źródeł zgodnych, zero tymczasowych obiektów __HTEQA, Edit/IsRunning=false. HttpEnabled=true i UseLocalMemoryStore=true zgodnie ze stanem początkowym. Dane fixture zniknęły z lokalną sesją.
- Ceny, bilans i źródła gry w repo bez zmian. Raport i towarzyszący plik dowodów są wynikiem tego zadania; brak nowego commita/pusha.

Następny krok: naprawić STUDIO-01 i STUDIO-02, następnie powtórzyć natywny tutorial i weryfikację świata na dwóch klientach.
