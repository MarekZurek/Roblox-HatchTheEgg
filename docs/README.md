# HatchTheEgg — dokumentacja
**Naprawy po review24de421 — 28.10.2026:** serwer blokuje nieobsługiwane zakupy Epic i oferty WKRÓTCE, podgląd prestiżu uwzględnia event, a potwierdzone martwe helpery i duplikaty zostały usunięte. [Zakres, regresje i ograniczenia](workflow/remaining_fixes_2026_10_28.md). Dowody tej dostawy to lokalne testy L i statyczny build; publikacja kodu GitHub nie oznacza publikacji Roblox ani odbioru Studio. #92/#93 pozostają poza tą naprawą.

> **Aktualna decyzja użytkownika — 28.10.2026 (R):** RCB zależne od liczby biegnących kur zostało usunięte. Dochód korzysta ze stałego mnożnika wynikającego z badań, niezależnego od wylęgu i `runningCount`; działa on również w rozliczeniu away. Grupy kur, rezerwacje miejsc i dotarcia pozostają logiką populacji. Nazwy `activeRCB`/`onscreenChickenMult*` w kodzie i zapisach są historyczne. Aktualny kontrakt: [31 §3](31_research_hatching_rcb_and_new_account.md#3-stały-mnożnik-dochodu-i-przejścia-populacji). Starsze opisy aktywnego RCB w historii dostaw nie są bieżącym wymaganiem.

[Weryfikacja zmian Gemini24de421 i aktualne braki](workflow/review_24de421_2026_10_28.md).

> **Decyzja użytkownika 28.10.2026 (R): czasowy podwajacz dochodu i badanie `video_doubler_time` („Dłuższe Wzmocnienia”) zostały usunięte z gry.** Dawne terminy/poziomy w profilach są zachowane wyłącznie dla zgodności i nie dają efektu ani możliwości zakupu. Poniższe wcześniejsze zasady VD, jego darmowej aktywacji i odnawiania są historyczne. Osobny pass `double_cash` (2× Cash), boosty oraz zasady bonusowych prezentów pozostają poza tą zmianą. [Zakres i testy](workflow/remove_timed_doubler_2026_10_28.md).

Stan:26.10.2026. Zrealizowano i zweryfikowano [#81 — dochód RCB](workflow/rcb_income_81_2026_10_26.md) oraz [#82 — okna StudUI Lite i ikony gvesster](workflow/asset_ui_82_2026_10_26.md) (49 zestawów / 82 727 asercji Luau PASS, 11 Python PASS, Rojo 41+2 PASS_STATIC_BUILD, weryfikacja w Studio i celowane QA AGY PASS); szczegóły i ograniczenia w [WORKING_CONTEXT](WORKING_CONTEXT.md). Lokalny test nie oznacza odbioru chmury ani wydania. Bilans 17–21 pozostaje odłożony.

Kod wcześniejszej płyty/UI opublikowano w6006f2b; #75–80 zamknięto. Nie publikowano Roblox.

## Punkty startowe

- [CURRENT_SPEC](CURRENT_SPEC.md) — reguły i statusy N/S/R/P/H; dane referencyjne nie oznaczają testów implementacji.
- [WORKING_CONTEXT](WORKING_CONTEXT.md) — kontekst dalszej pracy.
- [TODO](TODO.md) — zadania i odłożone decyzje.
- [Workflow](workflow/README.md), [etapy](workflow/IMPLEMENTATION_STAGES.md) i [skills](workflow/SKILLS_PLAN.md) — organizacja przyszłej realizacji.

## Systemy

| Dokument | Zakres |
|---|---|
| [01](01_upgrades_and_research.md) | Badania Common i Epic |
| [02](02_eggs_and_farm_value.md) | Jaja, Farm Value i awans farmy |
| [03](03_habitats_and_population.md) | Kurniki, populacja i wylęg |
| [04](04_vehicles_and_shipping.md) | Transport i wagony Hyperloop |
| [05](05_prestige_soul_eggs_and_boosts.md) | Prestiż, SE/PE i boosty |
| [06](06_drones_silos_and_events.md) | Drony, silosy i wydarzenia |
| [07](07_roblox_architecture_and_roadmap.md) | Szkic architektury |
| [08](08_monetization_and_economy.md) | Produkty i ekonomia |
| [09](09_pets_system_and_artifacts.md) | Pety |
| [10](10_verified_simulation_and_server_config.md) | Symulacja offline i konfiguracja |
| [11](11_periodicals_calendar_events_and_boost_rules.md) | Kalendarz, wydarzenia i boosty |
| [12](12_calendar_scaling_and_video_doubler.md) | Podwajacz dochodu |
| [13](13_rewards_contracts_resets_and_gift_distributions.md) | Konwersje, resety i rozkłady nagród |
| [14](14_reward_claim_safety.md) | Bezpieczeństwo odbioru |
| [15](15_calendar_gameplay_formula_and_roblox_scope.md) | Skalowanie kalendarza |
| [16](16_pet_stacking_offline_and_package_schedule.md) | Składanie efektów i harmonogram prezentów |
| [UI](ui/ui_design_specification.md) | Propozycja interfejsu i makiety |

## Decyzje i scenariusze

[22 — D01–D07](22_gameplay_rules_for_approval.md), [23 — łączenie](23_pet_fusion_acceptance_review.md), [24 — podwajacz i prezenty](24_doubler_and_bonus_gift_acceptance_review.md), [25 — produkty](25_approved_product_structure.md), [26 — premiera i dostępność Pro](26_approved_launch_scope_and_pro_availability.md). Aktualne decyzje R rozstrzygają rozbieżności ze starszymi propozycjami.

## Odłożony bilans

[17](17_pet_balance_draft.md), [18](18_incubator_prices_and_acquisition_pacing.md), [19](19_integrated_farm_progression_simulation.md), [20](20_paying_player_balance_direction.md), [21](21_payer_progression_and_incubation.md) zawierają historyczne analizy i niezatwierdzone parametry. Redakcja opisów nie zmienia liczb ani nie wznawia strojenia.

## Materiały pomocnicze

[ECC](ecc/README.md) wspiera proces techniczny. [Historia redakcji](DOCUMENTATION_CLEANUP.md) wyjaśnia granice dokumentacji i wcześniejszych raportów. Raporty historyczne nie zastępują przyszłych testów kodu HatchTheEgg.

## Dane referencyjne w projekcie

[Dane referencyjne JSON](reference_data/README.md) zawierają pełne ceny i efekty badań, infrastrukturę, punkty krzywych, boosty, nagrody oraz reguły dronów i silosów. Są materiałem do przyszłej implementacji, nie konfiguracją wydania.

## Kontrakt przed implementacją

[27 — liczby, czas i model stanu gracza](27_numbers_time_and_player_state_contract.md): propozycja techniczna obejmująca formaty i jednostki, zegary, profil, resety i jednokrotne operacje. Bez kodu i nowych parametrów bilansu.

[28 — podział modułów i komunikacja serwer–klient](28_modules_and_client_server_contract.md) uzupełnia kontrakt 27 o granice odpowiedzialności, intencje i odpowiedzi, replikację widoku oraz odtwarzanie po rozłączeniu. Status P, bez kodu i zatwierdzania ekonomii.

[29 — pierwszy zakres implementacji: podstawowa farma](29_first_farm_implementation_plan.md) przekłada 27–28 na zadania F01–F09, konkretne zależności i scenariusze odbioru A01–A16. Jedno jajo, wylęg/RCB/IHR, transport, Common i bezpieczne zakupy/powrót; bez petów, prestiżu i płatności. Plan P; implementacja i scenariusze niewykonane.

[30 — manifest pierwszej farmy i wybory techniczne](30_first_farm_manifest_and_technical_choices.md) przygotowuje dokumentacyjną część F01: konkretne ID, źródła startu, TEST_ONLY profil, model wejścia/RCB, DTO i kierunki adapterów. U01–U06 jawnie ograniczają gotowość; nie jest konfiguracją wydania ani implementacją.

[31 — badania, ręczny wylęg, RCB i nowe konto](31_research_hatching_rcb_and_new_account.md) uzupełnia dostępne reguły i referencyjny start, odróżniając je od testowego profilu oraz zatwierdzonej konfiguracji. [32 — równoległy backlog](32_parallel_delivery_backlog.md) jest mapą ukończonych materiałów i przyszłych zadań z zależnościami.

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

[40 — ukończenie i odbiór pierwszej farmy](40_first_farm_completion_delivery.md): w pełni zaimplementowano i odebrano FarmActions, ViewProjector, NetworkGateway, ClientTransport, ClientStateStore, RoutePresentation, IntentControllers, HUD, Bootstrap serwera i klienta oraz testy akceptacyjne A01–A16. Łącznie **21 914 asercji PASS**, 24 moduły w statycznym buildzie Rojo. Zgłoszenia #19–#25 zamknięte.


## Poprawki bezpieczeństwa 25.10.2026

[Odbiór poprawek #51–53](workflow/security_fixes_51_53.md): ścisłe wejścia nagród, trwałe rejestry i testy regresyjne. Inkubacja produkcyjna bez zatwierdzonej konfiguracji jest niedostępna; bilans nadal odłożony. Pozostałe uwagi audytu nie są zamknięte.


## Produkcja — poprawki 25.10.2026

[#54–55: aktualne jajo, SE/PE, pety i boosty](workflow/production_fixes_54_55.md). 147 nowych regresji L, pełny runner 67 941 asercji PASS. Bez zatwierdzenia bilansu lub gotowości wydania; #56–61 pozostają do realizacji.


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

[Dostawa #71–74](workflow/entitlement_farm_fixes_71_74.md): zaufane nadanie passa czeka na rozliczenie czasu i rozstrzygnięcie zapisu; FV używa maksimum RCB Common/Epic; ceny uwzględniają istniejące zniżki Epic; odrzucony reset nie przerywa ważnego hold. L/statyczny build, bez zaliczenia S/D/H lub wznowienia bilansu.
