# Pierwszy zakres implementacji — podstawowa farma

23.10.2026. **P — plan przyszłej realizacji, NIE ROZPOCZĘTO.** Sporządzenie planu nie zleca kodowania, uruchamiania Studio, instalowania narzędzi, operacji chmurowych, publikacji lub zmian Git. Dokument konkretyzuje fragment etapów 0–2 z [mapy etapów](workflow/IMPLEMENTATION_STAGES.md), a nie cały zakres premiery.

## 1. Cel i granice odbioru

Po osobnym zleceniu realizacji gracz ma wejść na własną farmę z jednym jajem, wykluć kury, zobaczyć wzrost populacji i sprzedaż jaj, rozpoznać wąskie gardło transportu oraz kupić badanie Common, kurnik i pojazd. Powtórzona komenda, przerwane połączenie lub przejęcie sesji nie mogą powtórzyć kosztu ani zgubić potwierdzonego zakupu.

Rezultatem ma być **wewnętrzny fragment gry do weryfikacji**, nie gotowa ekonomia wydania. Źródła: [CURRENT_SPEC](CURRENT_SPEC.md), [27 — liczby, czas i profil](27_numbers_time_and_player_state_contract.md), [28 — moduły i protokół](28_modules_and_client_server_contract.md). Reguły R i opisane reguły N mają pierwszeństwo przed propozycjami tego planu.

| W zakresie P | Poza tym zakresem realizacyjnym |
|---|---|
| Jedno jajo, cztery rekordy kurników, ręczna wylęgarnia, kury w drodze, RCB i IHR | Zmiana jaja, prestiż, pełna ścieżka jaj, FV/SE jako osobne funkcje postępu |
| Produkcja, sprzedaż ograniczona przepustowością, portfel i właściwe akumulatory dochodu | Pety, inkubacja, łączenie, aktywacja boostów/VD, rotacja wydarzeń |
| Wybrany jawnie podzbiór Common, kurników i zwykłych pojazdów; zakupy pojedyncze | Epic jako sklep, Buy MAX, Hyperloop/wagony i zakup silosów; ich brak nie zmienia reguł v1 |
| Sesja, zapis/odtworzenie, podglądy zakupów, operacje z ID, minimalna projekcja i UI | Drony, paczki, kalendarz, trofea, tutorial, Piggy, Pro i płatności platformowe |
| Rozliczenie powrotu w obsługiwanym stanie neutralnym, włącznie z progiem away i limitem posiadanych silosów | Pełna integracja historii uprawnień, petów, boostów i eventów; kontrakty kooperacyjne, handel, ekspedycje |

Wyłączenie funkcji z pierwszego fragmentu nie usuwa jej ze specyfikacji premiery. Odbiór dotyczy nowego profilu lub jawnego profilu testowego o obsługiwanych cechach: bez aktywnych boostów/VD, wyposażonych petów i aktywnych wydarzeń. Taki zestaw warunków jest ograniczeniem środowiska testowego, nie nową zasadą gry. Profilu z nieobsługiwanym stanem nie wolno wyzerować lub zasymulować bez jego efektów: zachować dane, odmówić uruchomienia tego fragmentu i podać przyczynę. Nie wolno przy okazji skasować sekcji trwałych z 27.

## 2. Dane i rozstrzygnięcia wymagane dla tego fragmentu

Status każdego JSON pozostaje `REFERENCE_ONLY`, `productionConfigurationApproved: false`. Ten plan nie zmienia plików danych i nie tworzy konfiguracji wykonywalnej, fixture ani generatora. W przyszłych testach można wskazać istniejące wartości jako kontrolowane wejścia; ich użycie nie zatwierdza tempa progresji.

