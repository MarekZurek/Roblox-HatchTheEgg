# F01 — manifest pierwszej farmy i wybory techniczne

23.10.2026. **P — przygotowanie dokumentacyjne F01 z [29](29_first_farm_implementation_plan.md). Bez implementacji.** To manifest przyszłego wewnętrznego fragmentu do testów, nie konfiguracja wydania. Zasady [27](27_numbers_time_and_player_state_contract.md), [28](28_modules_and_client_server_contract.md) i R z [CURRENT_SPEC](CURRENT_SPEC.md) pozostają nadrzędne. Nie zmieniono danych referencyjnych, 17–21 ani historii Git.

> **Aktualizacja 24.10.2026:** [31](31_research_hatching_rcb_and_new_account.md) rozstrzyga U01/U02, rdzeń stanowy i wzór U03 oraz referencyjny start podstawowej farmy U04. Starszy profil TEST_ONLY poniżej pozostaje osobnym fixture; nie opisuje referencyjnego nowego konta. Nowe ustalenia mają pierwszeństwo nad opisami niewiadomych pierwszej redakcji.

## 1. Wybrany zakres i dostępność danych

P: nazwa manifestu `first-farm-neutral`, wersja opisowa 1. Jeden gracz ma własny agregat; na serwerze trzeba później sprawdzić izolację co najmniej dwóch graczy. Brak zakupów platformowych, Epic jako sklepu, petów, boostów/VD, wydarzeń, nagród, resetów i Hyperloop. Profil z nieobsługiwanym aktywnym efektem pozostaje zachowany i nie jest uruchamiany przez ten fragment.

Każdy wybór ID poniżej ma status **P**, a jego istniejące wartości **S/N**. Pełne ceny/poziomy czytać z [research.json](reference_data/research.json) i [infrastructure.json](reference_data/infrastructure.json); żadnych nowych cen lub ich zaokrągleń. Indeksy danych są od zera, slot UI od 1 wymaga jawnej konwersji. Nie tworzymy obecnie pliku manifestu wykonywalnego lub generatora.

| Pozycja | Wybrane ID / rekordy P | Źródło S/N i użycie |
|---|---|---|
| Jajo | eggs[index=0], EDIBLE | Wartość 0.25; tylko to jajo, bez trofeów lub awansu. |
| Kurniki | habitats[index=0] COOP; habitats[index=1] SHACK | Pojemność bazowa 250/500, ceny z `prices`. Cztery rekordy slotów; pusty slot nie jest dodatkowym zakupionym COOP. |
| Pojazdy | vehicles[index=0] TRIKE; vehicles[index=1] TRANSIT VAN | 5000/15000 jaj/min. Cena według liczby egzemplarzy danego typu przed zakupem. Limit floty jest osobnym wejściem, nie wynika z długości listy pojazdów. |
| Silosy | Brak komendy zakupu; liczba posiadanych podana przez testowy profil | [drone_and_silo_rules.json](reference_data/drone_and_silo_rules.json) i [06](06_drones_silos_and_events.md): secondsPerSilo=3600+360×levelSiloCapacity. To nie liczba domyślnie nadanych silosów. |

### Siedem Common — lista dopuszczona wyłącznie w tym planie

| ID | tier_raw / maxLevel S | Obsługiwany wymiar S; wynik dla poziomu 1 |
|---|---|---|
| comfy_nests | 0 / 50 | eggLayingRateMult=1.1 |
| nutritional_sup | 0 / 40 | eggValueMult=1.25 |
| better_incubators | 0 / 15 | hatcheryRefillRateMult=1.1 |
| hab_capacity1 | 1 / 8 | habCapacityMult=1.05 |
| internal_hatchery1 | 1 / 10 | internalHatcheryRate=2 kur/min/kurnik |
| hatchery_expansion | 1 / 10 | hatcheryCapacity=10, dodatek do bazowej pojemności |
| leafsprings | 2 / 30 | vehicleCapacityMult=1.05 |

`prices[k]` kupuje poziom k+1, `effectsByLevel[k]` jest izolowanym efektem poziomu k. Poziom 0 ma pusty rekord efektów, nie zestaw zerowych mnożników. Bazę/addytywność/mnożenie ustala właściwy agregator z [01](01_upgrades_and_research.md) i [03](03_habitats_and_population.md). Nie wyliczać wszystkich poziomów z pierwszej próbki.

