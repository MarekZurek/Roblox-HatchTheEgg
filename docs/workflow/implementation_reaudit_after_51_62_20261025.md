# Ponowny audyt implementacji po #51–62

25.10.2026. Badany commit: `fe4d2ad54af8bbffc0368c4a2516ccfa8553d9bb`. Werdykt: **wymaga poprawek; niezatwierdzone wydanie**. Audyt porównuje bieżące integracje z regułami i kontraktami projektu, bez nowego audytu źródeł reguł oraz bez kalibracji bilansu.

## Odtworzone błędy — zgłoszone na GitHub

| Priorytet | Zgłoszenie | Obserwowany wynik / wymagane zachowanie |
|---|---|---|
| P1 | [#63 — kolizja ID zakupów po reconnect](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/63) | Dwa rzeczywiste ClientBootstrap, rozłączenie i ponowne wejście: drugi świadomy zakup używa ponownie op-BuyResearch-1. Serwer zwraca REPLAYED z poziomem 1 zamiast kupić poziom 2. Nowa intencja potrzebuje nowego ID; stare retry nadal musi być idempotentne. |
| P1 | [#64 — wydarzenie prestiżu](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/64) | Przy E=1000000 i aktywnym evencie kolekcji ×4 prawidłowa komenda Prestige przyznaje 7.943282347242814 SE zamiast 31.773129388971256, po czym resetuje przychód. Bootstrap nie przekazuje serwerowego mnożnika. |
| P1 | [#65 — aktywne RCB](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/65) | 100 zasiedlonych kur, 10 biegnących, excitable_chickens=25: dochód za 0.3 s wynosi 0.25 zamiast około 0.32002113604908916. Timeline wymusza rcbMultiplier=1. |
| P2 | [#66 — widoczne nagrody bez wystawienia](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/66) | Klient tworzy drone-1 i wysyła offer_2plus1, ale produkcyjny serwer nie wystawia tych rekordów. Rzeczywisty ingress odrzuca UNKNOWN_SPAWN / OFFER_NOT_FOUND. Zabezpieczenie #51–53 jest poprawne; normalne interakcje pozostają z nim niepołączone. |
| P2 | [#67 — Accounting Tricks w FV](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/67) | Po ustawieniu istniejącego Accounting Tricks na poziom 20 FV pustej farmy pozostaje 13732.00679132647 zamiast 27464.01358265294. Adapter wymusza valuationMult=1. Dotyka awansu i procentowych nagród kalendarza. |
| P2 | [#68 — Hold to Hatch](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/68) | Hold to Hatch=15, pełny zapas i wolny Coop: start przyjęty, held=true, lecz po 0.3 s nadal nie ma żadnej grupy. Brak wywołania holdStep w integracji. To odrębne od odłożonego Auto-Hatch passa. |
| P2 | [#69 — IHR Sharing](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/69) | Pełny pierwszy Coop, pusty drugi, IHR=2/min i sharing=100%: akumulator drugiego po 0.3 s wynosi 0.01 zamiast 0.02. Timeline przekazuje sharing=0. |
| P2 | [#70 — bramka stacji Hyperloop](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/70) | Quote i zakup HYPERLOOP TRAIN przechodzą mimo permanent.hyperloop=false. Slot otrzymuje typ 11 bez trwałego odblokowania stacji. |

Każde zgłoszenie ma źródło i linię na badanym commicie, wejście, obserwowany wynik, wymaganie docs i kryteria przyszłej naprawy. Nie usuwano zabezpieczeń ani nie tworzono zgłoszeń na podstawie samej liczby asercji. Próba projekcji profilu z PE ponad 2^53 i SE=0 **przeszła**; nie zgłoszono jej jako awarii projekcji.

## Powtórne sprawdzenie dostaw #51–62

| Dostawa | Wykonana weryfikacja L i ograniczenie |
|---|---|
| #51–53 | reward_security: 174 asercje. Zmyślone nagrody i wymuszona inkubacja są blokowane. To nie dowodzi obecności produkcyjnego harmonogramu; odrębny błąd #66. |
| #54–55 | production_context: 147 asercji. Aktualne jajo, SE/PE oraz testowane pety/boosty wpływają na produkcję. Nie oznacza to kompletnego podłączenia wszystkich badań, RCB i eventów kolekcji. |
| #56 | game_behavior: 2012 asercji i pozostałe testy sieci/UI. Wykryty scenariusz #63 korzysta z dwóch nowych klientów i trwałego ledgera, a nie retry tej samej intencji. |
| #62 | calendar_cycle: 9812 asercji, pełne 28 dni w 10 cyklach. Resolver i wypłata procentu FV są podłączone; błędne wejście FV przy Accounting Tricks pozostaje #67. |
| #57 | persistence_startup: 154 asercje. Brak produkcyjnego fallbacku do pamięci i kontrolowane próby rzeczywistego Main. Nie jest to dowód działania natywnej chmury. |
| #58 | pro_policy: 207 asercji. Nieznana/ograniczona polityka nie uprawnia do +10 p.p. Nie wykonano rzeczywistego PolicyService lub zakupu platformowego. |
| #59 | resets: 1148 asercji. Licznik grup zachowany przy resetach, w tym ponad 2^53; stare dotarcie nie zamyka nowej grupy. |
| #60 | 11 testów Python i walidacja bieżących raportów. PASS_LOCAL_CHECKS, releaseCandidateReady=false, S/D/H NOT_VERIFIED. Nowe ustalenia nie unieważniają tej poprawki raportowania. |
| #61 | event_time: 109 asercji. Historyczny czas wydarzenia dochodu, silosy i checkpointy zgodne w testowanych przypadkach; nie jest to implementacja eventu kolekcji z #64. |

Świeży pełny runner na badanym commicie: **35 zestawów Luau / 80 360 asercji PASS**, dodatkowo **11 testów raportowania Python PASS**, **25/25 wybranych mutacji wykrytych**. Build statyczny: 39 modułów / 2 entrypointy. Osiem dodatkowych prób audytu pokazuje rozbieżności pomimo tego wyniku. Nie wyprowadzamy z liczby testów procentu zgodności gry z docs.

## Co jeszcze nie jest dostarczoną ścieżką produkcyjną

Poniższe to potwierdzone statycznie braki integracji lub konfiguracji, odrębne od ośmiu odtworzonych błędów. Nie udajemy odtworzenia transakcji, dla której nie ma portu.

| Obszar | Stan i potrzebny krok |
|---|---|
| Buy MAX | Istnieje produkt/uprawnienie, lecz protokół i zakupy badań obsługują wyłącznie mode=single. Potrzebna rzeczywista operacja maksymalnego zakupu z wyceną i ograniczeniami z 25/28. Samo nadanie passa nie implementuje korzyści. |
| Użycie boostów i VD | Istnieją czyste activateBoost/activateVideoDoubler, ale brak ich wywołań przez Bootstrap i właściwych komend w protokole. Potrzebna ścieżka ekwipunek → aktywacja, limity/pauza i D04 z dziennym użyciem oraz bezpieczną opłatą. Ceny pozostają odłożone. |
| D04/D05 i bonusowy prezent za Robux | Moduł offers ma odrzucenie/rezerwację/potwierdzenie, ale obecny produkcyjny ingress nie stanowi kompletnej ścieżki PreparePurchase/order/receipt z 28. Nie zaliczać jej testem samego modułu lub zwykłym ClaimOffer. |
| Silosy i Epic | Brak osobnych komend kupna silosu i Epic w bieżącym protokole; istniejące efekty i trwały stan nie zastępują sklepu i walidacji tych operacji. Potrzebne domknięcie dostępnych korzyści Pro oraz zakupu według zatwierdzonych reguł, bez wymyślania nowych parametrów. |
| Hyperloop i wagony | Oprócz bramki #70 nie ma komend stacji/wagonów, a integracja produkcji przenosi listę typów pojazdów bez długości pociągu. Wymaga osobnego dostarczenia modelu i operacji z 04; zakup typu 11 jako zwykłego pojazdu nie jest pełnym Hyperloop. |
| Konfiguracja wydarzeń | Integrator z #61 jest podłączony do wstrzykniętego liveEvents; Main domyślnie nie przekazuje produkcyjnej historii wydarzeń. Potrzebne zaufane źródło harmonogramu, wersji i kwalifikacji; nie stosować obecnego eventu do całej przeszłości. |
| Pety / inkubatory / fuzja / sklep boostów | Produkcyjne ścieżki wymagające niezatwierdzonych receptur/cen pozostają wyłączone; host przyjmuje jedynie jawne fixture INTERNAL_TEST_ONLY. Nie włączać ich w ramach tego audytu ani nie przenosić odłożonych liczb do produkcji. |
| Piggy | Warunkowy zakres premiery z 26, nadal zależny od odłożonych parametrów. Brak gotowego produktu nie jest tu nowym błędem wymagającym obejścia bilansu. |
| Studio / chmura / człowiek | S/D/H per scenariusz pozostają bez dowodu odbioru. Potrzebne osobno zlecone testy rzeczywistej replikacji, zapisu, przerwań i ergonomii. PASS L ani synchronizacja sceny ich nie zastępują. |

Kontrakty, Auto-Hatch passa i VIP pozostają poza bieżącym zakresem. Nie wykonano ponownej analizy mechanik referencyjnych ani symulacji progresji. Zalecana kolejność napraw bez bilansu: #63, następnie niezależne #64/#65, potem #66–70; szersze niedostarczone ścieżki wymagają odrębnego zakresu.

## Dowody i granice

[Skrypt reprodukcji](reaudit_after_51_62_20261025_repro.luau) uruchamia się lokalnie z root projektu przez Lune. [Wyniki i sumy kontrolne](implementation_reaudit_after_51_62_20261025.json). Log pełnego runnera: build/full-test-reaudit-20261025.log (lokalny, ignorowany). Próby używają izolowanych profili; nie są nową konfiguracją produkcji i nie zmieniają danych użytkowników.

Nie zmieniono kodu gry, istniejących testów, docs/17–21, danych referencyjnych ani istniejących raportów. Utworzono lokalne materiały audytu i osiem zgłoszeń GitHub. Trzy wcześniejsze nieśledzone pliki audytu pozostawiono nietknięte. Nie wykonywano commit/push, Studio, chmury, realnych zakupów lub przepisywania historii Git. To audyt wskazanych integracji z dodatkowymi próbami, nie dowód sprawdzenia każdej ścieżki i każdego możliwego stanu gry.