| Potrzeba | Istniejące źródło | Jak wykorzystać w przyszłym zadaniu |
|---|---|---|
| Common, poziomy, efekty i bramki tierów | [01](01_upgrades_and_research.md), [research.json](reference_data/research.json): common, tierThresholds | Jawna lista obsługiwanych ID i wymiarów. `prices[k]` kupuje poziom k+1, `effectsByLevel[k]` opisuje poziom k. Nie interpolować z tabel skróconych w Markdown. |
| Jajo, kurniki i zwykłe pojazdy | [03](03_habitats_and_population.md), [04](04_vehicles_and_shipping.md), [infrastructure.json](reference_data/infrastructure.json): eggs, habitats, vehicles | Zachować ID i pełną precyzję. Ceny egzemplarzy zależą od liczby już posiadanych danego typu, nie bezwarunkowo od numeru slotu. Jaja/min przeliczać na jaja/s. |
| Wylęg, IHR, sharing, produkcja i czas | [03](03_habitats_and_population.md), [10](10_verified_simulation_and_server_config.md), 27 | Zachować zapas i refill jako różne wielkości, ułamki per kurnik, rezerwację miejsc dla kur w drodze, produkcję przed wzrostem i wybór celu sharing. |
| Powrót i silosy | [06](06_drones_silos_and_events.md), [drone_and_silo_rules.json](reference_data/drone_and_silo_rules.json), 27 | Próg nieobecności >60 s, produkcja away ograniczona posiadanymi silosami; online bez tego limitu. Jakość away właściwa dla obsługiwanego stanu, bez nadania Pro. |
| Zapis, czas i wiadomości | 27 i 28, pomocniczo [zapis ECC](ecc/adaptations/datastore_migration_and_session_lock.md) | Jeden koordynator, wspólny wynik/koszt/ID, fence sesji, quoteId, różne commitRevision/viewSeq i odtworzenie nierozstrzygniętej operacji. |
| Minimalna prezentacja | [specyfikacja UI](ui/ui_design_specification.md), jako P | Czytelna działka i podstawowe kontrolki; bez przebudowy całego UI i bez nowego zadania pozyskiwania assetów. |

### Wejścia do ustalenia przed odpowiednim zadaniem

- **Manifest fragmentu:** wybrane jajo i ID badań/infrastruktury, źródło każdej wartości, obsługiwane efekty i wymagania. Zakres obejmuje wpływ na znoszenie, wartość jaja, zapas/refill wylęgarni, IHR, pojemność kurnika i transport. Bramka wybranego badania musi być osiągalna w obsługiwanym zestawie albo stan musi być jawnie przygotowanym fixture testu funkcji, bez deklaracji naturalnej progresji. Niewdrożony wymiar oznacza niedostępne badanie, a nie płatny poziom bez efektu.
- **Stan startowy:** mapowanie gotówki, jaja, kurników, pojazdów, silosów, zapasu wylęgarni, poziomów i akumulatorów do konkretnych reguł/źródeł. Nie zakładać zera ani ceny zakupu jako stanu startowego. Jeśli w docs brak wartości, oznaczyć ją jako nierozstrzygniętą; dla izolowanego testu można później podać fixture, ale nie przedstawiać go jako zatwierdzonego nowego konta. To nie jest zadanie resetu po prestiżu.
- **Ręczny wylęg/RCB:** tabela wejście → wypuszczenie grupy → rezerwacja miejsca → dotarcie/RCB, z jednostkami i źródłem tempa. Odróżnić bazowe wejście od efektu Hold to Hatch oraz płatnego Auto-Hatch. Braku parametru nie zastępować kliencką fizyką albo dowolną częstością heartbeat; wskazać dokładną brakującą regułę bez ponownego audytu zamkniętych mechanik.
- **Adaptery i narzędzia:** wybór codec/arytmetyki w zakresach 27, zegara, zapisu z sesją/retencją i odtworzeniem, transportu, harnessu oraz sposobu dostarczenia źródeł do Studio. Ocenić je dla tego fragmentu; nie jest wymagana arbitralna liczba ADR, bibliotek lub modeli. Nie deklarować dostępnego runnera lub narzędzia przed jego sprawdzeniem.

To zależności techniczne i mapowanie istniejących danych. Jeśli rozwiązanie wymaga nowej ceny, siły bonusu lub innego elementu odłożonego bilansu, zatrzymać wyłącznie zależną część; nie wracać do symulacji 17–21. Szczegółów przyszłych adapterów nie wybieramy tym dokumentem.

## 3. Przepływ i model danych

