# IMP-02, IMP-03 i IMP-07 — dostarczenie modułów

24.10.2026. Wykonano równolegle zlecony katalog, schematy komunikacji i repozytorium sesji. To moduły i testy lokalne **L**, nie działająca pętla farmy, transport RPC lub potwierdzona trwałość w chmurze. Nie zmieniono bilansu 17–21, danych referencyjnych, NumericCodec ani zatwierdzonych zasad produktu.

## IMP-02 — prywatny katalog

[CatalogRegistry](../src/server/CatalogRegistry/init.luau) i jego [Data](../src/server/CatalogRegistry/Data.luau) zawierają wyłącznie siedem Common z 30, jajo 0, COOP/SHACK i TRIKE/VAN. Konstruktor wymaga NumericCodec, danych i jawnego mode=INTERNAL_TEST_ONLY. To katalog referencyjny do wewnętrznego fragmentu; productionConfigurationApproved=false pozostaje wiążące. Dane/API są głęboko niezmienne. Nie utworzono konfiguracji wydania.

Wykonano kontrolę wszystkich 163 cen badań, 170 rekordów efektów z poziomem 0, 13 progów, jaja, ośmiu cen kurników i 34 cen pojazdów. Wykryto różnicę 1 ULP w dekodowaniu niektórych liczb JSON przez Lune serde; nie zmieniono cen ani tolerancji. Bitowy oracle jest osobnym odczytem Python/struct ze źródłowych JSON, a generator emituje poprawne literały binary64. Oba generatory mają tryb --check w głównym runnerze. [API i ograniczenia](workflow/imp02_notes.md).

## IMP-03 — schematy protokołu v1

[ProtocolSchemas](../src/shared/ProtocolSchemas.luau) udostępnia new(codec).validateClient / validateServer. Ścisłe allowlisty obejmują odczyty, podglądy, trzy pojedyncze zakupy, osobne press/hold oraz snapshot/delta/quote/wynik/admission. Walidacja rozdziela requestId/operationId i commitRevision/viewSeq, wymaga codec, odrzuca obce pola, niepoprawne UTF-8, cykle, metatabele i nadmierny payload. CalculationVersion=1 ma ten sam typ liczbowy co profil.

Własny i publiczny widok mają osobne listy pól; pełny profil, token i ledger nie są DTO. Zgodność schematu nie potwierdza uprawnień, katalogu, dostępności materiałów, świeżości quote lub kolejności pakietów. Gateway, projektor i ClientStore nie są zaimplementowane tym zadaniem. [Dokładny wire i limity](workflow/imp03_notes.md).

## IMP-07 — SessionRepository

[Repozytorium](../src/server/SessionRepository.luau) jest fabryką new(deps): mode=INTERNAL_TEST_ONLY, codec, [PersistenceData](../src/server/PersistenceData.luau), [ProfileSchema](../src/server/ProfileSchema.luau), store, clock, encodeJson i tokenFactory. Clock dostarcza UTC ms i elapsed sekundy; tokenFactory ma tworzyć niepowtarzalne tokeny poza callbackiem. Nie utworzono aktywnego serwera lub połączenia z bazą. Format profilu jest P z kontraktu 27, schemaVersion=1, codec=1 i calculationVersion=1.

| API | Znaczenie |
|---|---|
| acquire(playerId) | Atomowe potwierdzenie braku i nowego profilu albo claim wygasłego/zwolnionego lease; jeden agregat gracza. ACQUIRED zwraca wewnętrzny handle i kopię potwierdzonego profilu. Błąd odczytu nie tworzy pustego konta. |
| commit(handle, operation, plan) | Operation: stabilny operationId, kind, args, quoteId, expectedRevision, opcjonalny validUntilMs. Plan: jawne zmiany ścieżek domenowych, przygotowany result i czysty validate(latestProfile,now). Nie przyjmuje klientowskiego patcha. |
| query(handle,id) / readOperation(playerId,id) | Tylko odczyt przez port bez cache. readOperation nie wymaga claim, więc pozwala odtworzyć istniejący wynik także przy pełnym zapisie. Wywołujący serwer odpowiada za powiązanie playerId z nadawcą. Brak wpisu daje NOT_FOUND/UNKNOWN, nigdy samodzielną nową mutację. |
| renew / release | Kontrola tokenu/generacji i aktualnego UTC wewnątrz mutacji. Renew przedłuża własny ważny lease, release zachowuje generację. Nie zwiększają ekonomicznej revision. |
| recover(oldHandle,id) | Blokuje stary handle. Po wygaśnięciu lease nowy atomowy claim zwiększa fence: jego snapshot zawiera wcześniejszy wynik albo pozwala potwierdzić NOT_APPLIED. Zajęty lease lub niepewny zapis pozostawia UNKNOWN. Nie ponawia sam zakupu. |

Plan jest kopią, a ścieżki mogą zmieniać tylko wskazane pola sekcji domenowych, nie meta/ownership/operations lub całą sekcję. Nakładające się ścieżki są odrzucone. Świeży walidator i migracje są wywoływane bez yield; losowy wynik musi być przygotowany raz przez przyszłą domenę. Walidator musi sprawdzić konkretne koszty i materiały na świeżym stanie; repository nie zastępuje FarmActions. Koszt, korzyść, checkpoint, revision i wynik ID trafiają do jednego UpdateAsync. Wszystkie niezmieniane sekcje, także nieaktywne i obce, pozostają zachowane.

