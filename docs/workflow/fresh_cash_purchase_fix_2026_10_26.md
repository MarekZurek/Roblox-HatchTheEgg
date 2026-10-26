# Zakup za świeży dochód — naprawa 26.10.2026

## Problem i zakres

Zlecenie: umożliwić wydawanie świeżego dochodu przed checkpointem, z regresjami braku podwójnych naliczeń i utraty postępu. Bazowy HEAD `3284b5b1d5fbe8c8dcfd685e1a1a27e7247175ad`; na wejściu były lokalne optymalizacje klienta z [poprzedniego zadania](client_performance_2026_10_26.md). Zachowano je. W tej naprawie zmieniono jeden moduł runtime: PlayerCoordinator. Bez zmian cen, wzorów, referencyjnych JSON-ów, docs/17–21, schematu profilu, protokołu i adaptera DataStore.

Reprodukcja przed poprawką: fixture 18 kurczaków, początkowe saldo 0, 20 s produkcji daje 3$ w working i 0$ w durable. Wycena comfy_nests dostępna (0,50260546768497227$), ale komenda zwracała REJECTED/INSUFFICIENT_CASH. Nowy test uruchomiono przed naprawą i otrzymano oczekiwany FAIL na wymaganym APPLIED.

Przyczyna: domena przygotowywała zakup na stanie po symulacji, natomiast SessionRepository wykonywało jego validator na trwałym rekordzie sprzed tej symulacji. Kontrola salda nie widziała jeszcze przychodu.

## Naprawa i granica atomowości

PlayerCoordinator przygotowuje validator stanu po symulacji i przed zakupem. Zmiany symulacji między durable i tym stanem są nakładane na osobną kopię aktualnego wejścia każdego callbacku repozytorium. Najpierw sprawdzana jest zgodność bazowych wartości pól; następnie oryginalny validator domeny otrzymuje stan z uwzględnionym świeżym dochodem. Pozostałe pola, np. niezmienione przez symulację uprawnienia, pozostają aktualnymi wartościami callbacku. Nie podmieniono całego rekordu snapshotem i nie usunięto walidacji.

Do właściwego zapisu nadal trafia **jeden** plan: symulacja, wydatek, zakupiona korzyść, kursor czasu i wynik operationId. Nie dodano poprzedzającego checkpointu ani drugiego zapisu. Ponowne wykonanie callbacku zaczyna od jego własnego wejścia, nie dopisuje ponownie dochodu do zmodyfikowanej kopii. Replay nadal wyprzedza walidację wersji i wyceny. Fencing token/generacja, kontrola rewizji, deadline, limity, UNKNOWN i ledger pozostają w SessionRepository.

Jeżeli pole bazowe symulacji zostało zmienione w storage mimo tej samej rewizji, validator odmawia SIMULATION_BASE_CHANGED. Koordynator ukrywa rozbieżny working i blokuje nowe mutacje/checkpointy do recovery, aby późniejszy zapis nie nadpisał świeższego stanu. To ochrona przed niezgodnością źródła, nie sposób na ominięcie braku środków.

## Testy regresji

`tests/fresh_cash_purchases/run.luau`: **308 asercji PASS L**, rzeczywiste Bootstrap/Timeline/Coordinator/FarmActions/SessionRepository z kontrolowanym storage i zegarem:

- wydanie 3$ dochodu bez wcześniejszego zapisu, jednokrotne potrącenie i zachowanie currentFarmCash;
- dochód między ostatnim tickiem a momentem komendy;
- badania, kurniki i pojazdy: pojedynczy zapis, zachowane timery, efekty, kursory, inwentarz i inne sekcje; checkpoint i reconnect bez zmian tych sekcji;
- kolejne zakupy, stare rewizje, wielokrotny replay oraz odrzucenie rzeczywistego braku środków bez utraty wcześniejszej symulacji;
- wielokrotny callback przed zapisem oraz callback obserwujący już utrwalony wynik;
- zapis z utraconą odpowiedzią: UNKNOWN, zamrożenie pracy, odczyt wyniku i replay po restarcie bez ponownego kosztu/nagrody;
- błąd przed zapisem i spóźniony callback: fence, rozstrzygnięcie NOT_APPLIED, odtworzenie czasu od trwałej granicy i jawna nowa próba; stary callback nie przyznaje korzyści;
- zmiana bazowego salda podczas zapisu: odmowa i blokada późniejszego checkpointu starego working.

W testach odzyskiwania bez zapisu użyto jawnego fixture Pro dla jakości offline=1. Niezależne oczekiwanie to 140 s × 18/30 × 0,25 = 21$ przed kosztem. Nie zmieniono reguły offline zwykłego konta ani nie obiecuje się zachowania niepotwierdzonej mutacji po awarii; po fence symulacja jest odtwarzana według istniejących reguł.