1. Bootstrap → ustalenie właściciela sesji → dekodowanie/wersjonowanie profilu → rozliczenie należnego okresu → spójny snapshot `ready`. Nieczytelny profil nie staje się nowym pustym kontem.
2. HatchInput start/odświeżenie/stop → PlayerCoordinator → kontrola zapasu, tempa i wolnego miejsca → autorytatywne grupy kur w drodze i RCB. Brak odświeżenia, rozłączenie lub utrata sesji kończą intencję zgodnie z 28.
3. TimelineSimulation rozlicza kroki z 27: sprzedaż z populacji początku kroku, refill i wzrost we właściwej kolejności; FarmMath oblicza efekty i przepustowość. Renderowana kura nie przyznaje populacji lub gotówki.
4. QuoteRequest → wycena serwera → jawne potwierdzenie → BuyResearch/BuyHabitat/BuyVehicle z quoteId i operationId. Koordynator rozlicza stary czas, waliduje świeży stan i atomowo zapisuje zakup z kosztem oraz wynikiem. Efekt działa na następny należny odcinek, nie wstecz.
5. ViewProjector publikuje snapshot/delta i osobny wynik operacji. Rozłączenie nie usuwa ID; reconnect odtwarza stan i wynik, a nie odgrywa starych inputów wylęgu.

| Odpowiedzialność z 28 | Stan/typ z 27 wykorzystywany teraz | Ograniczenie |
|---|---|---|
| NumericCodec / CatalogRegistry | BigAmount cash/ceny; ExactUInt populacja/liczniki/revision; Real64 ułamki; SmallIndex/ID; Instant/Duration | Nie rozszerzać zakresu binary64 ani nie zaokrąglać ExactUInt przez number. Katalog testowy nie jest konfiguracją wydania. |
| FarmMath / TimelineSimulation | farm: Common, cztery rekordy populacji/ułamków, hatch/refill, RCB, pojazdy i silosy; timeline: settledWallThrough/checkpoint | Wyniki pochodne, np. tempo i pojemność, nie są drugą prawdą w zapisie. Kury w drodze zajmują właściwe miejsce, bez podwójnego dodania. |
| PlayerCoordinator / FarmActions | cash i właściwe accounting, meta.revision, operations oraz ownership | Wydatek zmniejsza portfel, ale nie cofa już zarobionego przychodu sesji. Brak funkcji prestiżu nie pozwala pominąć jego księgowania. |
| SessionRepository | Agregat profilu, token/generacja, operacja, wynik i cursor | Zapisać razem skutki i postęp czasu. Utrata sesji blokuje starego autora; brak rekordu nie dowodzi anulowania. |
| Gateway / ViewProjector / klient | protocolVersion, operationId/requestId, commitRevision, streamId/viewSeq, serverObservedAt | UI widzi własny dozwolony wycinek, bez tokenów i pełnego ledgeru. Klient nie wysyła autorytatywnej ceny/populacji/dt. |

Minimalny widok P zawiera gotówkę, wybrane jajo, populację i pojemność per kurnik, stan wylęgarni, tempo znoszenia i sprzedaży, przepustowość, właściwy wskaźnik dochodu, dostępne zakupy i ich powody blokady. Widok rozróżnia loading/offlineSettling/ready/sessionLost oraz wynik zakupu od animacji. Dane publiczne drugiej farmy są osobną allowlistą, nie kopią prywatnego widoku.

## 4. Zadania przyszłej realizacji i rzeczywiste zależności

**Aktualizacja F01:** [30 — manifest i wybory techniczne](30_first_farm_manifest_and_technical_choices.md) zawiera przygotowanie dokumentacyjne i jawne U01–U06, bez pełnej gotowości wykonawczej. F02–F09 pozostają **ZAPLANOWANE / NIE WYKONANO**. „Zakres zapisu” wskazuje logiczny obszar przyszłego zadania, nie istniejącą ścieżkę kodu ani zgodę na jego utworzenie. Proponowane obszary plików opisuje 30; ich mapowanie nadal wymaga rozstrzygnięcia technicznego zgodnie z briefem z [TASK_TEMPLATES](workflow/TASK_TEMPLATES.md). Żadne zadanie nie zmienia 17–21, JSON-ów referencyjnych, cen/sił lub zakresu premiery.