Canonical argsKey jest pełnym jednoznacznym kodowaniem kind/args/quoteId, bez kryptograficznego skrótu i bez expectedRevision/terminu ważności; nowa kolejność kluczy nie zmienia znaczenia. Replay preceduje kontrolę revision i expiry. Zmieniony sens tego samego ID daje konflikt. Terminalne odrzucenia nowej operacji są także zapisywane z wynikiem i revision, więc ponowienie nie może później zmienić ich w sukces. Wynik repository jest wewnętrzny: przyszły projektor mapuje go na allowlistowane CommandResult; nigdy nie wysyła surowego rekordu do klienta.

Lease ma 120 s, próba odnowienia jest planowana przez przyszłego koordynatora co 30 s, a nowe mutacje zatrzymują się 20 s przed potwierdzonym końcem. W każdym wywołaniu callbacku jest świeży odczyt clock. Cofnięcie lub rozjazd UTC/elapsed większy niż 5 s blokuje handle; jest to parametr techniczny P, nie reguła gospodarki. Nie obiecujemy maksymalnego skosu zegarów między maszynami. Repository nie uruchamia własnego timera ani nie porównuje elapsed między serwerami.

Raw błąd storage to UNKNOWN i blokada dalszych mutacji. Nil anulujący transform nie jest commit; nawet pcall=true bez oczekiwanego rekordu nie dowodzi wykonania. Odczyt może odtworzyć istniejący wynik, ale sam brak wpisu po timeout nie daje pewności niewykonania. Lease/fence i wykluczenie starego callbacku są rozstrzygane jawnie przez recover. Lokalny guard serializuje wywołania jednego handle; przyszły PlayerCoordinator nadal musi porządkować komendy/ticki/checkpointy gracza.

## Profil, limity i adapter natywny

Nowy profil wewnętrzny używa referencji 31, nie fixture z 30: cash=0, jeden pusty COOP, TRIKE przy limicie 4, jeden silos, zapas 250, neutralne efekty oraz referencyjne GE=10 i spent=0. Nie aktywuje to konfiguracji produkcyjnej. Nowszy, uszkodzony albo nieobsługiwany profil pozostaje nienadpisany. Brak domyślnych migracji starych kont; jawne wstrzyknięte migracje wymagają obsługi wersji i zachowania sekcji. Test migracji dotyczy sztucznego stanu, nie danych graczy.

Cały JSON profilu ma limit 3 MiB, w tym ledger 2 MiB; mierzymy zakodowane bajty, nie liczbę wpisów. Bounded copy odrzuca cykle, metatabele, nieprawidłowe UTF-8, mieszane/rzadkie tablice, NaN/Inf, głębokość >48 i >100000 węzłów. To limity techniczne danych, nie pojemność farmy. Pełny ledger zatrzymuje nowe operacje bez usuwania ID; odczyt i replay pozostają dostępne. Nie ma FIFO, resetu profilu, podziału transakcji na dwa klucze ani płatnego odblokowania miejsca. To rozwiązanie skończonego fragmentu wewnętrznego. Długotrwała retencja i rzeczywisty test D pozostają bramkami przed wydaniem; nie twierdzimy, że ta wersja obsłuży produkcję bez ograniczeń.

[RobloxDataStorePort](../src/server/RobloxDataStorePort.luau) opakowuje UpdateAsync/GetAsync, zachowuje istniejące userIds/metadata i używa DataStoreGetOptions.UseCache=false. Wymaga jawnie przekazanego obiektu store; nie wybiera automatycznie przestrzeni produkcyjnej. Fakty API sprawdzono w [Data Stores](https://create.roblox.com/docs/cloud-services/data-stores), [GetOptions](https://create.roblox.com/docs/reference/engine/classes/DataStoreGetOptions) i [limitach/błędach](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits). Test portu jest fake API, nie wykonaniem usług Roblox.

## Uruchomienie i poziom dowodów

W PowerShell: ./tools/bootstrap.ps1, następnie ./tools/test.ps1 -PythonExecutable python. Potrzebny Python 3.10+ (stdlib) do dwóch kontroli katalogu i statycznego sprawdzenia pliku Rojo; można podać pełną ścieżkę interpretera. Lune i Rojo nadal przypięte jak w IMP-01. Wyniki w ignorowanym build; binaria w ignorowanym .tools.

Mapowanie Rojo rozdziela NumericCodec/ProtocolSchemas w ReplicatedStorage od wszystkich modułów katalogu/zapisu w ServerScriptService. Testy i narzędzia nie są mapowane. Statyczna kontrola artefaktu budowania nie jest dowodem replikacji w Studio. Brak Script/LocalScript uruchamiającego farmę, połączenia z serwisami lub handlera przyznającego zasoby. servePlaceIds pozostaje puste. To konfiguracja wewnętrznego budowania, nie manifest produkcji.

[Raport weryfikacji](workflow/parallel_implementation_verification.json) zawiera wyniki L, źródła oczekiwań, hashe i zakres QA. Nie wykonano typecheckera, Studio, RPC, prawdziwego DataStore, awarii rzeczywistego serwera ani danych graczy. Stare raporty, w tym numeric_codec_verification.json, są snapshotami wcześniejszych wersji narzędzi; nie przepisano ich hashy pod nowy runner. Zakończenie tych trzech zadań nie zalicza F03 lub A01–A16 w środowisku D i nie zleca kolejnych implementacji.
