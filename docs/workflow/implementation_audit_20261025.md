# Audyt implementacji HatchTheEgg — 25.10.2026

**Werdykt: wymaga istotnych poprawek przed wydaniem.** Istnieje szeroki zestaw modułów domenowych, entrypointy i prezentacja gry. Nie potwierdzono kompletnej zgodności implementacji z dokumentacją ani gotowości produkcyjnej. Potwierdzono 11 usterek: 2 P0, 7 P1 i 2 P2.

Badana wersja: [e1c0eb913b437f36859401bc7956e0aaf634a871](https://github.com/MarekZurek/Roblox-HatchTheEgg/commit/e1c0eb913b437f36859401bc7956e0aaf634a871); lokalny HEAD zgadzał się z publicznym main, working tree przed audytem był czysty. Audyt nie poprawiał kodu gry, nie zmieniał konfiguracji/bilansu, nie wykonywał zakupów ani nie modyfikował historii Git.

## Co rzeczywiście wykonano i sprawdzono

Uruchomiono istniejący ./tools/test.ps1 z przypiętym Lune 0.11.1, Rojo 7.7.1 i lokalnym Pythonem. Wynik: **28 zestawów, 67 616 asercji PASS**, generatory --check PASS, statyczny build **38 ModuleScript i 2 entrypointy**. To wynik L i kontroli statycznych w tej wersji, nie procent pokrycia wymagań. Aż 60 915 asercji pochodzi z NumericCodec i katalogu; ich liczba nie dowodzi pełnej integracji rozgrywki.

Dodatkowo wykonano [próby audytowe](audit_20261025_repro.luau) na rzeczywistych modułach Bootstrap/Timeline/ProgressActions/ClientBootstrap, z odizolowanym storage w pamięci. [Zapis wyników](audit_20261025_results.json). Próby świadomie dokumentują nieprawidłowe działanie; nie są nowym standardowym zestawem PASS gry.

Przegląd obejmował implementację uruchamianą przez Main, Bootstrap i Gateway, warstwy produkcji i czasu, resetów, produktów i petów oraz deklaracje dostaw 40–41, backlog i testy. Nie wykonano niezależnego ponownego sprawdzenia każdego elementu UI, każdej ceny lub całej macierzy wzorów. Nie uruchamiano Studio, prawdziwego DataStore, Marketplace ani testów mobilnych. Wcześniejszych deklaracji Studio w repo nie zaliczono automatycznie jako dowodu dla bieżącego SHA.

## Pokrycie dokumentacji — mapa zakresów

„Moduł/test L” oznacza obecność kodu i wykonany lokalny test; „częściowo” nie oznacza zgodności całej funkcji. Nie wyliczono sztucznego procentu pokrycia na podstawie liczby plików lub zamkniętych Issues.

| Obszar i dokumentacja | Obecna implementacja/dowód | Ocena względem realnej ścieżki gry |
|---|---|---|
| Liczby i serializacja — 27, 36 | NumericCodec; 15 702 asercje L | Mocne lokalne dowody arytmetyki; nie dowód całej ekonomii |
| Katalog — 01–04, reference_data, 37 | 56 Common, 24 Epic, 19 jaj/kurników, 12 pojazdów; 45 213 asercji katalogu | Dane dostępne; tabela Epic/Hyperloop nie jest jeszcze dowodem zakupu i użycia wszystkich efektów |
| Common, pojemność, transport — 01/03/04/38 | production_research i FarmActions, testy math/purchases | Częściowo; brak dowodu kompletnego zastosowania Epic, wagonów/stacji Hyperloop i Buy MAX. Nie traktować samego wpisu katalogu jako mechaniki |
| Wylęg, rezerwacje, IHR — 10/31/35/38 | hatching_rcb, PopulationMath, ihr; testy L | Rdzeń lokalny istnieje; reset ID grup jest niezgodny (#59). holdStep jest w module, nie znaleziono wywołania w serwerowym ticku |
| Produkcja aktualnego jaja i premie SE/PE — 02/05/27 | Tabele i funkcje progresji istnieją | Niezgodne w naliczaniu dochodu — #54 |
| Farm Value / Soul Eggs — 02/05/31 | fv_se; 358 asercji; ProgressActions | Czyste funkcje i reset istnieją; pełna ścieżka gracza nie jest ukończona, Prestige nie ma trasy Gateway |
| Sesja, fencing, kolejka — 27/28/34/39 | SessionRepository, Coordinator, kontrolowane awarie w testach | Dowody L; rzeczywista ścieżka startowa ma niebezpieczny fallback pamięci — #57 |
| Neutralne online/away/checkpoint — 10/27/39 | Timeline + integracje; fazowy checkpoint | Lokalny rdzeń istnieje, nie stanowi dowodu pełnego offline z efektami |
| Boosty / VD / pety w symulacji — 12/16/22 | EffectsManager i equipment oraz ich testy | Kontekst ginie w Bootstrap; zegar boosta nie jest rozliczany — #55 |
| Historyczne wydarzenia — 16/27 | Punktowy predykat w EffectsManager | Nawet bez Bootstrap graniczny krok nie jest ważony czasem — #61 |
| Pety / wyposażenie / inkubacja — 09/16/22/26 | equipment, serwerowe operacje, UI inkubatora | Efekty nie wpływają na ekonomię; wejście inkubacji umożliwia wymuszenie ceny i wyniku — #51/#55. Aktywne fixture nie zatwierdza bilansu |
| Fuzja i gwarancja — 22/23/27 | fusion, 103 asercje L | Logika modułu, ale przycisk zwraca fikcyjny sukces; receptury TEST_ONLY nie są bilansem produkcyjnym — #56 |
| Drony — 06/13/16 | rewards/drones, 89 asercji L, aktory 3D | Brak wymagania uprawnionego spawnu w ścieżce claim — #52 |
| Paczki 2+1 / bonusowe oferty — 13/16/22/24 | rewards/offers, 64 asercje L, prezentacja | Runtime tworzy ofertę przy odbiorze i nie trzyma jej stanu w trwałym agregacie — #53 |
| Kalendarz i trofea — 13/15/22 | calendar/trophies, 76 asercji L, okna UI | Moduły istnieją, rzeczywiste przyciski nie wywołują serwera — #56 |
| Pro / GE / Piggy / Buy MAX — 25/26/28 | products, ProcessReceipt, odczyt własności passów | Częściowo; sklep klienta ma atrapę sukcesu, Pro brak kwalifikacji +10 p.p., fallback storage zagraża trwałości — #56/#58/#57 |
| Onboarding — 31/35 | manager, TutorialController, 62 asercje L | Lokalne reguły istnieją; ukończenie przez odbiór kalendarza nie jest potwierdzone w produkcyjnym wiringu |
| UI / świat / animacje / audio — ui/, 29, 35 | HUD, FarmPlotBuilder, RoutePresentation, AudioController, Main | Kod i lokalne testy istnieją; wyglądu, ergonomii i wydajności S/H nie zweryfikowano tym audytem |
| Kontrakty i odłożony bilans — 17–21/26 | Dokumenty odłożenia istnieją | Poza bieżącą implementacją audytu; aktywne domyślne 100 GE i losowania petów nie uzyskują zatwierdzenia przez testy |
| Odbiór wydania — 29/40/41 | acceptance/release_candidate/verify_release | Zawyżone oznaczenie L/S/D i gotowości; test modułów nie sprawdza produkcyjnego połączenia — #60 |

## Potwierdzone usterki i zgłoszenia

| ID | Priorytet | Problem | GitHub |
|---|---|---|---|
| A01 | P0 | Klient wybiera koszt, gatunek i wariant peta przez HatchPetEgg | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/51) |
| A02 | P0 | HitDrone wypłaca nagrody za dowolne nigdy niespawnowane ID | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/52) |
| A03 | P1 | ClaimOffer tworzy nieistniejącą ofertę i wypłaca domyślne 50 000 | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/53) |
| A04 | P1 | Produkcja po zmianie jaja i zdobyciu SE/PE pozostaje na bazowym Edible | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/54) |
| A05 | P1 | Bootstrap pomija aktywne boosty i pety przy naliczaniu czasu | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/55) |
| A06 | P1 | Przyciski kalendarza, fuzji i zakupów zwracają fikcyjne APPLIED bez serwera | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/56) |
| A07 | P1 | Awaria DataStore w produkcji przełącza płatną grę na nietrwałą pamięć | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/57) |
| A08 | P1 | Pro włącza +10 p.p. bez ustalenia dostępności bonusu graczowi | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/58) |
| A09 | P2 | Zmiana jaja i prestiż zerują monotoniczny hatchGroupSequence | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/59) |
| A10 | P2 | Raporty i bramki wydania zawyżają pokrycie oraz poziomy S/D | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/60) |
| A11 | P1 | Wydarzenia dochodu nie są ważone czasem granicznego kroku | [zgłoszenie](https://github.com/MarekZurek/Roblox-HatchTheEgg/issues/61) |

## Dowody szczegółowe

### A01 — Klient wybiera koszt, gatunek i wariant peta przez HatchPetEgg

[src/server/Bootstrap.luau:993](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/Bootstrap.luau#L993). Main.server.luau:222 przekazuje całe message do hatchPet, a metoda kopiuje costGE/roll/variantRoll/petUid do argumentów operacji. Domena używa ich zamiast zaufanej ceny i losowania serwera.

**Odtworzenie:** Na nowym profilu (10 GE) wywołanie rzeczywistego Bootstrap:hatchPet('1',{costGE=0,roll=0,variantRoll=0,petUid='attacker-selected'}) zwróciło success=true. W trwałym profilu pojawił się rainbow Legendary drone_hawk; GE pozostało 10.

**Kontrakt:** docs/27–28: autorytet serwera, koszt i wynik; docs/26: niezatwierdzone parametry inkubacji pozostają odłożone.

**Kierunek naprawy:** Zdalne żądanie może określać wyłącznie dozwoloną intencję/identyfikator. Cenę, los i UID ustala serwer; odrzucić nadmiarowe pola przed domeną. Nie dobierać nowego bilansu; niezaprobowaną konfigurację utrzymać za bramką. Dodać test przechodzący tą samą ścieżką co Main.

### A02 — HitDrone wypłaca nagrody za dowolne nigdy niespawnowane ID

[src/server/Bootstrap.luau:490](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/Bootstrap.luau#L490). Gdy brak spawn, domainApply tworzy syntetyczny aktywny spawn z ID podanym w żądaniu. claimedDrones blokuje tylko to konkretne ID. Main obsługuje HitDrone przed ProtocolSchemas/Gateway.

**Odtworzenie:** Bez jakiegokolwiek spawn na serwerze dwa wywołania hitDrone('1','never-spawned-1') i hitDrone('1','never-spawned-2') zakończyły się sukcesem i realną zmianą cash/GE w snapshot.durable. Kwoty losowe; sukces obu nie zależy od istnienia drona.

**Kontrakt:** docs/06 oraz NEXT-06: serwerowy uprawniony spawn, trafienie i jedna nagroda; docs/28 walidacja wejścia.

**Kierunek naprawy:** Wymagać istniejącego, niewygasłego, przypisanego graczowi rejestru spawnów serwera i autorytatywnej kwalifikacji trafienia. Nie tworzyć spawn w ścieżce claim. Testy nieznanego ID, cudzej własności i powtórki.

### A03 — ClaimOffer tworzy nieistniejącą ofertę i wypłaca domyślne 50 000

[src/server/Bootstrap.luau:552](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/Bootstrap.luau#L552). Brak findOffer powoduje createOffer z fixture reward Cash=50000 zamiast odmowy. offersState żyje w playerSession, jest nowy przy join i jest zmieniany przed trwałym commit.

**Odtworzenie:** Na nowym koncie bez wystawionej oferty: claimOffer('1','never-offered') -> success=true, snapshot.durable.farm.cash='50000'. Żądanie z Main przyjmuje dowolny offerId.

**Kontrakt:** D04/D05/D07 w docs/22 i 24: stała wcześniej utworzona oferta, harmonogram 2+1, trwałość i atomowy odbiór.

**Kierunek naprawy:** Claim musi odnosić się do wcześniej zapisanej oferty; nie dopisywać nagrody w fallbacku. Stan oferty/rezerwacji/odbioru utrwalać z ekonomią, bez mutowania osobnego runtime przed potwierdzeniem. Test nieznanego ID i reconnect/awarii zapisu.

### A04 — Produkcja po zmianie jaja i zdobyciu SE/PE pozostaje na bazowym Edible

[src/server/FarmMath/production_research.luau:74](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/FarmMath/production_research.luau#L74). research() zawsze bierze catalog.getEgg(0).value. productionStep nie otrzymuje bieżącego eggIndex/permanent.SE/PE/Epic, a Timeline podaje rcbMultiplier=1. Pełne tabele i czyste funkcje progresji nie są połączone z pełnym modelem dochodu.

**Odtworzenie:** Rzeczywisty Bootstrap, 100 zasiedlonych kur, identyczny 1 s: eggIndex0 i eggIndex1 oba cash='0.83333333333333326'. Profil z SE=1000, PE=2 daje ten sam wynik co SE=PE=0. Test nie wymaga ustalania nowego bilansu.

**Kontrakt:** docs/02 i 05: wartość aktualnego jaja i trwały earning bonus; docs/27: poprawne źródła i warstwy mnożników.

**Kierunek naprawy:** Przekazać do produkcji aktualne jajo i potwierdzone efekty progresji, zachowując porządek arytmetyki. Testy po realnym UpgradeEgg i prestiżu, nie tylko gettery i tablice. Rozliczenie starego odcinka poprzedza zmianę.

### A05 — Bootstrap pomija aktywne boosty i pety przy naliczaniu czasu

[src/server/Bootstrap.luau:123](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/Bootstrap.luau#L123). profileToMemory zwraca tylko farm/accounting/settledWallThrough, bez effects, petów i uprawnień historycznych. _simulationAdvance konstruuje config bez liveEvents; memoryToWire nie utrwala zmienionych effects. Sam Timeline ma obsługę EffectsManager, ale nie dostaje rzeczywistego kontekstu.

**Odtworzenie:** 100 kur, Jimbo ×3 z remainingSeconds=1000: po 1 s cash nadal '0.83333333333333326', a pozostały czas nadal 1000. Wyposażony farmer_dog (+50% w katalogu modułu) daje ten sam cash co brak peta. Przebieg przez rzeczywisty Bootstrap.

**Kontrakt:** docs/16: składanie petów/boostów i historyczne wydarzenia; docs/27 §3: czas efektów i zapis; NEXT-03/04.

**Kierunek naprawy:** Połączyć wire–memory z pełnym kontekstem efektów i ich trwałym zapisem. Dodać testy pełnego Bootstrap dla dochodu, IHR, wygaśnięcia i powrotu, również Enlightenment. Nie aktywować niezatwierdzonych wartości bilansu.

### A06 — Przyciski kalendarza, fuzji i zakupów zwracają fikcyjne APPLIED bez serwera

[src/client/Bootstrap.luau:324](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/client/Bootstrap.luau#L324). claimDailyGift/claimTrophy/fusePets/equipPet/unequipPet/togglePetLock/buyBoost/purchaseProduct zwracają lokalne APPLIED/SUCCESS, gdy brak injected callback. Main nie wstrzykuje tych portów do ClientBootstrap. Gateway/Schemas nie obsługują większości tych poleceń; Prestige także nie ma obsłużonej trasy.

**Odtworzenie:** ClientBootstrap.new({playerId='1',send=function() sends+=1 end}); claimDailyGift(), fusePets('none',{'none2'}), purchaseProduct('ge_pack_small') -> APPLIED/SUCCESS, networkSends=0. dispatch dla Prestige/ClaimDailyGift/ClaimTrophy/FusePets/BuyBoost -> NOT_ACCEPTED/INVALID_REQUEST.

**Kontrakt:** docs/28: intencje klienta i tylko potwierdzony wynik serwera; docs/40–41 deklarują integrację systemów; D07.

**Kierunek naprawy:** Podłączyć rzeczywiste komendy i odpowiedzi oraz właściwą ścieżkę zakupu platformy. Brak implementacji ma oznaczać FEATURE_UNAVAILABLE, nie sukces. Testować przyciski z produkcyjnym wiringiem, bez injected success-stub.

### A07 — Awaria DataStore w produkcji przełącza płatną grę na nietrwałą pamięć

[src/server/Main.server.luau:64](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/Main.server.luau#L64). createProductionStore zwraca nil przy błędzie GetDataStore lub pojedynczego GetAsync. Nie sprawdza IsStudio. Bootstrap używa deps.store or createMemoryStore, a ProcessReceipt nadal może zwrócić PurchaseGranted po lokalnym commit.

**Odtworzenie:** Ścieżka statycznie potwierdzona: nieudana sonda -> persistentStore=nil -> ServerBootstrap.new -> pamięć procesu -> normalne sesje/zakupy. Restart/zmiana serwera nie zachowuje tego stanu. Nie wykonywano awarii prawdziwej chmury ani płatności.

**Kontrakt:** D07, docs/27 i 34: błąd odczytu nie oznacza nowego konta; potwierdzenie zakupu wymaga trwałości; PROD-04/05.

**Kierunek naprawy:** Fail closed w produkcji: blokada inicjalizacji/komend/fulfillment do odzyskania storage. Pamięć dopuszczać wyłącznie w jawnie wybranym trybie lokalnym bez prawdziwych zakupów. Test startu z niedostępnym portem.

### A08 — Pro włącza +10 p.p. bez ustalenia dostępności bonusu graczowi

[src/server/Bootstrap.luau:880](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/Bootstrap.luau#L880). grantEntitlement domyślnie przyjmuje paidRandomAllowed=true. Obie rzeczywiste ścieżki Main (odczyt własności GamePass i ukończony zakup) wywołują grantEntitlement bez kwalifikacji gracza. W src nie znaleziono integracji ustalającej tę dostępność.

**Odtworzenie:** grantEntitlement('1','pro_permit') bez kontekstu -> durable.entitlements.pro_plus10_enabled=true. Brak danych o dostępności jest potraktowany jak zezwolenie.

**Kontrakt:** Zatwierdzony wariant A, docs/26: uprawnienie do Pro oddzielne od bieżącej dostępności +10 p.p.; jawne ograniczenie przed zakupem.

**Kierunek naprawy:** Przekazywać wiarygodny wynik dostępności, z bezpieczną obsługą nieznanego stanu. Nie nadawać +10 p.p. wyłącznie na podstawie własności passa. Podgląd przed zakupem ma odzwierciedlać ten sam stan. Bez zmiany zatwierdzonej oferty.

### A09 — Zmiana jaja i prestiż zerują monotoniczny hatchGroupSequence

[src/server/ProgressActions.luau:245](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/ProgressActions.luau#L245). applyUpgradeEgg oraz applyPrestige ustawiają hatchGroupSequence='0', mimo że format ID hatch:N wymaga niewznawiania dawnych identyfikatorów.

**Odtworzenie:** ProfileSchema.createReference -> farm.hatchGroupSequence='123', accounting.currentFarmCash='1000000' -> ProgressActions.applyPrestige -> APPLIED i sequence='0'. Dwa miejsca resetu: linie245 i338.

**Kontrakt:** docs/38: licznik nie może być zerowany przez reconnect, zmianę jaja, prestiż lub kasowanie zamkniętych grup; docs/27 integralność.

**Kierunek naprawy:** Zachować monotoniczny licznik przy obu resetach. Testy: po resecie następna grupa ma nowe ID większe od poprzedniego; stare dotarcie nie może zamknąć nowej grupy.

### A10 — Raporty i bramki wydania zawyżają pokrycie oraz poziomy S/D

[docs/40_first_farm_completion_delivery.md:4](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/docs/40_first_farm_completion_delivery.md#L4). docs/40 deklaruje dostawę L/S/D; tests/acceptance zapisuje level='L/S/D' mimo lokalnego Lune. Docs/32 oznacza A01–A16 jako L/S/D 100%. tests/release_candidate uruchamia domeny bez produkcyjnego Bootstrap i deklaruje releaseCandidateReady=true; verify_release sprawdza flagi/wybrane teksty, nie wykrywa potwierdzonych luk runtime.

**Odtworzenie:** Główny runner na badanym SHA przechodzi 28 zestawów (67 616 asercji), 38 ModuleScript i2 entrypointy. Równocześnie dodatkowe lokalne próby potwierdziły niepodłączone komendy i błędne działanie ekonomii. Nie ma podstaw do utożsamienia liczby asercji z procentem wymagań lub chmurą.

**Kontrakt:** docs/29 i33: rozdzielić L (harness), S (Studio), D (rzeczywisty zapis), H. Sam PASS testów nie zalicza niewykonanych poziomów ani całego wydania.

**Kierunek naprawy:** Skorygować bieżące deklaracje oraz metadane wyników i wskazać dowody S/D/H per scenariusz, jeśli istnieją. Brakujące oznaczyć niewykonane/niezweryfikowane. Rozszerzyć testy o produkcyjny wiring. Nie przepisywać historycznych wyników jako nowych dowodów.

### A11 — Wydarzenia dochodu nie są ważone czasem granicznego kroku

[src/server/TimelineSimulation.luau:109](https://github.com/MarekZurek/Roblox-HatchTheEgg/blob/e1c0eb913b437f36859401bc7956e0aaf634a871/src/server/TimelineSimulation.luau#L109). Timeline odczytuje mnożnik wydarzenia wyłącznie na końcu kroku. EffectsManager stosuje punktowy predykat aktywności zamiast ważenia czasu.

**Odtworzenie:** Rzeczywisty Timeline: 100 kur, jajo0, krok300ms, event dochodu x3 aktywny przez pierwsze100ms. Wynik cash=0.25; wymagane ważenie daje 0.4166666666666667. Potwierdzono w izolowanym Lune.

**Kontrakt:** docs/16 sekcja3 i docs/27 sekcja3.2: średni mnożnik wydarzenia dochodu ważony rzeczywistym czasem. To zatwierdzona adaptacja.

**Kierunek naprawy:** Obliczać przecięcie okna wydarzenia z krokiem i ważyć mnożnik dochodu. Nie dodawać dodatkowych kroków IHR/boostów; zachować własną semantykę VD. Test granicy wydarzenia wewnątrz kroku, granic [start,end), silosów i checkpointu.

## Kolejność domknięcia

1. Usunąć możliwość wymuszenia peta oraz nagradzania fikcyjnych spawnów i ofert (#51–53).
2. Zablokować nietrwałą produkcję/fulfillment przy awarii storage i poprawić kwalifikację Pro (#57–58).
3. Przywrócić ekonomię aktualnego jaja, bonusy progresji i pełny kontekst efektów, następnie historyczne ważenie (#54–55, #61).
4. Podłączyć przyciski do prawdziwych, walidowanych komend i potwierdzonych wyników (#56), zachować monotoniczne ID (#59).
5. Uzupełnić testy produkcyjnego wiringu, a poziomy S/D/H i deklaracje wydania oprzeć na rzeczywistych dowodach (#60).

To kolejność naprawy zgodności, nie plan kalibracji. Nie wznawia odłożonego bilansu i nie uprawnia automatycznie do publikacji gry.