W JSON pierwsze progi tierów wynoszą 0, 30, 80. **Aktualnie U01 rozstrzyga 31:** licznik jest sumą poziomów wszystkich Common, z inkluzywnym porównaniem. 105 poziomów pozwala osiągnąć progi 30 i 80 bez dowodu tempa progresji; osobny test funkcji może otrzymać jawny poziom jako wejście, ale nie omija bramki gracza. Wszystkie niewymienione ID są niedostępne, bez sprzedaży poziomu z pominiętym efektem. Wyłączenie excitable_chickens nie usuwa bazowego RCB.

## 2. Start: źródło a profil testowy

[02](02_eggs_and_farm_value.md) opisuje po resecie cash=0, populację=0, jeden COOP, jeden TRIKE i Common=0. **Reset nie jest dowodem inicjalizacji nowego konta.** Nie nadawać poniższym propozycjom statusu R/N nowego konta. Dopóki inicjalizacja nie jest ustalona, A01 z 29 nie może być zaliczone jako rzeczywisty onboarding nowego gracza.

P: przyszły profil `TEST_ONLY_EMPTY_FARM` ma służyć izolowanym testom; teraz opisujemy go wyłącznie w Markdown:

| Pole 27 | Propozycja TEST_ONLY | Pochodzenie / ograniczenie |
|---|---|---|
| farm.eggIndex, cash, Common | 0; BigAmount 0; wszystkie Common 0 | Wartości wzorowane na opisanym resecie, wybór fixture P. Pełne dane Common zachowane, dostępność tylko siedmiu ID. |
| farm.habitats | Cztery sloty; pierwszy COOP, pozostałe puste; populacje/ułamki/kury przypisane w drodze 0 | Fixture P wzorowany na 02. Nie utożsamiać pustego slotu z kurnikiem typu 0. |
| farm.vehicles | Jeden TRIKE, bez pociągu | Fixture P. Dla początkowych testów podmiany pojazdu limit floty TEST_ONLY=1; nie jest to referencyjny limit nowego konta lub zatwierdzony limit gry. |
| farm.hatchery | Zapas TEST_ONLY=250, brak aktywnej intencji; bazowa pojemność 250 i refill 3/s z 03 | Pełny zapas jest wyborem fixture, nie dowodem startu konta. Przed pierwszym ruchem populacja i RCB neutralne; U02/U03 blokują pełny ręczny przebieg. |
| farm.silosOwned; Epic | TEST_ONLY=0; poziomy Epic=0 | Brak przyznanego Pro; zero silosów daje zero produkcji away. Oddzielny wariant testu z 1 silosem sprawdza istniejący wzór czasu, nie nową nagrodę. |
| accounting | Akumulatory bieżącej i archiwalnej sesji, lastBaseEarnings i statystyki=0 | Pusty testowy przebieg, bez wcześniejszego przychodu. Koszt zakupu nie cofa zarobionego przychodu. |
| inventory/effects/entitlements/rewards/piggy | Neutralne/puste sekcje zgodne ze schematem 27; brak aktywnych korzyści i ofert | Nowy fixture, nie instrukcja wyzerowania istniejącego profilu. Inaktywne sekcje mają pozostać zachowane podczas zapisu. |
| timeline, meta, ownership, operations | Start z kontrolowanego zegara testu; wersje codec/schema/config; właściciel testu i pusta historia | Nie losowe daty z klienta. Nazwy i wartości wersji oraz token generuje przyszły adapter; P, nie istniejący format produkcyjny. |

Wyższe populacje/poziomy, gotówkę na zakup, stan sharing i błędy wstrzykuje wyłącznie lokalny harness testu wskazanej funkcji. Nie tworzyć remotes przyznających zasoby. Nie używać podwyższonych wartości jako dowodu naturalnej osiągalności, czasu progresji lub poprawnego nowego konta. Nie nakładać fixture na istniejący zapis.

## 3. Wylęg i RCB — aktualizacja 24.10.2026

Pierwsza redakcja wskazywała brak danych U02/U03. Aktualne reguły i ich statusy opisuje [31](31_research_hatching_rcb_and_new_account.md): pojedynczy press to jedna próba, holdRate bez Epic=0, refill to osobna wielkość. RCB ma wzór q=min(c^n,K), M tylko gdy q>1; cel jest wybierany według przedziałów wolnego miejsca. Wypuszczenie rezerwuje miejsce, dotarcie dopiero zwiększa zasiedloną populację. Nie dodajemy dodatkowych etapów inkubacji lub arbitralnych 6 s.