| ID | Wynik / dozwolony obszar przyszłej pracy | Dokładne wejście / zależność | Gotowe gdy / poziom weryfikacji |
|---|---|---|---|
| F01 | Manifest fragmentu i startu, mapowanie jednostek, wylęgu/RCB, schemat minimalnej projekcji; decyzje adapterów i układu źródeł. Wyłącznie kontrakty/konfiguracja testowego zakresu, bez dodawania mechanik. | 27/28 oraz źródła §2; nie wymaga ukończenia innych systemów gry. | Każde pole startu i użyte ID ma źródło lub jawny status fixture/brak; wiadomo, gdzie kończy się zdolność adapterów i jak sprawdzić wynik. Nieznane parametry mają wskazanego konsumenta. |
| F02 | NumericCodec, czytanie wybranych danych i kontrolowane zegary; testy lokalne tego obszaru. | Typy, zakresy, mapowanie i wybór adapterów z F01. | Round-trip i konwersje z 27, poprawne indeksy poziomów/cen i jednostki min/s; błędne/niefinitywne wartości nie naprawiają się zerem. Nie aktywowano całego katalogu. |
| F03 | Profil, SessionRepository i szkielet PlayerCoordinator: jeden autor, ID, wersje, wyniki, odtworzenie i checkpoint. Bez sklepu platformowego. | Codec/wersjonowanie F02 i wymagania sesji, retencji oraz zapisu F01. | Harness odtwarza zapisany koszt/wynik i zmianę właściciela; APPLIED/REPLAYED/UNKNOWN nie są jednym boolean. Mock nie stanowi dowodu trwałości chmury. |
| F04 | FarmMath: agregaty wybranych Common, pojemność, tempo/refill, IHR/sharing, sprzedaż/dochód; testy czystych funkcji. | Typy i dane F02 oraz rozstrzygnięty model wylęgu/RCB z F01. Nie wymaga UI ani ukończenia F03. | Kontrolowane wejścia i oczekiwane wartości z docs pozwalają odróżnić efekt poziomu od pełnego agregatu. Test dochodu nie jest testem FV; brak kalibracji progresji. |
| F05 | TimelineSimulation i integracja ręcznego wylęgu/RCB z koordynatorem; online oraz minimalny neutralny powrót z §1. | Funkcje F04, właściciel/cursor/checkpoint F03 i zegary F02. | Zachowano siatkę i fazy 27, produkcję przed wzrostem, ułamki, ograniczenia i wygaśnięcie intencji. Wznowienie tego samego okresu nie daje nowej wypłaty. |
| F06 | FarmActions i wyceny dla pojedynczych Common/kurników/zwykłych pojazdów; koszt, efekt, zapis wyniku. Bez Buy MAX/Epic/Hyperloop. | Świeży stan i rozliczanie starego odcinka F05, efekty/ceny F04/F02 i transakcje F03. | Zakup działa raz, ma poprawną bramkę/cenę egzemplarza i quoteId; odrzucenie nie pobiera środków ani nie zmienia poziomu. Nie ma nowej waluty lub cen. |
| F07 | Gateway, ClientTransport/StateStore, projekcje, bootstrap/statusy/resync oraz kontrolery wejścia. Bez UI przyznającego zasoby. | Schematy F01 i codec F02; integracja komend wymaga wyników F03/F05/F06. Samo przygotowanie walidacji DTO nie wymaga gotowej sceny. | Stary replay nie cofa widoku; utracona delta powoduje resync; NOT_ACCEPTED/PENDING/UNKNOWN i zmiana streamId spełniają 28. Dane innego gracza są izolowane. |
| F08 | Minimalna działka, wizualne kury i UI dotykowe/klawiaturowe zgodne z §3. Bez finalnego artu, płatności i tutorialu. | Projekcja i kontrolery F07 dla działającego UI. Statyczny układ można przygotować wcześniej na opisanym DTO F01. | Gracz rozpoznaje pełny kurnik/transport, brak gotówki i oczekiwanie. Modele są prezentacją; ich usunięcie nie zmienia stanu ekonomii. |
| F09 | Integracja oraz dowody odbioru wyłącznie tego fragmentu; poprawki w dotkniętych modułach. | Działające przepływy F03/F05/F06/F07/F08 i dostępne środowisko testowe z F01. | Scenariusze §5 mają dowód albo jawny status niezweryfikowany; oddzielono test lokalny, Studio, prawdziwy zapis i ocenę człowieka. Nie deklaruje się gotowości publikacji. |

