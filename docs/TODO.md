# TODO — stan 26.10.2026
**Naprawy po review24de421 — 28.10.2026:** serwer blokuje nieobsługiwane zakupy Epic i oferty WKRÓTCE, podgląd prestiżu uwzględnia event, a potwierdzone martwe helpery i duplikaty zostały usunięte. [Zakres, regresje i ograniczenia](workflow/remaining_fixes_2026_10_28.md). Dowody tej dostawy to lokalne testy L i statyczny build; publikacja kodu GitHub nie oznacza publikacji Roblox ani odbioru Studio. #92/#93 pozostają poza tą naprawą.

> **Aktualna decyzja użytkownika — 28.10.2026 (R):** RCB zależne od liczby biegnących kur zostało usunięte. Dochód korzysta ze stałego mnożnika wynikającego z badań, niezależnego od wylęgu i `runningCount`; działa on również w rozliczeniu away. Grupy kur, rezerwacje miejsc i dotarcia pozostają logiką populacji. Nazwy `activeRCB`/`onscreenChickenMult*` w kodzie i zapisach są historyczne. Aktualny kontrakt: [31 §3](31_research_hatching_rcb_and_new_account.md#3-stały-mnożnik-dochodu-i-przejścia-populacji). Starsze opisy aktywnego RCB w historii dostaw nie są bieżącym wymaganiem.

- [x] Zaktualizować kontrakt po usunięciu aktywnego RCB —28.10.2026; stały mnożnik dochodu, grupy i dotarcia zachowane.
- [x] [#99](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/99): Refaktoryzacja systemu badań: 4 kategorie tematyczne zamiast 13 tierów oraz scalenie powtarzających się technologii (14 drzew ulepszeń) — zrealizowano model danych (14 technologii, 4 kategorie), generator `Data.luau`, `ViewProjector`, `production_research`, 4 szerokie zakładki w `HUD.luau` i pełną suitę testów `tools/test.ps1` (PASS L).
- [x] [#93](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/93): Wdrożono Decyzję R — silosy usunięte na rzecz stałego limitu offline 6h/18h, Hyperloop odłożony jako "Egg to the Moon 🚀", badanie `silo_capacity` zablokowane, zaktualizowano HUD i testy (zamknięte).
- [x] [#98](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/98): Dedykowane okno prestiżu z pełnym zestawieniem korzyści i widocznym dostępem w UI — kod i testy L gotowe; **do dokończenia:** weryfikacja w Studio ([raport](workflow/issues_96_98_2026_10_29.md)).
- [x] [#97](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/97): Zaokrąglanie kwot gotówki (Cash) do 2 miejsc po przecinku w całej grze i nagrodach z dronów — kod i testy L gotowe; **do dokończenia:** weryfikacja w Studio ([raport](workflow/issues_96_98_2026_10_29.md)).
- [x] [#96](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/96): Zweryfikować i ujednolicić oznaczenie nagród z prezentów i dronów: "GE" -> "Diamenty" (💎) — kod i testy L gotowe; **do dokończenia:** weryfikacja w Studio ([raport](workflow/issues_96_98_2026_10_29.md)).
- [x] [#95](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/95): Usunąć modele silosów z mapy 3D farmy (`FarmPlotBuilder.luau`) — usunięto `_buildSiloTower`, `SILO_POSITIONS` i aktualizacje etykiet silosów; zachowano puste kolekcje `getSilos()`/`getSiloLabels()` dla kompatybilności API; testy `tests/presentation/run.luau` (425 asercji PASS L).
- [x] [#92](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/92): Aktywacja boostów z ekwipunku gracza (`ActivateBoost`) oraz widok posiadanych i aktywnych boostów w `HUD.luau` — serwerowa walidacja `profile.inventory.boosts`, limitu slotów (`2` standard / `5` Pro Permit), blokady Oświecenia (`eggIndex == 18`), jednorazowych boostów gotówkowych (`0.1 / 1.0 / 5.0 * homeFV` z uwzględnieniem `prestigeExtraEarnings`) oraz odliczania czasu; pokryte testami w `tests/ui/run.luau` (476 asercji PASS L) i `tests/game_behavior/run.luau` (2104 asercje PASS L).


> **Decyzja użytkownika 28.10.2026 (R): czasowy podwajacz dochodu i badanie `video_doubler_time` („Dłuższe Wzmocnienia”) zostały usunięte z gry.** Dawne terminy/poziomy w profilach są zachowane wyłącznie dla zgodności i nie dają efektu ani możliwości zakupu. Poniższe wcześniejsze zasady VD, jego darmowej aktywacji i odnawiania są historyczne. Osobny pass `double_cash` (2× Cash), boosty oraz zasady bonusowych prezentów pozostają poza tą zmianą. [Zakres i testy](workflow/remove_timed_doubler_2026_10_28.md).

> **Decyzja użytkownika 29.10.2026 (R): Silosy usunięte na rzecz stałego limitu offline (6h F2P / 18h Pro Permit); Hyperloop odłożony z rebrandingiem na „Egg to the Moon”.**
> 1. Mechanika silosów i ich zakupu zostaje całkowicie wycofana z farmy. Stały czas produkcji offline: **6 godzin** dla graczy zwykłych (bez Pro Permit) oraz **18 godzin** dla graczy posiadających Pro Permit. Badania epickie `silo_capacity` oraz `epic_silo_quality` zostają wycofane/zablokowane w `FeatureAvailability.luau`.
> 2. Zakup pojazdu 11 (Hyperloop) zostaje odłożony. W UI Floty slot 11 otrzymuje status `WKRÓTCE: EGG TO THE MOON 🚀` z zablokowanym przyciskiem; przyszły koncept przewiduje wystrzeliwanie rakiet z jajkami w kosmos jako unikalny element wyróżniający grę. Dotyczy: [#93](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/93).

## Bieżące zadanie

- [x] **Audyt i oczyszczenie Sklepu Badań Epickich:** Usunięto odniesienia do rakiet i ekspedycji kosmicznych po artefakty (`afx_mission_time` -> *Szybkość Kursu Floty*, `afx_mission_capacity` -> *Logistyka i Magazyn Floty*) oraz dostosowano opisy badań wylęgu, mnożników i zniżek.
- [x] **Rebranding waluty premium:** Oficjalną walutą premium są **Diamenty (Diamonds, 💎)**. Wszelkie odniesienia prezentacyjne w UI i dialogach stosują Diamenty (np. liczniki waluty `Diamenty: -`, koszty badań epickich `54 💎`, Sklep Diamentów i Przepustek, pakiety `1,000 💎` i `10,000 💎`). Wewnętrzny klucz profilu zachowuje identyfikator `profile.permanent.GE` dla pełnej wstecznej zgodności DataStore i logiki serwera.
- [x] [Górny panel tempa](workflow/top_rates_panel_2026_10_26.md): trzy opisane wartości w jaj/s, skalowanie i safe area; lokalne testy i ograniczone Studio PASS, Cline/AGY; bez nowego commitu/pusha.
- [x] [#81](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/81): sprawdzono rzeczywisty wpływ aktywnego RCB na gotówkę ([raport](workflow/rcb_income_81_2026_10_26.md), 212 asercji PASS + native Studio + QA AGY PASS; brak błędu runtime).
- [x] [#82](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/82): wdrożono spójne 8 okien na StudUI Lite i 14 wgranych ikonach gvesster ([raport](workflow/asset_ui_82_2026_10_26.md), 240 asercji PASS + native Studio 320×640/640×360/1200×700 + QA AGY PASS).

- [x] [UI #77–80](workflow/ui_tasks_77_80_2026_10_26.md): feedback braku miejsca/zapasu, nazwy Tier kurników i pojazdów, usunięcie płytek pojazdów; implementacja Cline, celowane QA AGY PASS, root runner i ograniczony smoke Studio PASS; kod opublikowano w 6006f2b, #77–80 zamknięte.

- [x] [Płyta 30/s i strumień kur](workflow/plate_hatching_2026_10_26.md): implementacja, regresje, celowane QA AGY i lokalna próba Studio wykonane; ograniczenia review w raporcie. Zgłoszenia #75–76 zamknięte po publikacji kodu 6006f2b na GitHub; Roblox niepublikowany.

## Odłożone na polecenie użytkownika

- [ ] **Dalsza kalibracja płatnej progresji i ekonomii petów.** Wznowić wyłącznie na kolejne polecenie użytkownika. Zakres: porównania F2P / Pro / 5 slotów / zakupy GE, ostateczne ceny inkubatorów (szczególnie Universe V), limit i tempo odnawiania inkubacji oraz tempo zdobywania i ulepszania petów.
- [ ] W ramach tego odłożonego zadania poprawić strategie symulacji (boosty, prestiż, rezerwa GE na Hyperloop), uwzględnić wybrany zakres trofeów i wydarzeń oraz sprawdzić dokładność modelu przed zamrożeniem bilansu.

Ostatni wynik: [21. Progresja płacącego gracza](21_payer_progression_and_incubation.md), 61 przebiegów analitycznych. Ceny I–IV i saldo F2P 120 / Pro 720 przy odnowieniu 60 s pozostają **niezatwierdzonymi propozycjami**; cena V jest nierozstrzygnięta. Odłożenie zadania nie zatwierdza tych liczb. Bez automatycznego wznowienia.

## Pozostałe decyzje przed implementacją

Propozycje rozstrzygnięć: [22, D01–D07](22_gameplay_rules_for_approval.md). D02–D07 zatwierdzone; D01: premium +10 p.p. zamiast dopłat zatwierdzone, skutek porażki zatwierdzony; definicja stopnia i ochrona kopii zatwierdzone. D04 zatwierdzone. Parametry bilansu nadal odłożone.

- [x] **D01 — zatwierdzony bonus premium:** premium pass +10 punktów procentowych (max 100%) zamiast dopłat do każdej próby zatwierdzone.
- [x] **D01 — skutek porażki:** zatwierdzono zachowanie peta bazowego, zużycie pozostałych kopii i trwały licznik gwarancji.
- [x] **D01 — definicja stopnia:** zatwierdzono tier pochodzenia × docelowy wariant ewolucji; gatunek/rarity bez dodatkowej zmiany szansy. Procenty bazowe/próg/ceny/receptury nadal odłożone.
- [x] **D01 — ochrona wyboru kopii:** zatwierdzono wcześniejsze zdjęcie/odblokowanie i brak automatycznej podmiany materiałów przy zmianie bazowego. Historia korekt scenariuszy: [23](23_pet_fusion_acceptance_review.md).
- [x] D02: dopuszczalne 100% elity i jawne nasycenie Hawka zatwierdzone, bez zmiany sił.
- [x] D03: Enlightenment bez efektów petów i Clarity w v1; zachowanie/pauza boostów zatwierdzone.
- [x] D04: zatwierdzono pierwsze użycie dnia UTC darmowe, kolejne GE/opcjonalnie Robux, z ujawnioną zawartością płatnego prezentu. Ceny odłożone.
- [x] D06: zakres premiery zatwierdzony według 22; PE z kalendarza i trofeów, bez ekspedycji/Ultra.
- [x] D05: limit paczek 2+1, stały wynik i trwałość oferty zatwierdzone.
- [x] D07: wymagania serwerowego czasu, sesji i jednokrotnego rozliczania zatwierdzone; realizacja pozostaje przyszłą implementacją.
- [x] Ujednolicić dokumentację (23.10.2026): [CURRENT_SPEC](CURRENT_SPEC.md) oddziela dowody, zatwierdzone zmiany i propozycje; poprawiono sprzeczności 01–09 i oznaczono historyczne etapy audytów. [Zakres porządkowania](DOCUMENTATION_CLEANUP.md).

## Doprecyzowania po przeglądzie scenariuszy

- [x] D04/D05/D07: zatwierdzono płatny charakter opłaconego zamówienia sprzed północy bez zużycia nowego darmowego prawa oraz rezerwację oferty przy nierozstrzygniętej płatności — [24](24_doubler_and_bonus_gift_acceptance_review.md).
- [x] D03/D04: zatwierdzono odbiór istniejącej oferty na Enlightenment; boost trafia do ekwipunku bez automatycznej aktywacji — R w 24.
- [ ] **W ramach odłożonego bilansu, nie aktywne zadanie:** podaż płatnych aktywacji VD i propozycja braku dodatkowego limitu dziennego; bez rozstrzygania teraz.

## Pozostałe decyzje adaptacji poza bilansem

Zakres: [ADAPTATION_OPEN_DECISIONS](ADAPTATION_OPEN_DECISIONS.md).

- [x] Podział produktów zatwierdzony: mocne Pro z dodatkowymi miejscami petów i +10 p.p.; osobne Buy MAX i Auto-Hatch kurczaków; powtarzalne GE i Piggy. [25](25_approved_product_structure.md). Ceny/liczby/tempo odłożone.
- [x] Zakres premiery zatwierdzony: Rainbow kończy v1, Pro/Buy MAX/GE od premiery, Piggy warunkowo po bilansie, Auto-Hatch i VIP później — [26](26_approved_launch_scope_and_pro_availability.md).
- [x] Zatwierdzono wariant A Pro: brak niedostępnego +10 p.p., reszta korzyści działa; jasny opis przed zakupem, bez zamiennika w v1 — [26](26_approved_launch_scope_and_pro_availability.md).
- **Pominięte:** task Opusa dotyczący ponownego przeglądu kalendarza/trofeów/PE. Nie wznawiać.

## Organizacja pracy

- [x] Przeanalizować workflow GrowASnack i dostosować do HatchTheEgg/ECC: [workflow](workflow/README.md), [etapy](workflow/IMPLEMENTATION_STAGES.md), [mapa skills](workflow/SKILLS_PLAN.md). Rezultat P; bez aktywacji.
- [x] Utworzyć siedem skills projektu w `.agents/skills` i połączyć z [workflow](workflow/SKILLS_PLAN.md). Zweryfikowano definicje i linki; bez instalacji hooków/runtime, uruchomienia Studio i implementacji gry. Załadowanie przez klienta niepotwierdzone.

## Po osobnym rozpoczęciu implementacji

- [ ] Zaprojektować autorytatywne rozliczanie ekonomii i zapis gracza po stronie serwera Roblox, w tym jednokrotny odbiór nagród.
- [ ] Sprawdzić całość w działającej grze: granice wydarzeń i offline, zmianę wyposażenia, składanie efektów, zmianę jaja i prestiż oraz odbiór nagród. Testy analityczne nie zastępują tej weryfikacji.


## Przygotowanie techniczne bez implementacji

- [x] Przygotować propozycję kontraktu liczb, czasu i modelu stanu: [27](27_numbers_time_and_player_state_contract.md). Oznaczenie dotyczy sporządzenia dokumentu P, nie akceptacji techniki, implementacji lub zaliczenia testów.
- [ ] W odpowiednim późniejszym zadaniu dobrać i zweryfikować adaptery liczb/czasu/zapisu, zakresy i konwersje, pola startowe resetu, retencję ID oraz harness. Nie jest to zlecenie realizacji ani wznowienia bilansu.

- [x] Przygotować propozycję podziału modułów i kontraktu komunikacji na podstawie 27: [28](28_modules_and_client_server_contract.md). Zamknięto sporządzenie dokumentu P, nie realizację, zatwierdzenie platformowego adaptera lub testy.
- [x] Doprecyzować 28 po lokalnym przeglądzie: obowiązkowy podgląd zakupów, rozdzielenie NOT_ACCEPTED/PENDING i odzyskiwanie po utracie kolejki oraz jedna ścieżka PreparePurchase dla prezentu Robux. Uzupełniono scenariusze; nie uruchomiono testów implementacji i nie nadano propozycjom statusu R.
- [ ] Przy osobnym zleceniu realizacji dobrać transport, schematy wiadomości i projekcji, budżety kolejek/rozmiarów oraz testy integracji protokołu 28. To przyszła zależność techniczna, nie aktywacja bilansu lub funkcji spoza v1.

- [x] Sporządzić [29 — plan pierwszej farmy](29_first_farm_implementation_plan.md): zakres, zadania F01–F09, zależności oraz A01–A16. Zamknięto przygotowanie planu P, nie realizację zadań ani testy.
- [x] Przygotować dokumentacyjną część F01: [30 — manifest i wybory techniczne](30_first_farm_manifest_and_technical_choices.md). Opisano ID, źródła startu/fixture, wejście i RCB, projekcję oraz kierunki adapterów, bez kodu lub konfiguracji wydania.
- [ ] Wykonać i sprawdzić pozostałe techniczne zależności F01: scenę/dotarcie oraz adaptery U05–U06. Projekty dokumentacyjne PRE-01–03 przygotowano w 33–35. Referencyjne U01/U02 i rdzeń U03/U04 rozstrzygnięto w 31. Nie oznaczać adapterów jako wykonanych, nie zmieniać bilansu; realizacja wymaga osobnego zlecenia.

## Aktualizacja 24.10.2026 — pierwsza farma i backlog

- [x] Rozstrzygnąć referencyjne progi Common, bazowy press/hold, aktywne RCB i podstawowy start konta — [31](31_research_hatching_rcb_and_new_account.md). Bez zmian bilansu i implementacji.
- [x] Przygotować kontrakt RouteProvider i autorytatywnego dotarcia — [35](35_pre03_routes_and_arrivals.md). Geometria i test sceny w IMP-13/15 nadal niewykonane.
- [x] Przygotować warsztat U06 i projekt zapisu/retencji U05: [33](33_pre01_toolchain_and_clocks.md), [34](34_pre02_sessions_and_retention.md). Wykonanie i testy pozostają w IMP-01/07; nie nadano gotowości wydania.

- [x] PRE-01/02/03: dokumentacja przygotowana równolegle i powiązana z backlogiem; odbiór statyczny opisuje [raport](workflow/preparation_01_03_review.md). L/S/D pozostają niewykonane.

## Wykonanie IMP-01

- [x] Przygotować przypięty warsztat Lune/Rojo oraz NumericCodec v1 i wykonać testy L — [36](36_imp01_numeric_codec_delivery.md).
- [ ] Pozostałe adaptery czasu, sesji i ich S/D pozostają przy istniejących IMP-*; lokalny codec ich nie zalicza. Nie wznawiać odłożonego bilansu.

## Wykonanie równoległe

- [x] IMP-02: wybrany katalog referencyjny i niezależne kontrole bitowe.
- [x] IMP-03: ścisłe schematy pierwszej farmy i adwersarialne testy L.
- [x] IMP-07: repozytorium/port natywny i kontrolowany fake L; rzeczywisty test D niewykonany.
- [ ] Studio/RPC, rzeczywiste konflikty DataStore oraz długotrwała retencja przed wydaniem pozostają przy odpowiednich integracjach, nie są zaliczone tymi checkboxami. [Wyniki](37_imp02_imp03_imp07_delivery.md).

## IMP-04/05/06 — wykonano L (24.10.2026)

[38 — produkcja, IHR i wylęg/RCB](38_imp04_imp05_imp06_delivery.md): ukończono trzy zlecone moduły i testy lokalne. Wspólny runner: **20 536 asercji PASS**, 490 niezależnych przypadków uint64, statyczny build 12 modułów bez skryptów startowych. AGY: PASS przeglądu dostarczonych źródeł każdego zakresu; nie jest to test silnika. ProfileSchema dopuszcza prawidłowy carry IHR >=1 i opcjonalny licznik grup. Nie wykonano Studio, rzeczywistych tras, RPC, DataStore ani typecheckera. Timeline, Gateway i integracja zapisu pozostają kolejnymi zadaniami. Bilans 17–21 i JSON-y referencyjne bez zmian. Wcześniejsze wyniki i ograniczenia uprawnień są historycznymi zapisami poprzednich dostaw; bieżące zlecenie obejmuje IMP-04/05/06 i publikację kodu/testów/docs, bez automatycznego rozpoczynania pozostałych zadań.

## IMP-08/09 — wykonano L (24.10.2026)

[39 — koordynator i neutralna symulacja](39_imp08_imp09_delivery.md): jeden autor komend/ticków/checkpointów, rozstrzyganie PENDING/UNKNOWN i odzyskiwanie sesji; neutralny Timeline z siatką do 0.3 s, fazowym checkpointem i pełnym zamknięciem away. Wspólny runner **20 885 asercji PASS L**, w tym 221 koordynatora, 58 Timeline i 70 integracji; statyczny build 14 modułów. Integracja używa rzeczywistych modułów z kontrolowanym storage i testowym adapterem pamięć–wire. Studio, prawdziwy DataStore, Gateway, produkcyjny bootstrap i typechecker niewykonane. Bieżące zlecenie obejmuje IMP-08/09 i publikację kodu/testów/docs; wcześniejsze ograniczenia zakresu są historyczne. Nie rozpoczęto kolejnych zadań. Bilans 17–21 i referencyjne JSON-y bez zmian.

## IMP-10–15 oraz QA-01 — wykonano lokalne warianty L; S/D/H niezweryfikowane (24.10.2026)

[40 — ukończenie i odbiór pierwszej farmy](40_first_farm_completion_delivery.md): w pełni zrealizowano pozostałe zadania pierwszej farmy:
- [x] IMP-10: FarmActions (wyceny createQuote, pojedyncze zakupy BuyResearch/BuyHabitat/BuyVehicle, sameTypeOwned, nienaruszalność accounting.currentFarmCash, idempotencja).
- [x] IMP-11: NetworkGateway i ViewProjector (projekcja PrivatePlayerViewDTO i PublicView, StateDelta, admission gating, izolacja graczy).
- [x] IMP-12: ClientTransport i ClientStateStore (korelacja żądań, monotoniczność viewSeq, wykrywanie luk i RefreshState, ignorowanie starych deltat).
- [x] IMP-13: Scena podstawowej farmy i prezentacja tras (RoutePresentation: 4 parcele PRE-03, animacja kur, zerowy wpływ 3D na autorytatywny stan).
- [x] IMP-14: Minimalny HUD i kontrolery intencji (IntentControllers: HatchPress/HatchInput z inputSeq, ShopController; HUD: formatowanie K/M/B/T, reaktywność, blokady, baner sesji).
- [x] IMP-15: Integracja pierwszej farmy i bootstrap (ServerBootstrap, ClientBootstrap, pełny smoke test pętli gry E2E).
- [x] QA-01: Formalny odbiór pierwszej farmy A01–A16 w tests/acceptance/run.luau (264 asercje PASS, lokalne warianty macierzy docs/29; nie jest to procent pokrycia wymagań).
Łączny runner: **21 914 asercji PASS L**, statyczny build 24 modułów bez skryptów wejściowych. Zamknięto issues #19–#25 na GitHubie.

## NEXT-01–10 oraz REL-01 — wykonano i odebrano (24.10.2026)

- [x] NEXT-01 (#26): Farm Value & Soul Eggs (`FarmMath/fv_se.luau`, 358 asercji).
- [x] NEXT-02 (#27): Zmiana jaja, prestiż i księgowanie sesji (`ProgressActions.luau`, 199 asercji).
- [x] NEXT-03 (#28): Pełne offline, boosty, Video Doubler i historia (`EffectsManager.luau`, 204 asercje).
- [x] NEXT-04 (#29): Pety: ekwipunek, wyposażenie i składanie efektów (`pets/equipment.luau`, 152 asercje).
- [x] NEXT-05 (#30): Łączenie petów, ochrona slotów/locków i trwała gwarancja (`pets/fusion.luau`, 103 asercje).
- [x] NEXT-06 (#31): Autorytatywne drony, walka, nagrody GE/Cash i pojedynczy claim (`rewards/drones.luau`, 72 asercje).
- [x] NEXT-07 (#32): Kanały dostaw 2+1, darmowe odrzucenie, dzienny bonus i rezerwacje (`rewards/offers.luau`, 64 asercje).
- [x] NEXT-08 (#33): Kalendarz 28 dni, trofea 19 jaj i konwersje nagród (`rewards/calendar.luau`, `rewards/trophies.luau`, 76 asercji).
- [x] NEXT-09 (#34): Adapter produktów Pro, Buy MAX, GE i warunkowego Piggy (`platform/products.luau`, 55 asercji).
- [x] NEXT-10 (#35): Onboarding, odzyskiwanie kroku samouczka i baseline konta (`onboarding/manager.luau`, `client/onboarding/TutorialController.luau`, 62 asercje).
- [x] REL-01 (#36): Nadrzędny runner kandydata wydania (`tests/release_candidate/run.luau`, 113 asercji) oraz audytor bramek wydania (`tools/verify_release.py`).
- [x] VIS-01..06 (#37–#42): Entrypointy Studio, generator świata 3D, wskaźniki diegetyczne, HUD w StarterGui, animacje kurcząt i dronów oraz weryfikacja na żywo.

## Zadania Wdrożenia Pełnego / Produkcyjnego (PROD-01–08)

- [x] **PROD-01 (#43)**: Pełny katalog badań, kurników i floty (Tiers 1–13, Epic, 19 Kurników, 12 Pojazdów). 66 358 asercji PASS.
- [x] **PROD-02 (#44)**: Progresja 19 Jaj i Stacja Ulepszania Jaja w świecie 3D. 67 196 asercji PASS.
- [x] **PROD-03 (#45)**: Kompletne okna modalne UI (Kurniki, Flota, Badania, Pety, Sklep GE, Kalendarz & Trofea). 321 asercji UI PASS.
- [x] **PROD-04 (#46)**: Produkcyjna integracja chmury Roblox DataStoreService i blokowanie sesji. 211 asercji DataStore PASS.
- [x] **PROD-05 (#47)**: Produkcyjna obsługa płatności Roblox MarketplaceService (GamePasses & DevProducts). 94 asercje Purchases PASS.
- [x] **PROD-06 (#48)**: Diegetyczne aktory 3D: Drony z celowaniem, Ciężarówka dostawcza 2+1 i Silosy z SurfaceGui. 444 asercje Presentation PASS, 89 Drones PASS.
- [x] **PROD-07 (#49)**: Stacja Inkubacji Petów w świecie 3D i animacja wykluwania jaj. 181 asercji Pet Effects PASS, 457 Presentation PASS.
- [x] **PROD-08 (#50)**: Oprawa dźwiękowa (SFX & Muzyka BGM) oraz optymalizacja mobilna interfejsu. 377 asercji UI/Audio PASS.


## Bezpieczeństwo — 25.10.2026

- [x] #51–53: zablokować wymuszanie ceny/wyniku inkubacji i wypłaty z nieistniejących dronów/ofert; dodać trwałe rejestry i regresję odbioru. [Zakres i ograniczenia](workflow/security_fixes_51_53.md). Nie zatwierdza bilansu ani całej gotowości wydania.
- [x] #61: historyczny czas wydarzeń dochodu w granicznym kroku, silosy i checkpointy. [Dostawa](workflow/earnings_event_time_61.md).

- [x] #54–55: podłączyć aktualne jajo, SE/PE, pety i boosty do produkcji, HUD oraz zapisu/wznowienia. [Zakres i dowody](workflow/production_fixes_54_55.md). Bilans bez zmian.

- [x] #56: usunąć fikcyjne sukcesy przycisków, podłączyć komendy i serwerowe odpowiedzi oraz dodać regresje zachowania. [Dostawa i ograniczenia](workflow/action_wiring_56.md).
- [x] #62: resolver dni 4/10/15/18/22, księgowanie gotówki i dokładny licznik Shell Scripts; testy pełnych 28 dni. [Dostawa i ograniczenia](workflow/calendar_rewards_62.md).
- [ ] Włączenie produkcyjnej fuzji/zakupu boostów wymaga osobnego zadania: podgląd/quote z kontraktu 28 oraz zatwierdzona konfiguracja. Obecne porty fixture'ów są INTERNAL_TEST_ONLY; bilansu nie wznowiono.

- [x] #57: wyłączyć fallback pamięci na produkcji; jawny lokalny tryb Studio bez płatności, bezpieczny start/receipt oraz regresje rzeczywistego Main i restartu. [Dostawa](workflow/persistent_startup_57.md).

- [x] #58: bieżąca polityka konta dla +10 p.p., bezpieczny brak danych, niezależna własność Pro i informacja przed zakupem. [Dostawa](workflow/pro_policy_58.md).

- [x] #59: zachować monotoniczny licznik grup przy obu resetach; regresje nowych ID i spóźnionych dotarć. [Dostawa](workflow/reset_group_ids_59.md).


## Zakres dowodów — #60 (25.10.2026)

[Raport #60](workflow/release_evidence_60.md) koryguje wcześniejsze deklaracje L/S/D i zatwierdzenia wydania. Lokalne harnessy dają wyłącznie L, także przy kontrolowanym DataStore i rzeczywistym Main. Dla A01–A16 brak zarejestrowanego dowodu per scenariusz S/D/H; pozostają NOT_VERIFIED. Zamknięcie Issues, synchronizacja sceny i liczby asercji nie dowodzą odbioru. Bieżące raporty mają releaseCandidateReady=false. Bez zmian bilansu i historycznych JSON-ów.

- [x] #60: rozdzielić lokalne wyniki od gotowości wydania, skorygować deklaracje i dodać regresje raportów/wybranego wiringu Main.
- [ ] Odbiór S/D/H według scenariuszy 29: zebrać rzeczywiste dowody w osobno zleconych środowiskach; #60 nie zalicza tych poziomów.


## Ponowny audyt — #63–70

- [x] #63–65: ID nowych intencji po reconnect/restarcie, zaufany event kolekcji SE i aktywne RCB. [Dostawa](workflow/session_prestige_rcb_63_65.md).
- [x] #66–70: autorytatywna prezentacja rekordów nagród / nieaktywny pusty kanał, Accounting Tricks w FV, Hold to Hatch, IHR Sharing i bramka stacji Hyperloop. [Dostawa](workflow/farm_gaps_66_70.md).

- [ ] Pozostała integracja premiery: rzeczywisty harmonogram wystawiania nagród, niedostarczone ścieżki aktywacji/zakupów i odbiór S/D/H. #66–70 nie zatwierdzają tych funkcji, parametrów ani wznowienia bilansu.

- [x] #71–74: ponowienie potwierdzonych passów, maksimum RCB w FV, zniżki Epic i granica zatwierdzenia resetu dla hold. [Dostawa](workflow/entitlement_farm_fixes_71_74.md). Nie zalicza S/D/H ani pozostałej integracji premiery.