W `tests/purchases/run.luau` poprawiono niespójny stary fixture testu braku środków. Zerował rekord i handle.snapshot, lecz próbował wyzerować working przez edycję kopii zwróconej z snapshots(). Właściwy working nadal miał poprzednie środki. Teraz osobny aktor startuje ze spójnym saldem 0. Nadal wymagane są REJECTED, INSUFFICIENT_CASH w wyniku terminalnym oraz replay tego odrzucenia. Powód odrzucenia domenowego jest w result.errorCode; wcześniejszy fixture sprawdzał przypadkiem ścieżkę odmowy późniejszego validatora. Pierwsze dwa przebiegi pełnego runnera ujawniły kolejno te dwie niespójności; po ich poprawieniu pełny runner przeszedł.

Wybrane mutacje semantyczne, `tests/fresh_cash_purchases/mutation_check.py`: **6/6 wykrytych** przez asercje nowego zestawu. Obejmują pominięcie nakładania symulacji, walidację tylko durable lub stanu po zakupie, pominięcie zapisu dochodu/kursora, usunięcie kontroli bazy i dopuszczenie checkpointu po rozbieżności. Skrypt przywrócił oryginalne bajty źródła w finally i ponownie uruchomił niemutowany zestaw: PASS. To wybrane mutacje, nie ogólny procent pokrycia.

## Pełna weryfikacja lokalna

Komendy:

```powershell
./tools/test.ps1 -PythonExecutable 'C:\Users\Marek\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& 'C:\Users\Marek\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/fresh_cash_purchases/mutation_check.py
git diff --check
```

Wynik: **40 zestawów / 81 171 asercji Luau PASS**, 11 testów Python PASS, generatory/oracle PASS, Rojo build i mapowanie PASS (39 modułów + 2 entrypointy), kontrola dowodów wydania PASS lokalnie. Bilans bez zmian. Nowy zestaw zarejestrowany w runnerze, nowe mutacje także w opcjonalnym -MutationChecks. Szerokich dawnych mutation checks nie powtarzano.

Self-review wykonano; niezależnego review nie wykonano. To nie jest zatwierdzenie wydania ani weryfikacja rzeczywistej chmury.

## Celowana próba Studio

Instancja `a2736f6d-166a-46c7-82a7-b7e01afa84ab`, `HatchTheEgg.rbxlx`, użytkownik Studio 11647593962, PlaceId=0, Edit na wejściu, Main.UseLocalMemoryStore=true. Przed zmianą PlayerCoordinator w Studio miał 13299 bajtów i sumę 1199307656; zgodny z wcześniejszym źródłem. Zsynchronizowano tylko ten moduł. Po zmianie repo i Studio: 14621 bajtów po normalizacji CRLF→LF, ważona suma modulo 2147483647 = 652243458. To kontrola niekryptograficzna tego źródła, nie całej sceny.

Własny Play, jeden klient i serwer STUDIO_MEMORY. Stan początkowy z odpowiedzi serwera: cash=0, common comfy_nests level=0, populacja=0, commitRevision=0. Postać stała 5 s na istniejącej płycie wylęgu; po dotarciu 18 kurczaków produkowało dochód. Przed kliknięciem: cash=5,6885416666666595, nadal commitRevision=0, dostępna wycena 0,50260546768497227. Runtime miał około 45 s — przed 300-sekundowym autosave.

Rzeczywiste kliknięcie menu badań i BuyButton comfy_nests zwróciło CommandResult **APPLIED, resultRevision=1, level=1**. Karta HUD pokazała `★ POZ. 1/50`. Nie użyto grantów ani ręcznego checkpointu.

Dwa ponowienia przechwyconej komendy z tym samym operationId i nowymi requestId zwróciły **REPLAYED, resultRevision=1, level=1**. Następny autorytatywny snapshot nadal miał commitRevision=1 i level=1. Gotówka rosła dalej z produkcji; ścisłe równania kosztu/przychodu i scenariusze awarii sprawdzają testy L powyżej.

Odłączono sondy klienta/serwera, usunięto ich dane, przywrócono pozycję postaci i zamknięto panel, zakończono własny Play. Końcowy odczyt: Edit, PlaceId=0, UseLocalMemoryStore=true. Źródło w otwartym Studio zmienione; bez zapisu place na dysk, bez publikacji, commitu lub push. Tryb pamięci nie testuje trwałych danych ani zakupów platformowych. Nie wykonano pełnego odbioru S/D/H.

## Identyfikacja plików

SHA256 z odczytu bajtów po weryfikacji:

| Plik | SHA256 |
|---|---|
| src/server/PlayerCoordinator.luau | FF4CF7DA056F0F3B9EACFED7FC817E3F6CFE4C643A49E452B0A29D3C5F45A686 |
| tests/fresh_cash_purchases/run.luau | 1D030E4D0E8E8F254FBED2B88E89D122C8B82D3DE7AC809274D4892426AA03FF |
| tests/fresh_cash_purchases/mutation_check.py | FB919DA1CED00255E96CF7D970FBBE6246678C55349AC5CEFB77B89F73DCBCA8 |
| tests/purchases/run.luau | EEF85A30543AF26E683D4F3664046193B535F0D02AAA10CAE8CDFA1F3C075467 |