Kolejność zależności: F01 → F02; następnie F03 i F04 mogą powstawać niezależnie; F03+F04 → F05 → F06; pełna integracja F07 konsumuje te wyniki, F08 korzysta z projekcji, F09 sprawdza całość. To możliwość podziału pracy po właściwym zleceniu, **nie zgoda na delegację**. F09 nie wymaga implementacji petów, prestiżu, sklepu Robux ani pełnej integracji etapu 4.

## 5. Scenariusze odbioru — NIE URUCHOMIONO

Oznaczenia przyszłego dowodu: **L** — lokalna czysta logika/harness z kontrolowanym zegarem i błędami; **S** — klient/serwer w Studio; **D** — rzeczywisty adapter trwałego zapisu w osobno dopuszczonym środowisku; **H** — obserwacja człowieka. S lub mock nie zastępują D. Każdy wynik odnosi się do wersji kodu, konfiguracji i wejść, a nie samego opisu scenariusza.

| ID / poziom | Stan i działanie | Oczekiwany wynik / właściciel zadania |
|---|---|---|
| A01 — L/S | Brak profilu; wejście według manifestu F01. Oddzielnie: profil nieczytelny lub nowszy. | Nowy profil tylko przy potwierdzonym braku danych; loading blokuje zakupy do spójnego ready. Błąd dekodowania nie tworzy pustego konta. F02/F03/F07. |
| A02 — L/S | Start/odświeżenie/stop wylęgu, pusty zapas, brak miejsca, rozłączenie i stary heartbeat. | Tempo i refill według serwera; brak ujemnego zapasu i nadmiernej rezerwacji. Stare inputy nie dodają kur po powrocie, intencja wygasa. F05/F07. |
| A03 — L/S | Kury przypisane do kurnika są jeszcze w drodze; dotarcie i zmiana liczby modeli. | Miejsce uwzględnia rezerwację, dotarcie nie podwaja populacji, RCB ma autorytatywne wejścia. Liczba modeli nie steruje przychodem. F04/F05/F08. |
| A04 — L | Stałe wejścia; transport powyżej, równy i poniżej produkcji. | Sprzedaż ograniczona min(produkcja, transport), spójne jaja/min i sekundy; gotówka odpowiada sprzedanym jajom oraz właściwym mnożnikom. F04. |
| A05 — L | IHR daje ułamki; pełny slot, z sharing i bez niego; wolny cel. | Produkcja używa populacji początku kroku; ułamki i kolejność per slot zachowane, sharing wybiera cel zgodnie z 10, nie dzieli równo. F04/F05. |
| A06 — L/S | Kupno Common; dokładnie wystarczająca gotówka, brak środków, zamknięty tier, maxLevel. | Poprawny indeks ceny, jeden koszt i poziom albo brak zmiany. Niewspierany ID nie jest sprzedawany. Zaległy czas używa starych efektów; wydanie gotówki nie zmniejsza historycznego przychodu. F06. |
| A07 — L/S | Ten sam typ kurnika/pojazdu kupowany na różnych dozwolonych slotach. | Cena zależy od liczby egzemplarzy przed zakupem, właściwe limity slotów; pojemność/transport po zakupie zgodne z danymi. Brak kasowania kur przy podmianie kurnika. F04/F06. |
| A08 — L/S | Cena/warunki wyceny zmienione przy niezmienionym commitRevision; zakup z dawnym quoteId. | QUOTE_CHANGED i nowy podgląd, bez niezaakceptowanego kosztu. Sam expectedRevision nie zastępuje zgody na cenę. Zmianę konfiguracji symuluje harness, nie nowy event produktu. F06/F07. |
| A09 — L/S/D | Dwa równoczesne identyczne ID; timeout przed/po trwałym wyniku, replay z dawną revision; ten sam ID ze zmienionymi argumentami. | Jeden koszt i efekt, zapisany wynik albo stan do rozstrzygnięcia; zmienione argumenty to konflikt. Bez ponownego kupna pod nowym ID w nieznanym stanie. F03/F06/F07. |
| A10 — L/S | Komenda przy offlineSettling; utrata pracy po PENDING. | NOT_ACCEPTED nie tworzy pozornej kolejki. Po utracie przyjętej pracy wynik odtworzony albo UNKNOWN do rozstrzygnięcia; brak wiecznego PENDING i brak automatycznego przyznania. F03/F07. |
| A11 — L/D | Przejęcie sesji, stary autor próbuje zapisać; nieznany wynik zapisu. | Stary token nie mutuje ani nie zwalnia nowej sesji. Nowy właściciel odtwarza wynik; brak nadpisania świeższego stanu starym buforem. F03. |
| A12 — L/S/D | Powrót po 60 s, po minimalnie dłuższym czasie oraz po wyczerpaniu silosów; ponowne wejście bez nowego okresu. | Poprawna gałąź online/away, brak limitu silosów online, ograniczenie away; zamknięty cały okres bez drugiej wypłaty. Zero silosów nie daje produkcji away. F05/F03. |
| A13 — L/D | Przerwanie obliczenia/checkpointu między produkcją a wzrostem. | Wznowienie tej samej siatki i wejść daje ten sam wynik jak nieprzerwane rozliczenie. Cursor i skutki zapisane razem; brak ponownej produkcji za krok. F03/F05. |
| A14 — L/S | Nowa delta przed wynikiem zakupu, stary replay, luka delty i zmiana streamId. | Brak cofnięcia widoku, resync zamiast sklejenia stanów; operacja i animacja nie tworzą drugiej korzyści. F07/F08. |
| A15 — S | Dwóch graczy; próba cudzego celu, salda, playerId lub dowolnej ceny/dt w payloadzie. | Odrzucenie nieautoryzowanego żądania; izolacja profili i brak prywatnych tokenów/ledgerów w projekcji. F07/F09. |
| A16 — S/H | Ręczne wejście, rozwój populacji, ograniczenie transportu, zakup i powrót; ekran mobilny oraz klawiatura. | Pętla zrozumiała, cena i powód blokady widoczne, oczekiwanie nie wygląda jak sukces. To odbiór funkcjonalny, nie ocena czasu progresji F2P/Pro. F08/F09. |