Produkcja poprzedza wzrost IHR; dotarcia są osobnymi zdarzeniami koordynatora. Pozostaje dostarczenie geometrii i autorytatywnego czasu/zdarzenia dotarcia przez scenę. Test z kontrolowanym dotarciem nie zalicza prawdziwego ruchu w Studio. Protokół 28 zawiera HatchPress oraz osobny hold; start/heartbeat sam nie przyznaje darmowego ciągu prób.

## 4. Minimalna projekcja i komendy

P: pola widoku są jawnie mapowane na typy 27, bez nowego źródła prawdy. Wszystkie liczniki ExactUInt są tekstem dziesiętnym, również populacja i revision; kwoty/Real64 używają tekstu round-trip z 27. SmallIndex może pozostać małym number. Instant to ms, Duration to sekundy.

| DTO P | Dozwolona zawartość |
|---|---|
| OwnFarmView | lifecycle; eggIndex: SmallIndex (ten sam indeks od zera co farm.eggIndex); cash; cztery sloty habitat: typ/null, population, reservedInTransit, capacity; hatchery: stock/capacity/refillPerSecond; flota: typy i shippingPerMinute; producedEggsPerSecond, soldEggsPerSecond, cashIncomePerSecond; Common: poziomy, dostępność i powody blokady. Wskaźniki tempa opisują ten sam stan/czas, nie obietnicę stałego przyszłego dochodu. |
| Snapshot / delta | protocol/schema/numeric/config/calculation versions, streamId, viewSeq, commitRevision, serverObservedAt i dozwolony widok. Delta ma baseViewSeq i jawne usunięcia; lifecycle z 28. |
| QuoteView | quoteId, cel/slot/ID, cena, waluta, następny poziom lub typ, warunki i wersje; utworzenie nie pobiera kosztu. Podgląd to osobna odpowiedź, nie operationId zakupu. |
| CommandResult / OperationStatus | Koperta i statusy z 28; tylko własna operacja. admission=NOT_ACCEPTED nie jest terminalnym odrzuceniem ani śledzoną pracą PENDING. |
| PublicFarmView | Tylko jajo, typy widocznych budynków/pojazdów oraz zagregowana populacja. Bez cash/GE, prywatnych ID operacji, tokenów i wyposażenia. To ograniczenie pierwszego fragmentu, nie rozstrzygnięcie wszystkich przyszłych danych publicznych. |

Allowlista pierwszego fragmentu: Bootstrap/RefreshState, QuoteRequest, OperationStatus; BuyResearch(single), BuyHabitat, BuyVehicle; HatchInput. Wymagane argumenty, quoteId i replay pozostają dokładnie z 28. Nie rejestrować pozostałych mutacji przez ogólny handler. Odrzucenie bramki lub nieobsługiwanego ID nie usuwa stanu profilu. quoteId nie zastępuje operationId, a expectedRevision nie zastępuje zgody na cenę.

Powtórkę istniejącego operationId o tych samych argumentach sprawdzić przed expectedRevision i wygaśnięciem quoteId; zwrócić utrwalony wynik, nie nowy zakup. Zmiana argumentów tego ID jest konfliktem. Samo ponowne połączenie lub nowszy widok nie unieważnia replay.

## 5. Wybory adapterów P i plan sprawdzenia

Poniżej wybieramy kierunek dla pierwszego fragmentu, **nie deklarujemy działających adapterów**. Fakty API sprawdzono w oficjalnych źródłach 23.10.2026. Nie instalowano bibliotek i nie otwierano Studio.

