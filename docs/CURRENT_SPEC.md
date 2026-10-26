# Bieżąca specyfikacja i status ustaleń

Stan: **26.10.2026**. Zakres: farma domowa HatchTheEgg z petami w Roblox; kod farmy i UI ma lokalne dowody L oraz ograniczone próby Studio opisane w [WORKING_CONTEXT](WORKING_CONTEXT.md). Implementacje płyty 30/s i [UI #77–80](workflow/ui_tasks_77_80_2026_10_26.md) sprawdzone lokalnie (zakres i ograniczenia w raportach); brak pełnego odbioru chmury i wydania. To indeks obowiązujących ustaleń, nie nowy bilans.

**Panel tempa — decyzja26.10.2026 (R):** górne pola Produkcja/Sprzedaż/Limit transportu w jaj/s. Limit to istniejące shippingPerMinute/60, nie dochód. [Wdrożenie i dowody lokalne](workflow/top_rates_panel_2026_10_26.md). Preferowany kierunek kolejnych okien: styl Roblox/stud z StudUI Lite i ikonami gvesster; szczegóły w planie[#82](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/82) i skillu hte-design-visuals. Bez zmiany domeny, balansu ani zatwierdzenia wydania.

## Jak czytać statusy

**UI #77–80 — zlecenie 26.10.2026:** typy kurników i pojazdów mają nazwy Tier 1, Tier 2 itd. według indeksu typu +1; identyfikatory domeny i zapisu pozostają bez zmian. Usunąć płytki pojazdów przed stacją, zachowując panel floty. Wdrożenie feedbacku wylęgu obejmuje brak miejsca z rezerwacjami oraz oddzielny brak zapasu, bez spamu. [Projekt i bieżące dowody](workflow/ui_tasks_77_80_2026_10_26.md). Nie zmienia bilansu, cen ani reguł wylęgu.

**Nowa decyzja użytkownika — 26.10.2026 (R):** stanie na płycie wylęgu ma wypuszczać do 30 kurczaków/s, przy niezmienionym zapasie i jego odnowieniu oraz ograniczeniu miejscami. To odrębna adaptacja płyty, nie zmiana pojedynczego press ani Epic Hold-to-Hatch poza płytą. Serwer potwierdza obecność i rozlicza rezerwacje, RCB i dotarcia; fizyczne modele klienta są ograniczoną reprezentacją ruchu. [Zakres i bieżące dowody](workflow/plate_hatching_2026_10_26.md). Nie otwiera odłożonego bilansu 17–21. Zatwierdzenie zachowania nie stanowi odbioru implementacji.

| Status | Znaczenie |
|---|---|
| **N — referencyjne reguły obliczeń** | Opis zachowania matematycznego stanowiący punkt odniesienia. Nie oznacza wykonania ani testów implementacji HatchTheEgg. |
| **S — referencyjne dane i tabele** | Dane opisane w dokumentacji. Nie są automatycznie zatwierdzoną konfiguracją wydania. |
| **R — zatwierdzona decyzja projektu** | Reguła zaakceptowana przez użytkownika; rozstrzyga zachowanie HatchTheEgg w danym zakresie. |
| **P — propozycja / szkic projektu** | Nie zatwierdza konfiguracji i nie zleca implementacji. |
| **H — materiał historyczny** | Dawny wariant lub raport; aktualne decyzje i późniejsze ustalenia mają pierwszeństwo. |

N/S rozróżniają rodzaj materiału referencyjnego, nie stopień przetestowania gry. Decyzja R nie zatwierdza automatycznie sąsiednich propozycji i liczb. Konfiguracja opisana w docs nie zastępuje przyszłej konfiguracji serwera HatchTheEgg. Sam status w tej tabeli nie zleca implementacji (aktualny wykonany zakres IMP-01–09 opisano na końcu dokumentu); odłożony bilans pozostaje odłożony.

## Referencyjne wzory i reguły

| Temat | Status i obowiązująca reguła | Źródło szczegółów |
|---|---|---|
| Badania i infrastruktura | S/N: 56 Common, 24 rozpoznawane Epic, 19 kurników i 12 typów pojazdów. 17 to liczba miejsc floty, nie typów. Lista konfiguracji referencyjnej zawiera też legacy; nie dowodzi widoczności wszystkich wpisów w sklepie. | [01](01_upgrades_and_research.md), [03](03_habitats_and_population.md), [04](04_vehicles_and_shipping.md), dane konfiguracji referencyjnej |
| Farm Value | N: wzór z osobnymi wejściami ResearchEngine, karą transportu, członem wolnej pojemności i przyszłego IHR. Nie podmieniać tych wejść pełnymi mnożnikami wyposażenia/boostów. | [02, sekcja 2](02_eggs_and_farm_value.md#2-wzór-farm-value-potwierdzony-w-modelu-referencyjnym), [16](16_pet_stacking_offline_and_package_schedule.md) |
| Soul Eggs | N: funkcja przedziałowa o wykładnikach 0.15–0.21. Soul Beacon/Feather wzmacniają przyrosty przychodu wejściowego; collection i event prestiżu działają po tej funkcji. Gotówka jednorazowa ma własną ścieżkę księgowania. | [05](05_prestige_soul_eggs_and_boosts.md), [13](13_rewards_contracts_resets_and_gift_distributions.md) |
| Produkcja i transport | N: sprzedaż ograniczona transportem, produkcja przed wzrostem populacji, ułamki per kurnik i sharing według wyboru wolnego miejsca. Hyperloop ma cenę wagonu z PriceCurve, nie prostą potęgę ceny pociągu. | [03](03_habitats_and_population.md), [04](04_vehicles_and_shipping.md), [10](10_verified_simulation_and_server_config.md) |
| Offline | N: gałąź away dla nieobecności >60 s, produkcja ograniczona posiadanymi silosami, kroki do 0.3 s; dochód away 0.5 bez Pro / 1 z Pro, Calm tylko away. Nie zastępować całego offline jednym iloczynem bieżącego dochodu i czasu. | [10](10_verified_simulation_and_server_config.md), [16](16_pet_stacking_offline_and_package_schedule.md) |
| Boosty | N: pełne siły jednej kategorii sumują się; Beacony sumują się i mnożą aktywne kategorie. Długość ustalana przy aktywacji, czas zużywany przez symulację. Wpis działa w kroku przed usunięciem przy remaining<0. Money Printer nie jest mnożnikiem czasowym. | [05](05_prestige_soul_eggs_and_boosts.md), [11](11_periodicals_calendar_events_and_boost_rules.md), [13](13_rewards_contracts_resets_and_gift_distributions.md) |
| Zmiana jaja i prestiż | N: Common i infrastruktura farmy są przebudowywane; Epic i zasoby trwałe zachowane. Aktywne boosty wraz z czasem oraz termin podwajacza są zachowane. Zachowany wpis nie oznacza działania na jaju wyłączającym boosty. | [13, sekcja 5](13_rewards_contracts_resets_and_gift_distributions.md#5-zmiana-jaja-i-prestiż) |
| Podwajacz | N: wymiar 2+0.5×level godzin, do 8 h. Callback sukcesu nadpisuje termin; inne gałęzie aktywacji mogą dawać 1 h. Reklama i Ultra Pro dają wspólnie ×2, nie ×4. | [12](12_calendar_scaling_and_video_doubler.md) |
| Kalendarz | S, wysoka pewność: pięć nagród min(cap,base×2^m), m=floor(C/28). Bazy/capy i pozostała tabela z kodu. Dzień 28: PE przez 24 cykle, potem 100000 GE, bez równoczesnego 50000 GE. | [15](15_calendar_gameplay_formula_and_roblox_scope.md), tabela 28 dni w [11](11_periodicals_calendar_events_and_boost_rules.md) |
| Odbiór nagród | N: konwersje maksymalnych Epic na GE, osobne obcięcia Piggy, przeliczenie źródeł PE. Kolejka jednego alertu blokuje wielokrotne potwierdzenie; funkcje wypłat same nie gwarantują trwałej idempotencji. | [13](13_rewards_contracts_resets_and_gift_distributions.md), [14](14_reward_claim_safety.md) |
| Drony i prezenty | N/S: rozkłady i filtry zależą od stanu/progresji; częstość dronów nie jest stałym 15–30 s. Próba paczki/oferty: I×(0.6+0.5×U), z bramkami i ponowieniami. Brak stosu zaległych nagród za offline. | [06](06_drones_silos_and_events.md), [13](13_rewards_contracts_resets_and_gift_distributions.md), [16](16_pet_stacking_offline_and_package_schedule.md) |

## Zatwierdzone zmiany i kierunek Roblox

**Aktualizacja po odpowiedzi użytkownika — [rejestr D01–D07](22_gameplay_rules_for_approval.md):** D02–D07 mają status R. Obowiązują: dopuszczalne 100% elity, Enlightenment bez efektów petów i Clarity w v1, paczki 2+1 ze stałym zapisanym wynikiem i bez wygaśnięcia, zakres premiery i PE z kalendarza/trofeów, wymagania jednokrotnego rozliczania. D01: użytkownik zatwierdził premium +10 punktów procentowych, max 100%, zamiast dopłat $/GE/Robux do prób. R: stopień = tier pochodzenia × docelowy wariant; pety przed użyciem wymagają zdjęcia/odblokowania; zmiana bazowego nie podmienia automatycznie materiałów. R — skutek porażki: zachować peta bazowego, zużyć pozostałe wybrane kopie i zwiększyć trwały licznik gwarancji. Definicja nie dodaje osobnego ryzyka według gatunku/rarity; szczegóły w 22. Bazowe procenty i wartości gwarancji pozostają odłożone. D04 zatwierdzone: pierwsze użycie dnia UTC darmowe, kolejne GE/opcjonalnie Robux, z ujawnioną zawartością płatnego prezentu; ceny odłożone. Dawne P w raportach historycznych nie odwołują nowych decyzji R.

| Decyzja użytkownika | Status / granica |
|---|---|
| Sumowanie premii petów | **R:** P[d]=1+sum(b_i[d]). Dwa +50% dają ×2. Nie sumować tą regułą pełnych sił referencyjnych boostów. |
| Drone Hawk | **R:** zwiększa szansę elity, zamiast częstości dronów: min(1,pBase×P). Siła poszczególnych petów i ewolucji pozostaje P. |
| Wydarzenia podczas offline | **R:** naliczać tylko faktyczny czas nakładania eventu na okno produkcji. Event dochodu ważyć czasem w granicznym kroku. Event prestiżu dotyczy chwili kolekcji, a wyprzedaż/bonus czasu boostu — chwili odpowiedniej czynności. To adaptacja, nie dowód historycznego rozliczania przez model referencyjny. |
| Kierunek ekonomii | **R:** znaczenie Pro, GE i boostów oraz późnego spowolnienia; priorytet płacącego gracza. Nie zatwierdza konkretnych cen, limitów ani oferty Robux. **Dalszy bilans odłożony.** |
| Zakres pracy | **R:** bez kontraktów kooperacyjnych; implementacja tylko w jawnie zleconych zadaniach IMP-* (obecnie wykonano lokalnie IMP-01–09). |

Mapa włączenia petów w potwierdzone wymiary jest w [16](16_pet_stacking_offline_and_package_schedule.md). Jest specyfikacją adaptacji popartą testami kontrolowanych wejść, nie referencyjnym systemem petów. Phoenix działa na przyszły przychód prestiżowy, Alien raz na aktywne kategorie, Cow na pojemność produkcyjną; nie dopisujemy tych mnożników wprost do FV. Przed zmianą zestawu rozliczamy czas starym wyposażeniem.

**R — po przeglądzie 24:** opłacone zamówienie sprzed północy nie zużywa darmowego prawa nowego dnia; oferta przy nierozstrzygniętej płatności jest zarezerwowana bez kupna/odbioru/odrzucenia; istniejącą ofertę można odebrać na Enlightenment, otrzymany boost tylko do ekwipunku. Szczegóły w [22](22_gameplay_rules_for_approval.md) i [24](24_doubler_and_bonus_gift_acceptance_review.md).

## Propozycje i otwarte decyzje

Konkretne rekomendacje D01–D07: [22. Zasady do zatwierdzenia](22_gameplay_rules_for_approval.md). Aktualne odpowiedzi: R dla D02–D07; D01: premium +10 p.p. zamiast dopłat za próbę zatwierdzone; skutek porażki (pet bazowy/materiały/gwarancja) zatwierdzony; definicja stopnia (tier × cel) oraz zdjęcie/odblokowanie i brak automatycznej podmiany materiałów zatwierdzone. Kierunek trudności pozostaje w odłożonym bilansie; Rainbow jako końcowy wariant v1 zatwierdzono w 26. Nie wznowiono bilansu.

- **P:** waluta inkubacji, ceny, szanse, siły, receptury Golden/Rainbow i limity inkubacji. Materiały [17–21](21_payer_progression_and_incubation.md) są wariantami analitycznymi. Nie ma zatwierdzonego końcowego cennika; V pozostaje nierozstrzygnięte. Bilans odłożony zgodnie z [TODO](TODO.md); nie zmieniono jego danych ani symulacji.
- **R:** rozszerzenie miejsc petów i +10 p.p. do łączenia należą do Pro. **P:** konkretne liczby miejsc 3/5 z dawnych scenariuszy, ceny i saldo inkubacji. Nie zatwierdzono osobnego +2 Pet Equip. [25](25_approved_product_structure.md).
- **R (D05):** ścisłe limity 2 zwykłych paczek +1 bonusowej, z dostawą zajmującą miejsce, to zatwierdzona reguła projektu z 16 i D05. Warunki zgłoszenia ciężarówki w modelu referencyjnym nie dowodzą identycznego limitu we wszystkich fazach animacji. Użytkownik następnie zatwierdził tę liczbę i trwałość oferty jako D05; status tego punktu to obecnie R.
- **R (D04):** pierwsza aktywacja podwajacza i pierwszy bonusowy prezent dnia UTC darmowe; następne GE/opcjonalnie Robux, z ujawnieniem zawartości płatnego prezentu. **P:** ceny i szczegóły dodatkowych produktów. Ograniczenia petów na Enlightenment zatwierdzono w D03, a zakres trofeów/zadań/PE/eventów i wyłączenie ekspedycji w D06. Obecność w makiecie nie oznacza włączenia do pierwszej wersji.
- **R:** Buy MAX i Auto-Hatch kurczaków to osobne passy poza Pro; GE i Piggy to zakupy powtarzalne. **P:** konkretna architektura, biblioteki, format zapisu, UI, ceny Robux, parametry produktów i dokładne terminy późniejszych wydań. Zakres premiery jest R według 26: Auto-Hatch i VIP później, Piggy warunkowo po bilansie. Wymagania zachowania zapisu i jednokrotnego rozliczania zatwierdzono jako D07. Rozdziały [07](07_roblox_architecture_and_roadmap.md), [08](08_monetization_and_economy.md), [09](09_pets_system_and_artifacts.md) i [UI](ui/ui_design_specification.md) nie są gotową implementacją ani zatwierdzonym zakresem produktów.

Bieżące otwarte decyzje własnej adaptacji, bez odłożonego bilansu: [ADAPTATION_OPEN_DECISIONS](ADAPTATION_OPEN_DECISIONS.md). Task Opusa kalendarza/trofeów/PE pominięty; nie otwierać ponownie audytu tych mechanik.

**R — [26](26_approved_launch_scope_and_pro_availability.md):** premiera Pro/Buy MAX/GE, Piggy warunkowo po bilansie, Auto-Hatch/VIP później; Rainbow kończy v1. Wariant A Pro: brak niedostępnego +10 p.p., reszta uprawnień działa, jawny opis przed zakupem, bez zamiennika w v1. Trzy grupy decyzji w spisie adaptacji zamknięte; pozostały odłożony bilans i przyszła realizacja.

## Granice dowodu i historia

Kalendarz ma opisaną specyfikację. Przyszłe testy odbioru i trwałości muszą dotyczyć implementacji HatchTheEgg; opis reguł nie zastępuje testów serwera.

Raporty 10–16 zachowują adresy, testy i ograniczenia etapów. Wcześniejsze wnioski o braku skalowania zastępuje 15; ogólne uwagi o aktualizacji GiftConfig zastępuje dokładne zachowanie z 16. Historyczne manifesty są snapshotami i nie są regenerowane przy porządkowaniu docs. Wyniki symulacji 17–21 nie dowodzą pełnej zgodności 1:1 ani dokładnego tempa realnych graczy.

## Dane referencyjne w projekcie

Pełne dane maszynowe: [katalog danych referencyjnych](reference_data/README.md). Przywrócono brakującą tabelę dronów i czas silosów w 06. Przeniesienie danych nie nadaje im statusu zatwierdzonego bilansu ani testów implementacji.

## Kontrakt techniczny przed implementacją — P

[27 — liczby, czas i stan gracza](27_numbers_time_and_player_state_contract.md) jest propozycją techniczną opartą na obecnych regułach i danych. Rozdziela BigAmount/Real64/ExactUInt, zegary, trwały profil i operacje. Nie zmienia R, nie zatwierdza bibliotek, nie rozszerza zakresu binary64 bez osobnego projektu i nie wznawia bilansu. Scenariusze są opisane, nie wykonane.

## Podział odpowiedzialności i komunikacja — P

[28](28_modules_and_client_server_contract.md) rozwija kontrakt 27 o moduły i wiadomości: autorytatywny koordynator gracza, podglądy i komendy, idempotencja, statusy nieznanego wyniku, ograniczone projekcje i resync. commitRevision oznacza trwały stan, viewSeq kolejność projekcji. Jest propozycją techniczną, bez nowych reguł R, aktywacji funkcji lub zmian bilansu.

Doprecyzowania P po lokalnym przeglądzie: zakupy badań/infrastruktury wymagają serwerowego quoteId, a Buy MAX wiąże także zakres i łączny koszt. NOT_ACCEPTED na etapie admission nie oznacza PENDING; utrata pracy po PENDING wymaga odtworzenia/rozstrzygnięcia przed ponowieniem. Prezent za Robux rozpoczyna PreparePurchase z offerId i quoteId; trwałe przygotowanie zamówienia nie jest wypłatą. Wypłatę realizuje wyłącznie zaufane potwierdzenie, jednokrotnie i bez dodatkowego ClaimOffer. Nie zmienia to kontraktu 27 ani zatwierdzonych zasad produktu.

## Plan pierwszej farmy — P

[29](29_first_farm_implementation_plan.md) konkretyzuje fragment etapów 0–2: jedno jajo, ręczny wylęg i RCB, IHR, produkcja/transport, pojedyncze zakupy Common/kurników/zwykłych pojazdów, zapis i minimalne UI. Neutralny powrót zachowuje próg away i limit silosów z 27; pełne efekty, resety, nagrody i płatności są poza tym fragmentem, bez zmiany zakresu premiery. Wymaga manifestu obsługiwanych ID, źródeł pól startowych i adapterów (F01), nie nadaje tabelom statusu produkcyjnego. F01–F09 i scenariusze A01–A16 są planem, nie wykonaniem lub testami. Bilans pozostaje odłożony.

Dokumentacyjny manifest F01 przygotowano w [30](30_first_farm_manifest_and_technical_choices.md): siedem Common, po dwa typy kurników/zwykłych pojazdów, jedno jajo, ograniczony DTO i kierunki adapterów. Start opisano jako TEST_ONLY, odróżniając go od danych resetu i nieustalonego nowego konta. U01–U06 wskazują brak semantyki bramek, pełnego wylęgu/RCB i wybranych rozstrzygnięć technicznych; manifest nie oznacza pełnej gotowości wykonawczej F01. Nie zmienia R lub parametrów danych referencyjnych. Wszystkie zadania implementacyjne i testy nadal niewykonane.

## Uzupełnienie pierwszej farmy — 24.10.2026

[31](31_research_hatching_rcb_and_new_account.md) rozstrzyga N/S: punkty Common=sum(poziomów), inkluzywne progi; press=jedna próba, refill 3/s odrębny od holdRate=0 bez Epic; aktywne RCB q=min(c^n,K), mnożnik M tylko gdy q>1; rezerwację kury w drodze i zaliczenie populacji przy dotarciu. Potwierdzony referencyjny start ma jeden silos, pełne 250 wylęgarni i limit floty 4 przy jednym TRIKE. Są to N/S, nie nowe R lub zatwierdzony balans. HatchPress dopisano do 28 jako P. Rdzeń U01–U04 nie jest już niewiadomą; do realizacji pozostają trasa sceny oraz U05/U06. Bieżący podział zadań: [32](32_parallel_delivery_backlog.md).

## PRE-01–03 — przygotowane 24.10.2026

[33 — warsztat i zegary](33_pre01_toolchain_and_clocks.md), [34 — sesja i retencja](34_pre02_sessions_and_retention.md), [35 — trasy i dotarcia](35_pre03_routes_and_arrivals.md). Dokumentacja P przygotowana; narzędzia, adaptery i scenariusze L/S/D nadal niewykonane. Wybrano Rojo/Lune i port Clock, skończoną retencję jednego agregatu oraz serwerowe trasy z fazą dotarć po produkcji, przed IHR. To wybory techniczne do realizacji, nie nowe R ani konfiguracja wydania. Następny etap po osobnym zleceniu: IMP-01, potem równolegle IMP-02/03/07 według 32. Bilans 17–21 pozostaje odłożony.

## IMP-01 — wykonano zakres lokalny

[36 — NumericCodec i warsztat](36_imp01_numeric_codec_delivery.md): kod NumericCodec v1, warsztat Lune/Rojo, niezależne wektory i wykonane testy L. To pierwsza implementacja infrastruktury numerycznej, bez logiki farmy. Uprawnienie użytkownika obejmuje wyłącznie IMP-01; nie rozpoczynać pozostałych IMP-* samym zamknięciem zależności. Nie wykonano Studio/DataStore ani typecheckera. Historyczne stwierdzenia o braku kodu dotyczą wcześniejszych etapów. Kolejne możliwe zadania po osobnym zleceniu: równolegle IMP-02/03/07. Bilans i dane referencyjne bez zmian.

## IMP-02, IMP-03 i IMP-07 — wykonano L

[37 — katalog, DTO i SessionRepository](37_imp02_imp03_imp07_delivery.md): prywatny CatalogRegistry wewnętrznej farmy, ProtocolSchemas v1 oraz SessionRepository z wersjonowaniem, fencing i odzyskiwaniem UNKNOWN. Wspólny runner: NumericCodec 15702, katalog 2732, protokół 745, zapis 151 asercji PASS L (łącznie 19330); statyczny build rozdziela moduły prywatne i wspólne. Nie wykonano Studio/RPC/prawdziwego DataStore/typecheckera. Nowe zlecenie użytkownika obejmuje te trzy zadania oraz publikację kodu/testów/docs, nie pozostałe IMP-*. Bilans i JSON-y referencyjne bez zmian. Gotowość L nie jest gotowością produkcji lub zatwierdzeniem konfiguracji.

## IMP-04/05/06 — wykonano L (24.10.2026)

[38 — produkcja, IHR i wylęg/RCB](38_imp04_imp05_imp06_delivery.md): ukończono trzy zlecone moduły i testy lokalne. Wspólny runner: **20 536 asercji PASS**, 490 niezależnych przypadków uint64, statyczny build 12 modułów bez skryptów startowych. AGY: PASS przeglądu dostarczonych źródeł każdego zakresu; nie jest to test silnika. ProfileSchema dopuszcza prawidłowy carry IHR >=1 i opcjonalny licznik grup. Nie wykonano Studio, rzeczywistych tras, RPC, DataStore ani typecheckera. Timeline, Gateway i integracja zapisu pozostają kolejnymi zadaniami. Bilans 17–21 i JSON-y referencyjne bez zmian. Wcześniejsze wyniki i ograniczenia uprawnień są historycznymi zapisami poprzednich dostaw; bieżące zlecenie obejmuje IMP-04/05/06 i publikację kodu/testów/docs, bez automatycznego rozpoczynania pozostałych zadań.

## IMP-08/09 — wykonano L (24.10.2026)

[39 — koordynator i neutralna symulacja](39_imp08_imp09_delivery.md): jeden autor komend/ticków/checkpointów, rozstrzyganie PENDING/UNKNOWN i odzyskiwanie sesji; neutralny Timeline z siatką do 0.3 s, fazowym checkpointem i pełnym zamknięciem away. Wspólny runner **20 885 asercji PASS L**, w tym 221 koordynatora, 58 Timeline i 70 integracji; statyczny build 14 modułów. Integracja używa rzeczywistych modułów z kontrolowanym storage i testowym adapterem pamięć–wire. Studio, prawdziwy DataStore, Gateway, produkcyjny bootstrap i typechecker niewykonane. Bieżące zlecenie obejmuje IMP-08/09 i publikację kodu/testów/docs; wcześniejsze ograniczenia zakresu są historyczne. Nie rozpoczęto kolejnych zadań. Bilans 17–21 i referencyjne JSON-y bez zmian.


## IMP-10–15 oraz QA-01 — wykonano i odebrano (24.10.2026)

[40 — ukończenie i odbiór pierwszej farmy](40_first_farm_completion_delivery.md): zaimplementowano moduły i sprawdzono ich lokalne warianty L; bez zaliczenia S/D/H dla pierwszej farmy (FarmActions, ViewProjector, NetworkGateway, ClientTransport, ClientStateStore, RoutePresentation, IntentControllers, HUD, Bootstrap serwera i klienta oraz formalny odbiór A01–A16 w tests/acceptance/run.luau). Zgłoszenia #19, #20, #21, #22, #23, #24, #25 zamknięte.

## NEXT-01–10 oraz REL-01 — wykonano, zweryfikowano i odebrano (24.10.2026)

[41 — dostawa kandydata wydania (Release Candidate)](41_release_candidate_delivery.md): w pełni zaimplementowano, przetestowano na poziomie L i zweryfikowano przez QA cały zakres rozszerzeń domenowych oraz integracji kandydata wydania:
- `NEXT-01` (#26): Farm Value & Soul Eggs (`src/server/FarmMath/fv_se.luau`, 358 asercji).
- `NEXT-02` (#27): Zmiana jaja, prestiż i księgowanie sesji (`src/server/ProgressActions.luau`, 199 asercji).
- `NEXT-03` (#28): Pełne offline, boosty, Video Doubler i historia (`src/server/EffectsManager.luau`, 204 asercje).
- `NEXT-04` (#29): Pety: ekwipunek, wyposażenie i składanie efektów (`src/server/pets/equipment.luau`, 152 asercje).
- `NEXT-05` (#30): Łączenie petów, ochrona slotów/locków i trwała gwarancja (`src/server/pets/fusion.luau`, 103 asercje).
- `NEXT-06` (#31): Autorytatywne drony, walka, nagrody GE/Cash i pojedynczy claim (`src/server/rewards/drones.luau`, 72 asercje).
- `NEXT-07` (#32): Kanały dostaw 2+1, darmowe odrzucenie, dzienny bonus i rezerwacje (`src/server/rewards/offers.luau`, 64 asercje).
- `NEXT-08` (#33): Kalendarz 28 dni, trofea 19 jaj i konwersje nagród (`src/server/rewards/calendar.luau`, `src/server/rewards/trophies.luau`, 76 asercji).
- `NEXT-09` (#34): Adapter produktów Pro, Buy MAX, GE i warunkowego Piggy (`src/server/platform/products.luau`, 55 asercji).
- `NEXT-10` (#35): Onboarding, odzyskiwanie kroku samouczka i baseline konta (`src/server/onboarding/manager.luau`, `src/client/onboarding/TutorialController.luau`, 62 asercje).
- `REL-01` (#36): Nadrzędny runner kandydata wydania (`tests/release_candidate/run.luau`, 113 asercji) oraz audytor bramek wydania (`tools/verify_release.py`).

**Wspólny runner testowy**: **23 875 asercji (100% PASS L)** w 28 zestawach testów.  
**Rojo Static Build**: Dokładnie **37 modułów Luau** (w tym `FarmPlotBuilder.luau`) oraz **2 skrypty wejściowe** (`Main.server.luau`, `Main.client.luau`).  
**Bramki wydania (Release Gates)**: Wszystkie 6 bramek zatwierdzone (brak devgrantów, baza docs/31 §4, niezmienniki stanu, fencing/retencja docs/34 §4, 37 modułów + 2 entrypointy Rojo, kwarantanna odłożonego bilansu docs/17..21).  
Zadania `DOC-01..05`, `PRE-01..03`, `IMP-01..15`, `QA-01`, `NEXT-01..10`, `REL-01` (#2–#36) zamknięte; zadania wizualne `VIS-01..05` (#37–#41) zaimplementowane w kodzie i zsynchronizowane z Roblox Studio. Repozytorium ma status **lokalne testy L; wydanie niezatwierdzone**. Bramki wdrożeniowe S (Studio), D (Cloud DataStore) oraz H (Mobile UI) jawnie zdefiniowane przed publikacją produkcyjną.


## Produkcja — poprawki #54–55 (25.10.2026)

[Wykonano podłączenie kontekstu](workflow/production_fixes_54_55.md): aktualne jajo, SE/PE i właściwe warstwy petów/boostów działają w Bootstrap/Timeline, a timery przechodzą zapis i wznowienie. Dowód L: 147 nowych regresji, cały runner 67 941 asercji PASS. Tabele i odłożony bilans bez zmian; nie zatwierdza konfiguracji produkcyjnej. Pozostałe uwagi #56–61 nadal otwarte, w tym historyczne ważenie granicznego eventu.


## Przyciski i testy zachowania — #56 (25.10.2026)

[Zakres poprawki i ograniczenia](workflow/action_wiring_56.md): rzeczywiste komendy serwera, prywatna projekcja postępu, jawny wybór petów, pełny panel trofeów i podgląd produktu przed promptem. Brak konfiguracji nie daje sukcesu. Nowe testy sprawdzają oczekiwane zachowanie przez rzeczywisty transport, niezależne JSON-y i mutacje semantyczne. Weryfikacja wyłącznie L i statyczny build; bez zatwierdzenia bilansu, Studio lub chmury. Produkcyjna fuzja/zakup boostu pozostają niedostępne. Dni kalendarza 4/10/15/18/22 wymagają resolvera — nowe konto zatrzyma kalendarz na dniu 4 ([#62](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/62)). Pozostałe ustalenia #57–61 nadal otwarte. Wcześniejsze deklaracje pełnej gotowości nie są potwierdzeniem tej dostawy.


## Pełne nagrody kalendarza — #62 (25.10.2026)

[Dostawa #62](workflow/calendar_rewards_62.md) zastępuje wcześniejsze ograniczenie pięciu dni z #56. Wzór gotówki był już w 11 §3: procent aktualnego Home Farm Value; typ 14 z 13 zapisuje się jako trwały ExactUInt permanent.shellScripts, bez nowej wymiany lub sklepu. Wszystkie 28 pozycji są rozliczane przez serwer, z ochroną dnia UTC/replay i księgowaniem earned/prestiżu. Testy obejmują dziesięć kompletnych cykli z niezależnym oracle oraz awarie. Wyłącznie L i statyczny build, bez Studio/chmury. Bilans 17–21 i referencyjne JSON-y bez zmian; pozostałe #57–61 i niedostępność funkcji bez konfiguracji pozostają aktualne. Dawna informacja o zatrzymaniu na dniu 4 opisuje stan poprzedniego commitu.


## DataStore bez fallbacku produkcyjnego — #57 (25.10.2026)

[Dostawa #57](workflow/persistent_startup_57.md): runtime domyślnie wymaga PERSISTENT i portu read/update. Awaria otwarcia/sondy zatrzymuje start; brak skutecznego pozyskania sesji odrzuca wejście gracza. Pamięć jest jawnym trybem STUDIO_MEMORY z rzeczywistym IsStudio i atrybutem UseLocalMemoryStore=true, bez płatności/passów. INTERNAL_TEST_ONLY pozostaje poza runtime Roblox. Main ma od początku bezpieczny handler receipt; nowy zakup nie jest potwierdzany bez trwałego sukcesu. Potwierdzony retry synchronizuje również snapshot, a sukces po restarcie jest odtwarzany bez drugiego grantu. Weryfikacja lokalna rzeczywistego entrypointu z kontrolowanymi usługami, bez Studio/chmury. Pozostałe #58–61 nie są domknięte; bilans i reference_data bez zmian. Wcześniejsze listy #57–61 opisują stan poprzednich dostaw.


## Polityka konta i bonus Pro — #58 (25.10.2026)

[Dostawa #58](workflow/pro_policy_58.md): własność Pro pozostaje trwała, a +10 p.p. wymaga aktualnej zaufanej polityki. Brak/błąd odczytu wyłącza bonus, zachowując pozostałe korzyści. Zapisane pro_plus10_enabled jest wyłącznie historyczną kwalifikacją nadania; nie autoryzuje użycia. Podgląd i potwierdzenie zakupu uwzględniają dostępność. Testy L: 34 zestawy, 80 126 asercji, 20 wykrytych mutacji; bez Studio/chmury. Pozostałe #59–61; bilans i dane referencyjne bez zmian. Starsze listy otwartych ustaleń opisują poprzednie dostawy.


## Identyfikatory grup po resecie — #59 (25.10.2026)

[Dostawa #59](workflow/reset_group_ids_59.md): zmiana jaja i prestiż zachowują hatchGroupSequence, usuwając poprzednie grupy i rezerwacje. Regresje sprawdzają następne dokładne ID oraz brak wpływu starych dotarć na nową grupę, także powyżej 2^53 i po serializacji profilu. Bez zmian bilansu i danych referencyjnych. Starsze listy otwartych ustaleń opisują stan poprzednich dostaw; pozostałe #60–61.


## Zakres dowodów — #60 (25.10.2026)

[Raport #60](workflow/release_evidence_60.md) koryguje wcześniejsze deklaracje L/S/D i zatwierdzenia wydania. Lokalne harnessy dają wyłącznie L, także przy kontrolowanym DataStore i rzeczywistym Main. Dla A01–A16 brak zarejestrowanego dowodu per scenariusz S/D/H; pozostają NOT_VERIFIED. Zamknięcie Issues, synchronizacja sceny i liczby asercji nie dowodzą odbioru. Bieżące raporty mają releaseCandidateReady=false. Bez zmian bilansu i historycznych JSON-ów.


## Historyczny czas wydarzeń dochodu — #61 (25.10.2026)

[Dostawa #61](workflow/earnings_event_time_61.md): graniczny krok otrzymuje mnożnik dochodu ważony rzeczywistym czasem wydarzenia. Bez dodatkowego IHR, dotarć lub odliczania boostów; VD zachowuje predykat końca kroku. Regresje obejmują silosy, wznowienie fazy i rzeczywisty most Bootstrap. Lokalne L i statyczny build nie zaliczają S/D/H ani nie zatwierdzają wydania. Bilans i reference_data bez zmian. Wcześniejsze listy otwartych ustaleń opisują stan historycznych dostaw; #61 jest domknięte w tej dostawie.


## Poprawki #63–65 — 25.10.2026

[Dostawa #63–65](workflow/session_prestige_rcb_63_65.md): nowe intencje zakupów mają ID w przestrzeni generacji/strumienia sesji, stare retry zachowują wynik. Prestige stosuje zaufany event kolekcji na końcowe SE, ze sprawdzeniem granicy zapisu. Produkcja i HUD używają aktywnego RCB z runningCount oraz istniejących badań Common/Epic. Nie zmieniono FV (#67) ani bilansu. Testy lokalne nie zaliczają S/D/H; pozostałe #66–70 pozostają otwarte.


## Poprawki #66–70 — 25.10.2026

[Dostawa #66–70](workflow/farm_gaps_66_70.md): widoczne nagrody mają ID wystawione przez serwer; pusty/nieskonfigurowany kanał nie udaje dostępnej nagrody. Accounting Tricks wpływa na FV, hold działa według Epic z dzierżawą intencji, Sharing przekazuje rzeczywisty efekt i zachowuje kursor wyboru celu, a pociąg wymaga trwałej stacji. Nie dodano harmonogramu nagród, kupna stacji/wagonów ani konfiguracji odłożonego bilansu. To naprawa błędów integracji, nie zakończenie wszystkich funkcji premiery. Tylko L/statyczny build, bez zaliczenia S/D/H.

[Dostawa #71–74](workflow/entitlement_farm_fixes_71_74.md): naprawiono ponowienie potwierdzonych nadań Pro/Buy MAX, odrębne maksimum RCB badań w FV, zniżki Epic w wycenie i wydatku oraz zatrzymanie hold dopiero po zatwierdzonym resecie. Nie zmieniono zasad R, konfiguracji referencyjnej ani bilansu 17–21; weryfikacja lokalna nie zatwierdza wydania.