Za dowód nie uznaje się identyczności dwóch kopii tej samej funkcji. W L porównywać z jawną regułą i kontrolowanym wynikiem; np. przykłady z 10 są dostępne w Markdown, lecz sam plan nie dostarcza zewnętrznego runnera. Brak wymaganego testu D pozostaje niezweryfikowaną trwałością, nie ogólnym PASS. Testy techniczne nie wymagają realnych produktów, wydawania Robux ani publikacji.

## 6. Warunki zakończenia i następne zlecenie

Przyszły fragment jest odebrany w zadeklarowanym środowisku, gdy:

- Pętla z §1 działa, a manifest, pola startu i ograniczenia profilu są jawne. Dane testowe nie trafiają do konfiguracji wydania.
- Każdy A01–A16 ma wynik i poziom dowodu; nieukończonych kontroli nie ukrywa się zbiorczym PASS. Ryzyka kosztu, zapisu i powtórek mają rozwiązanie przed deklaracją trwałości.
- Wszystkie dostępne zakupy mają rzeczywisty efekt, poprawne ograniczenia i wycenę. Wyłączone funkcje nie mają aktywnych handlerów przyznających korzyści.
- UI prezentuje stan serwera, a stan czasu i księgowanie pozwalają dołączyć później postęp/prestiż oraz pełne efekty bez zerowania wcześniejszych danych. Nie oznacza to wykonania tych funkcji.

**Następny konkretny krok P po przygotowaniu 31 i PRE-01–03:** wykonać IMP-01 (warsztat/codec), a potem niezależnie IMP-02/03/07 według 32. Warsztat U06 opisuje 33, zapis U05 — 34, trasę — 35; rzeczywiste adaptery i pomiary nadal niewykonane. Manifest F01 i reguły U01–U04 są opisane w 30–31, a projekty techniczne w 33–35. Fixture nadal nie jest startem nowego konta, zaś dokumentacja nie dowodzi wykonania wylęgu lub trasy. Nie zaczynać od równoczesnej implementacji wszystkich modułów z 28. Osobne zlecenie realizacji ma wskazać dopuszczone środowisko i wymagany poziom odbioru.

Ten dokument nie rozstrzyga tempa zdobywania zasobów, cen inkubatorów, limitów petów, oferty Robux lub innych elementów bilansu. Nie wznawia 17–21 i nie zmienia historii Git. **Stan obecny: plan i dokumentacyjny manifest F01 sporządzone; F01 ma jawne niewykonane zależności sceny/adapterów z 30 i 33–35, F02–F09 oraz A01–A16 niewykonane.**