| Obszar | Kierunek P | Wymagany dowód przed użyciem |
|---|---|---|
| Kwoty i Real64 | Luau number w granicach finite binary64; tekst round-trip do zapisu/wire, bez mantysy/wykładnika rozszerzającej zakres | F02: round-trip, odrzucenie NaN/Inf, zakres funkcji, jawne float32 i lokalne konwersje. [Luau](https://luau.org/syntax/) ma jeden typ liczbowy double; to nie zapewnia dokładnego uint64. |
| ExactUInt | Osobny adapter z parą 32-bitowych części w pamięci i kanonicznym tekstem dziesiętnym na granicy; bez tonumber całego uint64 | F02: 2^53 i granice uint64, dodawanie/odejmowanie/porównanie i przepełnienie. Przy konwersji populacji do obliczenia double jawna reguła 27. To wybór reprezentacji P, bez kodu lub zweryfikowanej biblioteki. |
| Czas | Wstrzykiwany Clock: osobny UTC ms i monotoniczny elapsed; scheduler budzi koordynator, nie wyznacza granic symulacji liczbą klatek | F02/F05: zgodność sekund/ms, brak cofania cursor, ta sama siatka przy checkpointach. Dostawców UTC/elapsed wybrano w [33](33_pre01_toolchain_and_clocks.md); ich pomiar pozostaje zadaniem realizacji U06; [Heartbeat](https://create.roblox.com/docs/reference/engine/classes/RunService) jest zdarzeniem klatki, nie dowodem dokładnego dt=0.3. |
| Transport | Zwykłe RemoteEvent w obie strony, logicznie oddzielone wejście wylęgu, komendy i odpowiedzi; bez blokującego czekania RemoteFunction na zapis/offline | F07: DTO, rozmiary/kolejki/limity, powtórki, stream i reconnect. [RemoteEvent](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent) jest asynchroniczny; sam transport nie daje trwałości, serializacji domeny ani jednokrotnego zakupu. |
| Trwałość | Port SessionRepository + kontrolowany fake do L. Kierunek adaptera D: jeden agregat profilu i aktualizacje przez DataStoreService UpdateAsync z kontrolą właściciela wewnątrz zapisu | F03: token/generacja, przejęcie, odnowienie, nieznany zapis i status własnej operacji. [UpdateAsync](https://create.roblox.com/docs/cloud-services/data-stores) nie pozwala yield w callbacku; nil anuluje zapis. Nie przyjęto konkretnej biblioteki sesji. Projekt portu, lease i odzyskiwania U05 opisuje [34](34_pre02_sessions_and_retention.md), nie jest gotowym systemem. |
| Retencja | W lokalnym fragmencie brak kasowania terminalnych rekordów operacji; po osiągnięciu technicznego budżetu zatrzymać przyjmowanie nowych mutacji zamiast usunąć ochronę powtórek | U05: limit rozmiaru, komunikat i odzyskiwanie wybrano w [34](34_pre02_sessions_and_retention.md); wymagają wykonania i sprawdzenia; bez nieskończonej mapy w produkcji. [Limity i błędy](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) wymagają obsługi ograniczeń i nieznanego wyniku. Sama polityka bez wykonania i testów nie daje gotowości zapisu D. |
| Harness i Studio | Rozdzielić testy czystych funkcji/awarii repozytorium od integracji klient–serwer; własne źródła server/shared/client i oddzielne fixtures | W PATH nie znaleziono rojo, luau, lune ani run-in-roblox; nie dowodzi to ich braku w całym systemie. Runner i mapowanie synchronizacji wybrano w [33](33_pre01_toolchain_and_clocks.md); instalacja i testy U06 niewykonane. Nie ma uruchomionych testów Luau. |

Koordynator jawnie serializuje komendy, ticki, checkpointy i odtwarzanie tego samego gracza. Pojedyncza sesja ani kolejność dostarczenia RemoteEvent nie zapewniają zakończenia poprzedniej mutacji przed następną; Gateway nie omija kolejki właściciela agregatu. To zastosowanie 28, nie dodatkowa blokada produktu.

Proponowane przyszłe obszary plików, obecnie **nieutworzone**: `src/shared` (codec/DTO), `src/server` (katalog, matematyka, czas, koordynator, domena, zapis i Gateway), `src/client` (transport/store/UI), `tests` (jawne fixture i testy L). Katalog serwera nie może być mapowany do obszaru replikowanego. Mapowanie na usługi Studio opisuje [33](33_pre01_toolchain_and_clocks.md); fizyczne pliki i konfiguracja synchronizacji pozostają nieutworzone. Testy D używają osobnego dopuszczonego środowiska; nie włączamy teraz dostępu Studio do danych gry.

## 6. Rzeczywiste niewiadome i gotowość konsumentów

| ID | Brak rozstrzygnięcia w bieżącym przygotowaniu | Blokowany rezultat | Co pozostaje niezależne |
|---|---|---|---|
| U01 — rozstrzygnięte N | Suma poziomów Common >= próg; Epic osobno; 31 | Wdrożenie i test bramki F06 nadal niewykonane | Codec i funkcje matematyczne |
| U02 — rozstrzygnięte N/P | Jedno naciśnięcie to jedna próba; holdRate bez Epic=0; HatchPress w 28/31 | Implementacja wejścia i testy F05 nadal niewykonane | Refill i IHR nie zależą od sieciowego wejścia |
| U03 — rdzeń rozstrzygnięty, projekt trasy przygotowany | Wzór i przejścia z 31; projekt RouteProvider w [35](35_pre03_routes_and_arrivals.md), wykonanie sceny w IMP-13 | Rzeczywisty bieg/termin dotarcia w Studio | Czysty wzór RCB i przejścia z kontrolowanym dotarciem |
| U04 — podstawowa farma rozstrzygnięta S/N | Tabela 31: silos 1, zapas 250, jeden TRIKE przy limicie 4; osobny fixture z §2 | Wdrożenie inicjalizacji i zatwierdzenie konfiguracji wydania | Dekodowanie istniejącego stanu nie stosuje inicjalizatora |
| U05 — projekt przygotowany | [34](34_pre02_sessions_and_retention.md): adapter, dzierżawy/budżety i retencja/odtworzenie; wykonanie niewykonane | F03 jako gotowa trwałość D, A09/A11/A13 na chmurze | Port, fake i specyfikacja błędów; nie zaliczają D |
| U06 — warsztat wybrany | [33](33_pre01_toolchain_and_clocks.md): dostawcy czasu, runner/synchronizacja; pomiary i parametry transportu nadal przyszłe | Zakończenie F02/F07 oraz integracja Studio | Kontrakt, lokalna walidacja danych i projekt testów; bez deklaracji wykonania |

Historyczne braki U01–U04 nie są pretekstem do ponownego audytu całej domeny ani do szukania nowych liczb w odłożonym bilansie. Ewentualne uzupełnienie źródeł lub wybór reguły adaptacji ma dotyczyć wskazanego braku. Fixture nie zamyka luki produktu, a opis adaptera nie zastępuje jego sprawdzenia.

**Wynik F01: przygotowano manifest dokumentacyjny z jawnymi zależnościami. Nie nadano pełnej gotowości wykonawczej adapterom. Aktualne rozstrzygnięcia U01–U04 zawiera 31.** Projekty techniczne U05/U06 i trasy przygotowano w 33–35. Następny możliwy zakres po osobnym poleceniu: wykonać IMP-01, następnie niezależnie IMP-02/03/07; żadna z tych pozycji nie uruchamia automatycznie implementacji. F02–F09 i A01–A16 nadal niewykonane. Bilans, referencje i historia Git bez zmian.

## 7. Wkład pomocniczy i granice QA

Cline / DeepSeek v4.1 Flash przygotował tekstową propozycję na podstawie przekazanego skrótu wybranych danych i kontraktów, bez narzędzi i zmian plików. Wykorzystano listę siedmiu badań i rozdzielenie niewiadomych od fixture. Odrzucono nieuzasadniony „jeden silos logiczny”, dodatkowe etapy inkubacji, traktowanie nieznanych danych jako statusu N i zlanie quoteId z operationId. Ostateczne ID, efekty i indeksy sprawdzono lokalnie w JSON; nie jest to audyt plików wykonany przez Cline ani test implementacji.

AGY / Gemini 3.8 Flash Medium oceniło pełny tekst pierwszej redakcji tego dokumentu z wybranymi fragmentami 27–29 i skrótem reguł, bez narzędzi i zmian projektu. Werdykt QA tekstu: CONDITIONAL PASS z czterema sugestiami. Po ocenie autora ujednolicono eggIndex/SmallIndex w DTO i powtórzono lokalnie reguły replay, produkcji/IHR/away oraz serializacji już obowiązujące z 27/28. Na tamtym etapie nie rozstrzygano momentu dotarcia; później rdzeń U03 uzupełniono w 31, z osobną zależnością sceny. [Zapis QA i jego ograniczeń](workflow/first_farm_f01_review.md) nie jest testem implementacji ani pełnym audytem repo. Końcowej redakcji nie wysyłano ponownie do modelu.
